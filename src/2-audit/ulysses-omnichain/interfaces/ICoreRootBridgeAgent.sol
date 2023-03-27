// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICoreRootBridgeAgent {
    /* ////////////////////////////////////////////////////////
                    EXTERNAL FUNCTIONS 
    //////////////////////////////////////////////////////// */

    /**
     * @dev Function to add a global token to a specific chain. Must be called from a branch interface.
     *   @param _newBranchBridgeAgent new branch bridge agent address
     *   @param _rootBridgeAgent new branch bridge agent address
     *   @param _fromChain branch chain id.
     *
     */
    function syncBranchBridgeAgent(address _newBranchBridgeAgent, address _rootBridgeAgent, uint24 _fromChain)
        external;

    /**
     * @dev Internal function to add a global token to a specific chain. Must be called from a branch interface.
     *     @param _data encoded data for the token to be added.
     *     @param _toChain chain to which the Global Token will be added.
     *
     *
     */
    function addGlobalToken(bytes memory _data, address _branchRouter, uint24 _toChain) external;

    /**
     * @dev Function to add a new local to the global environment. Called from branch chain.
     *   @param _underlyingAddress the token's underlying/native address.
     *   @param _localAddress the token's address.
     *   @param _globalAddress the token's underlying/native address.
     *   @param _toChain the token's chain Id.
     *
     */
    function addLocalToken(address _underlyingAddress, address _localAddress, address _globalAddress, uint24 _toChain)
        external;

    /**
     * @dev Internal function to set the local token on a specific chain for a global token.
     *   @param _globalAddress global token to be updated.
     *   @param _localAddress local token to be added.
     *   @param _toChain local token's chain.
     *
     */
    function setLocalToken(address _globalAddress, address _localAddress, uint24 _toChain) external;
}
