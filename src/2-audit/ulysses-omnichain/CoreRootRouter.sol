// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRootRouter.sol";
import {ICoreBridgeAgent as IBridgeAgent} from "./interfaces/ICoreBridgeAgent.sol";
import {IVirtualAccount, Call} from "./interfaces/IVirtualAccount.sol";
import {IERC20hTokenRootFactory as IFactory} from "./interfaces/IERC20hTokenRootFactory.sol";

import {ERC20hTokenRoot} from "./token/ERC20hTokenRoot.sol";

/**
 * @title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
 * @author MaiaDAO
 * @dev Func IDs for calling these functions through messaging layer.
 *
 *   CROSS-CHAIN MESSAGING FUNCIDs
 *   -----------------------------
 *   FUNC ID      | FUNC NAME
 *   -------------+---------------
 *   0x01         | addGlobalToken
 *   0x02         | addLocalToken
 *   0x03         | setLocalToken
 *   0x04         | syncBranchBridgeAgent
 *
 */
contract CoreRootRouter is IRootRouter, Ownable {
    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    uint24 public immutable rootChainId;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    address public immutable rootPortAddress;

    /// @notice Bridge Agent to maneg communcations and cross-chain assets.
    address payable public bridgeAgentAddress;

    /// @notice Uni V3 Factory Address
    address public hTokenFactoryAddress;

    constructor(uint24 _rootChainId, address _wrappedNativeToken, address _rootPortAddress) {
        rootChainId = _rootChainId;
        wrappedNativeToken = WETH9(_wrappedNativeToken);
        rootPortAddress = _rootPortAddress;
        _initializeOwner(msg.sender);
    }

    function initialize(address _bridgeAgentAddress, address _hTokenFactory) external onlyOwner {
        bridgeAgentAddress = payable(_bridgeAgentAddress);
        hTokenFactoryAddress = _hTokenFactory;
        renounceOwnership();
    }

    /*///////////////////////////////////////////////////////////////
                    BRIDGE AGENT MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to add a global token to a specific chain. Must be called from a branch interface.
     *   @param _newBranchBridgeAgent new branch bridge agent address
     *   @param _rootBridgeAgent new branch bridge agent address
     *   @param _fromChain branch chain id.
     *
     */
    function _syncBranchBridgeAgent(address _newBranchBridgeAgent, address _rootBridgeAgent, uint24 _fromChain)
        internal
    {
        IPort(rootPortAddress).syncBranchBridgeAgentWithRoot(_newBranchBridgeAgent, _rootBridgeAgent, _fromChain);
    }

    /*///////////////////////////////////////////////////////////////
                        TOKEN MANAGEMENT FUNCTIONS
    ////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to add a global token to a specific chain. Must be called from a branch interface.
     *   @param _remoteExecutionGas gas to be used in remote execution.
     *   @param _globalAddress global token to be added.
     *   @param _branchRouter branch router address.
     *   @param _toChain chain to which the Global Token will be added.
     *
     */
    function _addGlobalToken(
        uint128 _remoteExecutionGas,
        address _globalAddress,
        address _branchRouter,
        uint24 _toChain
    ) internal {
        if (_toChain == rootChainId) revert InvalidChainId();

        if (!IPort(rootPortAddress).isGlobalAddress(_globalAddress)) {
            revert UnrecognizedGlobalToken();
        }

        //Verify that it does not exist
        if (IPort(rootPortAddress).isGlobalToken(_globalAddress, _toChain)) {
            revert TokenAlreadyAdded();
        }

        //Encode CallData
        bytes memory data = abi.encode(
            _globalAddress, ERC20(_globalAddress).name(), ERC20(_globalAddress).symbol(), _remoteExecutionGas
        );

        //Add new global token to branch chain
        IBridgeAgent(bridgeAgentAddress).callOut(_branchRouter, data, _toChain);
    }

    /**
     * @notice Function to add a new local to the global environment. Called from branch chain.
     *   @param _underlyingAddress the token's underlying/native address.
     *   @param _localAddress the token's address.
     *   @param _name the token's name.
     *   @param _symbol the token's symbol.
     *   @param _fromChain the token's origin chain Id.
     *
     */
    function _addLocalToken(
        address _underlyingAddress,
        address _localAddress,
        string memory _name,
        string memory _symbol,
        uint24 _fromChain
    ) internal {
        // Verify if token already added
        if (
            IPort(rootPortAddress).isLocalToken(_underlyingAddress, _fromChain)
                || IPort(rootPortAddress).isUnderlyingToken(_underlyingAddress, _fromChain)
        ) revert TokenAlreadyAdded();

        address newToken = address(IFactory(hTokenFactoryAddress).createToken(_name, _symbol));
        //Update Registry
        IPort(rootPortAddress).setAddresses(
            newToken, (_fromChain == rootChainId) ? newToken : _localAddress, _underlyingAddress, _fromChain
        );
    }

    /**
     * @notice Internal function to set the local token on a specific chain for a global token.
     *   @param _globalAddress global token to be updated.
     *   @param _localAddress local token to be added.
     *   @param _toChain local token's chain.
     *
     */
    function _setLocalToken(address _globalAddress, address _localAddress, uint24 _toChain) internal {
        IPort(rootPortAddress).setLocalAddress(_globalAddress, _localAddress, _toChain);
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootRouter
    function anyExecuteResponse(bytes1 funcId, bytes calldata encodedData, uint24 fromChainId)
        external
        payable
        override
        requiresAgent
        returns (bool, bytes memory)
    {
        ///  FUNC ID: 2 (_addLocalToken)
        if (funcId == 0x02) {
            (address underlyingAddress, address localAddress, string memory name, string memory symbol) =
                abi.decode(encodedData, (address, address, string, string));

            _addLocalToken(underlyingAddress, localAddress, name, symbol, fromChainId);

            emit LogCallin(funcId, encodedData, fromChainId);
            /// FUNC ID: 3 (_setLocalToken)
        } else if (funcId == 0x03) {
            (address globalAddress, address localAddress) = abi.decode(encodedData, (address, address));

            _setLocalToken(globalAddress, localAddress, fromChainId);

            emit LogCallin(funcId, encodedData, fromChainId);

            /// Unrecognized Function Selector
        } else {
            return (false, "unknown selector");
        }
        return (true, "");
    }

    /// @inheritdoc IRootRouter
    function anyExecute(bytes1 funcId, bytes calldata encodedData, uint24 fromChainId)
        external
        payable
        override
        requiresAgent
        returns (bool, bytes memory)
    {
        /// FUNC ID: 1 (_addGlobalToken)
        if (funcId == 0x01) {
            (address branchRouter, address globalAddress, uint24 toChain, uint128 remoteExecutionGas) =
                abi.decode(encodedData, (address, address, uint24, uint128));

            _addGlobalToken(remoteExecutionGas, globalAddress, branchRouter, toChain);

            emit LogCallin(funcId, encodedData, fromChainId);

            /// FUNC ID: 4 (_syncBranchBridgeAgent)
        } else if (funcId == 0x04) {
            (address newBranchBridgeAgent, address rootBridgeAgent) = abi.decode(encodedData, (address, address));

            _syncBranchBridgeAgent(newBranchBridgeAgent, rootBridgeAgent, fromChainId);

            emit LogCallin(funcId, encodedData, fromChainId);

            /// Unrecognized Function Selector
        } else {
            return (false, "unknown selector");
        }
        return (true, "");
    }

    /// @inheritdoc IRootRouter
    function anyExecuteDepositSingle(bytes1, bytes memory, DepositParams memory, uint24)
        external
        payable
        override
        requiresAgent
        returns (bool, bytes memory)
    {
        revert();
    }

    /// @inheritdoc IRootRouter
    function anyExecuteDepositMultiple(bytes1, bytes calldata, DepositMultipleParams memory, uint24)
        external
        payable
        requiresAgent
        returns (bool, bytes memory)
    {
        revert();
    }

    /// @inheritdoc IRootRouter
    function anyExecuteSigned(bytes1, bytes memory, address, uint24)
        external
        payable
        override
        requiresAgent
        returns (bool, bytes memory)
    {
        revert();
    }

    /// @inheritdoc IRootRouter
    function anyExecuteSignedDepositSingle(bytes1, bytes memory, DepositParams memory, address, uint24)
        external
        payable
        override
        requiresAgent
        returns (bool, bytes memory)
    {
        revert();
    }

    /// @inheritdoc IRootRouter
    function anyExecuteSignedDepositMultiple(bytes1, bytes memory, DepositMultipleParams memory, address, uint24)
        external
        payable
        returns (bool, bytes memory)
    {
        revert();
    }

    /// @inheritdoc IRootRouter
    function anyFallback(bytes calldata) external pure returns (bool, bytes memory) {
        return (true, "");
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    ////////////////////////////////////////////////////////////*/

    uint256 internal _unlocked = 1;

    /// @notice Modifier for a simple re-entrancy check.
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /// @notice Modifier that requires caler to be an active branch interface.
    modifier requiresAgent() {
        _requiresAgent();
        _;
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresAgent() internal view {
        require(msg.sender == bridgeAgentAddress, "Unauthorized Caller");
    }

    error InvalidChainId();

    error TokenAlreadyAdded();

    error UnrecognizedGlobalToken();
}
