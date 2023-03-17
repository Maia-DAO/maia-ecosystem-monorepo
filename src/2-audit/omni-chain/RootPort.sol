// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IRootPort.sol";

contract RootPort is Ownable, IRootPort {
    using SafeTransferLib for address;

    /// @notice Local Chain Id
    uint256 public immutable localChainId;

    address public immutable wrappedNativeTokenAddress;

    /// @notice The address of the core bridge agent in charge of adding new tokens to the system.
    address public localBranchPortAddress;

    /// @notice The address of the core bridge agent in charge of adding new tokens to the system.
    address public coreRootBridgeAgentAddress;

    /// @notice Mapping from user address to Virtual Account.
    mapping(address => VirtualAccount) public getUserAccount;

    /// @notice Mapping from Underlying Address to isUnderlying (bool).
    mapping(VirtualAccount => mapping(address => bool)) public isRouterApproved;

    /// @notice Mapping from Underlying Address to isUnderlying (bool).
    mapping(address => bool) public isBridgeAgent;

    /// @notice Bridge Agents deployed in root chain.
    address[] public bridgeAgents;

    /// @notice Number of hTokens deployed in current chain.
    uint256 public bridgeAgentsLenght;

    /// @notice Mapping from Underlying Address to isUnderlying (bool).
    mapping(address => bool) public isBridgeAgentFactory;

    /// @notice Bridge Agents deployed in root chain.
    address[] public bridgeAgentFactories;

    /// @notice Number of hTokens deployed in current chain.
    uint256 public bridgeAgentFactoriesLenght;

    /// @notice ChainId -> Local Address -> Global Address
    mapping(uint256 => mapping(address => address)) public getGlobalAddressFromLocal;

    /// @notice ChainId -> Global Address -> Local Address
    mapping(uint256 => mapping(address => address)) public getLocalAddressFromGlobal;

    /// @notice ChainId -> Underlying Address -> Local Address
    mapping(uint256 => mapping(address => address)) public getLocalAddressFromUnder;

    /// @notice Mapping from Local Address to Underlying Address.
    mapping(uint256 => mapping(address => address)) public getUnderlyingAddressFromLocal;

    /// @notice Mapping from chainId to Wrapped Native Token Address
    mapping(uint256 => address) public getWrappedNativeToken;

    /// @notice Mapping from chainId to Gas Pool Address
    mapping(uint256 => GasPoolInfo) public getGasPoolInfo;

    /**
        @notice Constructor for Root Port.
        @param _bridgeAgentFactory The address of the core bridge agent in charge of adding new tokens to the system.
        @param _coreBridgeAgent The address of the core bridge agent in charge of adding new tokens to the system.
     */
    constructor(
        uint256 _localChainId,
        address _wrappedNativeToken,
        address _bridgeAgentFactory,
        address _coreBridgeAgent,
        address _owner
    ) {
        localChainId = _localChainId;
        wrappedNativeTokenAddress = _wrappedNativeToken;
        coreRootBridgeAgentAddress = _coreBridgeAgent;
        bridgeAgentFactories[bridgeAgentFactoriesLenght++] = _bridgeAgentFactory;
        isBridgeAgentFactory[_bridgeAgentFactory] = !isBridgeAgentFactory[_bridgeAgentFactory];
        _initializeOwner(_owner);
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice View Function returns Token's Local Address.
    function getGlobalTokenFromLocal(address _localAddress, uint256 _fromChain)
        external
        view
        returns (address)
    {
        return _getGlobalTokenFromLocal(_localAddress, _fromChain);
    }

    /// @notice View Function returns Token's Local Address.
    function _getGlobalTokenFromLocal(address _localAddress, uint256 _fromChain)
        internal
        view
        returns (address)
    {
        return getGlobalAddressFromLocal[_fromChain][_localAddress];
    }

    /// @notice View Function returns Token's Local Address.
    function getLocalTokenFromGlobal(address _globalAddress, uint256 _fromChain)
        external
        view
        returns (address)
    {
        return _getLocalTokenFromGlobal(_globalAddress, _fromChain);
    }

    /// @notice View Function returns Token's Local Address.
    function _getLocalTokenFromGlobal(address _globalAddress, uint256 _fromChain)
        internal
        view
        returns (address)
    {
        return getLocalAddressFromGlobal[_fromChain][_globalAddress];
    }

    /// @notice View Function returns Token's Local Address.
    function getLocalTokenFromUnder(address _underlyingAddress, uint256 _fromChain)
        external
        view
        returns (address)
    {
        return _getLocalTokenFromUnder(_underlyingAddress, _fromChain);
    }

    /// @notice View Function returns Token's Local Address.
    function _getLocalTokenFromUnder(address _underlyingAddress, uint256 _fromChain)
        internal
        view
        returns (address)
    {
        return getLocalAddressFromUnder[_fromChain][_underlyingAddress];
    }

    /// @notice View Function returns Local Token's Local Address on another chain.
    function getLocalToken(
        address _localAddress,
        uint256 _fromChain,
        uint256 _toChain
    ) external view returns (address) {
        return _getLocalToken(_localAddress, _fromChain, _toChain);
    }

    /// @notice View Function returns Local Token's Local Address on another chain.
    function _getLocalToken(
        address _localAddress,
        uint256 _fromChain,
        uint256 _toChain
    ) internal view returns (address) {
        address globalAddress = getGlobalAddressFromLocal[_fromChain][_localAddress];
        return getLocalAddressFromGlobal[_toChain][globalAddress];
    }

    /// @notice View Function returns a Local Token's Native Underlying Token Address.
    function getUnderlyingTokenFromLocal(address _localAddress, uint256 _fromChain)
        external
        view
        returns (address)
    {
        return _getUnderlyingTokenFromLocal(_localAddress, _fromChain);
    }

    /// @notice View Function returns a Local Token's Native Underlying Token Address.
    function _getUnderlyingTokenFromLocal(address _localAddress, uint256 _fromChain)
        internal
        view
        returns (address)
    {
        return getUnderlyingAddressFromLocal[_fromChain][_localAddress];
    }

    /// @notice View Function returns a Global Token's Native Underlying Token Address.
    function getUnderlyingTokenFromGlobal(address _globalAddress, uint256 _fromChain)
        external
        view
        returns (address)
    {
        return _getUnderlyingTokenFromGlobal(_globalAddress, _fromChain);
    }

    /// @notice View Function returns a Global Token's Native Underlying Token Address.
    function _getUnderlyingTokenFromGlobal(address _globalAddress, uint256 _fromChain)
        internal
        view
        returns (address)
    {
        address localAddress = getLocalAddressFromGlobal[_fromChain][_globalAddress];
        return getUnderlyingAddressFromLocal[_fromChain][localAddress];
    }

    /// @notice View Function returns True if Global Token is already added in current chain, false otherwise.
    function isGlobalToken(address _globalAddress, uint256 _fromChain)
        external
        view
        returns (bool)
    {
        return _isGlobalToken(_globalAddress, _fromChain);
    }

    /// @notice View Function returns True if Global Token is already added in current chain, false otherwise.
    function _isGlobalToken(address _globalAddress, uint256 _fromChain)
        internal
        view
        returns (bool)
    {
        return _getLocalTokenFromGlobal(_globalAddress, _fromChain) != address(0);
    }

    /// @notice View Function returns True if Global Token is already added in current chain, false otherwise.
    function isLocalToken(address _localAddress, uint256 _fromChain) external view returns (bool) {
        return _getGlobalTokenFromLocal(_localAddress, _fromChain) != address(0);
    }

    /// @notice View Function returns True if Local Token and is also already added in another branch chain, false otherwise.
    function isLocalToken(
        address _localAddress,
        uint256 _fromChain,
        uint256 _toChain
    ) external view returns (bool) {
        return _isLocalToken(_localAddress, _fromChain, _toChain);
    }

    /// @notice View Function returns True if Local Token and is also already added in another branch chain, false otherwise.
    function _isLocalToken(
        address _localAddress,
        uint256 _fromChain,
        uint256 _toChain
    ) internal view returns (bool) {
        return _getLocalToken(_localAddress, _fromChain, _toChain) != address(0);
    }

    /// @notice View Function returns True if Local Token is already added in current chain, false otherwise.
    function isUnderlyingToken(address _underlyingToken, uint256 _fromChain)
        external
        view
        returns (bool)
    {
        return _getLocalTokenFromUnder(_underlyingToken, _fromChain) != address(0);
    }

    /*///////////////////////////////////////////////////////////////
                        hTOKEN MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
      @notice Setter function to a local hTokens's Underlying Address.
      @param _localAddress new hToken address to update.
      @param _underlyingAddress new underlying/native token address to set.
    **/
    function setUnderlyingAddress(
        address _localAddress,
        address _underlyingAddress,
        uint256 _fromChain
    ) external requiresCoreBridgeAgent {
        getUnderlyingAddressFromLocal[_fromChain][_localAddress] = _underlyingAddress;
        getLocalAddressFromUnder[_fromChain][_underlyingAddress] = _localAddress;
    }

    /**
      @notice Setter function to update a Global hToken's Local hToken Address.
      @param _globalAddress new hToken address to update.
      @param _localAddress new underlying/native token address to set.
    **/
    function setAddresses(
        address _globalAddress,
        address _localAddress,
        address _underlyingAddress,
        uint256 _fromChain
    ) external requiresCoreBridgeAgent {
        getGlobalAddressFromLocal[_fromChain][_localAddress] = _globalAddress;
        getLocalAddressFromGlobal[_fromChain][_globalAddress] = _localAddress;
        getLocalAddressFromUnder[_fromChain][_underlyingAddress] = _localAddress;
        getUnderlyingAddressFromLocal[_fromChain][_localAddress] = _underlyingAddress;
    }

    /**
      @notice Setter function to update a Global hToken's Local hToken Address.
      @param _globalAddress new hToken address to update.
      @param _localAddress new underlying/native token address to set.
    **/
    function setLocalAddress(
        address _globalAddress,
        address _localAddress,
        uint256 _fromChain
    ) external requiresCoreBridgeAgent {
        getGlobalAddressFromLocal[_fromChain][_localAddress] = _globalAddress;
        getLocalAddressFromGlobal[_fromChain][_globalAddress] = _localAddress;
    }

    /*///////////////////////////////////////////////////////////////
                        hTOKEN ACCOUNTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function mint(
        address _to,
        address _hToken,
        uint256 _amount,
        uint256 _fromChain
    ) internal requiresBridgeAgent {
        ERC20hTokenRoot(_hToken).mint(_to, _amount, _fromChain);
    }

    function burn(
        address _from,
        address _hToken,
        uint256 _amount,
        uint256 _fromChain
    ) external requiresBridgeAgent {
        ERC20hTokenRoot(_hToken).burn(_from, _amount, _fromChain);
    }

    function bridgeToRoot(
        address _recipient,
        address _hToken,
        uint256 _amount,
        uint256 _deposit,
        uint256 fromChainId
    ) external requiresBridgeAgent {
        if (_amount - _deposit > 0) _hToken.safeTransfer(_recipient, _amount - _deposit);
        if (_deposit > 0) mint(_recipient, _hToken, _amount, fromChainId);
        //TODO add event Bridge
    }

    function bridgeToRootFromLocalBranch(
        address _from,
        address _hToken,
        uint256 _amount
    ) external requiresLocalBranchPort {
        _hToken.safeTransferFrom(_from, address(this), _amount);
        //TODO add event Bridge
    }

    function bridgeToLocalBranch(
        address _recipient,
        address _hToken,
        uint256 _amount,
        uint256 _deposit
    ) external requiresLocalBranchPort {
        if (_amount - _deposit > 0) _hToken.safeTransfer(_recipient, _amount - _deposit);
        if (_deposit > 0) mint(_recipient, _hToken, _amount - _deposit, localChainId);
        //TODO add event Bridge
    }

    function mintToLocalBranch(
        address _recipient,
        address _hToken,
        uint256 _amount
    ) external requiresLocalBranchPort {
        mint(_recipient, _hToken, _amount, localChainId);
        //TODO add event Bridge
    }

    function burnFromLocalBranch(
        address _from,
        address _hToken,
        uint256 _amount
    ) external requiresLocalBranchPort {
        ERC20hTokenRoot(_hToken).burn(_from, _amount, localChainId);
    }

    /*///////////////////////////////////////////////////////////////
                    VIRTUAL ACCOUNT MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function fetchVirtualAccount(address _user)
        external
        requiresBridgeAgent
        returns (VirtualAccount account)
    {
        account = getUserAccount[_user];
        if (address(account) == address(0)) account = addVirtualAccount(_user);
    }

    function addVirtualAccount(address _user) internal returns (VirtualAccount newAccount) {
        newAccount = new VirtualAccount(_user, address(this));
        getUserAccount[_user] = newAccount;
    }

    function toggleVirtualAccountApproved(VirtualAccount _userAccount, address _router)
        external
        requiresBridgeAgent
    {
        isRouterApproved[_userAccount][_router] = !isRouterApproved[_userAccount][_router];
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addBridgeAgent(address _bridgeAgent) external requiresBridgeAgentFactory {
        bridgeAgents[bridgeAgentsLenght++] = _bridgeAgent;
    }

    function toggleBridgeAgent(address _bridgeAgent) external requiresBridgeAgentFactory {
        isBridgeAgent[_bridgeAgent] = !isBridgeAgent[_bridgeAgent];
    }

    function addBridgeAgentFactory(address _bridgeAgentFactory) external onlyOwner {
        bridgeAgentFactories[bridgeAgentsLenght++] = _bridgeAgentFactory;
    }

    function toggleBridgeAgentFactory(address _bridgeAgentFactory) external onlyOwner {
        isBridgeAgentFactory[_bridgeAgentFactory] = !isBridgeAgentFactory[_bridgeAgentFactory];
    }

    function setLocalBranchPort(address _branchPort) external onlyOwner {
        localBranchPortAddress = _branchPort;
    }

    function addNewChain(
        uint256 _chainId,
        string memory _name,
        string memory _symbol,
        uint24 _fee,
        uint24 _priceImpactPercentage,
        uint160 _sqrtPriceX96,
        address _hTokenFactoryAddress,
        address _nonFungiblePositionManagerAddress,
        address _newBranchBridgeAgentFactoryAddress,
        // address _newBranchCoreBridgeAgentAddress,
        // address _newBranchPortAddress,
        address _newBranchWrappedNativeTokenAddress
    ) external onlyOwner {
    
        {getWrappedNativeToken[_chainId] = _newBranchWrappedNativeTokenAddress;}

        address newGasPoolAddress;

        bool zeroForOneOnInflow;

        address newGlobalToken = address(
            IERC20hTokenRootFactory(_hTokenFactoryAddress).createToken(_name, _symbol)
        );

        {if (newGlobalToken < wrappedNativeTokenAddress) {
            zeroForOneOnInflow = true;
            newGasPoolAddress = INonfungiblePositionManager(_nonFungiblePositionManagerAddress)
                .createAndInitializePoolIfNecessary(
                    newGlobalToken,
                    wrappedNativeTokenAddress,
                    _fee,
                    _sqrtPriceX96
                );
        } else {
            zeroForOneOnInflow = false;
            newGasPoolAddress = INonfungiblePositionManager(_nonFungiblePositionManagerAddress)
                .createAndInitializePoolIfNecessary(
                    wrappedNativeTokenAddress,
                    newGlobalToken,
                    _fee,
                    _sqrtPriceX96
                );
        }}

        getGasPoolInfo[_chainId] = GasPoolInfo({
            zeroForOneOnInflow: zeroForOneOnInflow,
            priceImpactPercentage: _priceImpactPercentage,
            gasTokenGlobalAddress: newGlobalToken,
            poolAddress: newGasPoolAddress
        });

        //TODO ADD BRIDGEAGENTFACTORY
        //TODO ADD SETTERS
        //PERFORM CALL TO DEPLOY NEW CORE ROOT BRIDGE AGENT
    }

    function setGasPoolInfo(uint256 _chainId, GasPoolInfo calldata _gasPoolInfo)
        external
        onlyOwner
    {
        getGasPoolInfo[_chainId] = _gasPoolInfo;
    }

    function initializeEcosystemTokenAddresses(
        address hermesGlobalAddress,
        address maiaGlobalAddress
    ) external onlyOwner {
        getGlobalAddressFromLocal[localChainId][hermesGlobalAddress] = hermesGlobalAddress;
        getLocalAddressFromGlobal[localChainId][hermesGlobalAddress] = hermesGlobalAddress;

        getGlobalAddressFromLocal[localChainId][maiaGlobalAddress] = maiaGlobalAddress;
        getLocalAddressFromGlobal[localChainId][maiaGlobalAddress] = maiaGlobalAddress;
    }

    function addEcosystemTokenToChain(
        address ecoTokenGlobalAddress,
        address ecoTokenLocalAddress,
        uint256 toChainId
    ) external onlyOwner {
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
        if (!(msg.sender == coreRootBridgeAgentAddress)) revert UnrecognizedCoreBridgeAgent();
        _;
    }

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresLocalBranchPort() {
        if (!(msg.sender == localBranchPortAddress)) revert UnrecognizedLocalBranchPort();
        _;
    }
}
