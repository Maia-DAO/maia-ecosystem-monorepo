// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BranchBridgeAgentFactory, IPort, WETH9 } from "./BranchBridgeAgentFactory.sol";
import { ArbitrumBranchBridgeAgent } from "../ArbitrumBranchBridgeAgent.sol";

/**
@title BridgeAgentFactory.
@author MaiaDAO.
@notice This contract is used to deploy new Bridge Agents which are in charge of managing the deposit and withdrawal of assets between the branch chains and the omnichain environment.
*/
contract ArbitrumBranchBridgeAgentFactory is BranchBridgeAgentFactory {
    /**
        @notice Constructor for Bridge Agent.
        @param _rootChainId Local Chain Id.
        @param _wrappedNativeToken Local Wrapped Native Token.
        @param _localAnyCallAddress Local Anycall Address.
        @param _localPortAddress Local Port Address.
        @param _owner Owner of the contract.
     */
    constructor(
        uint256 _rootChainId,
        WETH9 _wrappedNativeToken,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localCoreBranchRouterAddress,
        address _localPortAddress,
        address _owner
    )
        BranchBridgeAgentFactory(
            _rootChainId,
            _rootChainId,
            _wrappedNativeToken,
            _localAnyCallAddress,
            _localAnyCallExecutorAddress,
            _localCoreBranchRouterAddress,
            _localPortAddress,
            _owner
        )
    {}

    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createBridgeAgent(
        address _newBranchRouterAddress,
        address _rootBridgeAgentAddress
    ) external override returns (address newBridgeAgent) {
        newBridgeAgent = address(
            new ArbitrumBranchBridgeAgent(
                wrappedNativeToken,
                rootChainId,
                _rootBridgeAgentAddress,
                localAnyCallAddress,
                localAnyCallExecutorAddress,
                _newBranchRouterAddress,
                localPortAddress
            )
        );

        IPort(localPortAddress).addBridgeAgent(newBridgeAgent);
    }
}
