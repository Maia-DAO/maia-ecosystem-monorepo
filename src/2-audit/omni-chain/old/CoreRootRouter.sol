// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
// import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

// import "./interfaces/IRootRouter.sol";
// import { ICoreBridgeAgent as IBridgeAgent } from "./interfaces/ICoreBridgeAgent.sol";
// import { IVirtualAccount, Call } from "./interfaces/IVirtualAccount.sol";

// import { Path } from "./interfaces/Path.sol";
// import { ISwapRouter } from "./interfaces/ISwapRouter.sol";
// import { INonfungiblePositionManager } from "./interfaces/INonfungiblePositionManager.sol";

// import { IUniswapV3Staker } from "@v3-staker/interfaces/IUniswapV3Staker.sol";

// import { ITalosBaseStrategy } from "@talos/interfaces/ITalosBaseStrategy.sol";

// import { IFlywheelCore } from "@rewards/interfaces/IFlywheelCore.sol";

// import { HERMES } from "@hermes/tokens/HERMES.sol";
// import { bHermes as bHERMES } from "@hermes/bHermes.sol";
// import { bHermesBoost as bHERMESBoost } from "@hermes/tokens/bHermesBoost.sol";
// import { bHermesGauges as bHERMESGauges } from "@hermes/tokens/bHermesGauges.sol";
// import { bHermesVotes as bHERMESVotes } from "@hermes/tokens/bHermesVotes.sol";

// import { ERC20hTokenRoot } from "./token/ERC20hTokenRoot.sol";

// import { IERC20hTokenRootFactory as IFactory } from "./interfaces/IERC20hTokenRootFactory.sol";

// /**
//  * @title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
//  * @author MaiaDAO
//  * @dev Func IDs for calling these functions through messaging layer.
//  *
//  *   CROSS-CHAIN MESSAGING FUNCIDs
//  *   -----------------------------
//  *   FUNC ID      | FUNC NAME
//  *   -------------+---------------
//  *   0x01         | addGlobalToken
//  *   0x02         | addLocalToken
//  *   0x03         | setLocalToken
//  *   0x04         | claimRewards
//  *   0x05         | claimBribes
//  *   0x06         | incrementDelegationVotes
//  *   0x07         | incrementDelegationWeight
//  *   0x08         | delegateVotes
//  *   0x09         | delegateWeight
//  *   0x0a         | undelegateVotes
//  *   0x0b         | undelegateWeight
//  *   0x0c         | incrementGaugeWeights
//  *   0x0d         | decrementGaugeWeights
//  *   0x0e         | decrementAllGaugesAllBoost
//  *
//  */
// contract CoreRootRouter is IRootRouter {
//     using Path for bytes;
//     using SafeTransferLib for address;
//     using SafeCastLib for *;

//     /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
//     uint256 public immutable localChainId;

//     /// @notice Local Wrapped Native Token
//     WETH9 public immutable wrappedNativeToken;

//     /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
//     address public immutable localPortAddress;

//     /// @notice Bridge Agent to maneg communcations and cross-chain assets. TODO
//     address payable public immutable bridgeAgentAddress;

//     /// @notice Uni V3 Factory Address
//     address public immutable hTokenFactoryAddress;

//     /// @notice hermes Contract Address
//     HERMES public immutable hermes;

//     /// @notice bHermes Contract Address
//     bHERMES public immutable bHermes;

//     /// @notice bHermes Weight Address
//     bHERMESGauges public immutable bHermesGauges;

//     /// @notice bHermes Boost Address
//     bHERMESBoost public immutable bHermesBoost;

//     /// @notice bHermes Weight Address
//     bHERMESVotes public immutable bHermesVotes;

//     /// @notice Local Uniswap V3 Staker Address
//     address public immutable uniswapV3StakerAddress;

//     constructor(
//         uint256 _localChainId,
//         address _wrappedNativeToken,
//         address _localPortAddress,
//         address _bridgeAgentAddress,
//         address _hermesAddress,
//         address _bHermesAddress,
//         address _uniswapV3StakerAddress,
//         address _hTokenFactoryAddress
//     ) {
//         localChainId = _localChainId;
//         localPortAddress = _localPortAddress;
//         wrappedNativeToken = WETH9(_wrappedNativeToken);
//         bridgeAgentAddress = payable(_bridgeAgentAddress);
//         hermes = HERMES(_hermesAddress);
//         bHermes = bHERMES(_bHermesAddress);
//         bHermesGauges = bHermes.gaugeWeight();
//         bHermesBoost = bHermes.gaugeBoost();
//         bHermesVotes = bHermes.governance();
//         uniswapV3StakerAddress = _uniswapV3StakerAddress;
//         hTokenFactoryAddress = _hTokenFactoryAddress;
//     }

//     /*///////////////////////////////////////////////////////////////
//                 ERC20 HTOKENS REMOTE FUNCTIONS
//     ////////////////////////////////////////////////////////////*/

//     function transfer(
//         address _token,
//         address _to,
//         uint256 _amount
//     ) internal {
//         _token.safeTransfer(_to, _amount);
//     }

//     /*///////////////////////////////////////////////////////////////
//                  TOKEN MANAGEMENT REMOTE FUNCTIONS
//     ////////////////////////////////////////////////////////////*/

//     /**
//      * @notice Internal function to add a global token to a specific chain. Must be called from a branch interface.
//      *   @param _globalAddress global token to be added.
//      *   @param _toChain chain to which the Global Token will be added.
//      *
//      */
//     function addGlobalToken(address _globalAddress, uint256 _toChain) internal {
//         if (_toChain == localChainId) revert InvalidChainId();
//         //Verify that it does not exist TODO verify it is known global hToken(?)
//         if (IPort(localPortAddress).isGlobalToken(_globalAddress, _toChain))
//             revert TokenAlreadyAdded();

//         //Check Gas + Fees
//         bytes memory data = abi.encode(
//             0x00,
//             0x01,
//             _globalAddress,
//             ERC20(_globalAddress).name(),
//             ERC20(_globalAddress).symbol(),
//             ERC20(_globalAddress).decimals()
//         );

//         IBridgeAgent(bridgeAgentAddress).addGlobalToken(data, _toChain);
//     }

//     /**
//      * @notice Function to add a new local to the global environment. Called from branch chain.
//      *   @param _underlyingAddress the token's underlying/native address.
//      *   @param _localAddress the token's address.
//      *   @param _name the token's name.
//      *   @param _symbol the token's symbol.
//      *   @param _fromChain the token's origin chain Id.
//      *
//      */
//     function addLocalToken(
//         address _underlyingAddress,
//         address _localAddress,
//         string memory _name,
//         string memory _symbol,
//         uint256 _fromChain
//     ) internal {
//         // Verify if token already added
//         if (IPort(localPortAddress).isUnderlyingToken(_underlyingAddress, _fromChain))
//             revert TokenAlreadyAdded();

//         address newToken = address(IFactory(hTokenFactoryAddress).createToken(_name, _symbol));

//         IBridgeAgent(bridgeAgentAddress).addLocalToken(
//             _underlyingAddress,
//             (_fromChain == localChainId) ? newToken : _localAddress,
//             newToken,
//             _fromChain
//         );
//     }

//     /**
//      * @notice Internal function to set the local token on a specific chain for a global token.
//      *   @param _globalAddress global token to be updated.
//      *   @param _localAddress local token to be added.
//      *   @param _toChain local token's chain.
//      *
//      */
//     function setLocalToken(
//         address _globalAddress,
//         address _localAddress,
//         uint256 _toChain
//     ) internal {
//         IBridgeAgent(bridgeAgentAddress).setLocalToken(_globalAddress, _localAddress, _toChain);
//     }

//     /*///////////////////////////////////////////////////////////////
//                 HERMES INCENTIVE SYSTEM REMOTE FUNCTIONS
//     ///////////////////////////////////////////////////////////////*/

//     function claimRewards(address userAccount, uint256 toChainId)
//         internal
//         returns (uint256 amount)
//     {
//         //Give Virtual Account call instructions
//         (, bytes memory returnData) = IVirtualAccount(userAccount).call(
//             Call({
//                 target: uniswapV3StakerAddress,
//                 callData: abi.encodeWithSignature("claimAllRewards(address)", address(this))
//             })
//         );

//         //Decode return data
//         (amount) = abi.decode(returnData, (uint256));

//         //If requested Withdraw assets from Virtual Account
//         if (toChainId != 0) {
//             if (amount > 0) IVirtualAccount(userAccount).withdrawERC20(address(bHermes), amount);
//         }
//     }

//     function claimBribes(
//         address userAccount,
//         address flywheel,
//         bool outputNative,
//         uint256 toChainId
//     )
//         internal
//         returns (
//             address outputToken,
//             uint256 amountOut,
//             uint256 depositOut
//         )
//     {
//         //Give Virtual Account accrue instructions
//         (, bytes memory returnData) = IVirtualAccount(userAccount).call(
//             Call({
//                 target: flywheel,
//                 callData: abi.encodeWithSignature("accrue(address)", userAccount)
//             })
//         );

//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: flywheel,
//                 callData: abi.encodeWithSignature("claimRewards(address)", userAccount)
//             })
//         );

//         //If requested Withdraw assets from Virtual Account
//         if (toChainId != 0) {
//             //Decode return data
//             amountOut = abi.decode(returnData, (uint256));

//             outputToken = IFlywheelCore(flywheel).rewardToken();

//             if (amountOut > 0) IVirtualAccount(userAccount).withdrawERC20(outputToken, amountOut);
//         }
//     }

//     /*///////////////////////////////////////////////////////////////
//                 BHERMES DELEGATION REMOTE FUNCTIONS
//     ////////////////////////////////////////////////////////////*/

//     function incrementDelegationVotes(
//         address userAccount,
//         address delegatee,
//         uint256 amount,
//         uint256 votesDeposited
//     ) internal {
//         //Transfer bHermesVotes virtual account.
//         if (votesDeposited > 0) address(bHermesVotes).safeTransfer(userAccount, votesDeposited);

//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: address(bHermesVotes),
//                 callData: abi.encodeWithSignature(
//                     "incrementDelegation(address,uint256)",
//                     delegatee,
//                     amount
//                 )
//             })
//         );
//     }

//     function incrementDelegationWeight(
//         address userAccount,
//         address delegatee,
//         uint256 amount,
//         uint256 weightDeposited
//     ) internal {
//         //Transfer bHermesGauges virtual account.
//         if (weightDeposited > 0) address(bHermesGauges).safeTransfer(userAccount, weightDeposited);

//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: address(bHermesGauges),
//                 callData: abi.encodeWithSignature(
//                     "incrementDelegation(address,uint256)",
//                     delegatee,
//                     amount
//                 )
//             })
//         );
//     }

//     function delegateVotes(
//         address userAccount,
//         address newDelegatee,
//         uint256 votesDeposited
//     ) internal {
//         //Transfer bHermesVotes virtual account.
//         if (votesDeposited > 0) address(bHermesVotes).safeTransfer(userAccount, votesDeposited);

//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: address(bHermesVotes),
//                 callData: abi.encodeWithSignature("delegate(address)", newDelegatee)
//             })
//         );
//     }

//     function delegateWeight(
//         address userAccount,
//         address newDelegatee,
//         uint256 weightDeposited
//     ) internal {
//         //Transfer bHermesGauges virtual account.
//         if (weightDeposited > 0) address(bHermesGauges).safeTransfer(userAccount, weightDeposited);

//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: address(bHermesGauges),
//                 callData: abi.encodeWithSignature("delegate(address)", newDelegatee)
//             })
//         );
//     }

//     function undelegateVotes(
//         address userAccount,
//         address delegatee,
//         uint256 amount
//     ) internal {
//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: address(bHermesVotes),
//                 callData: abi.encodeWithSignature("undelegate(address,uint256)", delegatee, amount)
//             })
//         );
//     }

//     function undelegateWeight(
//         address userAccount,
//         address delegatee,
//         uint256 amount
//     ) internal {
//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: address(bHermesGauges),
//                 callData: abi.encodeWithSignature("undelegate(address,uint256)", delegatee, amount)
//             })
//         );
//     }

//     /*///////////////////////////////////////////////////////////////
//                     BHERMES-WEIGHT REMOTE FUNCTIONS
//     ////////////////////////////////////////////////////////////*/

//     function incrementGaugeWeights(
//         address userAccount,
//         address[] memory gaugeList,
//         uint112[] memory weights,
//         uint112 weightDeposited
//     ) internal {
//         //Transfer bHermesGauges virtual account.
//         if (weightDeposited > 0) address(bHermesGauges).safeTransfer(userAccount, weightDeposited);

//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: address(bHermesGauges),
//                 callData: abi.encodeWithSignature(
//                     "incrementGauges(address[],uint112[])",
//                     gaugeList,
//                     weights
//                 )
//             })
//         );
//     }

//     function decrementGaugeWeights(
//         address userAccount,
//         address[] memory gaugeList,
//         uint112[] memory weights
//     ) internal {
//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: address(bHermesGauges),
//                 callData: abi.encodeWithSignature(
//                     "decrementGauges(address[],uint112[])",
//                     gaugeList,
//                     weights
//                 )
//             })
//         );
//     }

//     /*///////////////////////////////////////////////////////////////
//                 BHERMES-BOOST REMOTE FUNCTIONS
//     ////////////////////////////////////////////////////////////*/

//     function decrementAllGaugesAllBoost(address userAccount) internal {
//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: address(bHermesBoost),
//                 callData: abi.encodeWithSignature("decrementAllGaugesAllBoost()")
//             })
//         );
//     }

//     /*///////////////////////////////////////////////////////////////
//                         UTILITY TOKENS LOGIC
//     //////////////////////////////////////////////////////////////*/

//     function forfeitMultipleAmounts(
//         bool isMaia,
//         uint256 weight,
//         uint256 boost,
//         uint256 _governance,
//         uint256 _partnerGovernance
//     ) public virtual {
//         forfeitWeight(weight);
//         forfeitBoost(boost);
//         forfeitGovernance(_governance);
//     }

//     function claimMultipleAmounts(
//         bool isMaia,
//         uint256 weight,
//         uint256 boost,
//         uint256 _governance,
//         uint256 _partnerGovernance
//     ) public virtual {
//         claimWeight(weight);
//         claimBoost(boost);
//         claimGovernance(_governance);
//     }

//     function claimOutstanding(bool isMaia) public virtual {
//         uint256 balance = balanceOf[msg.sender];
//         /// @dev Never overflows since balandeOf >= userClaimed.
//         claimWeight(balance - userClaimedWeight[msg.sender]);
//         claimBoost(balance - userClaimedBoost[msg.sender]);
//         claimGovernance(balance - userClaimedGovernance[msg.sender]);
//     }

//     /*///////////////////////////////////////////////////////////////
//                         INTERNAL HOOKS
//     ////////////////////////////////////////////////////////////*/

//     function _approveAndCallOut(
//         address recipient,
//         address outputToken,
//         uint256 amountOut,
//         uint256 depositOut,
//         uint256 toChain
//     ) internal virtual {
//         //Approve Root Port to spend/send output hTokens.
//         ERC20hTokenRoot(outputToken).approve(localPortAddress, amountOut);

//         //Move output hTokens from Root to Branch and call 'clearToken'.
//         IBridgeAgent(bridgeAgentAddress).bridgeOutAndCall{ value: msg.value }(
//             recipient,
//             "",
//             outputToken,
//             amountOut,
//             depositOut,
//             toChain
//         );
//     }

//     function _approveMultipleAndCallOut(
//         address recipient,
//         address[] memory outputTokens,
//         uint256[] memory amountsOut,
//         uint256[] memory depositsOut,
//         uint256 toChain
//     ) internal virtual {
//         //Approve Root Port to spend/send output hTokens.
//         ERC20hTokenRoot(outputTokens[0]).approve(localPortAddress, amountsOut[0]);
//         if (amountsOut[1] > 0)
//             ERC20hTokenRoot(outputTokens[1]).approve(localPortAddress, amountsOut[1]);

//         //Move output hTokens from Root to Branch and call 'clearTokens'.
//         IBridgeAgent(bridgeAgentAddress).bridgeOutAndCallMultiple{ value: msg.value }(
//             recipient,
//             "",
//             outputTokens,
//             amountsOut,
//             depositsOut,
//             toChain
//         );
//     }

//     /*///////////////////////////////////////////////////////////////
//                         ANYCALL FUNCTIONS
//     ////////////////////////////////////////////////////////////*/
//     /**
//      *     @notice Function responsible of executing a branch router response.
//      *     @param funcId 1 byte called Router function identifier.
//      *     @param data data received from messaging layer.
//      *     @param fromChainId chain where the request originated from.
//      *
//      *   2            | addLocalToken
//      *   3            | setLocalToken
//      *
//      */
//     function anyExecuteResponse(
//         bytes1 funcId,
//         bytes calldata data,
//         uint256 fromChainId
//     ) external payable override requiresAgent returns (bool success, bytes memory result) {
//         ///  FUNC ID: 2 (addLocalToken)
//         if (funcId == 0x02) {
//             bytes memory decodedData = RLPDecoder.decodeCallData(data[1:], 5); // TODO max 5 bytes32 slots

//             (
//                 address underlyingAddress,
//                 address localAddress,
//                 string memory name,
//                 string memory symbol
//             ) = abi.decode(decodedData, (address, address, string, string));

//             addLocalToken(underlyingAddress, localAddress, name, symbol, fromChainId);

//             emit LogCallin(funcId, data, fromChainId);
//             /// FUNC ID: 3 (setLocalToken)
//         } else if (funcId == 0x03) {
//             bytes memory decodedData = RLPDecoder.decodeCallData(data[1:], 3); // TODO max 3 bytes32 slots

//             (address globalAddress, address localAddress, uint256 toChain) = abi.decode(
//                 decodedData,
//                 (address, address, uint256)
//             );

//             setLocalToken(globalAddress, localAddress, toChain);

//             emit LogCallin(funcId, data, fromChainId);

//             /// Unrecognized Function Selector
//         } else {
//             return (false, "unknown selector");
//         }
//         return (true, "");
//     }

//     /**
//      *     @notice Function responsible of executing a crosschain request without any deposit.
//      *     @param funcId 1 byte Router function identifier.
//      *     @param rlpEncodedData data received from messaging layer.
//      *     @param fromChainId chain where the request originated from.
//      *
//      *   1            | addGlobalToken
//      *
//      */
//     function anyExecute(
//         bytes1 funcId,
//         bytes calldata rlpEncodedData,
//         uint256 fromChainId
//     ) external payable override requiresAgent returns (bool success, bytes memory result) {
//         /// FUNC ID: 1 (addGlobalToken)
//         if (funcId == 0x01) {
//             bytes memory decodedData = RLPDecoder.decodeCallData(rlpEncodedData[1:], 2); // TODO max 2 bytes32 slots

//             (address globalAddress, uint256 toChain) = abi.decode(decodedData, (address, uint256));

//             addGlobalToken(globalAddress, toChain);

//             emit LogCallin(funcId, rlpEncodedData, fromChainId);

//             /// Unrecognized Function Selector
//         } else {
//             return (false, "unknown selector");
//         }
//         return (true, "");
//     }

//     /**
//      *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information attached.
//      *   @param funcId 1 byte Router function identifier.
//      *   @param rlpEncodedData execution data received from messaging layer.
//      *   @param dParams cross-chain deposit information.
//      *   @param fromChainId chain where the request originated from.
//      *
//      */
//     function anyExecute(
//         bytes1 funcId,
//         bytes calldata rlpEncodedData,
//         DepositParams memory dParams,
//         uint256 fromChainId
//     ) external payable override requiresAgent returns (bool success, bytes memory result) {
//         revert();
//     }

//     /**
//      *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information for multiple assets attached.
//      *   @param funcId 1 byte Router function identifier.
//      *   @param rlpEncodedData execution data received from messaging layer.
//      *   @param dParams cross-chain multiple deposit information.
//      *   @param fromChainId chain where the request originated from.
//      *
//      */
//     function anyExecute(
//         bytes1 funcId,
//         bytes calldata rlpEncodedData,
//         DepositMultipleParams memory dParams,
//         uint256 fromChainId
//     ) external payable requiresAgent returns (bool, bytes memory) {
//         revert();
//     }

//     /**
//      *     @notice Function responsible of executing a signed crosschain request without any deposit.
//      *     @param funcId 1 byte Router function identifier.
//      *     @param rlpEncodedData execution data received from messaging layer.
//      *     @param fromChainId chain where the request originated from.
//      *
//      *   0x04         | claimRewards
//      *   0x05         | claimBribes
//      *   0x06         | incrementDelegationVotes
//      *   0x07         | incrementDelegationWeight
//      *   0x08         | delegateVotes
//      *   0x09         | delegateWeight
//      *   0x0a         | undelegateVotes
//      *   0x0b         | undelegateWeight
//      *   0x0c         | incrementGaugeWeights
//      *   0x0d         | decrementGaugeWeights
//      *   0x0e         | decrementAllGaugesAllBoost
//      *
//      */
//     function anyExecute(
//         bytes1 funcId,
//         bytes memory rlpEncodedData,
//         address userAccount,
//         uint256 fromChainId
//     ) external payable override requiresAgent returns (bool success, bytes memory result) {
//         ///  FUNC ID: 4 (hermes incentive system claimRewards)
//         if (funcId == 0x04) {
//             uint256 toChainId = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (uint256)
//             ); // TODO max 16 bytes32 slots

//             uint256 amount = claimRewards(userAccount, toChainId);

//             _approveAndCallOut(
//                 IVirtualAccount(userAccount).userAddress(),
//                 address(hermes),
//                 amount,
//                 amount,
//                 toChainId
//             );
//             ///  FUNC ID: 5 (hermes incentive system claimBribes)
//         } else if (funcId == 0x05) {
//             (
//                 address flywheel,
//                 bool outputNative,
//                 uint256 toChainId,
//                 bytes memory additionalInfo
//             ) = abi.decode(
//                     RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                     (address, bool, uint256, bytes)
//                 ); // TODO max 16 bytes32 slots

//             (address outputToken, uint256 amountOut, uint256 depositOut) = claimBribes(
//                 userAccount,
//                 flywheel,
//                 outputNative,
//                 toChainId
//             );

//             _approveAndCallOut(
//                 IVirtualAccount(userAccount).userAddress(),
//                 outputToken,
//                 amountOut,
//                 depositOut,
//                 toChainId
//             );

//             ///  FUNC ID: 6 (bhermes utility tokens incrementDelegationVotes)
//         } else if (funcId == 0x06) {
//             (address delegatee, uint256 amount) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address, uint256)
//             ); // TODO max 16 bytes32 slots

//             incrementDelegationVotes(userAccount, delegatee, amount, 0);
//             ///  FUNC ID: 7 (bhermes utility tokens incrementDelegationWeight)
//         } else if (funcId == 0x07) {
//             (address delegatee, uint256 amount) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address, uint256)
//             ); // TODO max 16 bytes32 slots

//             incrementDelegationWeight(userAccount, delegatee, amount, 0);

//             ///  FUNC ID: 8 (bhermes utility tokens delegateVotes)
//         } else if (funcId == 0x08) {
//             address newDelegatee = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address)
//             ); // TODO max 16 bytes32 slots

//             delegateVotes(userAccount, newDelegatee, 0);
//             ///  FUNC ID: 9 (bhermes utility tokens delegateWeight)
//         } else if (funcId == 0x09) {
//             address newDelegatee = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address)
//             ); // TODO max 16 bytes32 slots

//             delegateWeight(userAccount, newDelegatee, 0);

//             ///  FUNC ID: 10 (hermes utility tokens undelegateVotes)
//         } else if (funcId == 0x0a) {
//             (address userAccount, address delegatee, uint256 amount) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address, address, uint256)
//             ); // TODO max 16 bytes32 slots

//             undelegateVotes(userAccount, delegatee, amount);

//             ///  FUNC ID: 11 (hermes utility tokens undelegateWeight)
//         } else if (funcId == 0x0b) {
//             (address userAccount, address delegatee, uint256 amount) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address, address, uint256)
//             ); // TODO max 16 bytes32 slots

//             undelegateWeight(userAccount, delegatee, amount);

//             ///  FUNC ID: 12 (bhermes utility tokens incrementGaugeWeights)
//         } else if (funcId == 0x0c) {
//             (address[] memory gaugeList, uint112[] memory weights) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address[], uint112[])
//             ); // TODO max 16 bytes32 slots (USE MAX GAUGES AS REF)

//             incrementGaugeWeights(userAccount, gaugeList, weights, 0);

//             ///  FUNC ID: 13 (hermes utility tokens decrementGaugeWeights)
//         } else if (funcId == 0x0d) {
//             (address[] memory gaugeList, uint112[] memory weights) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address[], uint112[])
//             ); // TODO max 16 bytes32 slots (USE MAX GAUGES AS REF)

//             decrementGaugeWeights(userAccount, gaugeList, weights);

//             ///  FUNC ID: 14 (hermes utility tokens decrementAllGaugesAllBoost)
//         } else if (funcId == 0x0e) {
//             decrementAllGaugesAllBoost(userAccount);
//         }
//         emit LogCallin(funcId, rlpEncodedData, fromChainId);
//     }

//     /**
//      *     @notice Function responsible of executing a signed crosschain request with single deposit.
//      *     @param funcId 1 byte Router function identifier.
//      *     @param rlpEncodedData execution data received from messaging layer.
//      *     @param fromChainId chain where the request originated from.
//      *
//      *   0x06         | incrementDelegationVotes
//      *   0x07         | incrementDelegationWeight
//      *   0x08         | delegateVotes
//      *   0x09         | delegateWeight
//      *   0x0c         | incrementGaugeWeights
//      *
//      */
//     function anyExecute(
//         bytes1 funcId,
//         bytes memory rlpEncodedData,
//         DepositParams memory dParams,
//         address userAccount,
//         uint256 fromChainId
//     ) external payable override requiresAgent returns (bool success, bytes memory result) {
//         ///  FUNC ID: 6 (bhermes utility tokens incrementDelegationVotes)
//         if (funcId == 0x06) {
//             (address delegatee, uint256 amount) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address, uint256)
//             ); // TODO max 16 bytes32 slots

//             incrementDelegationVotes(userAccount, delegatee, amount, dParams.amount.toUint112());
//             ///  FUNC ID: 7 (bhermes utility tokens incrementDelegationWeight)
//         } else if (funcId == 0x07) {
//             (address delegatee, uint256 amount) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address, uint256)
//             ); // TODO max 16 bytes32 slots

//             incrementDelegationWeight(userAccount, delegatee, amount, dParams.amount.toUint112());

//             ///  FUNC ID: 8 (bhermes utility tokens delegateVotes)
//         } else if (funcId == 0x08) {
//             address newDelegatee = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address)
//             ); // TODO max 16 bytes32 slots

//             delegateVotes(userAccount, newDelegatee, dParams.amount.toUint112());
//             ///  FUNC ID: 9 (bhermes utility tokens delegateWeight)
//         } else if (funcId == 0x09) {
//             address newDelegatee = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address)
//             ); // TODO max 16 bytes32 slots

//             delegateWeight(userAccount, newDelegatee, dParams.amount.toUint112());

//             ///  FUNC ID: 12 (bhermes utility tokens incrementGaugeWeights)
//         } else if (funcId == 0x0c) {
//             (address[] memory gaugeList, uint112[] memory weights) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address[], uint112[])
//             ); // TODO max 16 bytes32 slots (USE MAX GAUGES AS REF)

//             incrementGaugeWeights(userAccount, gaugeList, weights, dParams.amount.toUint112());
//         }
//         emit LogCallin(funcId, rlpEncodedData, fromChainId);
//     }

//     function anyExecute(
//         bytes1 funcId,
//         bytes memory rlpEncodedData,
//         DepositMultipleParams memory dParams,
//         address userAccount,
//         uint256 fromChainId
//     ) external payable returns (bool success, bytes memory result) {
//         revert();
//     }

//     function anyFallback(bytes calldata data) external returns (bool success, bytes memory result) {
//         return (true, "");
//     }

//     /*///////////////////////////////////////////////////////////////
//                             MODIFIERS
//     ////////////////////////////////////////////////////////////*/

//     /// @notice Modifier for a simple re-entrancy check.
//     uint256 internal _unlocked = 1;

//     modifier lock() {
//         require(_unlocked == 1);
//         _unlocked = 2;
//         _;
//         _unlocked = 1;
//     }

//     /// @notice require msg sender == active branch interface
//     modifier requiresAgent() {
//         _requiresAgent();
//         _;
//     }

//     /// @notice reuse to reduce contract bytesize
//     function _requiresAgent() internal view {
//         require(msg.sender == bridgeAgentAddress, "Unauthorized Caller");
//     }

//     error InvalidChainId();

//     error TokenAlreadyAdded();
// }
