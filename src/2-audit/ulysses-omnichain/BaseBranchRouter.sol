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

    function initialize(address _localBridgeAgentAddress) external onlyOwner {
        localBridgeAgentAddress = _localBridgeAgentAddress;
        renounceOwnership();
    }

    /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchRouter
    function getDepositEntry(uint32 _depositNonce) external view returns (Deposit memory) {
        return IBridgeAgent(localBridgeAgentAddress).getDepositEntry(_depositNonce);
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchRouter
    function callOut(bytes calldata params, uint128 remoteExecutionGas) external payable lock {
        IBridgeAgent(localBridgeAgentAddress).performCallOut{ value: msg.value }(
            msg.sender,
            params,
            remoteExecutionGas
        );
    }

    /// @inheritdoc IBranchRouter
    function callOutAndBridge(
        bytes calldata params,
        DepositInput memory dParams,
        uint128 remoteExecutionGas
    ) external payable lock {
        IBridgeAgent(localBridgeAgentAddress).performCallOutAndBridge{ value: msg.value }(
            msg.sender,
            params,
            dParams,
            remoteExecutionGas
        );
    }

    /// @inheritdoc IBranchRouter
    function callOutAndBridgeMultiple(
        bytes calldata params,
        DepositMultipleInput memory dParams,
        uint128 remoteExecutionGas
    ) external payable lock {
        IBridgeAgent(localBridgeAgentAddress).performCallOutAndBridgeMultiple{ value: msg.value }(
            msg.sender,
            params,
            dParams,
            remoteExecutionGas
        );
    }

    /// @inheritdoc IBranchRouter
    function retrySettlement(uint32 _settlementNonce) external payable lock {
        IBridgeAgent(localBridgeAgentAddress).retrySettlement{ value: msg.value }(_settlementNonce);
    }

    /// @inheritdoc IBranchRouter
    function redeemDeposit(uint32 _depositNonce) external lock {
        IBridgeAgent(localBridgeAgentAddress).redeemDeposit(_depositNonce);
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
