// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRootRouter.sol";
import { ICoreBridgeAgent as IBridgeAgent } from "./interfaces/ICoreBridgeAgent.sol";
import { IVirtualAccount, Call } from "./interfaces/IVirtualAccount.sol";
import { IERC20hTokenRootFactory as IFactory } from "./interfaces/IERC20hTokenRootFactory.sol";

import { ERC20hTokenRoot } from "./token/ERC20hTokenRoot.sol";

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
 *   0x04         | claimRewards
 *   0x05         | claimBribes
 *   0x06         | incrementDelegationVotes
 *   0x07         | incrementDelegationWeight
 *   0x08         | delegateVotes
 *   0x09         | delegateWeight
 *   0x0a         | undelegateVotes
 *   0x0b         | undelegateWeight
 *   0x0c         | incrementGaugeWeights
 *   0x0d         | decrementGaugeWeights
 *   0x0e         | decrementAllGaugesAllBoost
 *
 */
contract CoreRootRouter is IRootRouter {
    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    uint256 public immutable localChainId;

    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    address public immutable localPortAddress;

    /// @notice Bridge Agent to maneg communcations and cross-chain assets. TODO
    address payable public immutable bridgeAgentAddress;

    /// @notice Uni V3 Factory Address
    address public immutable hTokenFactoryAddress;

    constructor(
        uint256 _localChainId,
        address _wrappedNativeToken,
        address _localPortAddress,
        address _bridgeAgentAddress,
        address _hTokenFactoryAddress
    ) {
        localChainId = _localChainId;
        localPortAddress = _localPortAddress;
        wrappedNativeToken = WETH9(_wrappedNativeToken);
        bridgeAgentAddress = payable(_bridgeAgentAddress);
        hTokenFactoryAddress = _hTokenFactoryAddress;
    }

    /*///////////////////////////////////////////////////////////////
                 TOKEN MANAGEMENT REMOTE FUNCTIONS
    ////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to add a global token to a specific chain. Must be called from a branch interface.
     *   @param _globalAddress global token to be added.
     *   @param _toChain chain to which the Global Token will be added.
     *
     */
    function addGlobalToken(address _globalAddress, uint256 _toChain) internal {
        if (_toChain == localChainId) revert InvalidChainId();
        //Verify that it does not exist TODO verify it is known global hToken(?)
        if (IPort(localPortAddress).isGlobalToken(_globalAddress, _toChain))
            revert TokenAlreadyAdded();

        //Check Gas + Fees
        bytes memory data = abi.encode(
            0x00,
            0x01,
            _globalAddress,
            ERC20(_globalAddress).name(),
            ERC20(_globalAddress).symbol(),
            ERC20(_globalAddress).decimals()
        );

        IBridgeAgent(bridgeAgentAddress).addGlobalToken(data, _toChain);
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
    function addLocalToken(
        address _underlyingAddress,
        address _localAddress,
        string memory _name,
        string memory _symbol,
        uint256 _fromChain
    ) internal {
        // Verify if token already added
        if (
            IPort(localPortAddress).isLocalToken(_underlyingAddress, _fromChain) ||
            IPort(localPortAddress).isUnderlyingToken(_underlyingAddress, _fromChain)
        ) revert TokenAlreadyAdded();

        address newToken = address(IFactory(hTokenFactoryAddress).createToken(_name, _symbol));

        IBridgeAgent(bridgeAgentAddress).addLocalToken(
            _underlyingAddress,
            (_fromChain == localChainId) ? newToken : _localAddress,
            newToken,
            _fromChain
        );
    }

    /**
     * @notice Internal function to set the local token on a specific chain for a global token.
     *   @param _globalAddress global token to be updated.
     *   @param _localAddress local token to be added.
     *   @param _toChain local token's chain.
     *
     */
    function setLocalToken(
        address _globalAddress,
        address _localAddress,
        uint256 _toChain
    ) internal {
        IBridgeAgent(bridgeAgentAddress).setLocalToken(_globalAddress, _localAddress, _toChain);
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/
    /**
     *     @notice Function responsible of executing a branch router response.
     *     @param funcId 1 byte called Router function identifier.
     *     @param data data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     *      2            | addLocalToken
     *      3            | setLocalToken
     *
     */
    function anyExecuteResponse(
        bytes1 funcId,
        bytes calldata data,
        uint256 fromChainId
    ) external payable override requiresAgent returns (bool success, bytes memory result) {
        ///  FUNC ID: 2 (addLocalToken)
        if (funcId == 0x02) {
            bytes memory decodedData = RLPDecoder.decodeCallData(data[1:], 5); // TODO max 5 bytes32 slots

            (
                address underlyingAddress,
                address localAddress,
                string memory name,
                string memory symbol
            ) = abi.decode(decodedData, (address, address, string, string));

            addLocalToken(underlyingAddress, localAddress, name, symbol, fromChainId);

            emit LogCallin(funcId, data, fromChainId);
            /// FUNC ID: 3 (setLocalToken)
        } else if (funcId == 0x03) {
            bytes memory decodedData = RLPDecoder.decodeCallData(data[1:], 3); // TODO max 3 bytes32 slots

            (address globalAddress, address localAddress, uint256 toChain) = abi.decode(
                decodedData,
                (address, address, uint256)
            );

            setLocalToken(globalAddress, localAddress, toChain);

            emit LogCallin(funcId, data, fromChainId);

            /// Unrecognized Function Selector
        } else {
            return (false, "unknown selector");
        }
        return (true, "");
    }

    /**
     *     @notice Function responsible of executing a crosschain request without any deposit.
     *     @param funcId 1 byte Router function identifier.
     *     @param rlpEncodedData data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     *      1            | addGlobalToken
     *
     */
    function anyExecute(
        bytes1 funcId,
        bytes calldata rlpEncodedData,
        uint256 fromChainId
    ) external payable override requiresAgent returns (bool success, bytes memory result) {
        /// FUNC ID: 1 (addGlobalToken)
        if (funcId == 0x01) {
            bytes memory decodedData = RLPDecoder.decodeCallData(rlpEncodedData[1:], 2); // TODO max 2 bytes32 slots

            (address globalAddress, uint256 toChain) = abi.decode(decodedData, (address, uint256));

            addGlobalToken(globalAddress, toChain);

            emit LogCallin(funcId, rlpEncodedData, fromChainId);

            /// Unrecognized Function Selector
        } else {
            return (false, "unknown selector");
        }
        return (true, "");
    }

    /**
     *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information attached.
     *   @param funcId 1 byte Router function identifier.
     *   @param rlpEncodedData execution data received from messaging layer.
     *   @param dParams cross-chain deposit information.
     *   @param fromChainId chain where the request originated from.
     *
     */
    function anyExecute(
        bytes1 funcId,
        bytes calldata rlpEncodedData,
        DepositParams memory dParams,
        uint256 fromChainId
    ) external payable override requiresAgent returns (bool success, bytes memory result) {
        revert();
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
        revert();
    }

    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedData,
        address userAccount,
        uint256 fromChainId
    ) external payable override requiresAgent returns (bool success, bytes memory result) {
        revert();
    }

    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedData,
        DepositParams memory dParams,
        address userAccount,
        uint256 fromChainId
    ) external payable override requiresAgent returns (bool success, bytes memory result) {
        revert();
    }

    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedData,
        DepositMultipleParams memory dParams,
        address userAccount,
        uint256 fromChainId
    ) external payable returns (bool success, bytes memory result) {
        revert();
    }

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

    error InvalidChainId();

    error TokenAlreadyAdded();
}
