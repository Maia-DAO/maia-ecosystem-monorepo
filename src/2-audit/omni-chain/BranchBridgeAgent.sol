// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IBranchBridgeAgent.sol";

import { console2 } from "forge-std/console2.sol";

/**
@title BaseBranchRouter contract for deployment in Branch Chains of Omnichain System.
@author MaiaDAO
@dev Base Branch Interface for Anycall cross-chain messaging.

//TODO: V7 notes is it still advisable to store the executor in the state or should we query every time

*/
contract BranchBridgeAgent is IBranchBridgeAgent {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /// AnyExec Decode Consts

    uint8 internal constant PARAMS_START = 1;

    uint8 internal constant PARAMS_START_SIGNED = 21;

    uint8 internal constant PARAMS_END_OFFSET = 38;

    uint8 internal constant PARAMS_END_SIGNED_OFFSET = 57;

    uint8 internal constant PARAMS_ENTRY_SIZE = 32;

    uint8 internal constant PARAMS_ADDRESS_SIZE = 20;

    uint8 internal constant PARAMS_TKN_SET_SIZE = 104;

    /// BridgeIn Decode Consts

    uint8 internal constant PARAMS_TKN_START = 5;

    uint8 internal constant PARAMS_TKN_OFFSET = 20;

    uint8 internal constant PARAMS_AMT_OFFSET = 40;

    uint8 internal constant PARAMS_DEPOSIT_OFFSET = 72;

    /// @notice Chain Id for Root Chain where liqudity is virtualized(e.g. 4).
    uint256 public immutable rootChainId;

    /// @notice Chain Id for Local Chain.
    uint256 public immutable localChainId;

    /// @notice Address for Local Wrapped Native Token.
    WETH9 public immutable wrappedNativeToken;

    /// @notice Address for Bridge Agent who processes requests submitted for the Root Router Address where cross-chain requests are executed in the Root Chain.
    address public immutable rootBridgeAgentAddress;

    /// @notice Address for Local AnycallV7 Proxy Address where cross-chain requests are sent to the Root Chain Router.
    address public immutable localAnyCallAddress;

    /// @notice Address for Local Anyexec Address where cross-chain requests from the Root Chain Router are received locally.
    address public immutable localAnyCallExecutorAddress;

    /// @notice Address for Local Router used for custom actions for different hApps.
    address public immutable localRouterAddress;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    address public immutable localPortAddress;

    /// @notice Deposit nonce used for identifying transaction.
    uint32 public depositNonce;

    /// @notice Mapping from Pending deposits hash to Deposit Struct.
    mapping(uint32 => Deposit) public getDeposit;

    uint256 internal constant MIN_EXECUTION_OVERHEAD = 250000;
    uint256 internal constant MIN_FALLBACK_OVERHEAD = 150000;

    uint256 public accumulatedFees;

    constructor(
        WETH9 _wrappedNativeToken,
        uint256 _rootChainId,
        uint256 _localChainId,
        address _rootBridgeAgentAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localRouterAddress,
        address _localPortAddress
    ) {
        wrappedNativeToken = _wrappedNativeToken;
        localChainId = _localChainId;
        rootChainId = _rootChainId;
        rootBridgeAgentAddress = _rootBridgeAgentAddress;
        localAnyCallAddress = _localAnyCallAddress;
        localAnyCallExecutorAddress = _localAnyCallExecutorAddress;
        localRouterAddress = _localRouterAddress;
        localPortAddress = _localPortAddress;
        depositNonce = 1;
    }

    /*///////////////////////////////////////////////////////////////
                    BRANCH ROUTER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /** @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging. 0x00 flag allows for identifying system emitted request/responses.
        @param params calldata for omnichain execution.
        @param depositor address of user depositing assets.
        @param rootExecutionGas gas allocated for omnichain execution.
    **/
    function performCall(
        bytes memory params,
        address depositor,
        uint128 rootExecutionGas
    ) external payable requiresRouter lock {
        //Encode Data for cross-chain call.
        bytes memory data = abi.encodePacked(
            bytes1(0x00),
            depositNonce,
            params,
            msg.value.toUint128(),
            rootExecutionGas
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCall(depositor, data, address(0), address(0), 0, 0);
    }

    /*///////////////////////////////////////////////////////////////
                    LOCAL USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
      @notice Function to perform a call to the Root Omnichain Router without token deposit.
      @param params RLP enconded parameters to execute on the root chain.
      @param rootExecutionGas gas allocated for omnichain execution.
      @dev ACTION ID: 1 (Call without deposit) 
    **/
    function callOut(bytes calldata params, uint128 rootExecutionGas) external payable lock {
        console2.log("here adskdajdal");
        //Encode Data for cross-chain call.
        bytes memory data = abi.encodePacked(
            bytes1(0x01),
            depositNonce,
            params,
            msg.value.toUint128(),
            rootExecutionGas
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCall(msg.sender, data, address(0), address(0), 0, 0);
    }

    /**
      @notice Function to perform a call to the Root Omnichain Router while depositing a single asset.
      @param params RLP enconded parameters to execute on the root chain.
      @param dParams additional token deposit parameters.
      @param rootExecutionGas gas allocated for omnichain execution.
      @dev ACTION ID: 2 (Call with single deposit) 
    **/
    function callOut(
        bytes calldata params,
        DepositInput memory dParams,
        uint128 rootExecutionGas
    ) external payable lock {
        //Encode Data for cross-chain call.
        bytes memory data = abi.encodePacked(
            bytes1(0x02),
            depositNonce,
            dParams.hToken,
            dParams.token,
            dParams.amount,
            dParams.deposit,
            dParams.toChain,
            params,
            msg.value.toUint128(),
            rootExecutionGas
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCall(
            msg.sender,
            data,
            dParams.hToken,
            dParams.token,
            dParams.amount,
            dParams.deposit
        );
    }

    /**
      @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets.
      @param params RLP enconded parameters to execute on the root chain.
      @param dParams additional token deposit parameters.
      @param rootExecutionGas gas allocated for omnichain execution.
      @dev ACTION ID: 3 (Call with multiple deposit) 
    **/
    function callOut(
        bytes calldata params,
        DepositMultipleInput memory dParams,
        uint128 rootExecutionGas
    ) external payable lock {
        //Encode Data for cross-chain call.
        bytes memory data = abi.encodePacked(
            bytes1(0x03),
            uint8(dParams.hTokens.length),
            depositNonce,
            dParams.hTokens,
            dParams.tokens,
            dParams.amounts,
            dParams.deposits,
            dParams.toChain,
            params,
            msg.value.toUint128(),
            rootExecutionGas
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCallMultiple(
            msg.sender,
            data,
            dParams.hTokens,
            dParams.tokens,
            dParams.amounts,
            dParams.deposits
        );
    }

    /**
      @notice Function to perform a call to the Root Omnichain Router without token deposit with msg.sender information.
      @param params RLP enconded parameters to execute on the root chain.
      @param rootExecutionGas gas allocated for omnichain execution.
      @dev ACTION ID: 4 (Call without deposit and verified sender) 
    **/
    function callOutSigned(bytes calldata params, uint128 rootExecutionGas) external payable lock {
        //Encode Data for cross-chain call.
        bytes memory data = abi.encodePacked(
            bytes1(0x04),
            msg.sender,
            depositNonce,
            params,
            msg.value.toUint128(),
            rootExecutionGas
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCall(msg.sender, data, address(0), address(0), 0, 0);
    }

    /**
      @notice Function to perform a call to the Root Omnichain Router while depositing a single asset msg.sender.
      @param params RLP enconded parameters to execute on the root chain.
      @param dParams additional token deposit parameters.
      @param rootExecutionGas gas allocated for omnichain execution.


      @dev ACTION ID: 5 (Call with single deposit and verified sender) 
      @dev FUNC ID: Call Root Router Function
    **/
    function callOutSigned(
        bytes calldata params,
        DepositInput memory dParams,
        uint128 rootExecutionGas
    ) external payable lock {
        //Encode Data for cross-chain call.
        bytes memory data = abi.encodePacked(
            bytes1(0x05),
            msg.sender,
            depositNonce,
            dParams.hToken,
            dParams.token,
            dParams.amount,
            dParams.deposit,
            dParams.toChain,
            params,
            msg.value.toUint128(),
            rootExecutionGas
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCall(
            msg.sender,
            data,
            dParams.hToken,
            dParams.token,
            dParams.amount,
            dParams.deposit
        );
    }

    /**
      @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets with msg.sender.
      @param params RLP enconded parameters to execute on the root chain.
      @param dParams additional token deposit parameters.
      @param rootExecutionGas gas allocated for omnichain execution.
      @dev ACTION ID: 6 (Call with multiple deposit and verified sender) 
    **/
    function callOutSigned(
        bytes calldata params,
        DepositMultipleInput memory dParams,
        uint128 rootExecutionGas
    ) external payable lock {
        //Encode Data for cross-chain call.
        bytes memory data = abi.encodePacked(
            bytes1(0x06),
            msg.sender,
            uint8(dParams.hTokens.length),
            depositNonce,
            dParams.hTokens,
            dParams.tokens,
            dParams.amounts,
            dParams.deposits,
            dParams.toChain,
            params,
            msg.value.toUint128(),
            rootExecutionGas
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCallMultiple(
            msg.sender,
            data,
            dParams.hTokens,
            dParams.tokens,
            dParams.amounts,
            dParams.deposits
        );
    }

    /** @notice External function to retry a failed Settlement entry on the root chain.
        @param _settlementNonce Identifier for user settlement.
        @dev ACTION ID: 10    
    **/
    function retrySettlement(uint32 _settlementNonce) external payable lock {
        //Encode Data for cross-chain call.
        bytes memory data = abi.encodePacked(bytes1(0x07), _settlementNonce, msg.value.toUint128());

        //Create Deposit and Send Cross-Chain request maybe mstore instead of casting two times
        _depositAndCall(msg.sender, data, address(0), address(0), 0, 0);
    }

    /** @notice External function to retry a failed Deposit entry on this branch chain.
        @param _depositNonce Identifier for user deposit.
    **/
    function redeemDeposit(uint32 _depositNonce) external lock {
        //Update Deposit
        if (getDeposit[_depositNonce].status != DepositStatus.Failed)
            revert DepositRedeemUnavailable();
        _redeemDeposit(_depositNonce);
    }

    /** @dev External function that returns a given deposit entry.
        @param _depositNonce Identifier for user deposit.
    **/
    function getDepositEntry(uint32 _depositNonce) external view returns (Deposit memory) {
        return _getDepositEntry(_depositNonce);
    }

    /*///////////////////////////////////////////////////////////////
                    LOCAL USER INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
      @notice Internal function to move assets from branch chain to root omnichain environment. Naive assets are deposited and hTokens are bridgedOut.
      @param _depositor token depositor.
      @param _data data to be sent to cross-chain messaging layer.
      @param _hToken Local Input hToken Address.
      @param _token Native / Underlying Token Address.
      @param _amount Amount of Local hTokens deposited for trade.
      @param _deposit Amount of native tokens deposited for trade.
    **/
    function _depositAndCall(
        address _depositor,
        bytes memory _data,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit
    ) internal {
        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{ value: msg.value }();

        //Deposit and Store Info
        _createDepositSingle(_depositor, _hToken, _token, _amount, _deposit);

        //Perform Call
        _performCall(_data);
    }

    /**
      @dev Internal function to move assets from branch chain to root omnichain environment. Naive assets are deposited and hTokens are bridgedOut.
      @param _depositor token depositor.
      @param _data data to be sent to cross-chain messaging layer.
      @param _hTokens Local Input hToken Address.
      @param _tokens Native / Underlying Token Address.
      @param _amounts Amount of Local hTokens deposited for trade.
      @param _deposits  Amount of native tokens deposited for trade.
    **/
    function _depositAndCallMultiple(
        address _depositor,
        bytes memory _data,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits
    ) internal {
        //Validate Input
        if (
            _hTokens.length != _tokens.length ||
            _tokens.length != _amounts.length ||
            _amounts.length != _deposits.length
        ) revert InvalidInput();

        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{ value: msg.value }();

        //Deposit and Store Info
        _createDepositMultiple(_depositor, _hTokens, _tokens, _amounts, _deposits);

        //Perform Call
        _performCall(_data);
    }

    /**
       @dev Function to create a pending deposit.
       @param _user user address.
       @param _hToken deposited local hToken addresses.
       @param _token deposited native / underlying Token addresses.
       @param _amount amounts of hTokens input.
       @param _deposit amount of deposited underlying / native tokens.
    **/
    function _createDepositSingle(
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit
    ) internal {
        //Cast to Dynamic TODO clean up
        address[] memory hTokens = new address[](1);
        hTokens[0] = _hToken;
        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = _deposit;

        //Create Deposit
        _createDepositMultiple(_user, hTokens, tokens, amounts, deposits);
    }

    /**
       @notice Function to create a pending deposit.
       @param _user user address.
       @param _hTokens deposited local hToken addresses.
       @param _tokens deposited native / underlying Token addresses.
       @param _amounts amounts of hTokens input.
       @param _deposits amount of deposited underlying / native tokens.
    **/
    function _createDepositMultiple(
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits
    ) internal {
        //Deposit / Lock Tokens into Port
        IPort(localPortAddress).bridgeOutMultiple(_user, _hTokens, _tokens, _amounts, _deposits);
        address(wrappedNativeToken).safeTransfer(localPortAddress, msg.value);

        // Update State
        getDeposit[_getAndIncrementDepositNonce()] = Deposit({
            owner: _user,
            hTokens: _hTokens,
            tokens: _tokens,
            amounts: _amounts,
            deposits: _deposits,
            status: DepositStatus.Success,
            depositedGas: msg.value
        });
    }

    /**
       @dev External function to clear / refund a user's failed deposit.
       @param _depositNonce Identifier for user deposit.
    **/
    function _redeemDeposit(uint32 _depositNonce) internal {
        //Get Deposit
        Deposit storage deposit = _getDepositEntry(_depositNonce);

        //Transfer token to depositor / user TODO: OPTIMIZE UNNECESSARY LOADS
        for (uint256 i = 0; i < deposit.hTokens.length; ) {
            if (deposit.amounts[i] - deposit.deposits[i] > 0) {
                IPort(localPortAddress).bridgeIn(
                    deposit.owner,
                    deposit.hTokens[i],
                    deposit.amounts[i] - deposit.deposits[i]
                );
            }
            IPort(localPortAddress).withdraw(deposit.owner, deposit.tokens[i], deposit.deposits[i]);

            unchecked {
                ++i;
            }
        }
        IPort(localPortAddress).withdraw(
            deposit.owner,
            address(wrappedNativeToken),
            deposit.depositedGas
        );
    }

    /** @notice External function that returns a given deposit entry.
        @param _depositNonce Identifier for user deposit.
    **/
    function _getDepositEntry(uint32 _depositNonce) internal view returns (Deposit storage) {
        return getDeposit[_depositNonce];
    }

    /**
      @notice Function that returns Deposit nonce and increments counter.
    **/
    function _getAndIncrementDepositNonce() internal returns (uint32) {
        return depositNonce++;
    }

    /*///////////////////////////////////////////////////////////////
                    REMOTE EXECUTED INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
       @notice Function to clear / refund a user's failed deposit. Called upon fallback in cross-chain messaging.
       @param _depositNonce Identifier for user deposit.
    **/
    function _clearDeposit(uint32 _depositNonce) internal {
        //Update and return Deposit
        getDeposit[_depositNonce].status = DepositStatus.Failed;
    }

    /**
        @notice Function to request balance clearance from a Port to a given user.
        @param _recipient token receiver.
        @param _hToken  local hToken addresse to clear balance for.
        @param _token  native / underlying token addresse to clear balance for.
        @param _amount amounts of hToken to clear balance for.
        @param _deposit amount of native / underlying tokens to clear balance for.
    **/
    function _clearToken(
        address _recipient,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit
    ) internal {
        if (_amount - _deposit > 0) {
            IPort(localPortAddress).bridgeIn(_recipient, _hToken, _amount - _deposit);
        }

        if (_deposit > 0) {
            IPort(localPortAddress).withdraw(_recipient, _token, _deposit);
        }
    }

    /**
        @notice Function to request balance clearance from a Port to a given user.
        @param _sParams encode packed multiple settlement info.
    **/
    function _clearTokens(
        bytes calldata _sParams,
        address _recipient
    ) internal returns (SettlementMultipleParams memory) {
        //Parse Params
        uint8 numOfAssets = uint8(bytes1(_sParams[0]));
        uint32 nonce = uint32(bytes4(_sParams[PARAMS_START:5]));
        uint256 toChain = uint256(bytes32(_sParams[_sParams.length - 32:_sParams.length]));

        address[] memory _hTokens = new address[](numOfAssets);
        address[] memory _tokens = new address[](numOfAssets);
        uint256[] memory _amounts = new uint256[](numOfAssets);
        uint256[] memory _deposits = new uint256[](numOfAssets);

        //Transfer token to recipient
        for (uint256 i = 0; i < numOfAssets; ) {
            //Parse Params
            _hTokens[i] = address(
                uint160(
                    bytes20(
                        _sParams[PARAMS_TKN_START + (PARAMS_ADDRESS_SIZE * i):PARAMS_TKN_START +
                            (PARAMS_ADDRESS_SIZE * i) +
                            PARAMS_ADDRESS_SIZE]
                    )
                )
            );

            _tokens[i] = address(
                uint160(
                    bytes20(
                        _sParams[PARAMS_TKN_START +
                            (PARAMS_ADDRESS_SIZE * numOfAssets) +
                            (PARAMS_ADDRESS_SIZE * i):PARAMS_TKN_START +
                            (PARAMS_ADDRESS_SIZE * numOfAssets) +
                            (PARAMS_ADDRESS_SIZE * i) +
                            PARAMS_ADDRESS_SIZE]
                    )
                )
            );

            _amounts[i] = uint256(
                bytes32(
                    _sParams[PARAMS_TKN_START +
                        (PARAMS_AMT_OFFSET * numOfAssets) +
                        (PARAMS_ENTRY_SIZE * i):PARAMS_TKN_START +
                        (PARAMS_AMT_OFFSET * numOfAssets) +
                        (PARAMS_ENTRY_SIZE * i) +
                        PARAMS_ENTRY_SIZE]
                )
            );

            _deposits[i] = uint256(
                bytes32(
                    _sParams[PARAMS_TKN_START +
                        (PARAMS_DEPOSIT_OFFSET * numOfAssets) +
                        (PARAMS_ENTRY_SIZE * i):PARAMS_TKN_START +
                        (PARAMS_DEPOSIT_OFFSET * numOfAssets) +
                        (PARAMS_ENTRY_SIZE * i) +
                        PARAMS_ENTRY_SIZE]
                )
            );

            //Clear Tokens to destination
            if (_amounts[i] - _deposits[i] > 0) {
                IPort(localPortAddress).bridgeIn(
                    _recipient,
                    _hTokens[i],
                    _amounts[i] - _deposits[i]
                );
            }

            if (_deposits[i] > 0) {
                IPort(localPortAddress).withdraw(_recipient, _tokens[i], _deposits[i]);
            }

            unchecked {
                ++i;
            }
        }

        //Transfer token to depositor / user TODO   OPTIMIZE UNNECESSARY EXTERNAL CALLS
        for (uint256 i = 0; i < _hTokens.length; ) {
            console2.log(_hTokens[i]);
            console2.log(_amounts[i] - _deposits[i]);
            console2.log(_tokens[i]);
            console2.log(_deposits[i]);

            if (_amounts[i] - _deposits[i] > 0) {
                IPort(localPortAddress).bridgeIn(
                    _recipient,
                    _hTokens[i],
                    _amounts[i] - _deposits[i]
                );
            }
            if (_deposits[i] > 0) {
                IPort(localPortAddress).withdraw(_recipient, _tokens[i], _deposits[i]);
            }

            unchecked {
                ++i;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function that returns 'from' address and 'fromChain' Id by performing an external call to AnycallExecutor Context.
    function _getContext() internal view returns (address from, uint256 fromChainId) {
        //TODO verify if localAnycallExecutor should be queried from callproxy every time.
        (from, fromChainId, ) = IAnycallExecutor(localAnyCallExecutorAddress).context();
    }

    /// @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
    function _performCall(bytes memory _calldata) internal virtual {
        //Sends message to AnycallProxy
        IAnycallProxy(localAnyCallAddress).anyCall(
            rootBridgeAgentAddress,
            _calldata,
            rootChainId,
            AnycallFlags.FLAG_ALLOW_FALLBACK,
            ""
        );
    }

    function _payExecutionGas(
        address _recipient,
        uint256 _initialGas,
        uint256 _depositedGasTokens,
        uint256 _feesOwed
    ) internal virtual returns (uint256) {
        //Unwrap Gas
        wrappedNativeToken.withdraw(_depositedGasTokens);

        //Get Branch Environment Execution Cost
        uint256 minExecCost = tx.gasprice *
            (MIN_EXECUTION_OVERHEAD + _initialGas - _feesOwed - gasleft());

        //Replenish Gas
        _replenishGas(minExecCost);

        //Transfer gas remaining to recipient
        if (minExecCost < _depositedGasTokens)
            SafeTransferLib.safeTransferETH(_recipient, _depositedGasTokens - minExecCost);
    }

    function _payFallbackGas(
        uint32 _depositNonce,
        uint256 _initialGas,
        uint256 _feesOwed
    ) internal virtual returns (uint256) {
        //Get Branch Environment Execution Cost
        uint256 minExecCost = tx.gasprice *
            (MIN_FALLBACK_OVERHEAD + _initialGas - _feesOwed - gasleft());

        //Update user deposit reverts if not enough gas => user must boost deposit with gas
        getDeposit[_depositNonce].depositedGas -= minExecCost;

        //Withdraw Gas
        IPort(localPortAddress).withdraw(address(this), address(wrappedNativeToken), minExecCost);

        //Unwrap Gas
        wrappedNativeToken.withdraw(minExecCost);

        //Replenish Gas
        _replenishGas(minExecCost);
    }

    function _replenishGas(uint256 _executionGasSpent) internal virtual {
        //Deposit Gas
        IAnycallConfig(IAnycallProxy(localAnyCallAddress).config()).deposit{
            value: _executionGasSpent
        }(address(this));
    }

    function _gasSwapIn(bytes memory gasData) internal returns (uint256 gasAmount) {
        //Cast to uint256
        gasAmount = uint256(uint128(bytes16(gasData)));
        //Move Gas hTokens from Branch to Root / Mint Sufficient hTokens to match new port deposit
        IPort(localPortAddress).withdraw(address(this), address(wrappedNativeToken), gasAmount);
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
      @notice Function responsible of executing a crosschain request when one is received.
      @param data data received from messaging layer.
    **/
    function anyExecute(
        bytes calldata data
    ) external virtual requiresExecutor returns (bool success, bytes memory result) {
        //Get Initial Gas Checkpoint
        uint256 initialGas = gasleft();

        //Save Length
        uint256 dataLength = data.length;

        //Action Recipient
        address recipient;

        //Get Action Flag
        bytes1 flag = bytes1(data[0]);

        //DEPOSIT FLAG: 0 (No settlement)
        if (flag == 0x00) {
            recipient = address(uint160(bytes20(data[1:21])));
            IRouter(localRouterAddress).anyExecuteNoSettlement(data[1:dataLength - 16]);
            emit LogCallin(flag, data, rootChainId);

            //DEPOSIT FLAG: 1 (Single Asset Settlement)
        } else if (flag == 0x01) {
            //Get Recipient
            recipient = address(uint160(bytes20(data[PARAMS_TKN_START:25])));
            //Clear Token / Execute Settlement
            SettlementParams memory sParams = SettlementParams({
                settlementNonce: uint32(bytes4(data[PARAMS_START:PARAMS_TKN_START])),
                recipient: recipient,
                hToken: address(uint160(bytes20(data[25:45]))),
                token: address(uint160(bytes20(data[45:65]))),
                amount: uint256(bytes32(data[65:97])),
                deposit: uint256(bytes32(data[97:129]))
            });

            _clearToken(
                sParams.recipient,
                sParams.hToken,
                sParams.token,
                sParams.amount,
                sParams.deposit
            );

            //Execute Calldata
            if (dataLength > 129) {
                IRouter(localRouterAddress).anyExecuteSettlement(
                    data[129:dataLength - 16],
                    sParams
                );
            }
            emit LogCallin(flag, data, rootChainId);

            //DEPOSIT FLAG: 2 (Multiple Settlement)
        } else if (flag == 0x02) {
            //Get Recipient
            recipient = address(uint160(bytes20(data[PARAMS_START:PARAMS_START_SIGNED])));
            ///Clear Tokens / Execute Settlement
            SettlementMultipleParams memory sParams = _clearTokens(
                data[PARAMS_START_SIGNED:PARAMS_END_SIGNED_OFFSET +
                    (uint8(bytes1(data[PARAMS_START_SIGNED])) * PARAMS_TKN_SET_SIZE)],
                address(uint160(bytes20(data[PARAMS_START:PARAMS_START_SIGNED])))
            );

            //Execute Calldata
            if (
                dataLength >
                PARAMS_END_SIGNED_OFFSET +
                    (uint8(bytes1(data[PARAMS_START_SIGNED])) * PARAMS_TKN_SET_SIZE)
            )
                IRouter(localRouterAddress).anyExecuteSettlementMultiple(
                    data[PARAMS_END_SIGNED_OFFSET +
                        (uint8(bytes1(data[PARAMS_START_SIGNED])) *
                            PARAMS_TKN_SET_SIZE):dataLength - 16],
                    sParams
                );

            _payExecutionGas(
                recipient,
                initialGas,
                _gasSwapIn(data[data.length - 16:dataLength]),
                _computeAnyCallFees(dataLength)
            );

            emit LogCallin(flag, data, rootChainId);

            //Unrecognized Function Selector
        } else {
            return (false, "unknown selector");
        }
        return (true, "");
    }

    /**
          @notice Function to responsible of calling _clearDeposit() if a cross-chain call fails/reverts.
          @param data data from reverted func.
        **/
    function anyFallback(
        bytes calldata data
    ) external virtual requiresExecutor returns (bool success, bytes memory result) {
        //Get Initial Gas Checkpoint
        uint256 initialGas = gasleft();
        //Save Flag
        bytes1 flag = data[0];
        //Save memory for Deposit Nonce
        uint32 _depositNonce;

        console2.log("anyFallback");
        console2.log(uint8(data[1]));

        /// DEPOSIT FLAG: 2, 3, 5 or 6 (with Deposit)
        if ((flag == 0x02) || (flag == 0x03) || (flag == 0x05) || (flag == 0x06)) {
            //TODO Check nonce calldata slice.
            _depositNonce = uint32(bytes4(data[22]));

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            //Deduct gas costs from deposit and replenish this bridge agent's execution budget.
            _payFallbackGas(_depositNonce, initialGas, _computeAnyCallFees(data.length));

            emit LogCalloutFail(flag, data, rootChainId);
            return (true, "");
        }
        //Unrecognized Function Selector
        else {
            return (false, "unknown selector");
        }
    }

    /**
      @notice Internal function to calculate cost fo cross-chain message.
      @param dataLength bytes that will be sent through messaging layer.
    **/
    function _computeAnyCallFees(uint256 dataLength) internal virtual returns (uint256 fees) {
        fees = IAnycallConfig(IAnycallProxy(localAnyCallAddress).config()).calcSrcFees(
            address(0),
            rootChainId,
            dataLength
        );
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier for a simple re-entrancy check.
    uint256 internal _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    /// TODO verify if eecutor must be queried every time
    modifier requiresExecutor() {
        _requiresExecutor();
        _;
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresExecutor() internal view virtual {
        if (msg.sender != localAnyCallExecutorAddress) revert AnycallUnauthorizedCaller();
        (address from, uint256 fromChainId, ) = IAnycallExecutor(localAnyCallExecutorAddress)
            .context();
        if (from != rootBridgeAgentAddress) revert AnycallUnauthorizedCaller();
    }

    /// @notice require msg sender == active branch interface
    modifier requiresRouter() {
        _requiresRouter();
        _;
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresRouter() internal view {
        if (msg.sender != localRouterAddress) revert UnauthorizedCallerNotRouter();
    }
}
