// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IBranchRouter.sol";
import { IBranchBridgeAgent as IBridgeAgent } from "./interfaces/IBranchBridgeAgent.sol";
import { console2 } from "forge-std/console2.sol";

/**
@title BaseBranchRouter contract for deployment in Branch Chains of Omnichain System.
@author MaiaDAO
@dev Base Branch Interface for Anycall cross-chain messaging.
*/
contract BaseBranchRouter is IBranchRouter, Ownable {
    /// @notice Address for local Branch Bridge Agent who processes requests and ineracts with local port.
    address public localBridgeAgentAddress;

    constructor() {
        _initializeOwner(msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
      @notice Function to perform a call to the Root Omnichain Router without token deposit.
      @param params RLP enconded parameters to execute on the root chain.
      @param remoteExecutionGas gas deposited via msg.value - gas deposited via msg.value - gas allocated for omnichain execution.
      @dev ACTION ID: 1 (Call without deposit) 
    **/
    function callOut(bytes calldata params, uint128 remoteExecutionGas) external payable lock {
        //TODO transfer funds from user to router
        IBridgeAgent(localBridgeAgentAddress).callOut{ value: msg.value }(
            params,
            remoteExecutionGas
        );
    }

    /**
      @notice Function to perform a call to the Root Omnichain Router while depositing a single asset.
      @param params RLP enconded parameters to execute on the root chain.
      @param dParams additional token deposit parameters.
      @param remoteExecutionGas gas deposited via msg.value - gas allocated for omnichain execution.
      @dev ACTION ID: 2 (Call with single deposit) 
    **/
    function callOut(
        bytes calldata params,
        DepositInput memory dParams,
        uint128 remoteExecutionGas
    ) external payable lock {
        //TODO transfer funds from user to router
        IBridgeAgent(localBridgeAgentAddress).callOut{ value: msg.value }(
            params,
            dParams,
            remoteExecutionGas
        );
    }

    /**
      @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets.
      @param params RLP enconded parameters to execute on the root chain.
      @param dParams additional token deposit parameters.
      @param remoteExecutionGas gas deposited via msg.value - gas allocated for omnichain execution.
      @dev ACTION ID: 3 (Call with multiple deposit) 
    **/
    function callOut(
        bytes calldata params,
        DepositMultipleInput memory dParams,
        uint128 remoteExecutionGas
    ) external payable lock {
        //TODO transfer funds from user to router
        IBridgeAgent(localBridgeAgentAddress).callOut{ value: msg.value }(
            params,
            dParams,
            remoteExecutionGas
        );
    }

    /** @notice External function to retry a failed Settlement entry on the root chain.
        @param _settlementNonce Identifier for user settlement.
        @dev ACTION ID: 10
    **/
    function retrySettlement(uint32 _settlementNonce) external payable lock {
        IBridgeAgent(localBridgeAgentAddress).retrySettlement{ value: msg.value }(_settlementNonce);
    }

    /** @notice External function to retry a failed Deposit entry on this branch chain.
        @param _depositNonce Identifier for user deposit.
    **/
    function redeemDeposit(uint32 _depositNonce) external lock {
        IBridgeAgent(localBridgeAgentAddress).redeemDeposit(_depositNonce);
    }

    /** @dev External function that returns a given deposit entry.
        @param _depositNonce Identifier for user deposit.
    **/
    function getDepositEntry(uint32 _depositNonce) external view returns (Deposit memory) {
        return IBridgeAgent(localBridgeAgentAddress).getDepositEntry(_depositNonce);
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function anyExecuteNoSettlement(
        bytes memory
    ) external virtual requiresBridgeAgent returns (bool success, bytes memory result) {
        /// NO FUNCS
        /// Unrecognized Function Selector

        return (false, "unknown selector");
    }

    function anyExecuteSettlement(
        bytes memory,
        SettlementParams memory
    ) external virtual requiresBridgeAgent returns (bool success, bytes memory result) {
        /// NO FUNCS
        /// Unrecognized Function Selector

        return (false, "unknown selector");
    }

    function anyExecuteSettlementMultiple(
        bytes memory,
        SettlementMultipleParams memory
    ) external virtual requiresBridgeAgent returns (bool success, bytes memory result) {
        /// NO FUNCS
        /// Unrecognized Function Selector

        return (false, "unknown selector");
    }

    function anyFallback(
        bytes calldata
    ) external virtual requiresBridgeAgent returns (bool success, bytes memory result) {
        /// NO FUNCS
        /// Unrecognized Function Selector

        return (false, "unknown selector");
    }

    function initialize(address _localBridgeAgentAddress) external onlyOwner {
        localBridgeAgentAddress = _localBridgeAgentAddress;
        renounceOwnership();
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier that verifies msg sender is this router's local Bridge Agent.
    modifier requiresBridgeAgent() {
        if (msg.sender != localBridgeAgentAddress) revert UnauthorizedCallerNotBridgeAgent();
        _;
    }

    /// @notice Modifier for a simple re-entrancy check.
    uint256 internal _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }
}
