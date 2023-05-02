// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IBranchBridgeAgent.sol";

/**
 * @title BaseBranchRouter contract for deployment in Branch Chains of Omnichain System.
 * @author MaiaDAO
 * @dev Base Branch Interface for Anycall cross-chain messaging.
 *
 */
contract BranchBridgeAgent is IBranchBridgeAgent {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /// AnyExec Decode Consts

    uint8 internal constant PARAMS_START = 1;

    uint8 internal constant PARAMS_START_SIGNED = 21;

    uint8 internal constant PARAMS_END_SIGNED_OFFSET = 26;

    uint8 internal constant PARAMS_ENTRY_SIZE = 32;

    uint8 internal constant PARAMS_ADDRESS_SIZE = 20;

    uint8 internal constant PARAMS_TKN_SET_SIZE = 128;

    uint8 internal constant PARAMS_GAS_OUT = 16;

    /// ClearTokens Decode Consts

    uint8 internal constant PARAMS_TKN_START = 5;

    uint8 internal constant PARAMS_AMT_OFFSET = 64;

    uint8 internal constant PARAMS_DEPOSIT_OFFSET = 96;

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

    uint128 public accumulatedFees;

    uint128 public remoteCallDepositedGas;

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
                    VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchBridgeAgent
    function getDepositEntry(uint32 _depositNonce) external view returns (Deposit memory) {
        return _getDepositEntry(_depositNonce);
    }

    /**
     * @notice External function that returns a given deposit entry.
     *     @param _depositNonce Identifier for user deposit.
     *
     */
    function _getDepositEntry(uint32 _depositNonce) internal view returns (Deposit storage) {
        return getDeposit[_depositNonce];
    }

    /// @notice Internal function that returns 'from' address and 'fromChain' Id by performing an external call to AnycallExecutor Context.
    function _getContext() internal view returns (address from, uint256 fromChainId) {
        (from, fromChainId,) = IAnycallExecutor(localAnyCallExecutorAddress).context();
    }

    /*///////////////////////////////////////////////////////////////
                    LOCAL USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchBridgeAgent
    function callOut(bytes calldata _params, uint128 _remoteExecutionGas) external payable lock requiresFallbackGas {
        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Perform Call without deposit
        _callOut(msg.sender, _params, msg.value.toUint128(), _remoteExecutionGas);
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutAndBridge(bytes calldata _params, DepositInput memory _dParams, uint128 _remoteExecutionGas)
        external
        payable
        lock
        requiresFallbackGas
    {
        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Perform Call with deposit
        _callOutAndBridge(msg.sender, _params, _dParams, msg.value.toUint128(), _remoteExecutionGas);
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutAndBridgeMultiple(
        bytes calldata _params,
        DepositMultipleInput memory _dParams,
        uint128 _remoteExecutionGas
    ) external payable lock requiresFallbackGas {
        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Perform Call with multiple deposits
        _callOutAndBridgeMultiple(msg.sender, _params, _dParams, msg.value.toUint128(), _remoteExecutionGas);
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutSigned(bytes calldata _params, uint128 _remoteExecutionGas)
        external
        payable
        lock
        requiresFallbackGas
    {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x04), msg.sender, depositNonce, _params, msg.value.toUint128(), _remoteExecutionGas
        );

        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Perform Signed Call without deposit
        _noDepositCall(msg.sender, packedData, msg.value.toUint128());
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutSignedAndBridge(bytes calldata _params, DepositInput memory _dParams, uint128 _remoteExecutionGas)
        external
        payable
        lock
        requiresFallbackGas
    {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x05),
            msg.sender,
            depositNonce,
            _dParams.hToken,
            _dParams.token,
            _dParams.amount,
            _dParams.deposit,
            _dParams.toChain,
            _params,
            msg.value.toUint128(),
            _remoteExecutionGas
        );

        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Create Deposit and Send Cross-Chain request
        _depositAndCall(
            msg.sender,
            packedData,
            _dParams.hToken,
            _dParams.token,
            _dParams.amount,
            _dParams.deposit,
            msg.value.toUint128()
        );
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutSignedAndBridgeMultiple(
        bytes calldata _params,
        DepositMultipleInput memory _dParams,
        uint128 _remoteExecutionGas
    ) external payable lock requiresFallbackGas {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x06),
            msg.sender,
            uint8(_dParams.hTokens.length),
            depositNonce,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            _dParams.deposits,
            _dParams.toChain,
            _params,
            msg.value.toUint128(),
            _remoteExecutionGas
        );

        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Create Deposit and Send Cross-Chain request
        _depositAndCallMultiple(
            msg.sender,
            packedData,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            _dParams.deposits,
            msg.value.toUint128()
        );
    }

    /// @inheritdoc IBranchBridgeAgent
    function retrySettlement(uint32 _settlementNonce) external payable lock requiresFallbackGas {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(bytes1(0x07), _settlementNonce, msg.value.toUint128());

        //Deposit Gas for call.
        _createGasDeposit(msg.sender, msg.value.toUint128());

        //Perform Call
        _performCall(packedData);
    }

    /// @inheritdoc IBranchBridgeAgent
    function redeemDeposit(uint32 _depositNonce) external lock {
        //Update Deposit
        if (getDeposit[_depositNonce].status != DepositStatus.Failed) {
            revert DepositRedeemUnavailable();
        }
        _redeemDeposit(_depositNonce);
    }

    /*///////////////////////////////////////////////////////////////
                    BRANCH ROUTER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchBridgeAgent
    function performSystemCallOut(
        address _depositor,
        bytes calldata _params,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) external payable lock requiresRouter {
        //Get remote call execution deposited gas.
        (uint128 gasToBridgeOut, bool isRemote) =
            (remoteCallDepositedGas > 0 ? (_gasToBridgeOut, true) : (msg.value.toUint128(), false));

        //Wrap the gas allocated for omnichain execution.
        if (isRemote) wrappedNativeToken.deposit{value: msg.value}();

        //Check Fallback Gas
        _requiresFallbackGas(gasToBridgeOut);

        //Encode Data for cross-chain call.
        bytes memory packedData =
            abi.encodePacked(bytes1(0x00), depositNonce, _params, gasToBridgeOut, _remoteExecutionGas);

        //Perform Call
        _noDepositCall(_depositor, packedData, gasToBridgeOut);
    }

    /// @inheritdoc IBranchBridgeAgent
    function performCallOut(
        address _depositor,
        bytes calldata _params,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) external payable lock requiresRouter {
        //Get remote call execution deposited gas.
        (uint128 gasToBridgeOut, bool isRemote) =
            (remoteCallDepositedGas > 0 ? (_gasToBridgeOut, true) : (msg.value.toUint128(), false));

        //Wrap the gas allocated for omnichain execution.
        if (!isRemote) wrappedNativeToken.deposit{value: msg.value}();

        //Check Fallback Gas
        _requiresFallbackGas(gasToBridgeOut);

        //Perform Call
        _callOut(_depositor, _params, gasToBridgeOut, _remoteExecutionGas);
    }

    /// @inheritdoc IBranchBridgeAgent
    function performCallOutAndBridge(
        address _depositor,
        bytes calldata _params,
        DepositInput memory _dParams,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) external payable lock requiresRouter {
        //Get remote call execution deposited gas.
        (uint128 gasToBridgeOut, bool isRemote) =
            (remoteCallDepositedGas > 0 ? (_gasToBridgeOut, true) : (msg.value.toUint128(), false));

        //Wrap the gas allocated for omnichain execution.
        if (!isRemote) wrappedNativeToken.deposit{value: msg.value}();

        //Check Fallback Gas
        _requiresFallbackGas(gasToBridgeOut);

        //Perform Call
        _callOutAndBridge(_depositor, _params, _dParams, gasToBridgeOut, _remoteExecutionGas);
    }

    /// @inheritdoc IBranchBridgeAgent
    function performCallOutAndBridgeMultiple(
        address _depositor,
        bytes calldata _params,
        DepositMultipleInput memory _dParams,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) external payable lock requiresRouter {
        //Get remote call execution deposited gas.
        (uint128 gasToBridgeOut, bool isRemote) =
            (remoteCallDepositedGas > 0 ? (_gasToBridgeOut, true) : (msg.value.toUint128(), false));

        //Wrap the gas allocated for omnichain execution.
        if (!isRemote) wrappedNativeToken.deposit{value: msg.value}();

        //Check Fallback Gas
        _requiresFallbackGas(gasToBridgeOut);

        //Perform Call
        _callOutAndBridgeMultiple(_depositor, _params, _dParams, gasToBridgeOut, _remoteExecutionGas);
    }

    /*///////////////////////////////////////////////////////////////
                    LOCAL USER INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to perform a call to the Root Omnichain Router without token deposit.
     *   @param _depositor address of the user that will deposit the funds.
     *   @param _params RLP enconded parameters to execute on the root chain.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *   @param _remoteExecutionGas gas allocated for branch chain execution.
     *   @dev ACTION ID: 1 (Call without deposit)
     *
     */
    function _callOut(address _depositor, bytes calldata _params, uint128 _gasToBridgeOut, uint128 _remoteExecutionGas)
        internal
    {
        //Encode Data for cross-chain call.
        bytes memory packedData =
            abi.encodePacked(bytes1(0x01), depositNonce, _params, _gasToBridgeOut, _remoteExecutionGas);

        //Perform Call
        _noDepositCall(_depositor, packedData, _gasToBridgeOut);
    }

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing a single asset.
     *   @param _depositor address of the user that will deposit the funds.
     *   @param _params RLP enconded parameters to execute on the root chain.
     *   @param _dParams additional token deposit parameters.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *   @param _remoteExecutionGas gas allocated for branch chain execution.
     *   @dev ACTION ID: 2 (Call with single deposit)
     *
     */
    function _callOutAndBridge(
        address _depositor,
        bytes calldata _params,
        DepositInput memory _dParams,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) internal {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x02),
            depositNonce,
            _dParams.hToken,
            _dParams.token,
            _dParams.amount,
            _dParams.deposit,
            _dParams.toChain,
            _params,
            _gasToBridgeOut,
            _remoteExecutionGas
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCall(
            _depositor, packedData, _dParams.hToken, _dParams.token, _dParams.amount, _dParams.deposit, _gasToBridgeOut
        );
    }

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets.
     *   @param _params RLP enconded parameters to execute on the root chain.
     *   @param _dParams additional token deposit parameters.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *   @param _remoteExecutionGas gas allocated for branch chain execution.
     *   @dev ACTION ID: 3 (Call with multiple deposit)
     *
     */
    function _callOutAndBridgeMultiple(
        address _depositor,
        bytes calldata _params,
        DepositMultipleInput memory _dParams,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) internal {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x03),
            uint8(_dParams.hTokens.length),
            depositNonce,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            _dParams.deposits,
            _dParams.toChain,
            _params,
            _gasToBridgeOut,
            _remoteExecutionGas
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCallMultiple(
            _depositor,
            packedData,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            _dParams.deposits,
            _gasToBridgeOut
        );
    }

    /**
     * @notice Internal function to move assets from branch chain to root omnichain environment. Naive assets are deposited and hTokens are bridgedOut.
     *   @param _depositor token depositor.
     *   @param _data data to be sent to cross-chain messaging layer.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *
     */
    function _noDepositCall(address _depositor, bytes memory _data, uint128 _gasToBridgeOut) internal {
        //Deposit Gas for call.
        _createGasDeposit(_depositor, _gasToBridgeOut);

        //Perform Call
        _performCall(_data);
    }

    /**
     * @notice Internal function to move assets from branch chain to root omnichain environment. Naive assets are deposited and hTokens are bridgedOut.
     *   @param _depositor token depositor.
     *   @param _data data to be sent to cross-chain messaging layer.
     *   @param _hToken Local Input hToken Address.
     *   @param _token Native / Underlying Token Address.
     *   @param _amount Amount of Local hTokens deposited for trade.
     *   @param _deposit Amount of native tokens deposited for trade.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *
     */
    function _depositAndCall(
        address _depositor,
        bytes memory _data,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint128 _gasToBridgeOut
    ) internal {
        //Deposit and Store Info
        _createDepositSingle(_depositor, _hToken, _token, _amount, _deposit, _gasToBridgeOut);

        //Perform Call
        _performCall(_data);
    }

    /**
     * @dev Internal function to move assets from branch chain to root omnichain environment. Naive assets are deposited and hTokens are bridgedOut.
     *   @param _depositor token depositor.
     *   @param _data data to be sent to cross-chain messaging layer.
     *   @param _hTokens Local Input hToken Address.
     *   @param _tokens Native / Underlying Token Address.
     *   @param _amounts Amount of Local hTokens deposited for trade.
     *   @param _deposits  Amount of native tokens deposited for trade.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *
     */
    function _depositAndCallMultiple(
        address _depositor,
        bytes memory _data,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint128 _gasToBridgeOut
    ) internal {
        //Validate Input
        if (
            _hTokens.length != _tokens.length || _tokens.length != _amounts.length
                || _amounts.length != _deposits.length
        ) revert InvalidInput();

        //Deposit and Store Info
        _createDepositMultiple(_depositor, _hTokens, _tokens, _amounts, _deposits, _gasToBridgeOut);

        //Perform Call
        _performCall(_data);
    }

    /**
     * @dev Function to create a pending deposit.
     *    @param _user user address.
     *    @param _gasToBridgeOut gas allocated for omnichain execution.
     *
     */
    function _createGasDeposit(address _user, uint128 _gasToBridgeOut) internal {
        //Deposit Gas to Port
        address(wrappedNativeToken).safeTransfer(localPortAddress, _gasToBridgeOut);

        // Update State
        getDeposit[_getAndIncrementDepositNonce()] = Deposit({
            owner: _user,
            hTokens: new address[](0),
            tokens: new address[](0),
            amounts: new uint256[](0),
            deposits: new uint256[](0),
            status: DepositStatus.Success,
            depositedGas: _gasToBridgeOut
        });
    }

    /**
     * @dev Function to create a pending deposit.
     *    @param _user user address.
     *    @param _hToken deposited local hToken addresses.
     *    @param _token deposited native / underlying Token addresses.
     *    @param _amount amounts of hTokens input.
     *    @param _deposit amount of deposited underlying / native tokens.
     *    @param _gasToBridgeOut gas allocated for omnichain execution.
     *
     */
    function _createDepositSingle(
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint128 _gasToBridgeOut
    ) internal {
        //Deposit / Lock Tokens into Port
        IPort(localPortAddress).bridgeOut(_user, _hToken, _token, _amount, _deposit);

        //Deposit Gas to Port
        address(wrappedNativeToken).safeTransfer(localPortAddress, _gasToBridgeOut);

        // Cast to dynamic memory array
        address[] memory hTokens = new address[](1);
        hTokens[0] = _hToken;
        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = _deposit;

        // Update State
        getDeposit[_getAndIncrementDepositNonce()] = Deposit({
            owner: _user,
            hTokens: hTokens,
            tokens: tokens,
            amounts: amounts,
            deposits: deposits,
            status: DepositStatus.Success,
            depositedGas: _gasToBridgeOut
        });
    }

    /**
     * @notice Function to create a pending deposit.
     *    @param _user user address.
     *    @param _hTokens deposited local hToken addresses.
     *    @param _tokens deposited native / underlying Token addresses.
     *    @param _amounts amounts of hTokens input.
     *    @param _deposits amount of deposited underlying / native tokens.
     *    @param _gasToBridgeOut gas allocated for omnichain execution.
     *
     */
    function _createDepositMultiple(
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint128 _gasToBridgeOut
    ) internal {
        //Deposit / Lock Tokens into Port
        IPort(localPortAddress).bridgeOutMultiple(_user, _hTokens, _tokens, _amounts, _deposits);

        //Deposit Gas to Port
        address(wrappedNativeToken).safeTransfer(localPortAddress, _gasToBridgeOut);

        // Update State
        getDeposit[_getAndIncrementDepositNonce()] = Deposit({
            owner: _user,
            hTokens: _hTokens,
            tokens: _tokens,
            amounts: _amounts,
            deposits: _deposits,
            status: DepositStatus.Success,
            depositedGas: _gasToBridgeOut
        });
    }

    /**
     * @dev External function to clear / refund a user's failed deposit.
     *    @param _depositNonce Identifier for user deposit.
     *
     */
    function _redeemDeposit(uint32 _depositNonce) internal {
        //Get Deposit
        Deposit storage deposit = _getDepositEntry(_depositNonce);

        //Transfer token to depositor / user
        for (uint256 i = 0; i < deposit.hTokens.length;) {
            if (deposit.amounts[i] - deposit.deposits[i] > 0) {
                IPort(localPortAddress).bridgeIn(
                    deposit.owner, deposit.hTokens[i], deposit.amounts[i] - deposit.deposits[i]
                );
            }
            IPort(localPortAddress).withdraw(deposit.owner, deposit.tokens[i], deposit.deposits[i]);

            unchecked {
                ++i;
            }
        }
        IPort(localPortAddress).withdraw(deposit.owner, address(wrappedNativeToken), deposit.depositedGas);

        //Delete Failed Deposit
        delete getDeposit[_depositNonce];
    }

    /**
     * @notice Function that returns Deposit nonce and increments counter.
     *
     */
    function _getAndIncrementDepositNonce() internal returns (uint32) {
        return depositNonce++;
    }

    /*///////////////////////////////////////////////////////////////
                    REMOTE EXECUTED INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to clear / refund a user's failed deposit. Called upon fallback in cross-chain messaging.
     *    @param _depositNonce Identifier for user deposit.
     *
     */
    function _clearDeposit(uint32 _depositNonce) internal {
        //Update and return Deposit
        getDeposit[_depositNonce].status = DepositStatus.Failed;
    }

    /**
     * @notice Function to request balance clearance from a Port to a given user.
     *     @param _recipient token receiver.
     *     @param _hToken  local hToken addresse to clear balance for.
     *     @param _token  native / underlying token addresse to clear balance for.
     *     @param _amount amounts of hToken to clear balance for.
     *     @param _deposit amount of native / underlying tokens to clear balance for.
     *
     */
    function _clearToken(address _recipient, address _hToken, address _token, uint256 _amount, uint256 _deposit)
        internal
    {
        if (_amount - _deposit > 0) {
            IPort(localPortAddress).bridgeIn(_recipient, _hToken, _amount - _deposit);
        }

        if (_deposit > 0) {
            IPort(localPortAddress).withdraw(_recipient, _token, _deposit);
        }
    }

    /**
     * @notice Function to request balance clearance from a Port to a given user.
     *     @param _sParams encode packed multiple settlement info.
     *
     */
    function _clearTokens(bytes calldata _sParams, address _recipient)
        internal
        returns (SettlementMultipleParams memory)
    {
        //Parse Params
        uint8 numOfAssets = uint8(bytes1(_sParams[0]));
        uint32 nonce = uint32(bytes4(_sParams[PARAMS_START:PARAMS_TKN_START]));

        address[] memory _hTokens = new address[](numOfAssets);
        address[] memory _tokens = new address[](numOfAssets);
        uint256[] memory _amounts = new uint256[](numOfAssets);
        uint256[] memory _deposits = new uint256[](numOfAssets);

        //Transfer token to recipient
        for (uint256 i = 0; i < numOfAssets;) {
            //Parse Params
            _hTokens[i] = address(
                uint160(
                    bytes20(
                        bytes32(
                            _sParams[
                                PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * i) + 12:
                                    PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * (PARAMS_START + i))
                            ]
                        )
                    )
                )
            );

            _tokens[i] = address(
                uint160(
                    bytes20(
                        _sParams[
                            PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(i + numOfAssets) + 12:
                                PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i + numOfAssets)
                        ]
                    )
                )
            );

            _amounts[i] = uint256(
                bytes32(
                    _sParams[
                        PARAMS_TKN_START + PARAMS_AMT_OFFSET * uint16(numOfAssets) + (PARAMS_ENTRY_SIZE * uint16(i)):
                            PARAMS_TKN_START + PARAMS_AMT_OFFSET * uint16(numOfAssets)
                                + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i)
                    ]
                )
            );

            _deposits[i] = uint256(
                bytes32(
                    _sParams[
                        PARAMS_TKN_START + PARAMS_DEPOSIT_OFFSET * uint16(numOfAssets) + (PARAMS_ENTRY_SIZE * uint16(i)):
                            PARAMS_TKN_START + PARAMS_DEPOSIT_OFFSET * uint16(numOfAssets)
                                + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i)
                    ]
                )
            );

            //Clear Tokens to destination
            if (_amounts[i] - _deposits[i] > 0) {
                IPort(localPortAddress).bridgeIn(_recipient, _hTokens[i], _amounts[i] - _deposits[i]);
            }

            if (_deposits[i] > 0) {
                IPort(localPortAddress).withdraw(_recipient, _tokens[i], _deposits[i]);
            }

            unchecked {
                ++i;
            }
        }

        return SettlementMultipleParams(numOfAssets, _recipient, nonce, _hTokens, _tokens, _amounts, _deposits);
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
    function _performCall(bytes memory _calldata) internal virtual {
        //Sends message to AnycallProxy
        IAnycallProxy(localAnyCallAddress).anyCall(
            rootBridgeAgentAddress, _calldata, rootChainId, AnycallFlags.FLAG_ALLOW_FALLBACK, ""
        );
    }

    function _payExecutionGas(address _recipient, uint256 _initialGas, uint256 _feesOwed) internal virtual {
        //Gas remaining
        uint256 gasRemaining = wrappedNativeToken.balanceOf(address(this));

        //Unwrap Gas
        wrappedNativeToken.withdraw(gasRemaining);

        //Get Branch Environment Execution Cost
        uint256 minExecCost = _feesOwed + tx.gasprice * (MIN_EXECUTION_OVERHEAD + _initialGas - gasleft());

        //Replenish Gas
        _replenishGas(minExecCost);

        //Transfer gas remaining to recipient
        if (minExecCost < gasRemaining) {
            SafeTransferLib.safeTransferETH(_recipient, gasRemaining - minExecCost);
        }

        delete(remoteCallDepositedGas);
    }

    function _payFallbackGas(uint32 _depositNonce, uint256 _initialGas, uint256 _feesOwed) internal virtual {
        //Get Branch Environment Execution Cost
        uint256 minExecCost = _feesOwed + tx.gasprice * (MIN_FALLBACK_OVERHEAD + _initialGas - gasleft());

        //Update user deposit reverts if not enough gas => user must boost deposit with gas
        getDeposit[_depositNonce].depositedGas -= minExecCost.toUint128();

        //Withdraw Gas
        IPort(localPortAddress).withdraw(address(this), address(wrappedNativeToken), minExecCost);

        //Unwrap Gas
        wrappedNativeToken.withdraw(minExecCost);

        //Replenish Gas
        _replenishGas(minExecCost);
    }

    function _replenishGas(uint256 _executionGasSpent) internal virtual {
        //Deposit Gas
        IAnycallConfig(IAnycallProxy(localAnyCallAddress).config()).deposit{value: _executionGasSpent}(address(this));
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
     * @notice Function responsible of executing a crosschain request when one is received.
     *   @param data data received from messaging layer.
     *
     */
    function anyExecute(bytes calldata data)
        external
        virtual
        requiresExecutor
        returns (bool success, bytes memory result)
    {
        //Get Initial Gas Checkpoint
        uint256 initialGas = gasleft();

        //Save Length
        uint256 dataLength = data.length;

        //Store deposited gas
        uint128 depositedGas = _gasSwapIn(data[data.length - PARAMS_GAS_OUT:dataLength]).toUint128();
        remoteCallDepositedGas = depositedGas;

        //Action Recipient
        address recipient = address(uint160(bytes20(data[PARAMS_START:PARAMS_START_SIGNED])));

        //Get Action Flag
        bytes1 flag = bytes1(data[0]);

        //DEPOSIT FLAG: 0 (No settlement)
        if (flag == 0x00) {
            IRouter(localRouterAddress).anyExecuteNoSettlement(
                data[PARAMS_START_SIGNED + 4:dataLength - PARAMS_GAS_OUT]
            );
            emit LogCallin(flag, data, rootChainId);

            //DEPOSIT FLAG: 1 (Single Asset Settlement)
        } else if (flag == 0x01) {
            //Clear Token / Execute Settlement
            SettlementParams memory sParams = SettlementParams({
                settlementNonce: 0,
                recipient: recipient,
                hToken: address(uint160(bytes20(data[25:45]))),
                token: address(uint160(bytes20(data[45:65]))),
                amount: uint256(bytes32(data[65:97])),
                deposit: uint256(bytes32(data[97:129]))
            });

            _clearToken(sParams.recipient, sParams.hToken, sParams.token, sParams.amount, sParams.deposit);

            //Execute Calldata
            if (dataLength - PARAMS_GAS_OUT > 129) {
                IRouter(localRouterAddress).anyExecuteSettlement(data[129:dataLength - PARAMS_GAS_OUT], sParams);
            }
            emit LogCallin(flag, data, rootChainId);

            //DEPOSIT FLAG: 2 (Multiple Settlement)
        } else if (flag == 0x02) {
            ///Clear Tokens / Execute Settlement

            SettlementMultipleParams memory sParams = _clearTokens(
                data[
                    PARAMS_START_SIGNED:
                        PARAMS_START_SIGNED + PARAMS_TKN_START
                            + (uint8(bytes1(data[PARAMS_START_SIGNED])) * uint16(PARAMS_TKN_SET_SIZE))
                ],
                address(uint160(bytes20(data[PARAMS_START:PARAMS_START_SIGNED])))
            );

            //Execute Calldata
            if (
                dataLength - PARAMS_GAS_OUT
                    > PARAMS_START_SIGNED + PARAMS_TKN_START
                        + (uint8(bytes1(data[PARAMS_START_SIGNED])) * uint16(PARAMS_TKN_SET_SIZE))
            ) {
                IRouter(localRouterAddress).anyExecuteSettlementMultiple(
                    data[
                        PARAMS_END_SIGNED_OFFSET + (uint8(bytes1(data[PARAMS_START_SIGNED])) * PARAMS_TKN_SET_SIZE):
                            dataLength - 16
                    ],
                    sParams
                );
            }

            emit LogCallin(flag, data, rootChainId);

            //Unrecognized Function Selector
        } else {
            _payExecutionGas(recipient, initialGas, _computeAnyCallFees(dataLength));
            return (false, "unknown selector");
        }
        _payExecutionGas(recipient, initialGas, _computeAnyCallFees(dataLength));
        return (true, "");
    }

    /**
     * @notice Function to responsible of calling _clearDeposit() if a cross-chain call fails/reverts.
     *       @param data data from reverted func.
     *
     */
    function anyFallback(bytes calldata data)
        external
        virtual
        requiresExecutor
        returns (bool success, bytes memory result)
    {
        //Get Initial Gas Checkpoint
        uint256 initialGas = gasleft();
        //Save Flag
        bytes1 flag = data[0];
        //Save memory for Deposit Nonce
        uint32 _depositNonce;

        /// ACTION FLAG: 0, 1, 2
        if ((flag == 0x00) || (flag == 0x01) || (flag == 0x02)) {
            //Check nonce calldata slice.
            _depositNonce = uint32(bytes4(data[PARAMS_START:PARAMS_TKN_START]));

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            //Deduct gas costs from deposit and replenish this bridge agent's execution budget.
            _payFallbackGas(_depositNonce, initialGas, _computeAnyCallFees(data.length));

            emit LogCalloutFail(flag, data, rootChainId);
            return (true, "");

            /// ACTION FLAG: 3
        } else if (flag == 0x03) {
            _depositNonce = uint32(bytes4(data[PARAMS_START + PARAMS_START:PARAMS_TKN_START + PARAMS_START]));

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            //Deduct gas costs from deposit and replenish this bridge agent's execution budget.
            _payFallbackGas(_depositNonce, initialGas, _computeAnyCallFees(data.length));

            emit LogCalloutFail(flag, data, rootChainId);
            return (true, "");

            /// DEPOSIT FLAG: 4, 5
        } else if ((flag == 0x04) || (flag == 0x05)) {
            _depositNonce = uint32(bytes4(data[PARAMS_START_SIGNED:PARAMS_START_SIGNED + PARAMS_TKN_START]));

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            //Deduct gas costs from deposit and replenish this bridge agent's execution budget.
            _payFallbackGas(_depositNonce, initialGas, _computeAnyCallFees(data.length));

            emit LogCalloutFail(flag, data, rootChainId);
            return (true, "");

            /// DEPOSIT FLAG: 6
        } else if (flag == 0x06) {
            _depositNonce = uint32(
                bytes4(data[PARAMS_START_SIGNED + PARAMS_START:PARAMS_START_SIGNED + PARAMS_TKN_START + PARAMS_START])
            );

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            //Deduct gas costs from deposit and replenish this bridge agent's execution budget.
            _payFallbackGas(_depositNonce, initialGas, _computeAnyCallFees(data.length));

            emit LogCalloutFail(flag, data, rootChainId);
            return (true, "");

            //Unrecognized Function Selector
        } else {
            return (false, "unknown selector");
        }
    }

    /**
     * @notice Internal function to calculate cost fo cross-chain message.
     *   @param dataLength bytes that will be sent through messaging layer.
     *
     */
    function _computeAnyCallFees(uint256 dataLength) internal virtual returns (uint256 fees) {
        fees =
            IAnycallConfig(IAnycallProxy(localAnyCallAddress).config()).calcSrcFees(address(0), rootChainId, dataLength);
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
    modifier requiresExecutor() {
        _requiresExecutor();
        _;
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresExecutor() internal view virtual {
        if (msg.sender != localAnyCallExecutorAddress) revert AnycallUnauthorizedCaller();
        (address from,,) = IAnycallExecutor(localAnyCallExecutorAddress).context();
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

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresFallbackGas() {
        _requiresFallbackGas();
        _;
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresFallbackGas() internal view virtual {
        if (msg.value <= MIN_FALLBACK_OVERHEAD) revert InsufficientGas();
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresFallbackGas(uint256 _depositedGas) internal view virtual {
        if (_depositedGas <= MIN_FALLBACK_OVERHEAD) revert InsufficientGas();
    }

    fallback() external payable {}
}
