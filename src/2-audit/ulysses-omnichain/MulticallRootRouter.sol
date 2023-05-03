// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import "./interfaces/IRootRouter.sol";
import {ICoreBridgeAgent as IBridgeAgent} from "./interfaces/ICoreBridgeAgent.sol";
import {IVirtualAccount, Call} from "./interfaces/IVirtualAccount.sol";

import {IMulticall2 as IMulticall} from "./interfaces/IMulticall2.sol";

import {ERC20hTokenRoot} from "./token/ERC20hTokenRoot.sol";

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
contract MulticallRootRouter is IRootRouter, Ownable {
    using SafeTransferLib for address;

    uint256 private constant MAX_LENGTH = 20 * 32;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    uint256 public immutable localChainId;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    address public immutable localPortAddress;

    /// @notice Multicall Address
    address public immutable multicallAddress;

    /// @notice Bridge Agent to maneg communcations and cross-chain assets.
    address payable public bridgeAgentAddress;

    uint256 public constant MIN_AMOUNT = 10 ** 6;

    constructor(uint256 _localChainId, address _localPortAddress, address _multicallAddress) {
        require(_localPortAddress != address(0), "Local Port Address cannot be 0");
        require(_multicallAddress != address(0), "Multicall Address cannot be 0");

        localChainId = _localChainId;
        localPortAddress = _localPortAddress;
        multicallAddress = _multicallAddress;
        _initializeOwner(msg.sender);
    }

    function initialize(address _bridgeAgentAddress) external onlyOwner {
        require(_bridgeAgentAddress != address(0), "Bridge Agent Address cannot be 0");

        bridgeAgentAddress = payable(_bridgeAgentAddress);
        renounceOwnership();
    }

    /*///////////////////////////////////////////////////////////////
                        MULTICALL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     *   @notice Function to perform a set of actions on the omnichian environment without using the user's Virtual Acccount.
     *   @param calls to be executed.
     *
     */
    function _multicall(IMulticall.Call[] memory calls)
        internal
        returns (uint256 blockNumber, bytes[] memory returnData)
    {
        //Call desired functions
        (blockNumber, returnData) = IMulticall(multicallAddress).aggregate(calls);
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
        uint24 toChain
    ) internal virtual {
        //Approve Root Port to spend/send output hTokens.
        ERC20hTokenRoot(outputToken).approve(bridgeAgentAddress, amountOut);

        //Move output hTokens from Root to Branch and call 'clearToken'.
        IBridgeAgent(bridgeAgentAddress).callOutAndBridge{value: msg.value}(
            recipient, "", outputToken, amountOut, depositOut, toChain
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
        uint24 toChain
    ) internal virtual {
        //For each output token
        for (uint256 i = 0; i < outputTokens.length;) {
            //Approve Root Port to spend output hTokens.
            ERC20hTokenRoot(outputTokens[i]).approve(bridgeAgentAddress, amountsOut[i]);
            unchecked {
                ++i;
            }
        }

        //Move output hTokens from Root to Branch and call 'clearTokens'.
        IBridgeAgent(bridgeAgentAddress).callOutAndBridgeMultiple{value: msg.value}(
            recipient, "", outputTokens, amountsOut, depositsOut, toChain
        );
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL FUNCTIONS
    ////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootRouter
    /// @dev This function will revert when called.
    function anyExecuteResponse(bytes1, bytes calldata, uint24)
        external
        payable
        override
        requiresAgent
        returns (bool, bytes memory)
    {
        revert();
    }

    /**
     *  @inheritdoc IRootRouter
     *  @dev
     *      0x01         |  multicallNoOutput
     *      0x02         |  multicallSingleOutput
     *      0x03         |  multicallMultipleOutput
     *      0x04         |  multicallSignedNoOutput
     *      0x05         |  multicallSignedSingleOutput
     *      0x06         |  multicallSignedMultipleOutput
     *
     */
    function anyExecute(bytes1 funcId, bytes calldata rlpEncodedData, uint24 fromChainId)
        external
        payable
        override
        requiresAgent
        returns (bool, bytes memory)
    {
        /// FUNC ID: 1 (multicallNoOutput)
        if (funcId == 0x01) {
            IMulticall.Call[] memory callData =
                abi.decode(RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (IMulticall.Call[]));

            _multicall(callData);

            /// FUNC ID: 2 (multicallSingleOutput)
        } else if (funcId == 0x02) {
            (IMulticall.Call[] memory callData, OutputParams memory outputParams, uint24 toChain) = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (IMulticall.Call[], OutputParams, uint24)
            );

            _multicall(callData);

            _approveAndCallOut(
                outputParams.recipient,
                outputParams.outputToken,
                outputParams.amountOut,
                outputParams.depositOut,
                toChain
            );

            /// FUNC ID: 3 (multicallMultipleOutput)
        } else if (funcId == 0x03) {
            (IMulticall.Call[] memory callData, OutputMultipleParams memory outputParams, uint24 toChain) = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (IMulticall.Call[], OutputMultipleParams, uint24)
            );

            _multicall(callData);

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
     *  @inheritdoc IRootRouter
     *  @dev
     *
     */
    function anyExecuteDepositSingle(bytes1, bytes calldata, DepositParams calldata, uint24)
        external
        payable
        override
        requiresAgent
        returns (bool, bytes memory)
    {
        revert();
    }

    /**
     * @inheritdoc IRootRouter
     */
    function anyExecuteDepositMultiple(bytes1, bytes calldata, DepositMultipleParams calldata, uint24)
        external
        payable
        requiresAgent
        returns (bool, bytes memory)
    {
        revert();
    }

    /**
     *  @inheritdoc IRootRouter
     *  @dev
     *
     */
    function anyExecuteSigned(bytes1 funcId, bytes calldata rlpEncodedData, address userAccount, uint24 fromChainId)
        external
        payable
        override
        requiresAgent
        returns (bool, bytes memory)
    {
        /// FUNC ID: 1 (multicallNoOutput)
        if (funcId == 0x01) {
            Call[] memory calls = abi.decode(RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (Call[]));

            //Call desired functions
            IVirtualAccount(userAccount).call(calls);

            /// FUNC ID: 2 (multicallSingleOutput)
        } else if (funcId == 0x02) {
            (Call[] memory calls, OutputParams memory outputParams, uint24 toChain) =
                abi.decode(RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (Call[], OutputParams, uint24));

            //Call desired functions
            IVirtualAccount(userAccount).call(calls);

            // Withdraw assets from Virtual Account
            IVirtualAccount(userAccount).withdrawERC20(outputParams.outputToken, outputParams.amountOut);

            _approveAndCallOut(
                outputParams.recipient,
                outputParams.outputToken,
                outputParams.amountOut,
                outputParams.depositOut,
                toChain
            );

            /// FUNC ID: 3 (multicallMultipleOutput)
        } else if (funcId == 0x03) {
            (Call[] memory calls, OutputMultipleParams memory outputParams, uint24 toChain) = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (Call[], OutputMultipleParams, uint24)
            );

            //Call desired functions
            IVirtualAccount(userAccount).call(calls);

            for (uint256 i = 0; i < outputParams.outputTokens.length;) {
                IVirtualAccount(userAccount).withdrawERC20(outputParams.outputTokens[i], outputParams.amountsOut[i]);

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
     *  @inheritdoc IRootRouter
     *  @dev
     *    8           | mint
     *    9           | increaseLiquidity
     *   12           | deposit
     *   14           | depositAndStake
     *   15           | mintDepositAndStake
     *   17           | unstakeAndWithdrawAndRemoveLiquidity
     *   18           | unstakeAndRestakeToNewAggregator
     *
     */
    function anyExecuteSignedDepositSingle(
        bytes1 funcId,
        bytes calldata rlpEncodedData,
        DepositParams calldata,
        address userAccount,
        uint24 fromChainId
    ) external payable override requiresAgent returns (bool success, bytes memory result) {
        /// FUNC ID: 1 (multicallNoOutput)
        if (funcId == 0x01) {
            Call[] memory calls = abi.decode(RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (Call[]));

            //Call desired functions
            IVirtualAccount(userAccount).call(calls);

            /// FUNC ID: 2 (multicallSingleOutput)
        } else if (funcId == 0x02) {
            (Call[] memory calls, OutputParams memory outputParams, uint24 toChain) =
                abi.decode(RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (Call[], OutputParams, uint24));

            //Call desired functions
            IVirtualAccount(userAccount).call(calls);

            // Withdraw assets from Virtual Account
            IVirtualAccount(userAccount).withdrawERC20(outputParams.outputToken, outputParams.amountOut);

            _approveAndCallOut(
                outputParams.recipient,
                outputParams.outputToken,
                outputParams.amountOut,
                outputParams.depositOut,
                toChain
            );

            /// FUNC ID: 3 (multicallMultipleOutput)
        } else if (funcId == 0x03) {
            (Call[] memory calls, OutputMultipleParams memory outputParams, uint24 toChain) = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (Call[], OutputMultipleParams, uint24)
            );

            //Call desired functions
            IVirtualAccount(userAccount).call(calls);

            for (uint256 i = 0; i < outputParams.outputTokens.length;) {
                IVirtualAccount(userAccount).withdrawERC20(outputParams.outputTokens[i], outputParams.amountsOut[i]);

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
     *  @inheritdoc IRootRouter
     *  @dev
     *
     */
    function anyExecuteSignedDepositMultiple(
        bytes1 funcId,
        bytes memory rlpEncodedData,
        DepositMultipleParams calldata,
        address userAccount,
        uint24 fromChainId
    ) external payable requiresAgent returns (bool success, bytes memory result) {
        /// FUNC ID: 1 (multicallNoOutput)
        if (funcId == 0x01) {
            Call[] memory calls = abi.decode(RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (Call[]));

            //Call desired functions
            IVirtualAccount(userAccount).call(calls);

            /// FUNC ID: 2 (multicallSingleOutput)
        } else if (funcId == 0x02) {
            (Call[] memory calls, OutputParams memory outputParams, uint24 toChain) =
                abi.decode(RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (Call[], OutputParams, uint24));

            //Call desired functions
            IVirtualAccount(userAccount).call(calls);

            // Withdraw assets from Virtual Account
            IVirtualAccount(userAccount).withdrawERC20(outputParams.outputToken, outputParams.amountOut);

            _approveAndCallOut(
                outputParams.recipient,
                outputParams.outputToken,
                outputParams.amountOut,
                outputParams.depositOut,
                toChain
            );

            /// FUNC ID: 3 (multicallMultipleOutput)
        } else if (funcId == 0x03) {
            (Call[] memory calls, OutputMultipleParams memory outputParams, uint24 toChain) = abi.decode(
                RLPDecoder.decodeCallData(rlpEncodedData, MAX_LENGTH), (Call[], OutputMultipleParams, uint24)
            );

            //Call desired functions
            IVirtualAccount(userAccount).call(calls);

            for (uint256 i = 0; i < outputParams.outputTokens.length;) {
                IVirtualAccount(userAccount).withdrawERC20(outputParams.outputTokens[i], outputParams.amountsOut[i]);

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
     *  @inheritdoc IRootRouter
     */
    function anyFallback(bytes calldata) external pure returns (bool, bytes memory) {
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
