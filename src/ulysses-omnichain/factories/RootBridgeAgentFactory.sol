// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WETH9} from "../interfaces/IWETH9.sol";

import {IRootBridgeAgentFactory} from "../interfaces/IRootBridgeAgentFactory.sol";
import {IRootPort} from "../interfaces/IRootPort.sol";

import {DeployRootBridgeAgent} from "../RootBridgeAgent.sol";

/// @title Root Bridge Agent Factory Contract
contract RootBridgeAgentFactory is IRootBridgeAgentFactory {
    /// @notice Root Chain Id
    uint16 public immutable rootChainId;

    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Root Port Address
    address public immutable rootPortAddress;

    /// @notice Local Layerzero Enpoint Address
    address public immutable lzEndpointAddress;

    /*///////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for Bridge Agent.
     *     @param _rootChainId Root Chain Layer Zero Id.
     *     @param _wrappedNativeToken Root Chain Wrapped Native Token.
     *     @param _lzEndpointAddress Layer Zero Endpoint for cross-chain communication.
     *     @param _rootPortAddress Root Port Address.
     */
    constructor(uint16 _rootChainId, WETH9 _wrappedNativeToken, address _lzEndpointAddress, address _rootPortAddress) {
        require(address(_wrappedNativeToken) != address(0), "Wrapped Native Token cannot be 0");
        require(_rootPortAddress != address(0), "Root Port Address cannot be 0");

        rootChainId = _rootChainId;
        wrappedNativeToken = _wrappedNativeToken;
        lzEndpointAddress = _lzEndpointAddress;
        rootPortAddress = _rootPortAddress;
    }

    /*///////////////////////////////////////////////////////////////
                BRIDGE AGENT FACTORY EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Creates a new Root Bridge Agent.
     *   @param _newRootRouterAddress New Root Router Address.
     *   @return newBridgeAgent New Bridge Agent Address.
     */
    function createBridgeAgent(address _newRootRouterAddress) external returns (address newBridgeAgent) {
        newBridgeAgent = address(
            DeployRootBridgeAgent.deploy(
                wrappedNativeToken, rootChainId, lzEndpointAddress, rootPortAddress, _newRootRouterAddress
            )
        );

        IRootPort(rootPortAddress).addBridgeAgent(msg.sender, newBridgeAgent);
    }
}
