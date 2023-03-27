// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IRootPort.sol";

/**
 * @title Root Port contract
 * @notice This contract is in the root chain of the OmniBridge system and it's used to manage cross chain balances.
 */
contract RootPort is Ownable, IRootPort {
    using SafeTransferLib for address;

    /*///////////////////////////////////////////////////////////////
                        ROOT PORT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Local Chain Id
    uint24 public immutable localChainId;

    /// @notice wrapped native token address
    address public immutable wrappedNativeTokenAddress;

    /// @notice The address of local branch port responsible for handling local transactions.
    address public localBranchPortAddress;

    /// @notice The address of the core router in charge of adding new tokens to the system.
    address public coreRootRouterAddress;

    /// @notice The address of the core router in charge of adding new tokens to the system.
    address public coreRootBridgeAgentAddress;

    /*///////////////////////////////////////////////////////////////
                        VIRTUAL ACCOUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from user address to Virtual Account.
    mapping(address => VirtualAccount) public getUserAccount;

    /// @notice Holds the mapping from Virtual account to router address => bool.
    /// @notice Stores whether a router is approved to spend a virtual account.
    mapping(VirtualAccount => mapping(address => bool)) public isRouterApproved;

    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from address to isBridgeAgent (bool).
    mapping(address => bool) public isBridgeAgent;

    /// @notice Bridge Agents deployed in root chain.
    address[] public bridgeAgents;

    /// @notice Number of bridgeAgents deployed in current chain.
    uint256 public bridgeAgentsLenght;

    /// @notice Mapping address Bridge Agent => address Bridge Agent Manager
    mapping(address => address) public getBridgeAgentManager;

    /*///////////////////////////////////////////////////////////////
                    BRIDGE AGENT FACTORIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from Underlying Address to isUnderlying (bool).
    mapping(address => bool) public isBridgeAgentFactory;

    /// @notice Bridge Agents deployed in root chain.
    address[] public bridgeAgentFactories;

    /// @notice Number of Bridge Agents deployed in current chain.
    uint256 public bridgeAgentFactoriesLenght;

    /*///////////////////////////////////////////////////////////////
                            hTOKENS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping with all global hTokens deployed in the system.
    mapping(address => bool) public isGlobalAddress;

    /// @notice ChainId -> Local Address -> Global Address
    mapping(uint256 => mapping(address => address)) public getGlobalAddressFromLocal;

    /// @notice ChainId -> Global Address -> Local Address
    mapping(uint256 => mapping(address => address)) public getLocalAddressFromGlobal;

    /// @notice ChainId -> Underlying Address -> Local Address
    mapping(uint256 => mapping(address => address)) public getLocalAddressFromUnder;

    /// @notice Mapping from Local Address to Underlying Address.
    mapping(uint256 => mapping(address => address)) public getUnderlyingAddressFromLocal;

    /*///////////////////////////////////////////////////////////////
                           GAS POOLS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from chainId to Wrapped Native Token Address
    mapping(uint256 => address) public getWrappedNativeToken;

    /// @notice Mapping from chainId to Gas Pool Address
    mapping(uint256 => GasPoolInfo) public getGasPoolInfo;

    /**
     * @notice Constructor for Root Port.
     *     @param _localChainId Local Chain Id.
     *     @param _wrappedNativeToken The address of the wrapped native token.
     */
    constructor(uint24 _localChainId, address _wrappedNativeToken) {
        localChainId = _localChainId;
        wrappedNativeTokenAddress = _wrappedNativeToken;

        _initializeOwner(msg.sender);
        setup = true;
    }

    function initialize(address _bridgeAgentFactory, address _coreRootRouter) external onlyOwner {
        require(setup, "Setup ended.");
        isBridgeAgentFactory[_bridgeAgentFactory] = true;
        bridgeAgentFactories.push(_bridgeAgentFactory);
        bridgeAgentFactoriesLenght++;

        coreRootRouterAddress = _coreRootRouter;
    }

    function initializeCore(
        address _coreRootBridgeAgent,
        address _coreLocalBranchBridgeAgent,
        address _localBranchPortAddress
    ) external onlyOwner {
        require(setup, "Setup ended.");
        require(isBridgeAgent[_coreRootBridgeAgent], "Core Bridge Agent doesn't exist.");
        coreRootBridgeAgentAddress = _coreRootBridgeAgent;
        localBranchPortAddress = _localBranchPortAddress;
        IBridgeAgent(_coreRootBridgeAgent).syncBranchBridgeAgent(_coreLocalBranchBridgeAgent, localChainId);
    }

    function forefeitOwnership(address _owner) external onlyOwner {
        _setOwner(address(_owner));
        setup = false;
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootPort
    function getGlobalTokenFromLocal(address _localAddress, uint24 _fromChain) external view returns (address) {
        return _getGlobalTokenFromLocal(_localAddress, _fromChain);
    }

    /**
     * @notice Internal function that returns Token's Global Address.
     * @param _localAddress The address of the token in the local chain.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function _getGlobalTokenFromLocal(address _localAddress, uint24 _fromChain) internal view returns (address) {
        return getGlobalAddressFromLocal[_fromChain][_localAddress];
    }

    /// @inheritdoc IRootPort
    function getLocalTokenFromGlobal(address _globalAddress, uint24 _fromChain) external view returns (address) {
        return _getLocalTokenFromGlobal(_globalAddress, _fromChain);
    }

    /**
     * @notice Internal function that returns Token's Local Address.
     * @param _globalAddress The address of the token in the global chain.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function _getLocalTokenFromGlobal(address _globalAddress, uint24 _fromChain) internal view returns (address) {
        return getLocalAddressFromGlobal[_fromChain][_globalAddress];
    }

    /// @inheritdoc IRootPort
    function getLocalTokenFromUnder(address _underlyingAddress, uint24 _fromChain) external view returns (address) {
        return _getLocalTokenFromUnder(_underlyingAddress, _fromChain);
    }

    /**
     * @notice Internal function that returns Token's Local Address.
     * @param _underlyingAddress The address of the underlying token.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function _getLocalTokenFromUnder(address _underlyingAddress, uint24 _fromChain) internal view returns (address) {
        return getLocalAddressFromUnder[_fromChain][_underlyingAddress];
    }

    /// @inheritdoc IRootPort
    function getLocalToken(address _localAddress, uint24 _fromChain, uint24 _toChain) external view returns (address) {
        return _getLocalToken(_localAddress, _fromChain, _toChain);
    }

    /**
     * @notice View Function returns Local Token's Local Address on another chain.
     * @param _localAddress The address of the token in the local chain.
     * @param _fromChain s
     * @param _toChain s
     */
    function _getLocalToken(address _localAddress, uint256 _fromChain, uint24 _toChain)
        internal
        view
        returns (address)
    {
        address globalAddress = getGlobalAddressFromLocal[_fromChain][_localAddress];
        return getLocalAddressFromGlobal[_toChain][globalAddress];
    }

    /// @inheritdoc IRootPort
    function getUnderlyingTokenFromLocal(address _localAddress, uint24 _fromChain) external view returns (address) {
        return _getUnderlyingTokenFromLocal(_localAddress, _fromChain);
    }

    /**
     * @notice Internal function that returns a underlying token address from it's local address.
     * @param _localAddress The address of the token in the local chain.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function _getUnderlyingTokenFromLocal(address _localAddress, uint24 _fromChain) internal view returns (address) {
        return getUnderlyingAddressFromLocal[_fromChain][_localAddress];
    }

    /// @inheritdoc IRootPort
    function getUnderlyingTokenFromGlobal(address _globalAddress, uint24 _fromChain) external view returns (address) {
        return _getUnderlyingTokenFromGlobal(_globalAddress, _fromChain);
    }

    /**
     * @notice Internal function that returns the underlying token address given it's global address.
     * @param _globalAddress The address of the token in the global chain.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function _getUnderlyingTokenFromGlobal(address _globalAddress, uint24 _fromChain) internal view returns (address) {
        address localAddress = getLocalAddressFromGlobal[_fromChain][_globalAddress];
        return getUnderlyingAddressFromLocal[_fromChain][localAddress];
    }

    /// @inheritdoc IRootPort
    function isGlobalToken(address _globalAddress, uint24 _fromChain) external view returns (bool) {
        return _isGlobalToken(_globalAddress, _fromChain);
    }

    /**
     * @notice Internal function that returns True if Global Token is already added in current chain, false otherwise.
     * @param _globalAddress The address of the token in the global chain.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function _isGlobalToken(address _globalAddress, uint24 _fromChain) internal view returns (bool) {
        return _getLocalTokenFromGlobal(_globalAddress, _fromChain) != address(0);
    }

    /// @inheritdoc IRootPort
    function isLocalToken(address _localAddress, uint24 _fromChain) external view returns (bool) {
        return _getGlobalTokenFromLocal(_localAddress, _fromChain) != address(0);
    }

    /// @inheritdoc IRootPort
    function isLocalToken(address _localAddress, uint24 _fromChain, uint24 _toChain) external view returns (bool) {
        return _isLocalToken(_localAddress, _fromChain, _toChain);
    }

    /// @notice Internal function that returns True if Local Token and is also already added in another branch chain, false otherwise.
    function _isLocalToken(address _localAddress, uint24 _fromChain, uint24 _toChain) internal view returns (bool) {
        return _getLocalToken(_localAddress, _fromChain, _toChain) != address(0);
    }

    /// @inheritdoc IRootPort
    function isUnderlyingToken(address _underlyingToken, uint24 _fromChain) external view returns (bool) {
        return _getLocalTokenFromUnder(_underlyingToken, _fromChain) != address(0);
    }

    /*///////////////////////////////////////////////////////////////
                        hTOKEN MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootPort
    function setUnderlyingAddress(address _localAddress, address _underlyingAddress, uint24 _fromChain)
        external
        requiresCoreBridgeAgent
    {
        getUnderlyingAddressFromLocal[_fromChain][_localAddress] = _underlyingAddress;
        getLocalAddressFromUnder[_fromChain][_underlyingAddress] = _localAddress;
    }

    /// @inheritdoc IRootPort
    function setAddresses(address _globalAddress, address _localAddress, address _underlyingAddress, uint24 _fromChain)
        external
        requiresCoreBridgeAgent
    {
        isGlobalAddress[_globalAddress] = true;
        getGlobalAddressFromLocal[_fromChain][_localAddress] = _globalAddress;
        getLocalAddressFromGlobal[_fromChain][_globalAddress] = _localAddress;
        getLocalAddressFromUnder[_fromChain][_underlyingAddress] = _localAddress;
        getUnderlyingAddressFromLocal[_fromChain][_localAddress] = _underlyingAddress;
    }

    /// @inheritdoc IRootPort
    function setLocalAddress(address _globalAddress, address _localAddress, uint24 _fromChain)
        external
        requiresCoreBridgeAgent
    {
        getGlobalAddressFromLocal[_fromChain][_localAddress] = _globalAddress;
        getLocalAddressFromGlobal[_fromChain][_globalAddress] = _localAddress;
    }

    /*///////////////////////////////////////////////////////////////
                        hTOKEN ACCOUNTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Mints new hTokens to the recipient.
     * @param _to recipient of the newly minted hTokens.
     * @param _hToken address of the hToken to mint.
     * @param _amount amount of hTokens to mint.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function mint(address _to, address _hToken, uint256 _amount, uint24 _fromChain) internal requiresBridgeAgent {
        ERC20hTokenRoot(_hToken).mint(_to, _amount, _fromChain);
    }

    /// @inheritdoc IRootPort
    function burn(address _from, address _hToken, uint256 _amount, uint24 _fromChain) external requiresBridgeAgent {
        ERC20hTokenRoot(_hToken).burn(_from, _amount, _fromChain);
    }

    /// @inheritdoc IRootPort
    function bridgeToRoot(address _recipient, address _hToken, uint256 _amount, uint256 _deposit, uint24 _fromChainId)
        external
        requiresBridgeAgent
    {
        if (_amount - _deposit > 0) _hToken.safeTransfer(_recipient, _amount - _deposit);
        if (_deposit > 0) mint(_recipient, _hToken, _amount, _fromChainId);
    }

    /// @inheritdoc IRootPort
    function bridgeToRootFromLocalBranch(address _from, address _hToken, uint256 _amount)
        external
        requiresLocalBranchPort
    {
        _hToken.safeTransferFrom(_from, address(this), _amount);
    }

    /// @inheritdoc IRootPort
    function bridgeToLocalBranch(address _recipient, address _hToken, uint256 _amount, uint256 _deposit)
        external
        requiresLocalBranchPort
    {
        if (_amount - _deposit > 0) _hToken.safeTransfer(_recipient, _amount - _deposit);
        if (_deposit > 0) mint(_recipient, _hToken, _amount - _deposit, localChainId);
    }

    /// @inheritdoc IRootPort
    function mintToLocalBranch(address _recipient, address _hToken, uint256 _amount) external requiresLocalBranchPort {
        mint(_recipient, _hToken, _amount, localChainId);
    }

    /// @inheritdoc IRootPort
    function burnFromLocalBranch(address _from, address _hToken, uint256 _amount) external requiresLocalBranchPort {
        ERC20hTokenRoot(_hToken).burn(_from, _amount, localChainId);
    }

    /*///////////////////////////////////////////////////////////////
                    VIRTUAL ACCOUNT MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootPort
    function fetchVirtualAccount(address _user) external requiresBridgeAgent returns (VirtualAccount account) {
        account = getUserAccount[_user];
        if (address(account) == address(0)) account = addVirtualAccount(_user);
    }

    /**
     * @notice Creates a new virtual account for a user.
     * @param _user address of the user to associate a virtual account with.
     */
    function addVirtualAccount(address _user) internal returns (VirtualAccount newAccount) {
        newAccount = new VirtualAccount(_user, address(this));
        getUserAccount[_user] = newAccount;
    }

    /// @inheritdoc IRootPort
    function toggleVirtualAccountApproved(VirtualAccount _userAccount, address _router) external requiresBridgeAgent {
        isRouterApproved[_userAccount][_router] = !isRouterApproved[_userAccount][_router];
    }

    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT ADDITION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootPort
    function addBridgeAgent(address _manager, address _bridgeAgent) external requiresBridgeAgentFactory {
        bridgeAgents.push(_bridgeAgent);
        bridgeAgentsLenght++;
        getBridgeAgentManager[_bridgeAgent] = _manager;
        isBridgeAgent[_bridgeAgent] = !isBridgeAgent[_bridgeAgent];
    }

    /// @inheritdoc IRootPort
    function syncBranchBridgeAgentWithRoot(
        address _newBranchBridgeAgent,
        address _rootBridgeAgent,
        uint24 _branchChainId
    ) external requiresCoreBridgeAgent {
        if (IBridgeAgent(_rootBridgeAgent).getBranchBridgeAgent(_branchChainId) != address(0)) {
            revert AlreadyAddedBridgeAgent();
        }
        if (!IBridgeAgent(_rootBridgeAgent).isBranchBridgeAgentAllowed(_branchChainId, _newBranchBridgeAgent)) {
            revert BridgeAgentNotAllowed();
        }
        IBridgeAgent(_rootBridgeAgent).syncBranchBridgeAgent(_newBranchBridgeAgent, _branchChainId);
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootPort
    function toggleBridgeAgent(address _bridgeAgent) external onlyOwner {
        isBridgeAgent[_bridgeAgent] = !isBridgeAgent[_bridgeAgent];
    }

    /// @inheritdoc IRootPort
    function addBridgeAgentFactory(address _bridgeAgentFactory) external onlyOwner {
        bridgeAgentFactories[bridgeAgentsLenght++] = _bridgeAgentFactory;
    }

    /// @inheritdoc IRootPort
    function toggleBridgeAgentFactory(address _bridgeAgentFactory) external onlyOwner {
        isBridgeAgentFactory[_bridgeAgentFactory] = !isBridgeAgentFactory[_bridgeAgentFactory];
    }

    /// @inheritdoc IRootPort
    function setLocalBranchPort(address _branchPort) external onlyOwner {
        localBranchPortAddress = _branchPort;
    }

    // function setCoreBridgeAgent(address _coreRootRouterAddress, address _coreBranchBridgeA) external onlyOwner {
    //     coreRootRouterAddress = _coreRootRouterAddress;
    //     isBridgeAgent[_coreRootRouterAddress] = true;
    //     bridgeAgents.push(_coreRootRouterAddress);
    //     bridgeAgentsLenght++;
    //     getBridgeAgentManager[_coreRootRouterAddress] = owner();
    // }

    /// @inheritdoc IRootPort
    function addNewChain(
        uint24 _chainId,
        string memory _gasTokenName,
        string memory _gasTokenSymbol,
        uint24 _fee,
        uint24 _priceImpactPercentage,
        uint160 _sqrtPriceX96,
        address _nonFungiblePositionManagerAddress,
        address _newLocalBranchWrappedNativeTokenAddress,
        address _newUnderlyingBranchWrappedNativeTokenAddress,
        address _hTokenFactoryAddress
    ) external onlyOwner {
        if (ICoreRootRouter(coreRootRouterAddress).hTokenFactoryAddress() != _hTokenFactoryAddress) {
            revert UnknowHTokenFactory();
        }
        {
            getWrappedNativeToken[_chainId] = _newUnderlyingBranchWrappedNativeTokenAddress;
        }

        address newGasPoolAddress;

        bool zeroForOneOnInflow;

        address newGlobalToken =
            address(IERC20hTokenRootFactory(_hTokenFactoryAddress).createToken(_gasTokenName, _gasTokenSymbol));

        isGlobalAddress[newGlobalToken] = true;
        getGlobalAddressFromLocal[_chainId][_newLocalBranchWrappedNativeTokenAddress] = newGlobalToken;
        getLocalAddressFromGlobal[_chainId][newGlobalToken] = _newLocalBranchWrappedNativeTokenAddress;
        getLocalAddressFromUnder[_chainId][_newUnderlyingBranchWrappedNativeTokenAddress] =
            _newLocalBranchWrappedNativeTokenAddress;
        getUnderlyingAddressFromLocal[_chainId][_newLocalBranchWrappedNativeTokenAddress] =
            _newUnderlyingBranchWrappedNativeTokenAddress;


        {
            if (newGlobalToken < wrappedNativeTokenAddress) {

                zeroForOneOnInflow = true;
                newGasPoolAddress = INonfungiblePositionManager(_nonFungiblePositionManagerAddress)
                    .createAndInitializePoolIfNecessary(newGlobalToken, wrappedNativeTokenAddress, _fee, _sqrtPriceX96);
            } else {
                zeroForOneOnInflow = false;
                newGasPoolAddress = INonfungiblePositionManager(_nonFungiblePositionManagerAddress)
                    .createAndInitializePoolIfNecessary(wrappedNativeTokenAddress, newGlobalToken, _fee, _sqrtPriceX96);
            }
        }

        getGasPoolInfo[_chainId] = GasPoolInfo({
            zeroForOneOnInflow: zeroForOneOnInflow,
            priceImpactPercentage: _priceImpactPercentage,
            gasTokenGlobalAddress: newGlobalToken,
            poolAddress: newGasPoolAddress
        });
    }

    /// @inheritdoc IRootPort
    function setGasPoolInfo(uint24 _chainId, GasPoolInfo calldata _gasPoolInfo) external onlyOwner {
        getGasPoolInfo[_chainId] = _gasPoolInfo;
    }

    bool setup;

    /// @inheritdoc IRootPort
    function addChainToCore(address _branchBridgeAgent, uint24 _chainId) external onlyOwner {
        require(setup, "Setup ended!");
        IBridgeAgent(coreRootBridgeAgentAddress).syncBranchBridgeAgent(_branchBridgeAgent, _chainId);
    }

    /**
     * @notice Function to initialize root environment ecosystem token addresses
     * @param hermesGlobalAddress hermes global address
     * @param maiaGlobalAddress maia global address
     */
    function initializeEcosystemTokenAddresses(address hermesGlobalAddress, address maiaGlobalAddress)
        external
        onlyOwner
    {
        getGlobalAddressFromLocal[localChainId][hermesGlobalAddress] = hermesGlobalAddress;
        getLocalAddressFromGlobal[localChainId][hermesGlobalAddress] = hermesGlobalAddress;

        getGlobalAddressFromLocal[localChainId][maiaGlobalAddress] = maiaGlobalAddress;
        getLocalAddressFromGlobal[localChainId][maiaGlobalAddress] = maiaGlobalAddress;
    }

    /// @inheritdoc IRootPort
    function addEcosystemTokenToChain(address ecoTokenGlobalAddress, address ecoTokenLocalAddress, uint256 toChainId)
        external
        onlyOwner
    {
        getGlobalAddressFromLocal[toChainId][ecoTokenLocalAddress] = ecoTokenGlobalAddress;
        getLocalAddressFromGlobal[toChainId][ecoTokenGlobalAddress] = ecoTokenLocalAddress;
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresBridgeAgentFactory() {
        if (!isBridgeAgentFactory[msg.sender]) revert UnrecognizedBridgeAgentFactory();
        _;
    }

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresBridgeAgent() {
        if (!isBridgeAgent[msg.sender]) revert UnrecognizedBridgeAgent();
        _;
    }

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresCoreBridgeAgent() {
        if (!(msg.sender == coreRootRouterAddress)) revert UnrecognizedCoreBridgeAgent();
        _;
    }

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresLocalBranchPort() {
        if (!(msg.sender == localBranchPortAddress)) revert UnrecognizedLocalBranchPort();
        _;
    }
}
