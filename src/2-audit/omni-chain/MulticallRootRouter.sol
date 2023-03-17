// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import "./interfaces/IRootRouter.sol";
import { ICoreBridgeAgent as IBridgeAgent } from "./interfaces/ICoreBridgeAgent.sol";
import { IVirtualAccount, Call } from "./interfaces/IVirtualAccount.sol";

import { Path } from "./interfaces/Path.sol";
import { ISwapRouter } from "./interfaces/ISwapRouter.sol";
import { INonfungiblePositionManager } from "./interfaces/INonfungiblePositionManager.sol";

import { IUniswapV3Staker } from "@v3-staker/interfaces/IUniswapV3Staker.sol";

import { ITalosBaseStrategy } from "@talos/interfaces/ITalosBaseStrategy.sol";

import { IMulticall2 as IMulticall } from "./interfaces/IMulticall2.sol";

import { ERC20hTokenRoot } from "./token/ERC20hTokenRoot.sol";

import { IERC20hTokenRootFactory as IFactory } from "./interfaces/IERC20hTokenRootFactory.sol";

struct OutputParams {
    address recipient;
    address outputToken;
    uint256 amountOut;
    uint256 depositOut;
}

struct OutputMultipleParams {
    address recipient;
    address[] outputTokens;
    uint256[] amountsOut;
    uint256[] depositsOut;
}

/**
 * @title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
 * @author MaiaDAO
 * @dev Func IDs for calling these  functions through messaging layer.
 *
 *   CROSS-CHAIN MESSAGING FUNCIDs
 *   -----------------------------
 *   FUNC ID      | FUNC NAME
 *   -------------+---------------
 *   0x01         | multicallNoOutput
 *   0x02         | multicallSingleOutput
 *   0x03         | multicallMultipleOutput
 *   0x04         | multicallSignedNoOutput
 *   0x05         | multicallSignedSingleOutput
 *   0x06         | multicallSignedMultipleOutput
 *
 */
contract MulticallRootRouter is IRootRouter {
    using SafeTransferLib for address;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    uint256 public immutable localChainId;

    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    address public immutable localPortAddress;

    /// @notice Bridge Agent to maneg communcations and cross-chain assets. TODO
    address payable public immutable bridgeAgentAddress;

    /// @notice Ulysses Router Address
    address public immutable ulyssesRouterAddress;

    /// @notice Uni V3 Router Address
    address public immutable uniswapRouterAddress;

    /// @notice Multicall Address
    address public immutable multicallAddress;

    /// @notice Local Non Fungible Position Manager Address
    address public immutable nonFungiblePositionManagerAddress;

    /// @notice Local Uniswap V3 Staker Address
    address public immutable uniswapV3StakerAddress;

    uint256 public constant MIN_AMOUNT = 10**6;

    constructor(
        uint256 _localChainId,
        address _wrappedNativeToken,
        address _localPortAddress,
        address _bridgeAgentAddress,
        address _ulyssesRouterAddress,
        address multicallyAddress,
        address _uniswapRouterAddress,
        address _nonFungiblePositionManagerAddress,
        address _uniswapV3StakerAddress
    ) {
        localChainId = _localChainId;
        wrappedNativeToken = WETH9(_wrappedNativeToken);
        localPortAddress = _localPortAddress;
        bridgeAgentAddress = payable(_bridgeAgentAddress);
        ulyssesRouterAddress = _ulyssesRouterAddress;
        multicallAddress = multicallyAddress;
        uniswapRouterAddress = _uniswapRouterAddress;
        nonFungiblePositionManagerAddress = _nonFungiblePositionManagerAddress;
        uniswapV3StakerAddress = _uniswapV3StakerAddress;
    }

    /*///////////////////////////////////////////////////////////////
                        MULTICALL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     *   @notice Function to perform a set of actions on the omnichian environment without using the user's Virtual Acccount.
     *   @param calls to be executed.
     *
     */
    function multicall(IMulticall.Call[] memory calls)
        internal
        returns (uint256 blockNumber, bytes[] memory returnData)
    {
        //Call desired functions
        (blockNumber, returnData) = IMulticall(multicallAddress).aggregate(calls);
    }

    /**
     *   @notice Function to perform a swap given the amount of token input.
     *   @param userAccount Virtual Account address.
     *   @param calls Uniswap V3 and Ulysses Router calls.
     *   @param outputTokens Tokens to be bridged.
     *   @param amountsToBridge Amounts of tokens to be bridged.
     *   @param dParams Cross Chain Deposit parameters.
     *   @param fromChainId Chain Id of the chain where the deposit was made.
     *
     */
    function multicallSignedMultipleDepositInteraction(
        address userAccount,
        IMulticall.Call[] memory calls,
        address[] memory outputTokens,
        uint256[] memory amountsToBridge,
        DepositMultipleParams memory dParams,
        uint256 fromChainId
    ) internal {
        for (uint256 i = 0; i < dParams.hTokens.length; i++) {
            if (dParams.amounts[i] > 0) {
                // Get global address of deposited local hToken.
                address globalAddress = IPort(localPortAddress).getGlobalTokenFromLocal(
                    dParams.hTokens[i],
                    fromChainId
                );

                //Transfer assets to Virtual Account
                globalAddress.safeTransfer(userAccount, dParams.amounts[i]);
            }
        }

        //Call desired functions
        (, bytes memory returnData) = IVirtualAccount(userAccount).call(
            Call({
                target: multicallAddress,
                callData: abi.encodeWithSignature("aggregate(IMulticall.Call[])", calls)
            })
        );

        for (uint256 i = 0; i < outputTokens.length; i++) {
            //If requested Withdraw assets from Virtual Account
            if (amountsToBridge[i] > 0) {
                IVirtualAccount(userAccount).withdrawERC20(outputTokens[i], amountsToBridge[i]);
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                        INTERNAL HOOKS
    ////////////////////////////////////////////////////////////*/
    /**
     *  @notice Function to call 'clearToken' on the Root Port.
     *  @param recipient Address to receive the output hTokens.
     *  @param outputToken Address of the output hToken.
     *  @param amountOut Amount of output hTokens to send.
     *  @param depositOut Amount of output hTokens to deposit.
     *  @param toChain Chain Id of the destination chain.
     */
    function _approveAndCallOut(
        address recipient,
        address outputToken,
        uint256 amountOut,
        uint256 depositOut,
        uint256 toChain
    ) internal virtual {
        //Approve Root Port to spend/send output hTokens.
        ERC20hTokenRoot(outputToken).approve(localPortAddress, amountOut);

        //Move output hTokens from Root to Branch and call 'clearToken'.
        IBridgeAgent(bridgeAgentAddress).bridgeOutAndCall{ value: msg.value }(
            recipient,
            "",
            outputToken,
            amountOut,
            depositOut,
            toChain
        );
    }

    /**
        *  @notice Function to approve token spend Bridge Agent.
        *  @param recipient Address to receive the output tokens.
        *  @param outputTokens Addresses of the output hTokens.
        *  @param amountsOut Total amount of tokens to send.
        *  @param depositsOut Amounts of tokens to withdraw from destination port.
        * 

     */
    function _approveMultipleAndCallOut(
        address recipient,
        address[] memory outputTokens,
        uint256[] memory amountsOut,
        uint256[] memory depositsOut,
        uint256 toChain
    ) internal virtual {
        //For each output token
        for (uint256 i = 0; i < outputTokens.length; ) {
            //Approve Root Port to spend output hTokens.
            ERC20hTokenRoot(outputTokens[i]).approve(localPortAddress, amountsOut[i]);
            unchecked {
                ++i;
            }
        }

        //Move output hTokens from Root to Branch and call 'clearTokens'.
        IBridgeAgent(bridgeAgentAddress).bridgeOutAndCallMultiple{ value: msg.value }(
            recipient,
            "",
            outputTokens,
            amountsOut,
            depositsOut,
            toChain
        );
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL FUNCTIONS
    ////////////////////////////////////////////////////////////*/
    function anyExecuteResponse(
        bytes1 funcId,
        bytes calldata data,
        uint256 fromChainId
    ) external payable override requiresAgent returns (bool success, bytes memory result) {
        revert();
    }

    /**
     *     @notice Function responsible of executing a crosschain request without any deposit.
     *     @param funcId 1 byte Router function identifier.
     *     @param rlpEncodedData data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     *      0x01         |  multicallNoOutput
     *      0x02         |  multicallSingleOutput
     *      0x03         |  multicallMultipleOutput
     *      0x04         |  multicallSignedNoOutput
     *      0x05         |  multicallSignedSingleOutput
     *      0x06         |  multicallSignedMultipleOutput
     *
     */
    function anyExecute(
        bytes1 funcId,
        bytes calldata rlpEncodedData,
        uint256 fromChainId
    ) external payable override requiresAgent returns (bool success, bytes memory result) {
        /// FUNC ID: 1 (multicallNoOutput)
        if (funcId == 0x01) {
            IMulticall.Call[] memory callData = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                (IMulticall.Call[])
            ); // TODO max 32 bytes32 slots

            (uint256 blockNumber, bytes[] memory returnData) = multicall(callData);

            /// FUNC ID: 2 (multicallSingleOutput)
        } else if (funcId == 0x02) {
            (
                IMulticall.Call[] memory callData,
                OutputParams memory outputParams,
                uint256 toChain
            ) = abi.decode(
                    RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                    (IMulticall.Call[], OutputParams, uint256)
                ); // TODO max 32 bytes32 slots

            (uint256 blockNumber, bytes[] memory returnData) = multicall(callData);

            _approveAndCallOut(
                outputParams.recipient,
                outputParams.outputToken,
                outputParams.amountOut,
                outputParams.depositOut,
                toChain
            );

            /// FUNC ID: 3 (multicallMultipleOutput)
        } else if (funcId == 0x03) {
            (
                IMulticall.Call[] memory callData,
                OutputMultipleParams memory outputParams,
                uint256 toChain
            ) = abi.decode(
                    RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                    (IMulticall.Call[], OutputMultipleParams, uint256)
                ); // TODO max 32 bytes32 slots

            (uint256 blockNumber, bytes[] memory returnData) = multicall(callData);

            _approveMultipleAndCallOut(
                outputParams.recipient,
                outputParams.outputTokens,
                outputParams.amountsOut,
                outputParams.depositsOut,
                toChain
            );
            /// UNRECOGNIZED FUNC ID
        } else {
            return (false, "FuncID not recognized!");
        }

        emit LogCallin(funcId, rlpEncodedData, fromChainId);
        return (true, "");
    }

    /**
     *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information attached.
     *   @param funcId 1 byte Router function identifier.
     *   @param rlpEncodedData execution data received from messaging layer.
     *   @param dParams cross-chain deposit information.
     *   @param fromChainId chain where the request originated from.
     *
     *   4            | exactInputSingle
     *   5            | exactInput
     *   6            | exactOutputSingle
     *   7            | exactOutput
     *
     */
    function anyExecute(
        bytes1 funcId,
        bytes calldata rlpEncodedData,
        DepositParams memory dParams,
        uint256 fromChainId
    ) external payable override requiresAgent returns (bool success, bytes memory result) {
        /// FUNC ID: 1 (multicallNoOutput)
        if (funcId == 0x01) {
            IMulticall.Call[] memory calls = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, 32),
                (IMulticall.Call[])
            ); // TODO max 32 bytes32 slots

            (uint256 blockNumber, bytes[] memory returnData) = multicall(calls);

            emit LogCallin(funcId, rlpEncodedData, fromChainId);

            /// FUNC ID: 2 (multicallSingleOutput)
        } else if (funcId == 0x02) {
            (IMulticall.Call[] memory calls, OutputParams memory outputParams) = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, 35),
                (IMulticall.Call[], OutputParams)
            ); // TODO max 32 bytes32 slots

            (uint256 blockNumber, bytes[] memory returnData) = multicall(calls);

            _approveAndCallOut(
                outputParams.recipient,
                outputParams.outputToken,
                outputParams.amountOut,
                outputParams.depositOut,
                dParams.toChain
            );

            emit LogCallin(funcId, rlpEncodedData, fromChainId);

            /// FUNC ID: 3 (multicallMultipleOutput)
        } else if (funcId == 0x03) {
            (IMulticall.Call[] memory calls, OutputMultipleParams memory outputParams) = abi
                .decode(
                    RLPDecoder.decodeCallData(rlpEncodedData, 42),
                    (IMulticall.Call[], OutputMultipleParams)
                ); // TODO max 32 bytes32 slots

            (uint256 blockNumber, bytes[] memory returnData) = multicall(calls);

            _approveMultipleAndCallOut(
                outputParams.recipient,
                outputParams.outputTokens,
                outputParams.amountsOut,
                outputParams.depositsOut,
                dParams.toChain
            );

            /// UNRECOGNIZED FUNC ID
        } else {
            return (false, "FuncID not recognized!");
        }

        emit LogCallin(funcId, rlpEncodedData, fromChainId);
        return (true, "");
    }

    /**
     *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information for multiple assets attached.
     *   @param funcId 1 byte Router function identifier.
     *   @param rlpEncodedData execution data received from messaging layer.
     *   @param dParams cross-chain multiple deposit information.
     *   @param fromChainId chain where the request originated from.
     *
     */
    function anyExecute(
        bytes1 funcId,
        bytes calldata rlpEncodedData,
        DepositMultipleParams memory dParams,
        uint256 fromChainId
    ) external payable requiresAgent returns (bool, bytes memory) {
        /// FUNC ID: 1 (multicallNoOutput)
        if (funcId == 0x01) {
            IMulticall.Call[] memory calls = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, 32),
                (IMulticall.Call[])
            ); // TODO max 32 bytes32 slots

            (uint256 blockNumber, bytes[] memory returnData) = multicall(calls);

            emit LogCallin(funcId, rlpEncodedData, fromChainId);

            /// FUNC ID: 2 (multicallSingleOutput)
        } else if (funcId == 0x02) {
            (IMulticall.Call[] memory calls, OutputParams memory outputParams) = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, 35),
                (IMulticall.Call[], OutputParams)
            ); // TODO max 32 bytes32 slots

            (uint256 blockNumber, bytes[] memory returnData) = multicall(calls);

            _approveAndCallOut(
                outputParams.recipient,
                outputParams.outputToken,
                outputParams.amountOut,
                outputParams.depositOut,
                dParams.toChain
            );

            emit LogCallin(funcId, rlpEncodedData, fromChainId);

            /// FUNC ID: 3 (multicallMultipleOutput)
        } else if (funcId == 0x03) {
            (
                IMulticall.Call[] memory calls,
                OutputMultipleParams memory outputParams
            ) = abi.decode(
                    RLPDecoder.decodeCallData(rlpEncodedData, 42),
                    (IMulticall.Call[], OutputMultipleParams)
                ); // TODO max 32 bytes32 slots

            (uint256 blockNumber, bytes[] memory returnData) = multicall(calls);

            _approveMultipleAndCallOut(
                outputParams.recipient,
                outputParams.outputTokens,
                outputParams.amountsOut,
                outputParams.depositsOut,
                dParams.toChain
            );

            /// UNRECOGNIZED FUNC ID
        } else {
            return (false, "FuncID not recognized!");
        }

        emit LogCallin(funcId, rlpEncodedData, fromChainId);
        return (true, "");
    }

    /**
     *     @notice Function responsible of executing a signed crosschain request without any deposit.
     *     @param funcId 1 byte Router function identifier.
     *     @param rlpEncodedData execution data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     *   10           | decreaseLiquidity
     *   11           | collect
     *   13           | redeeem
     *   16           | unstakeAndWithdraw
     *   17           | unstakeAndWithdrawAndRemoveLiquidity
     *   18           | unstakeAndRestakeToNewAggregator
     *
     */
    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedData,
        address userAccount,
        uint256 fromChainId
    ) external payable override requiresAgent returns (bool success, bytes memory result) {
        /// FUNC ID: 1 (multicallNoOutput)
        if (funcId == 0x01) {
            IMulticall.Call[] memory calls = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                (IMulticall.Call[])
            ); // TODO max 32 bytes32 slots

            //Call desired functions
            (, bytes memory returnData) = IVirtualAccount(userAccount).call(
                Call({
                    target: multicallAddress,
                    callData: abi.encodeWithSignature("aggregate(IMulticall.Call[])", calls)
                })
            );

            /// FUNC ID: 2 (multicallSingleOutput)
        } else if (funcId == 0x02) {
            (
                IMulticall.Call[] memory calls,
                OutputParams memory outputParams,
                uint256 toChain
            ) = abi.decode(
                    RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                    (IMulticall.Call[], OutputParams, uint256)
                ); // TODO max 32 bytes32 slots

            //Call desired functions
            (, bytes memory returnData) = IVirtualAccount(userAccount).call(
                Call({
                    target: multicallAddress,
                    callData: abi.encodeWithSignature("aggregate(IMulticall.Call[])", calls)
                })
            );

            // Withdraw assets from Virtual Account
            IVirtualAccount(userAccount).withdrawERC20(
                outputParams.outputToken,
                outputParams.amountOut
            );

            _approveAndCallOut(
                outputParams.recipient,
                outputParams.outputToken,
                outputParams.amountOut,
                outputParams.depositOut,
                toChain
            );

            /// FUNC ID: 3 (multicallMultipleOutput)
        } else if (funcId == 0x03) {
            (
                IMulticall.Call[] memory calls,
                OutputMultipleParams memory outputParams,
                uint256 toChain
            ) = abi.decode(
                    RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                    (IMulticall.Call[], OutputMultipleParams, uint256)
                ); // TODO max 32 bytes32 slots

            //Call desired functions
            (, bytes memory returnData) = IVirtualAccount(userAccount).call(
                Call({
                    target: multicallAddress,
                    callData: abi.encodeWithSignature("aggregate(IMulticall.Call[])", calls)
                })
            );

            for (uint256 i = 0; i < outputParams.outputTokens.length; ) {
                IVirtualAccount(userAccount).withdrawERC20(
                    outputParams.outputTokens[i],
                    outputParams.amountsOut[i]
                );

                unchecked {
                    ++i;
                }
            }

            _approveMultipleAndCallOut(
                outputParams.recipient,
                outputParams.outputTokens,
                outputParams.amountsOut,
                outputParams.depositsOut,
                toChain
            );
            /// UNRECOGNIZED FUNC ID
        } else {
            return (false, "FuncID not recognized!");
        }

        emit LogCallin(funcId, rlpEncodedData, fromChainId);
        return (true, "");
    }

    /**
     *     @notice Function responsible of executing a signed crosschain request with single asset deposit.
     *     @param funcId 1 byte Router function identifier.
     *     @param rlpEncodedData execution data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     *    8           | mint
     *    9           | increaseLiquidity
     *   12           | deposit
     *   14           | depositAndStake
     *   15           | mintDepositAndStake
     *   17           | unstakeAndWithdrawAndRemoveLiquidity
     *   18           | unstakeAndRestakeToNewAggregator
     *
     */
    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedData,
        DepositParams memory dParams,
        address userAccount,
        uint256 fromChainId
    ) external payable override requiresAgent returns (bool success, bytes memory result) {
        /// FUNC ID: 1 (multicallNoOutput)
        if (funcId == 0x01) {
            IMulticall.Call[] memory calls = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                (IMulticall.Call[])
            ); // TODO max 32 bytes32 slots

            //Call desired functions
            (, bytes memory returnData) = IVirtualAccount(userAccount).call(
                Call({
                    target: multicallAddress,
                    callData: abi.encodeWithSignature("aggregate(IMulticall.Call[])", calls)
                })
            );

            /// FUNC ID: 2 (multicallSingleOutput)
        } else if (funcId == 0x02) {
            (
                IMulticall.Call[] memory calls,
                OutputParams memory outputParams,
                uint256 toChain
            ) = abi.decode(
                    RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                    (IMulticall.Call[], OutputParams, uint256)
                ); // TODO max 32 bytes32 slots

            //Call desired functions
            (, bytes memory returnData) = IVirtualAccount(userAccount).call(
                Call({
                    target: multicallAddress,
                    callData: abi.encodeWithSignature("aggregate(IMulticall.Call[])", calls)
                })
            );

            // Withdraw assets from Virtual Account
            IVirtualAccount(userAccount).withdrawERC20(
                outputParams.outputToken,
                outputParams.amountOut
            );

            _approveAndCallOut(
                outputParams.recipient,
                outputParams.outputToken,
                outputParams.amountOut,
                outputParams.depositOut,
                toChain
            );

            /// FUNC ID: 3 (multicallMultipleOutput)
        } else if (funcId == 0x03) {
            (
                IMulticall.Call[] memory calls,
                OutputMultipleParams memory outputParams,
                uint256 toChain
            ) = abi.decode(
                    RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                    (IMulticall.Call[], OutputMultipleParams, uint256)
                ); // TODO max 32 bytes32 slots

            //Call desired functions
            (, bytes memory returnData) = IVirtualAccount(userAccount).call(
                Call({
                    target: multicallAddress,
                    callData: abi.encodeWithSignature("aggregate(IMulticall.Call[])", calls)
                })
            );

            for (uint256 i = 0; i < outputParams.outputTokens.length; ) {
                IVirtualAccount(userAccount).withdrawERC20(
                    outputParams.outputTokens[i],
                    outputParams.amountsOut[i]
                );

                unchecked {
                    ++i;
                }
            }

            _approveMultipleAndCallOut(
                outputParams.recipient,
                outputParams.outputTokens,
                outputParams.amountsOut,
                outputParams.depositsOut,
                toChain
            );
            /// UNRECOGNIZED FUNC ID
        } else {
            return (false, "FuncID not recognized!");
        }

        emit LogCallin(funcId, rlpEncodedData, fromChainId);
        return (true, "");
    }

    /**
     *     @notice Function responsible of executing a signed crosschain request with multiple asset deposit.
     *     @param funcId 1 byte Router function identifier.
     *     @param rlpEncodedData execution data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     *    8           | mint
     *    9           | increaseLiquidity
     *   12           | deposit
     *   14           | depositAndStake
     *   15           | mintDepositAndStake
     *   17           | unstakeAndWithdrawAndRemoveLiquidity
     *   18           | unstakeAndRestakeToNewAggregator
     *
     */
    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedData,
        DepositMultipleParams memory dParams,
        address userAccount,
        uint256 fromChainId
    ) external payable returns (bool success, bytes memory result) {
        /// FUNC ID: 1 (multicallNoOutput)
        if (funcId == 0x01) {
            IMulticall.Call[] memory calls = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                (IMulticall.Call[])
            ); // TODO max 32 bytes32 slots

            //Call desired functions
            (, bytes memory returnData) = IVirtualAccount(userAccount).call(
                Call({
                    target: multicallAddress,
                    callData: abi.encodeWithSignature("aggregate(IMulticall.Call[])", calls)
                })
            );

            /// FUNC ID: 2 (multicallSingleOutput)
        } else if (funcId == 0x02) {
            (
                IMulticall.Call[] memory calls,
                OutputParams memory outputParams,
                uint256 toChain
            ) = abi.decode(
                    RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                    (IMulticall.Call[], OutputParams, uint256)
                ); // TODO max 32 bytes32 slots

            //Call desired functions
            (, bytes memory returnData) = IVirtualAccount(userAccount).call(
                Call({
                    target: multicallAddress,
                    callData: abi.encodeWithSignature("aggregate(IMulticall.Call[])", calls)
                })
            );

            // Withdraw assets from Virtual Account
            IVirtualAccount(userAccount).withdrawERC20(
                outputParams.outputToken,
                outputParams.amountOut
            );

            _approveAndCallOut(
                outputParams.recipient,
                outputParams.outputToken,
                outputParams.amountOut,
                outputParams.depositOut,
                toChain
            );

            /// FUNC ID: 3 (multicallMultipleOutput)
        } else if (funcId == 0x03) {
            (
                IMulticall.Call[] memory calls,
                OutputMultipleParams memory outputParams,
                uint256 toChain
            ) = abi.decode(
                    RLPDecoder.decodeCallData(rlpEncodedData, rlpEncodedData.length),
                    (IMulticall.Call[], OutputMultipleParams, uint256)
                ); // TODO max 32 bytes32 slots

            //Call desired functions
            (, bytes memory returnData) = IVirtualAccount(userAccount).call(
                Call({
                    target: multicallAddress,
                    callData: abi.encodeWithSignature("aggregate(IMulticall.Call[])", calls)
                })
            );

            for (uint256 i = 0; i < outputParams.outputTokens.length; ) {
                IVirtualAccount(userAccount).withdrawERC20(
                    outputParams.outputTokens[i],
                    outputParams.amountsOut[i]
                );

                unchecked {
                    ++i;
                }
            }

            _approveMultipleAndCallOut(
                outputParams.recipient,
                outputParams.outputTokens,
                outputParams.amountsOut,
                outputParams.depositsOut,
                toChain
            );
            /// UNRECOGNIZED FUNC ID
        } else {
            return (false, "FuncID not recognized!");
        }

        emit LogCallin(funcId, rlpEncodedData, fromChainId);
        return (true, "");
    }

    /**
     *     @notice Function responsible for any necessary actions upon fallback.
     *     @param data execution data received from messaging layer.
     *     @dev additional fallback logic not necessary for this router.
     */
    function anyFallback(bytes calldata data) external returns (bool success, bytes memory result) {
        return (true, "");
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    ////////////////////////////////////////////////////////////*/

    /// @notice Modifier for a simple re-entrancy check.
    uint256 internal _unlocked = 1;

    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /// @notice require msg sender == active branch interface
    modifier requiresAgent() {
        _requiresAgent();
        _;
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresAgent() internal view {
        require(msg.sender == bridgeAgentAddress, "Unauthorized Caller");
    }
}
