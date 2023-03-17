// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { WETH9 } from "../interfaces/IWETH9.sol";

import { AnycallFlags } from "../lib/AnycallFlags.sol";
import { ERC20hTokenBranch as ERC20hToken } from "../token/ERC20hTokenBranch.sol";
import { IBranchRouter as IRouter } from "../interfaces/IBranchRouter.sol";
import { IBranchPort as IPort } from "../interfaces/IBranchPort.sol";

import { IApp } from "./IApp.sol";
import { IAnycallProxy } from "./IAnycallProxy.sol";
import { IAnycallConfig } from "./IAnycallConfig.sol";
import { IAnycallExecutor } from "./IAnycallExecutor.sol";
import { INonfungiblePositionManager } from "../interfaces/INonfungiblePositionManager.sol";

struct UserFeeInfo {
    uint256 depositedGas;
    uint256 feesOwed;
}

enum DepositStatus {
    Success,
    Pending,
    Failed
}

struct Deposit {
    address owner;
    address[] hTokens;
    address[] tokens;
    uint256[] amounts;
    uint256[] deposits;
    DepositStatus status;
    uint256 depositedGas;
}

struct DepositInput {
    //Deposit Info
    address hToken; //Input Local hTokens Address.
    address token; //Input Native / underlying Token Address.
    uint256 amount; //Amount of Local hTokens deposited for interaction.
    uint256 deposit; //Amount of native tokens deposited for interaction.
    uint256 toChain; //Destination chain for interaction.
}

struct DepositMultipleInput {
    //Deposit Info
    address[] hTokens; //Input Local hTokens Address.
    address[] tokens; //Input Native / underlying Token Address.
    uint256[] amounts; //Amount of Local hTokens deposited for interaction.
    uint256[] deposits; //Amount of native tokens deposited for interaction.
    uint256 toChain; //Destination chain for interaction.
}

struct DepositParams {
    //Deposit Info
    uint32 depositNonce; //Deposit nonce.
    address hToken; //Input Local hTokens Address.
    address token; //Input Native / underlying Token Address.
    uint256 amount; //Amount of Local hTokens deposited for interaction.
    uint256 deposit; //Amount of native tokens deposited for interaction.
    uint256 toChain; //Destination chain for interaction.
    uint256 depositedGas; //BRanch chain gas token amount sent with request.
}

struct DepositMultipleParams {
    //Deposit Info
    uint8 numberOfAssets; //Number of assets to deposit.
    uint32 depositNonce; //Deposit nonce.
    address[] hTokens; //Input Local hTokens Address.
    address[] tokens; //Input Native / underlying Token Address.
    uint256[] amounts; //Amount of Local hTokens deposited for interaction.
    uint256[] deposits; //Amount of native tokens deposited for interaction.
    uint256 toChain; //Destination chain for interaction.
    uint256 depositedGas; //BRanch chain gas token amount sent with request.
}

struct SettlementParams {
    uint32 settlementNonce;
    address recipient;
    address hToken;
    address token;
    uint256 amount;
    uint256 deposit;
}

struct SettlementMultipleParams {
    uint8 numberOfAssets; //Number of assets to deposit.
    address recipient;
    uint32 settlementNonce;
    address[] hTokens;
    address[] tokens;
    uint256[] amounts;
    uint256[] deposits;
}

/**
@title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
@author MaiaDAO
@dev Base Branch Interface for Anycall cross-chain messaging.
* 
*   CROSS-CHAIN MESSAGING FUNCIDs
*   -----------------------------
*   FUNC ID      | FUNC NAME     
*   -------------+---------------    
*   0x00         | message w/o deposit    
*   0x01         | message w/ single deposit   
*   0x02         | message w/ multiple deposit
*   0x03         | finalizeDeposit      
*   0x04         | finalizeWithdraw       
*
*/
interface IBranchBridgeAgent is IApp {
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
      @notice Function to perform a call to the Root Omnichain Router without token deposit with msg.sender information.
      @param params RLP enconded parameters to execute on the root chain.
      @param rootExecutionGas gas allocated for remote execution.
      @dev ACTION ID: 4 (Call without deposit and verified sender) 
    **/
    function callOutSigned(bytes calldata params, uint128 rootExecutionGas) external payable;

    /**
      @notice Function to perform a call to the Root Omnichain Router while depositing a single asset msg.sender.
      @param params RLP enconded parameters to execute on the root chain.
      @param dParams additional token deposit parameters.
      @param rootExecutionGas gas allocated for remote execution.
      @dev ACTION ID: 5 (Call with single deposit and verified sender) 
    **/
    function callOutSigned(
        bytes calldata params,
        DepositInput memory dParams,
        uint128 rootExecutionGas
    ) external payable;

    /**
      @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets with msg.sender.
      @param params RLP enconded parameters to execute on the root chain.
      @param dParams additional token deposit parameters.
      @param rootExecutionGas gas allocated for remote execution.
      @dev ACTION ID: 6 (Call with multiple deposit and verified sender) 
    **/
    function callOutSigned(
        bytes calldata params,
        DepositMultipleInput memory dParams,
        uint128 rootExecutionGas
    ) external payable;

    /** @notice External function to retry a failed Settlement entry on the root chain.
        @param _settlementNonce Identifier for user settlement.
        @dev ACTION ID: 10
    **/
    function retrySettlement(uint32 _settlementNonce) external payable;

    /** @notice External function to retry a failed Deposit entry on this branch chain.
        @param _depositNonce Identifier for user deposit.
    **/
    function redeemDeposit(uint32 _depositNonce) external;

    /** @dev External function that returns a given deposit entry.
        @param _depositNonce Identifier for user deposit.
    **/
    function getDepositEntry(uint32 _depositNonce) external view returns (Deposit memory);

    /*///////////////////////////////////////////////////////////////
                        BRANCH ROUTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /** @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging. 0x00 flag allows for identifying system emitted request/responses.
        @param params calldata for omnichain execution.
        @param depositor address of user depositing assets.
        @param rootExecutionGas gas allocated for omnichain execution.
    **/
    function performCall(
        bytes memory params,
        address depositor,
        uint128 rootExecutionGas
    ) external payable;

    /*///////////////////////////////////////////////////////////////
                        EVENTS
    //////////////////////////////////////////////////////////////*/

    event LogCallin(bytes1 selector, bytes data, uint256 fromChainId);

    event LogCallout(bytes1 selector, bytes data, uint256, uint256 toChainId);

    event LogCalloutFail(bytes1 selector, bytes data, uint256 toChainId);

    event RouterFallbackFailed(bytes data);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidInput();

    error InvalidChain();

    error InsufficientGas();

    error DepositRedeemUnavailable();

    error AnycallUnauthorizedCaller();

    error UnauthorizedCallerNotRouter();
}
