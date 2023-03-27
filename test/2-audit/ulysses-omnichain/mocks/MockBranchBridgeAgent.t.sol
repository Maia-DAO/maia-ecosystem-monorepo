///SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BranchBridgeAgent, DepositParams, DepositMultipleParams } from "@omni/BranchBridgeAgent.sol";
import { IBranchRouter, Deposit } from "@omni/interfaces/IBranchRouter.sol";
import { IBranchPort as IPort } from "@omni/interfaces/IBranchPort.sol";
import { ERC20hTokenBranch as ERC20hToken } from "@omni/token/ERC20hTokenBranch.sol";
import { INonfungiblePositionManager } from "@omni/interfaces/INonfungiblePositionManager.sol";
import { Path } from "@omni/interfaces/Path.sol";
import { WETH9 } from "@omni/interfaces/IWETH9.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { console2 } from "forge-std/console2.sol";

/**
@title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
@author MaiaDAO
@dev Base Branch Interface for Anycall cross-chain messaging.
* 
*   CROSS-CHAIN MESSAGING FUNCIDs
*   -----------------------------
*   FUNC ID      | FUNC NAME     
*   -------------+---------------    
*   1            | clearDeposit   
*   2            | closeDeposit
*   3            | finalizeDeposit      
*   4            | clearToken
*   5            | clearTokens   
*
*/
contract MockBranchBridgeAgent is BranchBridgeAgent {
    constructor(
        WETH9 _wrappedNativeToken,
        uint256 _rootChainId,
        uint256 _localChainId,
        address _rootBridgeAgentAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localRouterAddress,
        address _localPortAddress
    )
        BranchBridgeAgent(
            _wrappedNativeToken,
            _rootChainId,
            _localChainId,
            _rootBridgeAgentAddress,
            _localAnyCallAddress,
            _localAnyCallExecutorAddress,
            _localRouterAddress,
            _localPortAddress
        )
    {}

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////*/
    /**
        @dev Function to request balance clearance from a Port to a given user.
        @param _recipient token receiver.
        @param _hToken  local hToken addresse to clear balance for.
        @param _token  native / underlying token addresse to clear balance for.
        @param _amount amounts of hToken to clear balance for.
        @param _deposit amount of native / underlying tokens to clear balance for.
    **/
    function clearToken(
        address _recipient,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit
    ) public {
        _clearToken(_recipient, _hToken, _token, _amount, _deposit);
    }

    /**
        @dev Function to request balance clearance from a Port to a given user.
        @param _recipient token receiver.
        @param _callData token clearance calldata.
    **/
    function clearTokens(address _recipient, bytes calldata _callData) public {
        _clearTokens(_callData, _recipient);
    }

    /**
       @dev Function to lock a users balance in Router.
       @param _user user address.
       @param _tokens local token addresses.
       @param _amounts amounts of hTokens input.
       @param _deposits amount of deposited underlying / native tokens.

    **/
    function _lockTokens(
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits
    ) public {
        _lockTokens(_user, _hTokens, _tokens, _amounts, _deposits);
    }
}
