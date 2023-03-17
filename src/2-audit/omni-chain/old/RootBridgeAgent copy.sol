// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "./interfaces/IRootBridgeAgent.sol";

// library CheckParamsLib {
//     /**
//         @notice Function to check cross-chain params and verify deposits made on branch chain. Local hToken must be recognized and address much match underlying if exists otherwise only local hToken is checked.
//         @param _dParams Cross Chain swap parameters.
//         TODO clean up
//     **/
//     function checkParams(
//         address _localPortAddress,
//         DepositParams memory _dParams,
//         uint256 _fromChain
//     ) public returns (bool) {
//         if (
//             (_dParams.amount < _dParams.deposit) || //Deposit can't be greater than amount.
//             (IPort(_localPortAddress).isLocalToken(_dParams.hToken, _fromChain)) || //Check local exists.
//             (_dParams.deposit > 0 &&
//                 IPort(_localPortAddress).getUnderlyingTokenFromLocal(
//                     _dParams.hToken,
//                     _fromChain
//                 ) ==
//                 _dParams.token) //Else check if underlying matches.
//         ) {
//             return false;
//         }
//         return true;
//     }

//     /**
//         @notice Function to check cross-chain params and verify deposits made on branch chain.
//         @param _dParams Cross Chain swap parameters.
//     **/
//     function checkMultipleParams(
//         address _localPortAddress,
//         DepositMultipleParams memory _dParams,
//         uint256 _fromChain
//     ) public returns (bool) {
//         for (uint256 i = 0; i < _dParams.hTokens.length; i++) {
//             if (
//                 !checkParams(
//                     _localPortAddress,
//                     DepositParams({
//                         hToken: _dParams.hTokens[i],
//                         token: _dParams.tokens[i],
//                         amount: _dParams.amounts[i],
//                         deposit: _dParams.deposits[i],
//                         toChain: 0,
//                         depositNonce: 0
//                     }),
//                     _fromChain
//                 )
//             ) return false;
//             unchecked {
//                 ++i;
//             }
//         }
//         return true;
//     }
// }

// /**
// @title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
// @author MaiaDAO
// @notice Base Root Router for Anycall cross-chain messaging.
// * 
// *   BRIDGE AGENT ACTION IDs
// *   --------------------------------------
// *   ID           | DESCRIPTION     
// *   -------------+------------------------
// *   0x00         | Branch Router Response.
// *   0x01         | Call to Root Router without Deposit.
// *   0x02         | Call to Root Router with Deposit.
// *   0x03         | Call to Root Router with Deposit of Multiple Tokens.
// *   0x04         | Call to Root Router without Deposit + singned message.
// *   0x05         | Call to Root Router with Deposit + singned message.
// *   0x06         | Call to Root Router with Deposit of Multiple Tokens + singned message.
// *   0x07         | Call to ´depositToPort()´.
// *   0x08         | Call to ´withdrawFromPort()´.
// *   0x09         | Call to ´bridgeTo()´.
// *   0x0a         | Call to ´clearSettlement()´.
// *
// */
// contract RootBridgeAgent is IRootBridgeAgent {
//     using SafeTransferLib for address;

//     /// @notice Local Chain Id
//     uint256 public immutable localChainId;

//     /// @notice Local Wrapped Native Token
//     WETH9 public immutable wrappedNativeToken;

//     /// @notice Local Root Router Address
//     address public immutable localRouterAddress;

//     /// @notice Address for Local Port Address where funds deposited from this chain are stored.
//     address public immutable localPortAddress;

//     /// @notice Local Anycall Address
//     address public immutable localAnyCallAddress;

//     /// @notice Local Anyexec Address
//     address public immutable localAnyCallExecutorAddress;

//     /// @notice Chain -> Branch Bridge Agent Address. For N chains, each Root Bridge Agent Address has M =< N Branch Bridge Agent Address.
//     mapping(uint256 => address) public getBranchBridgeAgent;

//     /// @notice Deposit nonce used for identifying transaction.
//     uint32 public settlementNonce;

//     /// @notice Mapping from Settlement nonce to Deposit Struct.
//     mapping(uint32 => Settlement) public getSettlement;

//     /**
//         @notice Constructor for Bridge Agent.
//         @param _wrappedNativeToken Local Wrapped Native Token.
//         @param _localChainId Local Chain Id.
//         @param _localAnyCallAddress Local Anycall Address.
//         @param _localPortAddress Local Port Address.
//         @param _localRouterAddress Local Port Address.
//      */
//     constructor(
//         WETH9 _wrappedNativeToken,
//         uint256 _localChainId,
//         address _localAnyCallAddress,
//         address _localAnyCallExecutorAddress,
//         address _localPortAddress,
//         address _localRouterAddress
//     ) {
//         wrappedNativeToken = _wrappedNativeToken;
//         localChainId = _localChainId;
//         localAnyCallAddress = _localAnyCallAddress;
//         localPortAddress = _localPortAddress;
//         localRouterAddress = _localRouterAddress;
//         localAnyCallExecutorAddress = _localAnyCallExecutorAddress;
//         settlementNonce = 1;
//     }

//     /*///////////////////////////////////////////////////////////////
//                         VIEW EXTERNAL FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     /** 
//         @notice External function that returns a given settlement entry.
//         @param _settlementNonce Identifier for token settlement.
//     **/
//     function getSettlementEntry(uint32 _settlementNonce) external view returns (Settlement memory) {
//         return _getSettlementEntry(_settlementNonce);
//     }

//     /*///////////////////////////////////////////////////////////////
//                         EXTERNAL FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     /**
//         @notice Function to retry a user's Settlement balance.
//         @param _settlementNonce Identifier for token settlement.
//     **/
//     function clearSettlement(uint32 _settlementNonce) external payable {
//         _clearSettlement(_settlementNonce);
//     }

//     /*///////////////////////////////////////////////////////////////
//                     ROOT ROUTER EXTERNAL FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     /**
//         @notice External function performs call to AnycallProxy Contract for cross-chain messaging.
//         @param _calldata Calldata for function call.
//         @param _fees Fees for cross-chain messaging.
//         @param _toChain Chain to bridge to.
//         @param _hasFallback Boolean to check if function call has fallback.
//      */
//     function performCall(
//         bytes memory _calldata,
//         uint256 _fees,
//         uint256 _toChain,
//         bool _hasFallback
//     ) external payable requiresRouter {
//         //Prepare data for call
//         bytes memory data = abi.encode(0x00, _calldata);

//         //Perform call to cross-chain messaging layer
//         _performCall(data, _fees, _toChain, _hasFallback);
//     }

//     /**
//       @notice Internal function to move assets from root chain to branch omnichain environment.
//       @param _recipient recipient of bridged tokens.
//       @param _data parameters for function call on branch chain.
//       @param _globalAddress global token to be moved.
//       @param _amount amount of ´token´.
//       @param _deposit amount of native / underlying token.
//       @param _toChain chain to bridge to.
//     **/
//     function bridgeOutAndCall(
//         address _recipient,
//         bytes memory _data,
//         address _globalAddress,
//         uint256 _amount,
//         uint256 _deposit,
//         uint256 _toChain
//     ) external payable requiresRouter {
//         _bridgeOutAndCall(
//             msg.sender,
//             _recipient,
//             _data,
//             _globalAddress,
//             _amount,
//             _deposit,
//             _toChain
//         );
//     }

//     /**
//       @notice Internal function to move assets from branch chain to root omnichain environment.
//       @param _recipient recipient of bridged tokens.
//       @param _data parameters for function call on branch chain.
//       @param _globalAddresses global tokens to be moved.
//       @param _amounts amounts of token.
//       @param _deposits amounts of underlying / token.
//       @param _toChain chain to bridge to.

//     **/
//     function bridgeOutAndCallMultiple(
//         address _recipient,
//         bytes memory _data,
//         address[] memory _globalAddresses,
//         uint256[] memory _amounts,
//         uint256[] memory _deposits,
//         uint256 _toChain
//     ) external payable requiresRouter {
//         address[] memory hTokens;
//         address[] memory tokens;

//         for (uint256 i = 0; i < tokens.length; ) {
//             _updateStateOnBridgeOut(
//                 msg.sender,
//                 _globalAddresses[i],
//                 _amounts[i],
//                 _deposits[i],
//                 _toChain
//             );

//             //Populate Addresses for Settlement
//             hTokens[i] = IPort(localPortAddress).getLocalTokenFromGlobal(
//                 _globalAddresses[i],
//                 _toChain
//             );
//             tokens[i] = IPort(localPortAddress).getUnderlyingTokenFromLocal(hTokens[i], _toChain);

//             unchecked {
//                 ++i;
//             }
//         }

//         //Prepare data for call with settlement of multiple assets
//         bytes memory data = abi.encode(
//             0x02,
//             _data,
//             SettlementMultipleParams({
//                 recipient: _recipient,
//                 hTokens: hTokens,
//                 tokens: tokens,
//                 amounts: _amounts,
//                 deposits: _deposits,
//                 nonce: settlementNonce
//             })
//         );

//         //Check Gas + Fees
//         (bool success, uint256 fees) = _checkFees(data, _toChain);
//         if (!success) revert InsufficientGasForFees();

//         //Create Settlement Balance
//         _createMultipleSettlement(_recipient, hTokens, tokens, _amounts, _deposits, data, _toChain);

//         //Perform Call to clear balance on destination branch chain.
//         _performCall(data, _toChain, fees, true);
//     }

//     /*///////////////////////////////////////////////////////////////
//                     REMOTE USER INTERNAL FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     /**
//       @notice Internal function to deposit new assets from branch chain into omnichain environment.
//       @param _recipient Deposit output hToken recipient.
//       @param _localAddress Branch chain hToken address.
//       @param _underlyingAddress Branch chain underlying token address.
//       @param _amount Tokens deposited.
//       @param _fromChain Deposit origin chain.
//     **/
//     function depositToPort(
//         address _recipient,
//         address _localAddress,
//         address _underlyingAddress,
//         uint256 _amount,
//         uint32 _depositNonce,
//         uint256 _fromChain
//     ) internal {
//         //Encode Data for `finalizeDeposit` call.
//         bytes memory data = abi.encode(0x03, _depositNonce, _localAddress, settlementNonce);

//         //Check Gas + Fees
//         (bool success, uint256 fees) = _checkFees(data, _fromChain);
//         if (!success) revert InsufficientGasForFees();

//         //Move output hTokens from Root to Branch
//         IPort(localPortAddress).getGlobalTokenFromLocal(_localAddress, _fromChain).safeTransfer(
//             localPortAddress,
//             _amount
//         );

//         //Create Settlement Balance
//         _createSettlement(
//             _recipient,
//             _localAddress,
//             _underlyingAddress,
//             _amount,
//             0,
//             data,
//             _fromChain
//         );

//         //Perform Call to clear hToken balance on destination branch chain.
//         _performCall(data, _fromChain, fees, true);
//     }

//     /**
//       @notice Internal function to withdraw underlying assets from Branch Chain Port.
//       @param _recipient Withdraw output underlying/deposit token recipient.
//       @param _localAddress Branch chain hToken address.
//       @param _underlyingAddress Branch chain underlying asset address.
//       @param _amount Tokens to withdraw.
//       @param _fromChain Withdraw origin chain.
//     **/
//     function withdrawFromPort(
//         address _recipient,
//         address _localAddress,
//         address _underlyingAddress,
//         uint256 _amount,
//         uint32 _depositNonce,
//         uint256 _fromChain
//     ) internal {
//         //Encode Data for `finalizeWithdraw` call.
//         bytes memory data = abi.encode(0x04, _depositNonce, _underlyingAddress, settlementNonce);

//         //Check Gas + Fees
//         (bool success, uint256 fees) = _checkFees(data, _fromChain);
//         if (!success) revert InsufficientGasForFees();

//         //Update Global state
//         IPort(localPortAddress).burn(
//             address(this),
//             IPort(localPortAddress).getGlobalTokenFromLocal(_localAddress, _fromChain),
//             _amount,
//             _fromChain
//         );

//         //Create Settlement Balance
//         _createSettlement(
//             _recipient,
//             _localAddress,
//             _underlyingAddress,
//             _amount,
//             _amount,
//             data,
//             _fromChain
//         );

//         //Perform Call to clear hToken balance on destination branch chain.
//         _performCall(data, _fromChain, fees, true);
//     }

//     /**
//       @notice Internal function to move hTokens from one branch to another.
//       @param _recipient user address to receive hToken balance.
//       @param _localAddress Branch chain hToken address.
//       @param _amount Tokens to biridge.
//       @param _fromChain Request origin chain.
//     **/
//     function bridgeTo(
//         address _recipient,
//         address _localAddress,
//         uint256 _amount,
//         uint256 _toChain,
//         uint256 _fromChain
//     ) internal {
//         //Revert if token is not added to destination chain.
//         if (
//             IPort(localPortAddress).getLocalToken(_localAddress, _fromChain, _toChain) == address(0)
//         ) revert UnrecognizedAddressInDestination();

//         //Perform call to destination chain.
//         _bridgeOutAndCall(
//             address(this),
//             _recipient,
//             "",
//             IPort(localPortAddress).getGlobalTokenFromLocal(_localAddress, _fromChain),
//             _amount,
//             0,
//             _toChain
//         );
//     }

//     /*///////////////////////////////////////////////////////////////
//                     TOKEN MANAGEMENT INTERNAL FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     /**
//       @notice Internal function to move assets from branch chain to root omnichain environment.
//       @param _dParams Cross-Chain Deposit of Multiple Tokens Params.
//       @param _fromChain chain to bridge from.
//     **/
//     function _bridgeIn(
//         address _recipient,
//         DepositParams memory _dParams,
//         uint256 _fromChain
//     ) internal {
//         //Check Deposit info from Cross Chain Parameters.
//         if (!CheckParamsLib.checkParams(localPortAddress, _dParams, _fromChain))
//             revert InvalidInputParams();

//         //Get global address
//         address globalAddress = IPort(localPortAddress).getGlobalTokenFromLocal(
//             _dParams.hToken,
//             _fromChain
//         );

//         //Move hTokens from Branch to Root + Mint Sufficient hTokens to match new port deposit
//         IPort(localPortAddress).bridgeToRoot(
//             _recipient,
//             globalAddress,
//             _dParams.amount,
//             _dParams.deposit,
//             _fromChain
//         );
//     }

//     /**
//       @notice Internal function to move assets from branch chain to root omnichain environment.
//       @param _dParams Cross-Chain Deposit of Multiple Tokens Params.
//       @param _fromChain chain to bridge from.
//     **/
//     function _bridgeInMultiple(
//         address _recipient,
//         DepositMultipleParams memory _dParams,
//         uint256 _fromChain
//     ) internal {
//         for (uint256 i = 0; i < _dParams.hTokens.length; ) {
//             _bridgeIn(
//                 _recipient,
//                 DepositParams({
//                     hToken: _dParams.hTokens[i],
//                     token: _dParams.tokens[i],
//                     amount: _dParams.amounts[i],
//                     deposit: _dParams.deposits[i],
//                     toChain: _dParams.toChain,
//                     depositNonce: 0
//                 }),
//                 _fromChain
//             );

//             unchecked {
//                 ++i;
//             }
//         }
//     }

//     /**
//       @notice Internal function to move assets from root chain to branch omnichain environment.
//       @param _recipient recipient of bridged tokens.
//       @param _data parameters for function call on branch chain.
//       @param _globalAddress global token to be moved.
//       @param _amount amount of ´token´.
//       @param _deposit amount of native / underlying token.
//       @param _toChain chain to bridge to.
//     **/
//     function _bridgeOutAndCall(
//         address _sender,
//         address _recipient,
//         bytes memory _data,
//         address _globalAddress,
//         uint256 _amount,
//         uint256 _deposit,
//         uint256 _toChain
//     ) internal {
//         //Get Addresses TODO requires tokens to exist?
//         address localAddress = IPort(localPortAddress).getLocalTokenFromGlobal(
//             _globalAddress,
//             _toChain
//         );

//         address underlyingAddress = IPort(localPortAddress).getUnderlyingTokenFromLocal(
//             localAddress,
//             _toChain
//         );

//         //Prepare data for call
//         bytes memory data = abi.encode(
//             0x01,
//             _data,
//             SettlementParams({
//                 recipient: _recipient,
//                 hToken: localAddress,
//                 token: underlyingAddress,
//                 amount: _amount,
//                 deposit: _deposit,
//                 nonce: settlementNonce
//             })
//         );

//         //Check Gas + Fees
//         (bool success, uint256 fees) = _checkFees(_data, _toChain);
//         if (!success) revert InsufficientGasForFees();

//         _updateStateOnBridgeOut(_sender, _globalAddress, _amount, _deposit, _toChain);

//         //Create Settlement Balance
//         _createSettlement(
//             _recipient,
//             localAddress,
//             underlyingAddress,
//             _amount,
//             _deposit,
//             data,
//             _toChain
//         );

//         //Perform Call to clear hToken balance on destination branch chain.
//         _performCall(data, _toChain, fees, true);
//     }

//     function _updateStateOnBridgeOut(
//         address _sender,
//         address _globalAddress,
//         uint256 _amount,
//         uint256 _deposit,
//         uint256 _toChain
//     ) internal {
//         if (_amount - _deposit > 0) {
//             //Move output hTokens from Root to Branch
//             _globalAddress.safeTransferFrom(_sender, localPortAddress, _amount - _deposit);
//         }

//         if (_deposit > 0) {
//             //Verify there is enough balance to clear native tokens if needed
//             require(IERC20hTokenRoot(_globalAddress).getTokenBalance(_toChain) >= _deposit); //TODO
//             IPort(localPortAddress).burn(_sender, _globalAddress, _deposit, _toChain);
//         }
//     }

//     /*///////////////////////////////////////////////////////////////
//                 SETTLEMENT INTERNAL FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     /**
//        @notice Function to create a settlemment A.K.A. token output to user. Settlement should be reopened if fallback occurs.
//        @param _user user address.
//        @param _hToken deposited global token addresses.
//        @param _token deposited global token addresses.
//        @param _amount amounts of hTokens input.
//        @param _deposit amount of deposited underlying / native tokens.
//        @param _callData amount of deposited underlying / native tokens.
//        @param _toChain amount of deposited underlying / native tokens.

//     **/
//     function _createSettlement(
//         address _user,
//         address _hToken,
//         address _token,
//         uint256 _amount,
//         uint256 _deposit,
//         bytes memory _callData,
//         uint256 _toChain
//     ) internal {
//         //Cast to Dynamic
//         address[] memory hTokens = new address[](1);
//         hTokens[0] = _hToken;
//         address[] memory tokens = new address[](1);
//         tokens[0] = _token;
//         uint256[] memory amounts = new uint256[](1);
//         amounts[0] = _amount;
//         uint256[] memory deposits = new uint256[](1);
//         deposits[0] = _deposit;

//         //Call createSettlement
//         _createMultipleSettlement(_user, hTokens, tokens, amounts, deposits, _callData, _toChain);
//     }

//     /**
//        @notice Function to create a settlemment A.K.A. token output to user. Settlement should be reopened if fallback occurs.
//        @param _user user address.
//        @param _hTokens deposited global token addresses.
//        @param _tokens deposited global token addresses.
//        @param _amounts amounts of hTokens input.
//        @param _deposits amount of deposited underlying / native tokens.
//        @param _callData amount of deposited underlying / native tokens.
//        @param _toChain amount of deposited underlying / native tokens.

//     **/
//     function _createMultipleSettlement(
//         address _user,
//         address[] memory _hTokens,
//         address[] memory _tokens,
//         uint256[] memory _amounts,
//         uint256[] memory _deposits,
//         bytes memory _callData,
//         uint256 _toChain
//     ) internal {
//         // Update State
//         getSettlement[_getAndIncrementSettlementNonce()] = Settlement({
//             owner: _user,
//             hTokens: _hTokens,
//             tokens: _tokens,
//             amounts: _amounts,
//             deposits: _deposits,
//             callData: _callData,
//             toChain: _toChain,
//             status: SettlementStatus.Success
//         });
//     }

//     /**
//         @notice Function to retry a user's Settlement balance.
//         @param _settlementNonce Identifier for token settlement.
//     **/
//     function _clearSettlement(uint32 _settlementNonce) internal {
//         //Get Settlement
//         Settlement memory settlement = _getSettlementEntry(_settlementNonce);
//         //Require Status to be Pending
//         require(settlement.status == SettlementStatus.Pending);
//         //Update Settlement
//         settlement.status = SettlementStatus.Success;
//         //Check Gas + Fees
//         (bool success, uint256 fees) = _checkFees(settlement.callData, settlement.toChain);
//         if (!success) revert InsufficientGasForFees();
//         //Retry Branch Chain interaction
//         _performCall(settlement.callData, fees, settlement.toChain, true);
//     }

//     /**
//         @notice Function to reopen a user's Settlement balance as pending and thus retryable by users. Called upon fallback of clearTokens() to Branch.
//         @param _settlementNonce Identifier for token settlement.
//     **/
//     function _reopenSettlemment(uint32 _settlementNonce) internal {
//         //Update Deposit
//         getSettlement[_settlementNonce].status = SettlementStatus.Pending;
//     }

//     /**
//         @notice Function that returns Deposit nonce and increments counter.
//     **/
//     function _getAndIncrementSettlementNonce() internal returns (uint32) {
//         return settlementNonce++;
//     }

//     /** 
//         @notice External function that returns a given settlement entry.
//         @param _settlementNonce Identifier for token settlement.
//     **/
//     function _getSettlementEntry(uint32 _settlementNonce)
//         internal
//         view
//         returns (Settlement storage)
//     {
//         return getSettlement[_settlementNonce];
//     }

//     /*///////////////////////////////////////////////////////////////
//                     ANYCALL INTERNAL FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     /// @notice Internal function that return 'from' address and 'fromChain' Id by performing an external call to AnycallExecutor Context.
//     function _getContext() internal view returns (address from, uint256 fromChainId) {
//         (from, fromChainId, ) = IAnycallExecutor(localAnyCallExecutorAddress).context();
//     }

//     function _checkFees(bytes memory _callData, uint256 _toChain)
//         internal
//         returns (bool success, uint256 fees)
//     {
//         //Check Gas + Fees
//         fees = _computeAnyCallFees(_callData, _toChain);
//         (msg.value < fees) ? success = false : success = true;
//     }

//     /**
//        @notice Internal function to calculate cost fo cross-chain message.
//        @param data bytes that will be sent through messaging layer.
//        @param toChain message destination chain Id.
//      **/
//     function _computeAnyCallFees(bytes memory data, uint256 toChain)
//         internal
//         view
//         returns (uint256 fees)
//     {
//         fees = msg.value;
//         // fees = IAnycallProxy(localAnyCallAddress).calcSrcFees("0", toChain, data.length);
//     }

//     /// @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
//     function _performCall(
//         bytes memory _calldata,
//         uint256 _fees,
//         uint256 _toChain,
//         bool _hasFallback
//     ) internal {
//         if (_toChain != localChainId) {
//             //Sends message to AnycallProxy
//             IAnycallProxy(localAnyCallAddress).anyCall{ value: _fees }(
//                 getBranchBridgeAgent[_toChain],
//                 _calldata,
//                 _toChain,
//                 _hasFallback ? AnycallFlags.FLAG_ALLOW_FALLBACK : AnycallFlags.FLAG_NONE,
//                 ""
//             );
//         } else {
//             //Execute locally
//             IBranchBridgeAgent(getBranchBridgeAgent[localChainId]).anyExecute(_calldata);
//         }
//     }

//     /**
//       @notice Function responsible of executing a crosschain request when one is received.
//       @param data data received from messaging layer.

//     **/
//     function anyExecute(bytes calldata data)
//         external
//         virtual
//         requiresExecutor
//         returns (bool success, bytes memory result)
//     {
//         uint256 fromChainId;

//         if (localAnyCallExecutorAddress == msg.sender) {
//             (, fromChainId) = _getContext();
//         } else {
//             fromChainId = localChainId;
//         }

//         bytes1 flag = bytes1(data[:1]);

//         //DEPOSIT FLAG: 0 (System request/response)
//         if (flag == 0x00) {
//             IRouter(localRouterAddress).anyExecuteResponse(bytes1(data[:1]), data[2:], fromChainId);

//             //DEPOSIT FLAG: 1 (Call without Deposit)
//         } else if (flag == 0x01) {
//             IRouter(localRouterAddress).anyExecute(bytes1(data[:1]), data[2:], fromChainId);
//             emit LogCallin(flag, data, fromChainId);

//             //DEPOSIT FLAG: 2 (Call with Deposit)
//         } else if (flag == 0x02) {
//             (bytes1 funcId, bytes memory encodedData, DepositParams memory dParams) = (
//                 abi.decode(data[1:], (bytes1, bytes, DepositParams))
//             );

//             _bridgeIn(localRouterAddress, dParams, fromChainId);

//             IRouter(localRouterAddress).anyExecute(funcId, encodedData, dParams, fromChainId);

//             //DEPOSIT FLAG: 3 (Call with multiple asset Deposit)
//         } else if (flag == 0x03) {
//             (bytes1 funcId, bytes memory encodedData, DepositMultipleParams memory dParams) = (
//                 abi.decode(data[1:], (bytes1, bytes, DepositMultipleParams))
//             );

//             _bridgeInMultiple(localRouterAddress, dParams, fromChainId);

//             IRouter(localRouterAddress).anyExecute(funcId, encodedData, dParams, fromChainId);

//             //DEPOSIT FLAG: 4 (Call without Deposit + msg.sender)
//         } else if (flag == 0x04) {
//             (bytes1 funcId, address sender, bytes memory encodedData) = (
//                 abi.decode(data[1:], (bytes1, address, bytes))
//             );
//             VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(sender);

//             IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

//             IRouter(localRouterAddress).anyExecute(
//                 funcId,
//                 encodedData,
//                 address(userAccount),
//                 fromChainId
//             );

//             IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

//             //DEPOSIT FLAG: 5 (Call with Deposit + msg.sender)
//         } else if (flag == 0x05) {
//             (
//                 bytes1 funcId,
//                 address sender,
//                 bytes memory encodedData,
//                 DepositParams memory dParams
//             ) = (abi.decode(data[1:], (bytes1, address, bytes, DepositParams)));

//             VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(sender);

//             _bridgeIn(address(userAccount), dParams, fromChainId);

//             IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

//             IRouter(localRouterAddress).anyExecute(
//                 funcId,
//                 encodedData,
//                 dParams,
//                 address(userAccount),
//                 fromChainId
//             );

//             IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

//             //DEPOSIT FLAG: 6 (Call with multiple asset Deposit + msg.sender)
//         } else if (flag == 0x06) {
//             (
//                 bytes1 funcId,
//                 address sender,
//                 bytes memory encodedData,
//                 DepositMultipleParams memory dParams
//             ) = (abi.decode(data[1:], (bytes1, address, bytes, DepositMultipleParams)));

//             VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(sender);

//             _bridgeInMultiple(address(userAccount), dParams, fromChainId);

//             IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

//             IRouter(localRouterAddress).anyExecute(
//                 funcId,
//                 encodedData,
//                 dParams,
//                 address(userAccount),
//                 fromChainId
//             );
//             IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

//             /// DEPOSIT FLAG: 7 (depositToPort)
//         } else if (flag == 0x07) {
//             (address recipient, address underlyingAddress, uint256 amount, uint32 depositNonce) = (
//                 abi.decode(data[1:], (address, address, uint256, uint32))
//             );

//             //Require deposit token to be a recognized underlying address in `_fromChain`.
//             if (!IPort(localPortAddress).isUnderlyingToken(underlyingAddress, fromChainId))
//                 revert UnrecognizedUnderlyingAddress();

//             address localAddress = IPort(localPortAddress).getLocalTokenFromUnder(
//                 underlyingAddress,
//                 fromChainId
//             );

//             _bridgeIn(
//                 address(this),
//                 DepositParams({
//                     hToken: localAddress,
//                     token: underlyingAddress,
//                     amount: amount,
//                     deposit: amount,
//                     toChain: fromChainId,
//                     depositNonce: depositNonce
//                 }),
//                 fromChainId
//             );

//             depositToPort(
//                 recipient,
//                 localAddress,
//                 underlyingAddress,
//                 amount,
//                 depositNonce,
//                 fromChainId
//             );

//             /// DEPOSIT FLAG: 8 (withdrawFromPort)
//         } else if (flag == 0x08) {
//             (address recipient, address localAddress, uint256 amount, uint32 depositNonce) = (
//                 abi.decode(data[1:], (address, address, uint256, uint32))
//             );

//             //Require deposit token to be a recognized underlying address in `_fromChain`.
//             if (!IPort(localPortAddress).isLocalToken(localAddress, fromChainId))
//                 revert UnrecognizedLocalAddress();

//             address underlyingAddress = IPort(localPortAddress).getUnderlyingTokenFromLocal(
//                 localAddress,
//                 fromChainId
//             );

//             _bridgeIn(
//                 address(this),
//                 DepositParams({
//                     hToken: localAddress,
//                     token: underlyingAddress,
//                     amount: amount,
//                     deposit: amount,
//                     toChain: fromChainId,
//                     depositNonce: depositNonce
//                 }),
//                 fromChainId
//             );

//             withdrawFromPort(
//                 recipient,
//                 localAddress,
//                 underlyingAddress,
//                 amount,
//                 depositNonce,
//                 fromChainId
//             );

//             /// DEPOSIT FLAG: 9 (bridgeTo)
//         } else if (flag == 0x09) {
//             /// address localAddress, uint256 amount
//             (
//                 address recipient,
//                 address localAddress,
//                 uint256 amount,
//                 uint256 toChain,
//                 uint32 depositNonce
//             ) = abi.decode(data[1:], (address, address, uint256, uint256, uint32));

//             //Require deposit token to be a recognized underlying address in `_fromChain`.
//             if (!IPort(localPortAddress).isLocalToken(localAddress, fromChainId))
//                 revert UnrecognizedLocalAddress();

//             address underlyingAddress = IPort(localPortAddress).getUnderlyingTokenFromLocal(
//                 localAddress,
//                 fromChainId
//             );

//             _bridgeIn(
//                 address(this),
//                 DepositParams({
//                     hToken: localAddress,
//                     token: underlyingAddress,
//                     amount: amount,
//                     deposit: 0,
//                     toChain: toChain,
//                     depositNonce: depositNonce
//                 }),
//                 fromChainId
//             );

//             bridgeTo(recipient, localAddress, amount, toChain, fromChainId);

//             /// DEPOSIT FLAG: 10 (clearSettlement)
//         } else if (flag == 0x0a) {
//             bytes memory encodedData = (abi.decode(data[1:], (bytes)));

//             bytes memory decodedData = RLPDecoder.decodeCallData(encodedData, 1);

//             uint32 _settlementNonce = abi.decode(decodedData, (uint32));

//             _clearSettlement(_settlementNonce);

//             //Unrecognized Function Selector
//         } else {
//             return (false, "unknown selector");
//         }
//         emit LogCallin(flag, data, fromChainId);
//         return (true, "");
//     }

//     /**
//           @notice Function to responsible of calling clearDeposit() if a cross-chain call fails/reverts.
//           @param data data from reverted func.
//         **/
//     function anyFallback(bytes calldata data)
//         external
//         virtual
//         requiresExecutor
//         returns (bool success, bytes memory result)
//     {
//         (, uint256 fromChainId) = _getContext();
//         bytes1 flag = bytes1(data);

//         /// DEPOSIT FLAG: 1 (single asset settlement)
//         if (flag == 0x01) {
//             (, SettlementParams memory _sParams) = abi.decode(data[1:], (bytes, SettlementParams));

//             _reopenSettlemment(_sParams.nonce);

//             try IRouter(localRouterAddress).anyFallback(data[1:]) returns (
//                 bool,
//                 bytes memory
//             ) {} catch {
//                 emit RouterFallbackFailed(data);
//             }

//             /// DEPOSIT FLAG: 2 (multiple asset settlement)
//         } else if (flag == 0x02) {
//             (, SettlementMultipleParams memory _sParams) = abi.decode(
//                 data[1:],
//                 (bytes, SettlementMultipleParams)
//             );

//             _reopenSettlemment(_sParams.nonce);

//             try IRouter(localRouterAddress).anyFallback(data[1:]) returns (
//                 bool,
//                 bytes memory
//             ) {} catch {
//                 emit RouterFallbackFailed(data);
//             }

//             /// DEPOSIT FLAG: 4/5 (finalize deposit/withdraw)
//         } else if ((flag == 0x03 || flag == 0x04)) {
//             (, , uint32 _settlementNonce) = abi.decode(data[1:], (bytes1, bytes, uint32));
//             _reopenSettlemment(_settlementNonce);
//         }

//         emit LogCalloutFail(flag, data, fromChainId);
//         return (true, "");
//     }

//     /*///////////////////////////////////////////////////////////////
//                             MODIFIERS
//     //////////////////////////////////////////////////////////////*/

//     /// @notice Modifier for a simple re-entrancy check.
//     uint256 internal _unlocked = 1;
//     modifier lock() {
//         require(_unlocked == 1);
//         _unlocked = 2;
//         _;
//         _unlocked = 1;
//     }

//     /// @notice require msg sender == active branch interface
//     modifier requiresExecutor() {
//         _requiresExecutor();
//         _;
//     }

//     /// @notice reuse to reduce contract bytesize
//     function _requiresExecutor() internal view {
//         if (msg.sender == getBranchBridgeAgent[localChainId]) return;
//         if (msg.sender != localAnyCallExecutorAddress) revert AnycallUnauthorizedCaller();
//         (address from, uint256 fromChainId, ) = IAnycallExecutor(localAnyCallExecutorAddress)
//             .context();
//         if (getBranchBridgeAgent[fromChainId] != from) revert AnycallUnauthorizedCaller();
//     }

//     /// @notice require msg sender == active branch interface
//     modifier requiresRouter() {
//         _requiresRouter();
//         _;
//     }

//     /// @notice reuse to reduce contract bytesize
//     function _requiresRouter() internal view {
//         if (msg.sender != localRouterAddress) revert UnauthorizedCaller();
//     }
// }
