// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICoreBranchRouter {
    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to deploy/add a token already present in the global environment to a branch chain.
     * @param _globalAddress the address of the global virtualized token.
     * @param _toChain the chain to which the token will be added.
     * @param _remoteExecutionGas the amount of gas to be sent to the remote chain.
     * @param _rootExecutionGas the amount of gas to be sent to the root chain.
     */
    function addGlobalToken(
        address _globalAddress,
        uint256 _toChain,
        uint128 _remoteExecutionGas,
        uint128 _rootExecutionGas
    ) external payable;

    /**
     * @notice Function to add a token that's not available in the global environment to the branch chain.
     * @param _underlyingAddress the address of the token to be added.
     */
    function addLocalToken(address _underlyingAddress) external payable;

    /**
     * @notice Function to link a new bridge agent to the root bridge agent (which resides in Arbitrum).
     * @param _newBridgeAgentAddress the address of the new local bridge agent.
     * @param _rootBridgeAgentAddress the address of the root bridge agent.
     */
    function syncBridgeAgent(address _newBridgeAgentAddress, address _rootBridgeAgentAddress) external payable;
}
