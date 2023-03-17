///SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RootBridgeAgent, ERC20, IPort, WETH9 } from "./RootBridgeAgent.sol";

/**
@title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
@author MaiaDAO
@dev Base Root Router for Anycall cross-chain messaging.
* 
*   BRIDGE AGENT ACTION IDs
*   --------------------------------------
*   ID           | DESCRIPTION     
*   -------------+------------------------
*   0x00         | Branch Router Response.
*   0x01         | Call to Root Router without Deposit.
*   0x02         | Call to Root Router with Deposit.
*   0x03         | Call to Root Router with Deposit of Multiple Tokens.
*   0x04         | Call to Root Router without Deposit + singned message.
*   0x05         | Call to Root Router with Deposit + singned message.
*   0x06         | Call to Root Router with Deposit of Multiple Tokens + singned message.
*   0x07         | Call to ´depositToPort()´.
*   0x08         | Call to ´withdrawFromPort()´.
*   0x09         | Call to ´bridgeTo()´.
*   0x10         | Call to ´clearSettlement()´.
*
*
*/
contract CoreRootBridgeAgent is RootBridgeAgent {
    /**
        @notice Constructor for the CoreBridgeAgent contract.
        @param _wrappedNativeToken the address of the wrapped native token.
        @param _daoAddress the address of the DAO.
        @param _localChainId the chain Id of the local chain.
        @param _localAnyCallAddress the address of the local anycall contract.
        @param _localPortAddress the address of the local port contract.
        @param _localRouterAddress the address of the local port contract.
     */
    constructor(
        WETH9 _wrappedNativeToken,
        uint256 _localChainId,
        address _daoAddress,
        address _localAnyCallAddress,
        address _localAnycallExecutorAddress,
        address _localPortAddress,
        address _localRouterAddress
    )
        RootBridgeAgent(
            _wrappedNativeToken,
            _localChainId,
            _daoAddress,
            _localAnyCallAddress,
            _localAnycallExecutorAddress,
            _localPortAddress,
            _localRouterAddress
        )
    {}

    /*///////////////////////////////////////////////////////////////
                 TOKEN MANAGEMENT EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
      @dev Internal function to add a global token to a specific chain. Must be called from a branch interface.
      @param _data calldata for branch router call.
      @param _toChain chain to which the Global Token will be added.
    **/
    function addGlobalToken(bytes memory _data, uint256 _toChain) external requiresRouter {
        //Perform Call
        _performCall(_data,_toChain);
    }

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
        uint256 _toChain
    ) external requiresRouter {
        //Update Registry
        if (_toChain == localChainId) {
            IPort(localPortAddress).setAddresses(
                _globalAddress,
                _globalAddress,
                _underlyingAddress,
                _toChain
            );
        } else {
            IPort(localPortAddress).setAddresses(
                _globalAddress,
                _localAddress,
                _underlyingAddress,
                _toChain
            );
        }
    }

    /**
      @dev Internal function to set the local token on a specific chain for a global token. 
      @param _globalAddress global token to be updated.
      @param _localAddress local token to be added.
      @param _toChain local token's chain.
    **/
    function setLocalToken(
        address _globalAddress,
        address _localAddress,
        uint256 _toChain
    ) external {
        //Update Registry
        IPort(localPortAddress).setLocalAddress(_globalAddress, _localAddress, _toChain);
    }
}
