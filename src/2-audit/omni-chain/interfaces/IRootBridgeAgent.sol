// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IRootPort as IPort } from "../interfaces/IRootPort.sol";
import { IRootRouter as IRouter } from "../interfaces/IRootRouter.sol";
import { IBranchBridgeAgent } from "../interfaces/IBranchBridgeAgent.sol";
import { IERC20hTokenRoot } from "../interfaces/IERC20hTokenRoot.sol";
import { VirtualAccount } from "../VirtualAccount.sol";

import { IApp } from "./IApp.sol";
import { IAnycallProxy } from "./IAnycallProxy.sol";
import { IAnycallConfig } from "./IAnycallConfig.sol";
import { IAnycallExecutor } from "./IAnycallExecutor.sol";
import { AnycallFlags } from "../lib/AnycallFlags.sol";

import { WETH9 } from "../interfaces/IWETH9.sol";
import { RLPDecoder } from "@rlp/RLPDecoder.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import { BytesLib } from "./BytesLib.sol";

//Any data passed through by the caller via the IUniswapV3PoolActions#swap call
struct SwapCallbackData {
    address tokenIn;
}

struct UserFeeInfo {
    uint128 depositedGas;
    uint128 gasToBridgeOut;
    uint256 feesOwed;
}

struct GasPoolInfo {
    //zeroForOne when swapping gas from branch chain into root chain gas
    bool zeroForOneOnInflow;
    uint24 priceImpactPercentage;
    address poolAddress;
}

enum SettlementStatus {
    Success,
    Pending,
    Failed
}

struct Settlement {
    address owner;
    address[] hTokens;
    address[] tokens;
    uint256[] amounts;
    uint256[] deposits;
    bytes callData;
    uint256 gasOwed;
    uint256 toChain;
    SettlementStatus status;
}

struct SettlementInput {
    //Deposit Info
    address hToken; //Input Local hTokens Address.
    address token; //Input Native / underlying Token Address.
    uint256 amount; //Amount of Local hTokens deposited for interaction.
    uint256 deposit; //Amount of native tokens deposited for interaction.
    uint256 toChain; //Destination chain for interaction.
}

struct SettlementMultipleInput {
    //Deposit Info
    address[] hTokens; //Input Local hTokens Address.
    address[] tokens; //Input Native / underlying Token Address.
    uint256[] amounts; //Amount of Local hTokens deposited for interaction.
    uint256[] deposits; //Amount of native tokens deposited for interaction.
    uint256 toChain; //Destination chain for interaction.
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
    uint32 settlementNonce;
    address recipient;
    address[] hTokens;
    address[] tokens;
    uint256[] amounts;
    uint256[] deposits;
}

struct DepositParams {
    //Deposit Info
    uint32 depositNonce; //Deposit nonce.
    address hToken; //Input Local hTokens Address.
    address token; //Input Native / underlying Token Address.
    uint256 amount; //Amount of Local hTokens deposited for interaction.
    uint256 deposit; //Amount of native tokens deposited for interaction.
    uint256 toChain; //Destination chain for interaction.
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
}

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
interface IRootBridgeAgent is IApp {
    function initialGas() external view returns (uint256);

    function userFeeInfo() external view returns (uint128, uint128, uint256);

    /*///////////////////////////////////////////////////////////////
                        TOKEN BRIDGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
      @dev Internal function to move assets from root chain to branch omnichain environment.
      @param _recipient recipient of bridged tokens.
      @param _data parameters for function call on branch chain.
      @param _globalAddress global token to be moved.
      @param _amount amount of ´token´.
      @param _deposit amount of native / underlying token.
      @param _toChain chain to bridge to.
    **/
    function bridgeOutAndCall(
        address _recipient,
        bytes memory _data,
        address _globalAddress,
        uint256 _amount,
        uint256 _deposit,
        uint256 _toChain
    ) external payable;

    /**
      @dev Internal function to move assets from branch chain to root omnichain environment.
      @param _recipient recipient of bridged tokens.
      @param _data parameters for function call on branch chain.
      @param _globalAddresses global tokens to be moved.
      @param _amounts amounts of token.
      @param _deposits amounts of underlying / token.
      @param _toChain chain to bridge to.

    **/
    function bridgeOutAndCallMultiple(
        address _recipient,
        bytes memory _data,
        address[] memory _globalAddresses,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint256 _toChain
    ) external payable;

    /*///////////////////////////////////////////////////////////////
                        SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /** 
        @dev Function that returns the current settlement nonce.
        @return nonce bridge agent's current settlement nonce
    **/
    function settlementNonce() external view returns (uint32 nonce);

    /**
        @dev Function to retry a user's Settlement balance.
        @param _settlementNonce Identifier for token settlement.
        @param _remoteExecutionGas Identifier for token settlement.
    **/
    function clearSettlement(uint32 _settlementNonce, uint128 _remoteExecutionGas) external payable;

    /** 
        @dev External function that returns a given settlement entry.
        @param _settlementNonce Identifier for token settlement.
    **/
    function getSettlementEntry(uint32 _settlementNonce) external view returns (Settlement memory);

    /*///////////////////////////////////////////////////////////////
                        ANYCALL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function anyExecute(bytes calldata data) external returns (bool success, bytes memory result);

    function anyFallback(bytes calldata data) external returns (bool success, bytes memory result);

    /// @dev Internal function performs call to AnycallProxy Contract for cross-chain messaging.
    function performCall(
        address _recipient,
        bytes memory _calldata,
        uint256 _toChain
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

    error AnycallUnauthorizedCaller();
    error UnauthorizedCaller();

    error UnrecognizedUnderlyingAddress();
    error UnrecognizedLocalAddress();
    error UnrecognizedGlobalAddress();
    error UnrecognizedAddressInDestination();

    error InsufficientBalanceForSettlement();
    error InsufficientGasForFees();
    error InvalidInputParams();

    error CallerIsNotPool();
    error AmountsAreZero();
}
