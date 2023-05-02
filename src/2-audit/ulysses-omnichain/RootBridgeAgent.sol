// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRootBridgeAgent.sol";

library CheckParamsLib {
    /**
     * @notice Function to check cross-chain params and verify deposits made on branch chain. Local hToken must be recognized and address much match underlying if exists otherwise only local hToken is checked.
     * @param _localPortAddress Address of local Port.
     * @param _dParams Cross Chain swap parameters.
     * @param _fromChain Chain ID of the chain where the deposit was made.
     *
     */
    function checkParams(address _localPortAddress, DepositParams memory _dParams, uint24 _fromChain)
        internal
        view
        returns (bool)
    {
        if (
            (_dParams.amount < _dParams.deposit) //Deposit can't be greater than amount.
                || (_dParams.amount > 0 && !IPort(_localPortAddress).isLocalToken(_dParams.hToken, _fromChain)) //Check local exists.
                || (_dParams.deposit > 0 && !IPort(_localPortAddress).isUnderlyingToken(_dParams.token, _fromChain)) //Check underlying exists.
        ) {
            return false;
        }
        return true;
    }
}

/**
 * @title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
 * @author MaiaDAO
 * @notice Base Root Router for Anycall cross-chain messaging.
 *
 *   BRIDGE AGENT ACTION IDs
 *   --------------------------------------
 *   ID           | DESCRIPTION
 *   -------------+------------------------
 *   0x00         | Branch Router Response.
 *   0x01         | Call to Root Router without Deposit.
 *   0x02         | Call to Root Router with Deposit.
 *   0x03         | Call to Root Router with Deposit of Multiple Tokens.
 *   0x04         | Call to Root Router without Deposit + singned message.
 *   0x05         | Call to Root Router with Deposit + singned message.
 *   0x06         | Call to Root Router with Deposit of Multiple Tokens + singned message.
 *   0x07         | Call to ´depositToPort()´.
 *   0x08         | Call to ´withdrawFromPort()´.
 *   0x09         | Call to ´bridgeTo()´.
 *   0x0a         | Call to ´clearSettlement()´.
 *
 */
contract RootBridgeAgent is IRootBridgeAgent {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /*///////////////////////////////////////////////////////////////
                            ENCODING CONSTS
    //////////////////////////////////////////////////////////////*/

    /// AnyExec Consts

    uint8 internal constant PARAMS_START = 1;

    uint8 internal constant PARAMS_START_SIGNED = 21;

    uint8 internal constant PARAMS_END_OFFSET = 9;

    uint8 internal constant PARAMS_END_SIGNED_OFFSET = 29;

    uint8 internal constant PARAMS_ENTRY_SIZE = 32;

    uint8 internal constant PARAMS_ADDRESS_SIZE = 20;

    uint8 internal constant PARAMS_TKN_SET_SIZE = 104;

    uint8 internal constant PARAMS_TKN_SET_SIZE_MULTIPLE = 128;

    uint8 internal constant PARAMS_GAS_IN = 32;

    uint8 internal constant PARAMS_GAS_OUT = 16;

    /// BridgeIn Consts

    uint8 internal constant PARAMS_TKN_START = 5;

    uint8 internal constant PARAMS_AMT_OFFSET = 64;

    uint8 internal constant PARAMS_DEPOSIT_OFFSET = 96;

    /*///////////////////////////////////////////////////////////////
                        ROOT BRIDGE AGENT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Local Chain Id
    uint24 public immutable localChainId;

    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Address of DAO.
    address public immutable factoryAddress;

    /// @notice Address of DAO.
    address public immutable daoAddress;

    /// @notice Local Root Router Address
    address public immutable localRouterAddress;

    /// @notice Address for Local Port Address where funds deposited from this chain are stored.
    address public immutable localPortAddress;

    /// @notice Local Anycall Address
    address public immutable localAnyCallAddress;

    /// @notice Local Anyexec Address
    address public immutable localAnyCallExecutorAddress;

    /*///////////////////////////////////////////////////////////////
                    BRANCH BRIDGE AGENTS STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Chain -> Branch Bridge Agent Address. For N chains, each Root Bridge Agent Address has M =< N Branch Bridge Agent Address.
    mapping(uint256 => address) public getBranchBridgeAgent;

    /// @notice If true, bridge agent manager has allowed for a new given branch bridge agent to be synced/added.
    mapping(uint256 => bool) public isBranchBridgeAgentAllowed;

    /*///////////////////////////////////////////////////////////////
                        SETTLEMENTS STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit nonce used for identifying transaction.
    uint32 public settlementNonce;

    /// @notice Mapping from Settlement nonce to Deposit Struct.
    mapping(uint32 => Settlement) public getSettlement;

    /*///////////////////////////////////////////////////////////////
                        GAS MANAGEMENT STATE
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MIN_EXECUTION_OVERHEAD = 250000;
    uint256 internal constant MIN_FALLBACK_OVERHEAD = 50000;
    uint256 internal constant MIN_PAY_FALLBACK_GAS_OVERHEAD = 10000;

    uint256 public initialGas;
    uint256 public accumulatedFees;
    UserFeeInfo public userFeeInfo;

    /**
     * @notice Constructor for Bridge Agent.
     *     @param _wrappedNativeToken Local Wrapped Native Token.
     *     @param _daoAddress Address of DAO.
     *     @param _localChainId Local Chain Id.
     *     @param _localAnyCallAddress Local Anycall Address.
     *     @param _localPortAddress Local Port Address.
     *     @param _localRouterAddress Local Port Address.
     */
    constructor(
        WETH9 _wrappedNativeToken,
        uint24 _localChainId,
        address _daoAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localPortAddress,
        address _localRouterAddress
    ) {
        wrappedNativeToken = _wrappedNativeToken;
        factoryAddress = msg.sender;
        daoAddress = _daoAddress;
        localChainId = _localChainId;
        localAnyCallAddress = _localAnyCallAddress;
        localPortAddress = _localPortAddress;
        localRouterAddress = _localRouterAddress;
        localAnyCallExecutorAddress = _localAnyCallExecutorAddress;
        settlementNonce = 1;
    }

    /*///////////////////////////////////////////////////////////////
                        VIEW EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function getSettlementEntry(uint32 _settlementNonce) external view returns (Settlement memory) {
        return _getSettlementEntry(_settlementNonce);
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresExecutor() internal view {
        if (msg.sender == getBranchBridgeAgent[localChainId]) return;

        if (msg.sender != localAnyCallExecutorAddress) revert AnycallUnauthorizedCaller();
        (address from, uint256 fromChainId,) = IAnycallExecutor(localAnyCallExecutorAddress).context();
        if (getBranchBridgeAgent[fromChainId] != from) revert AnycallUnauthorizedCaller();
    }

    /**
     * @notice External function that returns a given settlement entry.
     *     @param _settlementNonce Identifier for token settlement.
     *
     */
    function _getSettlementEntry(uint32 _settlementNonce) internal view returns (Settlement storage) {
        return getSettlement[_settlementNonce];
    }

    /// @notice Internal function that return 'from' address and 'fromChain' Id by performing an external call to AnycallExecutor Context.
    function _getContext() internal view returns (address from, uint256 fromChainId) {
        (from, fromChainId,) = IAnycallExecutor(localAnyCallExecutorAddress).context();
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresRouter() internal view {
        if (msg.sender != localRouterAddress) revert UnauthorizedCaller();
    }

    /*///////////////////////////////////////////////////////////////
                        USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function clearSettlement(uint32 _settlementNonce, uint128 _remoteExecutionGas) external payable {
        //Update User Gas available.
        if (initialGas == 0) {
            userFeeInfo.depositedGas = uint128(msg.value);
            userFeeInfo.gasToBridgeOut = _remoteExecutionGas;
        }
        //Clear Settlement with updated gas.
        _clearSettlement(_settlementNonce);
    }

    /*///////////////////////////////////////////////////////////////
                    ROOT ROUTER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function callOut(address _recipient, bytes memory _data, uint24 _toChain) external payable requiresRouter {
        //Encode Data for call.
        bytes memory data = abi.encodePacked(bytes1(0x00), _recipient, settlementNonce, _data, _manageGasOut(_toChain));

        //Perform Call to clear hToken balance on destination branch chain.
        _performCall(data, _toChain);
    }

    /// @inheritdoc IRootBridgeAgent
    function callOutAndBridge(
        address _recipient,
        bytes memory _data,
        address _globalAddress,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain
    ) external payable requiresRouter {
        //Get destination Local Address from Global Address.
        address localAddress = IPort(localPortAddress).getLocalTokenFromGlobal(_globalAddress, _toChain);

        //Get destination Underlying Address from Local Address.
        address underlyingAddress = IPort(localPortAddress).getUnderlyingTokenFromLocal(localAddress, _toChain);

        //Create Settlement Entry + Perform Call to destination Branch Chain.
        _settleAndCall(
            msg.sender, _recipient, _globalAddress, localAddress, underlyingAddress, _amount, _deposit, _toChain, _data
        );
    }

    /// @inheritdoc IRootBridgeAgent
    function callOutAndBridgeMultiple(
        address _recipient,
        bytes memory _data,
        address[] memory _globalAddresses,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain
    ) external payable requiresRouter {
        address[] memory hTokens = new address[](_globalAddresses.length);
        address[] memory tokens = new address[](_globalAddresses.length);
        for (uint256 i = 0; i < _globalAddresses.length;) {
            //Populate Addresses for Settlement
            hTokens[i] = IPort(localPortAddress).getLocalTokenFromGlobal(_globalAddresses[i], _toChain);
            tokens[i] = IPort(localPortAddress).getUnderlyingTokenFromLocal(hTokens[i], _toChain);
            _updateStateOnBridgeOut(
                msg.sender, _globalAddresses[i], hTokens[i], tokens[i], _amounts[i], _deposits[i], _toChain
            );

            unchecked {
                ++i;
            }
        }

        //Prepare data for call with settlement of multiple assets
        bytes memory data = abi.encodePacked(
            bytes1(0x02),
            _recipient,
            uint8(hTokens.length),
            settlementNonce,
            hTokens,
            tokens,
            _amounts,
            _deposits,
            _data,
            _manageGasOut(_toChain)
        );

        //Create Settlement Balance
        _createMultipleSettlement(_recipient, hTokens, tokens, _amounts, _deposits, data, _toChain);

        //Perform Call to destination Branch Chain.
        _performCall(data, _toChain);
    }

    /*///////////////////////////////////////////////////////////////
                    TOKEN MANAGEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to move assets from branch chain to root omnichain environment.
     *   @param _dParams Cross-Chain Deposit of Multiple Tokens Params.
     *   @param _fromChain chain to bridge from.
     *
     */
    function _bridgeIn(address _recipient, DepositParams memory _dParams, uint24 _fromChain) internal {
        //Check Deposit info from Cross Chain Parameters.
        if (!CheckParamsLib.checkParams(localPortAddress, _dParams, _fromChain)) {
            revert InvalidInputParams();
        }

        //Get global address
        address globalAddress = IPort(localPortAddress).getGlobalTokenFromLocal(_dParams.hToken, _fromChain);

        //Move hTokens from Branch to Root + Mint Sufficient hTokens to match new port deposit
        IPort(localPortAddress).bridgeToRoot(_recipient, globalAddress, _dParams.amount, _dParams.deposit, _fromChain);
    }

    /**
     * @notice Internal function to move assets from branch chain to root omnichain environment.
     *   @param _dParams Cross-Chain Deposit of Multiple Tokens Params.
     *   @param _fromChain chain to bridge from.
     *   @dev Since the input data is encodePacked we need to parse it:
     *     1. First byte is the number of assets to be bridged in. Equals length of all arrays.
     *     2. Next 4 bytes are the nonce of the deposit.
     *     3. Last 32 bytes after the token related information are the chain to bridge to.
     *     4. Token related information starts at index PARAMS_TKN_START is encoded as follows:
     *         1. N * 32 bytes for the hToken address.
     *         2. N * 32 bytes for the underlying token address.
     *         3. N * 32 bytes for the amount of hTokens to be bridged in.
     *         4. N * 32 bytes for the amount of underlying tokens to be bridged in.
     *     5. Each of the 4 token related arrays are of length N and start at the following indexes:
     *         1. PARAMS_TKN_START [hToken address has no offset from token information start].
     *         2. PARAMS_TKN_START + (PARAMS_ADDRESS_SIZE * N)
     *         3. PARAMS_TKN_START + (PARAMS_AMT_OFFSET * N)
     *         4. PARAMS_TKN_START + (PARAMS_DEPOSIT_OFFSET * N)
     *
     */
    function _bridgeInMultiple(address _recipient, bytes calldata _dParams, uint24 _fromChain)
        internal
        returns (DepositMultipleParams memory)
    {
        // Parse Parameters
        uint8 numOfAssets = uint8(bytes1(_dParams[0]));
        uint32 nonce = uint32(bytes4(_dParams[PARAMS_START:5]));
        uint24 toChain = uint24(bytes3(_dParams[_dParams.length - 3:_dParams.length]));

        address[] memory hTokens = new address[](numOfAssets);
        address[] memory tokens = new address[](numOfAssets);
        uint256[] memory amounts = new uint256[](numOfAssets);
        uint256[] memory deposits = new uint256[](numOfAssets);

        for (uint256 i = 0; i < uint256(uint8(numOfAssets));) {
            //Parse Params
            hTokens[i] = address(
                uint160(
                    bytes20(
                        bytes32(
                            _dParams[
                                PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * i) + 12:
                                    PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * (PARAMS_START + i))
                            ]
                        )
                    )
                )
            );

            tokens[i] = address(
                uint160(
                    bytes20(
                        _dParams[
                            PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(i + numOfAssets) + 12:
                                PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i + numOfAssets)
                        ]
                    )
                )
            );

            amounts[i] = uint256(
                bytes32(
                    _dParams[
                        PARAMS_TKN_START + PARAMS_AMT_OFFSET * uint16(numOfAssets) + (PARAMS_ENTRY_SIZE * uint16(i)):
                            PARAMS_TKN_START + PARAMS_AMT_OFFSET * uint16(numOfAssets)
                                + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i)
                    ]
                )
            );

            deposits[i] = uint256(
                bytes32(
                    _dParams[
                        PARAMS_TKN_START + PARAMS_DEPOSIT_OFFSET * uint16(numOfAssets) + (PARAMS_ENTRY_SIZE * uint16(i)):
                            PARAMS_TKN_START + PARAMS_DEPOSIT_OFFSET * uint16(numOfAssets)
                                + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i)
                    ]
                )
            );

            _bridgeIn(
                _recipient,
                DepositParams({
                    hToken: hTokens[i],
                    token: tokens[i],
                    amount: amounts[i],
                    deposit: deposits[i],
                    toChain: toChain,
                    depositNonce: 0
                }),
                _fromChain
            );

            unchecked {
                ++i;
            }
        }
        return (
            DepositMultipleParams({
                numberOfAssets: numOfAssets,
                depositNonce: nonce,
                hTokens: hTokens,
                tokens: tokens,
                amounts: amounts,
                deposits: deposits,
                toChain: toChain
            })
        );
    }

    /**
     * @notice Updates the token balance state by moving assets from root omnichain environment to branch chain, when a user wants to bridge out tokens from the root bridge agent chain.
     *     @param _sender address of the sender.
     *     @param _globalAddress address of the global token.
     *     @param _localAddress address of the local token.
     *     @param _underlyingAddress address of the underlying token.
     *     @param _amount amount of hTokens to be bridged out.
     *     @param _deposit amount of underlying tokens to be bridged out.
     *     @param _toChain chain to bridge to.
     */
    function _updateStateOnBridgeOut(
        address _sender,
        address _globalAddress,
        address _localAddress,
        address _underlyingAddress,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain
    ) internal {
        if (_amount - _deposit > 0) {
            //Move output hTokens from Root to Branch
            if (_localAddress == address(0)) revert UnrecognizedLocalAddress();
            _globalAddress.safeTransferFrom(_sender, localPortAddress, _amount - _deposit);
        }

        if (_deposit > 0) {
            //Verify there is enough balance to clear native tokens if needed
            if (_underlyingAddress == address(0)) revert UnrecognizedUnderlyingAddress();
            if (IERC20hTokenRoot(_globalAddress).getTokenBalance(_toChain) < _deposit) {
                revert InsufficientBalanceForSettlement();
            }
            IPort(localPortAddress).burn(_sender, _globalAddress, _deposit, _toChain);
        }
    }

    /**
     * @notice Internal function to move assets from root omnichain environment to branch chain. hTokens are bridgedOut.
     *   @param _data data to be sent to cross-chain messaging layer for remote execution.
     *   @param _depositor token depositor.
     *   @param _recipient token recipient on destination chain (important for gas refunds).
     *   @param _globalAddress Global / Root Environment hToken Address.
     *   @param _localAddress Local Input hToken Address.
     *   @param _underlyingAddress Native / Underlying Token Address.
     *   @param _amount Amount of Local hTokens deposited for trade.
     *   @param _deposit Amount of native tokens deposited for trade.
     *   @param _toChain  Destination chain identificator.
     *
     */
    function _settleAndCall(
        address _depositor,
        address _recipient,
        address _globalAddress,
        address _localAddress,
        address _underlyingAddress,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain,
        bytes memory _data
    ) internal {
        //Prepare data for call
        bytes memory data = abi.encodePacked(
            bytes1(0x01),
            _recipient,
            settlementNonce,
            _localAddress,
            _underlyingAddress,
            _amount,
            _deposit,
            _data,
            _manageGasOut(_toChain)
        );

        _updateStateOnBridgeOut(
            _depositor, _globalAddress, _localAddress, _underlyingAddress, _amount, _deposit, _toChain
        );

        //Create Settlement Balance
        _createSettlement(_recipient, _localAddress, _underlyingAddress, _amount, _deposit, data, _toChain);

        //Perform Call to clear hToken balance on destination branch chain.
        _performCall(data, _toChain);
    }

    /*///////////////////////////////////////////////////////////////
                SETTLEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to create a settlemment A.K.A. token output to user. Settlement should be reopened if fallback occurs.
     *    @param _user user address.
     *    @param _hToken deposited global token addresses.
     *    @param _token deposited global token addresses.
     *    @param _amount amounts of hTokens input.
     *    @param _deposit amount of deposited underlying / native tokens.
     *    @param _callData amount of deposited underlying / native tokens.
     *    @param _toChain amount of deposited underlying / native tokens.
     *
     *
     */
    function _createSettlement(
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        bytes memory _callData,
        uint24 _toChain
    ) internal {
        //Cast to Dynamic
        address[] memory hTokens = new address[](1);
        hTokens[0] = _hToken;
        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = _deposit;

        //Call createSettlement
        _createMultipleSettlement(_user, hTokens, tokens, amounts, deposits, _callData, _toChain);
    }

    /**
     * @notice Function to create a settlemment A.K.A. token output to user. Settlement should be reopened if fallback occurs.
     *    @param _user user address.
     *    @param _hTokens deposited global token addresses.
     *    @param _tokens deposited global token addresses.
     *    @param _amounts amounts of hTokens input.
     *    @param _deposits amount of deposited underlying / native tokens.
     *    @param _callData amount of deposited underlying / native tokens.
     *    @param _toChain amount of deposited underlying / native tokens.
     *
     *
     */
    function _createMultipleSettlement(
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        bytes memory _callData,
        uint24 _toChain
    ) internal {
        // Update State
        getSettlement[_getAndIncrementSettlementNonce()] = Settlement({
            owner: _user,
            hTokens: _hTokens,
            tokens: _tokens,
            amounts: _amounts,
            deposits: _deposits,
            callData: _callData,
            gasOwed: 0,
            toChain: _toChain,
            status: SettlementStatus.Success
        });
    }

    /**
     * @notice Function to retry a user's Settlement balance.
     *     @param _settlementNonce Identifier for token settlement.
     *
     */
    function _clearSettlement(uint32 _settlementNonce) internal {
        //Get Settlement
        Settlement memory settlement = _getSettlementEntry(_settlementNonce);

        //Require Status to be Pending
        require(settlement.status == SettlementStatus.Pending);

        //Update Settlement
        getSettlement[_settlementNonce].status = SettlementStatus.Success;

        //Slice last 4 bytes calldata
        uint128 prevGasToBridgeOut =
            uint128(bytes16(BytesLib.slice(settlement.callData, settlement.callData.length - 16, 16)));

        //abi encodePacked
        bytes memory newGas = abi.encodePacked(prevGasToBridgeOut + _manageGasOut(settlement.toChain));

        //overwrite last 16bytes of callData
        for (uint256 i = 0; i < newGas.length;) {
            settlement.callData[settlement.callData.length - 16 + i] = newGas[i];
            unchecked {
                ++i;
            }
        }

        //Set Settlement
        getSettlement[_settlementNonce].callData = settlement.callData;

        //Retry call with additional gas
        _performCall(settlement.callData, settlement.toChain);
    }

    /**
     * @notice Function to reopen a user's Settlement balance as pending and thus retryable by users. Called upon fallback of clearTokens() to Branch.
     *     @param _settlementNonce Identifier for token settlement.
     *
     */
    function _reopenSettlemment(uint32 _settlementNonce) internal {
        //Update Deposit
        getSettlement[_settlementNonce].status = SettlementStatus.Pending;
    }

    /**
     * @notice Function that returns Deposit nonce and increments counter.
     *
     */
    function _getAndIncrementSettlementNonce() internal returns (uint32) {
        return settlementNonce++;
    }

    /*///////////////////////////////////////////////////////////////
                    GAS SWAP INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    uint24 private constant GLOBAL_DIVISIONER = 1e6; // for basis point (0.0001%)

    mapping(address => bool) private approvedGasPool;

    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata _data) external {
        if (!approvedGasPool[msg.sender]) revert CallerIsNotPool();
        if (amount0 == 0 && amount1 == 0) revert AmountsAreZero();
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));

        address(data.tokenIn).safeTransfer(msg.sender, uint256(amount0 > 0 ? amount0 : amount1));
    }

    /**
     * @notice Swaps gas tokens from the given branch chain to the root chain
     * @param _amount amount of gas token to swap
     * @param _fromChain chain to swap from
     */
    function _gasSwapIn(uint256 _amount, uint24 _fromChain) internal returns (uint256) {
        //Get fromChain's Gas Pool Info
        (bool zeroForOneOnInflow, uint24 priceImpactPercentage, address gasTokenGlobalAddress, address poolAddress) =
            IPort(localPortAddress).getGasPoolInfo(_fromChain);

        //Move Gas hTokens from Branch to Root / Mint Sufficient hTokens to match new port deposit
        IPort(localPortAddress).bridgeToRoot(address(this), gasTokenGlobalAddress, _amount, _amount, _fromChain);

        //Save Gas Pool for future use
        if (!approvedGasPool[poolAddress]) approvedGasPool[poolAddress] = true;

        //Get sqrtPriceX96
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddress).slot0();

        // Calculate Price limit depending on pre-set price impact
        uint160 exactSqrtPriceImpact = (sqrtPriceX96 * (priceImpactPercentage / 2)) / GLOBAL_DIVISIONER;

        uint160 sqrtPriceLimitX96 =
            zeroForOneOnInflow ? sqrtPriceX96 - exactSqrtPriceImpact : sqrtPriceX96 + exactSqrtPriceImpact;

        //Swap imbalanced token as long as we haven't used the entire amountSpecified and haven't reached the price limit
        (int256 amount0, int256 amount1) = IUniswapV3Pool(poolAddress).swap(
            address(this),
            zeroForOneOnInflow,
            int256(_amount),
            sqrtPriceLimitX96,
            abi.encode(SwapCallbackData({tokenIn: gasTokenGlobalAddress}))
        );

        return uint256((zeroForOneOnInflow ? amount1 : amount0));
    }

    /**
     * @notice Swaps gas tokens from the given root chain to the branch chain
     * @param _amount amount of gas token to swap
     * @param _toChain chain to swap to
     */
    function _gasSwapOut(uint256 _amount, uint24 _toChain) internal returns (uint256, address) {
        //Get fromChain's Gas Pool Info
        (bool zeroForOneOnInflow, uint24 priceImpactPercentage, address gasTokenGlobalAddress, address poolAddress) =
            IPort(localPortAddress).getGasPoolInfo(_toChain);

        //Save Gas Pool for future use
        if (!approvedGasPool[poolAddress]) approvedGasPool[poolAddress] = true;

        uint160 sqrtPriceLimitX96;
        {
            //Get sqrtPriceX96
            (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddress).slot0();

            // Calculate Price limit depending on pre-set price impact
            uint160 exactSqrtPriceImpact = (sqrtPriceX96 * (priceImpactPercentage / 2)) / GLOBAL_DIVISIONER;

            sqrtPriceLimitX96 =
                zeroForOneOnInflow ? sqrtPriceX96 + exactSqrtPriceImpact : sqrtPriceX96 - exactSqrtPriceImpact;
        }

        //Swap imbalanced token as long as we haven't used the entire amountSpecified and haven't reached the price limit
        (int256 amount0, int256 amount1) = IUniswapV3Pool(poolAddress).swap(
            address(this),
            !zeroForOneOnInflow,
            int256(_amount),
            sqrtPriceLimitX96,
            abi.encode(SwapCallbackData({tokenIn: address(wrappedNativeToken)}))
        );

        return (uint256((!zeroForOneOnInflow ? amount1 : amount0)), gasTokenGlobalAddress);
    }

    /**
     * @notice
     * @param _toChain chain to swap to
     */
    function _manageGasOut(uint24 _toChain) internal returns (uint128) {
        uint256 amountOut;
        address gasToken;
        if (_toChain == localChainId) return uint128(userFeeInfo.gasToBridgeOut);

        if (initialGas > 0) {
            if (userFeeInfo.gasToBridgeOut <= MIN_FALLBACK_OVERHEAD) revert InsufficientGasForFees();
            (amountOut, gasToken) = _gasSwapOut(userFeeInfo.gasToBridgeOut, _toChain);
        } else {
            if (msg.value <= MIN_FALLBACK_OVERHEAD) revert InsufficientGasForFees();
            wrappedNativeToken.deposit{value: msg.value}();
            (amountOut, gasToken) = _gasSwapOut(msg.value, _toChain);
        }

        IPort(localPortAddress).burn(address(this), gasToken, amountOut, _toChain);
        return amountOut.toUint128();
    }

    /*///////////////////////////////////////////////////////////////
                    ANYCALL INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
    function _performCall(bytes memory _calldata, uint256 _toChain) internal {
        if (_toChain != localChainId) {
            //Sends message to AnycallProxy
            IAnycallProxy(localAnyCallAddress).anyCall(
                getBranchBridgeAgent[_toChain], _calldata, _toChain, AnycallFlags.FLAG_ALLOW_FALLBACK, ""
            );
        } else {
            //Execute locally
            IBranchBridgeAgent(getBranchBridgeAgent[localChainId]).anyExecute(_calldata);
        }
    }

    /**
     * @notice Pays for the execution gas. Demands that the user has enough gas to replenish gas for the anycall config contract.
     * @param _depositedGas available user gas to pay for execution
     * @param _gasToBridgeOut amount of gas needed to bridge out
     * @param _initialGas initial gas used by the transaction
     * @param _feesOwed amount of fees owed
     * @param _fromChain chain to swap from
     * @param _toChain chain to swap to
     */
    function _payExecutionGas(
        uint128 _depositedGas,
        uint128 _gasToBridgeOut,
        uint256 _initialGas,
        uint256 _feesOwed,
        uint24 _fromChain,
        uint24 _toChain
    ) internal returns (uint256 availableGas) {
        //reset initial remote execution gas and remote execution fee information
        delete(initialGas);
        delete(userFeeInfo);

        if (_fromChain == localChainId) return 0;

        //Get Available Gas
        availableGas = _depositedGas - _gasToBridgeOut;

        //Get Root Environment Execution Cost
        uint256 minExecCost = _feesOwed + tx.gasprice * (MIN_EXECUTION_OVERHEAD + _initialGas - gasleft());

        //Check if sufficient balance
        if (minExecCost > availableGas) revert InsufficientGasForFees();

        //Replenish Gas
        _replenishGas(minExecCost);

        //Account for excess gas
        accumulatedFees += availableGas - minExecCost;
    }

    // /**
    // @notice Updates the user deposit with the amount of gas needed to pay for the fallback function execution.
    // @param _settlementNonce
    // @param _initialGas
    // @param _feesOwed
    //   */
    function _payFallbackGas(uint32 _settlementNonce, uint256 _initialGas, uint256 _feesOwed) internal virtual {
        //Get Branch Environment Execution Cost
        uint256 minExecCost = _feesOwed + tx.gasprice * (MIN_PAY_FALLBACK_GAS_OVERHEAD + _initialGas - gasleft());

        //Update user deposit reverts if not enough gas => user must boost deposit with gas
        getSettlement[_settlementNonce].gasOwed += minExecCost.toUint128();
    }

    function _replenishGas(uint256 _executionGasSpent) internal {
        //Unwrap Gas
        wrappedNativeToken.withdraw(_executionGasSpent);
        IAnycallConfig(IAnycallProxy(localAnyCallAddress).config()).deposit{value: _executionGasSpent}(address(this));
    }

    /**
     * @notice Internal function to calculate cost fo cross-chain message.
     *   @param dataLength bytes that will be sent through messaging layer.
     *   @param fromChain message destination chain Id.
     *
     */
    function _computeAnyCallFees(uint256 dataLength, uint256 fromChain) internal virtual returns (uint256 fees) {
        fees =
            IAnycallConfig(IAnycallProxy(localAnyCallAddress).config()).calcSrcFees(address(0), fromChain, dataLength);
    }

    /// @inheritdoc IRootBridgeAgent
    function anyExecute(bytes calldata data)
        external
        virtual
        requiresExecutor
        returns (bool success, bytes memory result)
    {
        //Get Initial Gas Checkpoint
        uint256 _initialGas = gasleft();

        uint24 fromChainId;
        UserFeeInfo memory _userFeeInfo;

        if (localAnyCallExecutorAddress == msg.sender) {
            //Save initial gas
            initialGas = _initialGas;

            //Get fromChainId from AnyExecutor Context
            (, uint256 _fromChainId) = _getContext();

            //Save fromChainId
            fromChainId = _fromChainId.toUint24();

            //Swap in all deposited Gas
            _userFeeInfo.depositedGas = _gasSwapIn(
                uint256(uint128(bytes16(data[data.length - PARAMS_GAS_IN:data.length - PARAMS_GAS_OUT]))), fromChainId
            ).toUint128();

            //Save Gas to Swap out to destination chain
            _userFeeInfo.gasToBridgeOut = uint128(bytes16(data[data.length - PARAMS_GAS_OUT:data.length]));

            //Compute Fees Owed from cross-chain data transfer
            _userFeeInfo.feesOwed = _computeAnyCallFees(data.length, fromChainId);
        } else {
            //Local Chain initiated call
            fromChainId = localChainId;

            //Save depositedGas
            _userFeeInfo.depositedGas = uint128(bytes16(data[data.length - 32:data.length - 16]));

            //Save Gas to Swap out to destination chain
            _userFeeInfo.gasToBridgeOut = _userFeeInfo.depositedGas;
        }

        if (_userFeeInfo.depositedGas < _userFeeInfo.gasToBridgeOut) revert InsufficientGasForFees();

        //Store User Fee Info
        userFeeInfo = _userFeeInfo;

        //Read Bridge Agent Action Flag attached from cross-chain message header.
        bytes1 flag = data[0];

        //DEPOSIT FLAG: 0 (System request / response)
        if (flag == 0x00) {
            IRouter(localRouterAddress).anyExecuteResponse(
                bytes1(data[5]), data[6:data.length - PARAMS_GAS_IN], fromChainId
            );

            //DEPOSIT FLAG: 1 (Call without Deposit)
        } else if (flag == 0x01) {
            IRouter(localRouterAddress).anyExecute(bytes1(data[5]), data[6:data.length - PARAMS_GAS_IN], fromChainId);
            emit LogCallin(flag, data, fromChainId);

            //DEPOSIT FLAG: 2 (Call with Deposit)
        } else if (flag == 0x02) {
            DepositParams memory dParams = DepositParams({
                depositNonce: uint32(bytes4(data[PARAMS_START:PARAMS_TKN_START])),
                hToken: address(uint160(bytes20(data[PARAMS_TKN_START:25]))),
                token: address(uint160(bytes20(data[25:45]))),
                amount: uint256(bytes32(data[45:77])),
                deposit: uint256(bytes32(data[77:109])),
                toChain: uint24(bytes3(data[109:112]))
            });

            _bridgeIn(localRouterAddress, dParams, fromChainId);

            IRouter(localRouterAddress).anyExecuteDepositSingle(
                data[112], data[113:data.length - PARAMS_GAS_IN], dParams, fromChainId
            );

            //DEPOSIT FLAG: 3 (Call with multiple asset Deposit)
        } else if (flag == 0x03) {
            DepositMultipleParams memory dParams = _bridgeInMultiple(
                localRouterAddress,
                data[
                    PARAMS_START:
                        PARAMS_END_OFFSET + uint16(uint8(bytes1(data[PARAMS_START]))) * PARAMS_TKN_SET_SIZE_MULTIPLE
                ],
                fromChainId
            );

            IRouter(localRouterAddress).anyExecuteDepositMultiple(
                bytes1(
                    data[PARAMS_END_OFFSET + uint16(uint8(bytes1(data[PARAMS_START]))) * PARAMS_TKN_SET_SIZE_MULTIPLE]
                ),
                data[
                    PARAMS_START + PARAMS_END_OFFSET
                        + uint16(uint8(bytes1(data[PARAMS_START]))) * PARAMS_TKN_SET_SIZE_MULTIPLE:
                        data.length - PARAMS_GAS_IN
                ],
                dParams,
                fromChainId
            );

            //DEPOSIT FLAG: 4 (Call without Deposit + msg.sender)
        } else if (flag == 0x04) {
            VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(
                address(uint160(bytes20(data[PARAMS_START:PARAMS_START_SIGNED])))
            );

            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            IRouter(localRouterAddress).anyExecuteSigned(
                data[25], data[26:data.length - PARAMS_GAS_IN], address(userAccount), fromChainId
            );

            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //DEPOSIT FLAG: 5 (Call with Deposit + msg.sender)
        } else if (flag == 0x05) {
            uint256 length = data.length;

            DepositParams memory dParams = DepositParams({
                depositNonce: uint32(bytes4(data[PARAMS_START_SIGNED:25])),
                hToken: address(uint160(bytes20(data[25:45]))),
                token: address(uint160(bytes20(data[45:65]))),
                amount: uint256(bytes32(data[65:97])),
                deposit: uint256(bytes32(data[97:129])),
                toChain: uint24(bytes3(data[129:132]))
            });

            VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(
                address(uint160(bytes20(data[PARAMS_START:PARAMS_START_SIGNED])))
            );

            _bridgeIn(address(userAccount), dParams, fromChainId);
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            IRouter(localRouterAddress).anyExecuteSignedDepositSingle(
                data[132], data[133:length - PARAMS_GAS_IN], dParams, address(userAccount), fromChainId
            );

            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //DEPOSIT FLAG: 6 (Call with multiple asset Deposit + msg.sender)
        } else if (flag == 0x06) {
            VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(
                address(uint160(bytes20(data[PARAMS_START:PARAMS_START_SIGNED])))
            );

            DepositMultipleParams memory dParams = _bridgeInMultiple(
                address(userAccount),
                data[
                    PARAMS_START_SIGNED:
                        PARAMS_END_SIGNED_OFFSET
                            + uint16(uint8(bytes1(data[PARAMS_START_SIGNED]))) * PARAMS_TKN_SET_SIZE_MULTIPLE
                ],
                fromChainId
            );

            {
                uint256 length = data.length;
                uint8 numOfAssets = uint8(bytes1(data[PARAMS_START_SIGNED]));

                IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

                IRouter(localRouterAddress).anyExecuteSignedDepositMultiple(
                    data[PARAMS_END_SIGNED_OFFSET + uint16(numOfAssets) * PARAMS_TKN_SET_SIZE_MULTIPLE],
                    data[
                        PARAMS_START + PARAMS_END_SIGNED_OFFSET + uint16(numOfAssets) * PARAMS_TKN_SET_SIZE_MULTIPLE:
                            length - PARAMS_GAS_IN
                    ],
                    dParams,
                    address(userAccount),
                    fromChainId
                );
                IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);
            }

            /// DEPOSIT FLAG: 10 (clearSettlement)
        } else if (flag == 0x07) {
            _clearSettlement(uint32(bytes4(data[1:5])));

            //Unrecognized Function Selector
        } else {
            //Zero out gas after use
            _payExecutionGas(
                userFeeInfo.depositedGas,
                userFeeInfo.gasToBridgeOut,
                _initialGas,
                userFeeInfo.feesOwed,
                fromChainId,
                localChainId
            );
            //Zero out gas after use
            return (false, "unknown selector");
        }
        if (initialGas > 0) {
            //Zero out gas after use
            _payExecutionGas(
                userFeeInfo.depositedGas,
                userFeeInfo.gasToBridgeOut,
                _initialGas,
                userFeeInfo.feesOwed,
                fromChainId,
                localChainId
            );
        }

        emit LogCallin(flag, data, fromChainId);
        return (true, "");
    }

    /// @inheritdoc IRootBridgeAgent
    function anyFallback(bytes calldata data)
        external
        virtual
        requiresExecutor
        returns (bool success, bytes memory result)
    {
        //Get Initial Gas Checkpoint
        uint256 _initialGas = gasleft();
        //Save to storage
        initialGas = _initialGas;
        //Get fromChain
        (, uint256 _fromChainId) = _getContext();
        uint24 fromChainId = _fromChainId.toUint24();
        //Save Flag
        bytes1 flag = data[0];
        //Save memory for Deposit Nonce
        uint32 _depositNonce;

        if (flag == 0x00) {
            _reopenSettlemment(uint32(bytes4(data[PARAMS_START_SIGNED:25])));

            /// DEPOSIT FLAG: 1 (single asset settlement)
        } else if (flag == 0x01) {
            _reopenSettlemment(uint32(bytes4(data[PARAMS_START_SIGNED:25])));

            /// DEPOSIT FLAG: 2 (multiple asset settlement)
        } else if (flag == 0x02) {
            _reopenSettlemment(uint32(bytes4(data[22:26])));
        }

        _payFallbackGas(_depositNonce, _initialGas, _computeAnyCallFees(data.length, fromChainId));

        emit LogCalloutFail(flag, data, fromChainId);
        return (true, "");
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function approveBranchBridgeAgent(uint256 _branchChainId) external requiresManager {
        if (getBranchBridgeAgent[_branchChainId] != address(0)) revert AlreadyAddedBridgeAgent();
        isBranchBridgeAgentAllowed[_branchChainId] = true;
    }

    /**
     * @notice Updates the address of the branch bridge agent
     * @param _newBranchBridgeAgent address of the new branch bridge agent
     * @param _branchChainId chainId of the branch chain
     */
    function syncBranchBridgeAgent(address _newBranchBridgeAgent, uint24 _branchChainId) external requiresPort {
        getBranchBridgeAgent[_branchChainId] = _newBranchBridgeAgent;
    }

    function sweep() external {
        if (msg.sender != daoAddress) revert UnauthorizedCaller();
        uint256 _accumulatedFees = accumulatedFees;
        accumulatedFees = 0;
        SafeTransferLib.safeTransferETH(daoAddress, _accumulatedFees);
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

    /// @notice Modifier that verifies msg sender is an active bridgeAgent.
    modifier requiresPort() {
        if (msg.sender != localPortAddress) revert UnrecognizedPort();
        _;
    }

    /// @notice Modifier that verifies msg sender is an active bridgeAgent.
    modifier requiresManager() {
        if (msg.sender != IPort(localPortAddress).getBridgeAgentManager(address(this))) {
            revert UnrecognizedBridgeAgentManager();
        }
        _;
    }

    /// @notice require msg sender == active branch interface
    modifier requiresExecutor() {
        _requiresExecutor();
        _;
    }

    /// @notice require msg sender == active branch interface
    modifier requiresRouter() {
        _requiresRouter();
        _;
    }

    fallback() external payable {}
}
