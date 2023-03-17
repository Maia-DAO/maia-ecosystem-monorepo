// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "solady/auth/Ownable.sol";

import { Deposit, DepositStatus, DepositInput, DepositParams, DepositMultipleInput, DepositMultipleParams, SettlementParams, SettlementMultipleParams } from "./IBranchBridgeAgent.sol";

/**
@title BaseBranchRouter contract for deployment in Branch Chains of Omnichain System.
@author MaiaDAO
@dev Base Branch Interface for Anycall cross-chain messaging.


*/
interface IBranchRouter {
    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
      @notice Function to perform a call to the Root Omnichain Router without token deposit.
      @param params RLP enconded parameters to execute on the root chain.
      @param rootExecutionGas gas allocated for remote execution.
      @dev ACTION ID: 1 (Call without deposit) 
    **/
    function callOut(bytes calldata params, uint128 rootExecutionGas) external payable;

    /**
      @notice Function to perform a call to the Root Omnichain Router while depositing a single asset.
      @param params RLP enconded parameters to execute on the root chain.
      @param dParams additional token deposit parameters.
      @param rootExecutionGas gas allocated for remote execution.
      @dev ACTION ID: 2 (Call with single deposit) 
    **/
    function callOut(
        bytes calldata params,
        DepositInput memory dParams,
        uint128 rootExecutionGas
    ) external payable;

    /**
      @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets.
      @param params RLP enconded parameters to execute on the root chain.
      @param dParams additional token deposit parameters.
      @param rootExecutionGas gas allocated for remote execution.
      @dev ACTION ID: 3 (Call with multiple deposit) 
    **/
    function callOut(
        bytes calldata params,
        DepositMultipleInput memory dParams,
        uint128 rootExecutionGas
    ) external payable;

    /** 
        @notice External function to retry a failed Settlement entry on the root chain.
        @param _settlementNonce Identifier for user settlement.
        @dev ACTION ID: 10
    **/
    function retrySettlement(uint32 _settlementNonce) external payable;

    /** 
        @notice External function to retry a failed Deposit entry on this branch chain.
        @param _depositNonce Identifier for user deposit.
    **/
    function redeemDeposit(uint32 _depositNonce) external;

    /** 
        @notice External function that returns a given deposit entry.
        @param _depositNonce Identifier for user deposit.
    **/
    function getDepositEntry(uint32 _depositNonce) external view returns (Deposit memory);

    /*///////////////////////////////////////////////////////////////
                        ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Function responsible of executing a branch router response.
        @param data data received from messaging layer.
     */
    function anyExecuteNoSettlement(bytes memory data)
        external
        returns (bool success, bytes memory result);

    /**
        @dev Function responsible of executing a crosschain request without any deposit.
        @param data data received from messaging layer.
        @param sParams SettlementParams struct.
   
     */
    function anyExecuteSettlement(bytes memory data, SettlementParams memory sParams)
        external
        returns (bool success, bytes memory result);

    /**
        @dev Function responsible of executing a crosschain request which contains cross-chain deposit information attached.
        @param data data received from messaging layer.
        @param sParams SettlementParams struct containing deposit information.
     *
     *   1            | addGlobalToken
     *   2            | addLocalToken
     *   3            | setLocalToken
     *   4            | exactInputSingle
     *   5            | exactInput
     *   6            | exactOutputSingle
     *   7            | exactOutput
     *
     *
     */
    function anyExecuteSettlementMultiple(
        bytes memory data,
        SettlementMultipleParams memory sParams
    ) external returns (bool success, bytes memory result);

    /**
        @notice Function to responsible of calling clearDeposit() if a cross-chain call fails/reverts.
        @param data data from reverted func.
    **/
    function anyFallback(bytes calldata data) external returns (bool success, bytes memory result);

    // /**
    //   @notice Internal function to calculate cost fo cross-chain message.
    //   @param data bytes that will be sent through messaging layer.
    //   @param toChain message destination chain Id.
    // **/
    // function computeAnyCallFees(bytes memory data, uint256 toChain) internal returns (uint256 fees) {
    //     fees = IAnycallProxy(IAnycallProxy(localAnyCallAddress).config()).calcSrcFees("0", toChain, data.length);
    // }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    error InvalidChain();

    error InsufficientGas();

    error UnauthorizedCallerNotBridgeAgent();
}
