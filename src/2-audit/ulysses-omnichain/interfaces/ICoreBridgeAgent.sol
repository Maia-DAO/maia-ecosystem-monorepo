// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IRootBridgeAgent.sol";

/**
@title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
@author MaiaDAO
@dev Base Root Router for Anycall cross-chain messaging.
* 
*   CROSS-CHAIN MESSAGING FUNCIDs
*   -----------------------------
*   FUNC ID      | FUNC NAME     
*   -------------|---------------
*   0            | No Deposit   
*   1            | With Deposit
*   2            | With Deposit of Multiple Tokens
*   3            | withdrawFromPort
*   4            | bridgeTo    
*   5            | clearSettlement           
*
*/
interface ICoreBridgeAgent is IRootBridgeAgent {
    /*///////////////////////////////////////////////////////////////
                    TOKEN MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
      @dev Function to add a new local to the global environment. Called from branch chain. 
      @param _newBranchBridgeAgent address of the new branch bridge agent.
      @param _rootBridgeAgent address of the root bridge agent.
      @param _fromChain chain from which the new branch bridge agent is being added.
    **/
    function syncBranchBridgeAgent(
        address _newBranchBridgeAgent,
        address _rootBridgeAgent,
        uint24 _fromChain
    ) external;

    /**
      @dev Internal function to add a global token to a specific chain. Must be called from a branch interface.
      @param _data encoded data of the global token to be added.
      @param _recipient recipient of the global token.
      @param _toChain chain to which the Global Token will be added.
    **/
    function addGlobalToken(
        bytes memory _data,
        address _recipient,
        uint24 _toChain
    ) external payable;

    /**
      @dev Function to add a new local to the global environment. Called from branch chain. 
      @param _underlyingAddress the token's underlying/native address. 
      @param _localAddress the token's address.
      @param _globalAddress the token's underlying/native address. 
      @param _toChain the token's chain Id.
    **/
    function addLocalToken(
        address _underlyingAddress,
        address _localAddress,
        address _globalAddress,
        uint24 _toChain
    ) external;

    /**
      @dev Internal function to set the local token on a specific chain for a global token. 
      @param _globalAddress global token to be updated.
      @param _localAddress local token to be added.
      @param _toChain local token's chain.
    **/
    function setLocalToken(
        address _globalAddress,
        address _localAddress,
        uint24 _toChain
    ) external;
}
