// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IRootBridgeAgentFactory.sol";

import { RootBridgeAgent } from "../RootBridgeAgent.sol";

import { IRootPort } from "../interfaces/IRootPort.sol";

/**
@title BridgeAgentFactory.
@author MaiaDAO.
@notice This contract is used to deploy new Bridge Agents which are in charge of managing the deposit and withdrawal of assets between the branch chains and the omnichain environment.
*/
contract RootBridgeAgentFactory is IRootBridgeAgentFactory {
    /// @notice Root Chain Id
    uint24 public immutable rootChainId;

    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Root Port Address
    address public immutable rootPortAddress;

    /// @notice DAO Address
    address public immutable daoAddress;

    /// @notice Local Anycall Address
    address public immutable localAnyCallAddress;

    /// @notice Local Anyexec Address
    address public immutable localAnyCallExecutorAddress;

    /// @notice Bridge Agent Manager
    mapping(address => address) public getBridgeAgentManager;

    /**
        @notice Constructor for Bridge Agent.
        @param _rootChainId Root Chain Id.
        @param _wrappedNativeToken Local Wrapped Native Token.
        @param _localAnyCallAddress Local Anycall Address.
        @param _rootPortAddress Local Port Address.
        @param _daoAddress DAO Address.
     */
    constructor(
        uint24 _rootChainId,
        WETH9 _wrappedNativeToken,
        address _localAnyCallAddress,
        address _rootPortAddress,
        address _daoAddress
    ) {
        rootChainId = _rootChainId;
        wrappedNativeToken = _wrappedNativeToken;
        localAnyCallAddress = _localAnyCallAddress;
        localAnyCallExecutorAddress = IAnycallProxy(localAnyCallAddress).executor();
        rootPortAddress = _rootPortAddress;
        daoAddress = _daoAddress;
    }

    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
        @notice Creates a new Bridge Agent.
        @param _newRootRouterAddress New Root Router Address.
        @return newBridgeAgent New Bridge Agent Address.
     */
    function createBridgeAgent(
        address _newRootRouterAddress
    ) external returns (address newBridgeAgent) {
        newBridgeAgent = address(
            new RootBridgeAgent(
                wrappedNativeToken,
                rootChainId,
                daoAddress,
                localAnyCallAddress,
                localAnyCallExecutorAddress,
                rootPortAddress,
                _newRootRouterAddress
            )
        );

        IRootPort(rootPortAddress).addBridgeAgent(msg.sender, newBridgeAgent);
        // IRootPort(rootPortAddress).toggleBridgeAgent(newBridgeAgent);
    }

    // function toggleBridgeAgent(address _bridgeAgentAddress) external onlyOwner {
    //     IRootPort(rootPortAddress).toggleBridgeAgent(_bridgeAgentAddress);
    // }
}
