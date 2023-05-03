// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRootPort as IPort} from "../interfaces/IRootPort.sol";
import {IRootRouter as IRouter} from "../interfaces/IRootRouter.sol";
import {IBranchBridgeAgent} from "../interfaces/IBranchBridgeAgent.sol";
import {IERC20hTokenRoot} from "../interfaces/IERC20hTokenRoot.sol";
import {VirtualAccount} from "../VirtualAccount.sol";

import {IApp} from "./IApp.sol";
import {IAnycallProxy} from "./IAnycallProxy.sol";
import {IAnycallConfig} from "./IAnycallConfig.sol";
import {IAnycallExecutor} from "./IAnycallExecutor.sol";
import {AnycallFlags} from "../lib/AnycallFlags.sol";

import {WETH9} from "../interfaces/IWETH9.sol";
import {RLPDecoder} from "@rlp/RLPDecoder.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {BytesLib} from "./BytesLib.sol";

/**
 * Glossary:
 *  - ht = hToken
 *  - t = Token
 *  - A = Amount
 *  - D = Destination
 *  - C = ChainId
 *  - b = bytes
 *  - n = number of assets
 *  ___________________________________________________________________________________________________________________________
 * |            Flag               |        Deposit Info        |             Token Info             |   DATA    |  Gas Info 	|
 * |           1 byte              |         4-25 bytes         |     3 + (105 or 128) * n bytes     |   ---	  |  32 bytes  	|
 * |                               |                            |          hT - t - A - D - C        |           |           	|
 * |_______________________________|____________________________|____________________________________|___________|_____________|
 * | callOutSystem = 0x0   	    |                 4b(nonce)  |            -------------           |   ---	  |  dep + bOut |
 * | callOut = 0x1                	|                 4b(nonce)  |            -------------           |   ---	  |  dep + bOut |
 * | callOutSingle = 0x2           |                 4b(nonce)  |      20b + 20b + 32b + 32b + 3b    |   ---	  |  16b + 16b  |
 * | callOutMulti = 0x3            |         1b(n) + 4b(nonce)  |   	32b + 32b + 32b + 32b + 3b    |   ---	  |  16b + 16b  |
 * | callOutSigned = 0x4           |    20b(recip) + 4b(nonce)  |   	      -------------           |   ---     |  16b + 16b  |
 * | callOutSignedSingle = 0x5     |           20b + 4b(nonce)  |      20b + 20b + 32b + 32b + 3b 	  |   ---	  |  16b + 16b  |
 * | callOutSignedMultiple = 0x6   |   20b + 1b(n) + 4b(nonce)  |      32b + 32b + 32b + 32b + 3b 	  |   ---	  |  16b + 16b  |
 * |_______________________________|____________________________|___________________________________ |___________|_____________|
 */

//Any data passed through by the caller via the IUniswapV3PoolActions#swap call
struct SwapCallbackData {
    address tokenIn; //Token being sold
}

struct UserFeeInfo {
    uint128 depositedGas; //Gas deposited by user
    uint128 gasToBridgeOut; //Gas to be sent to bridge
    uint256 feesOwed; //Fees owed to user
}

struct GasPoolInfo {
    //zeroForOne when swapping gas from branch chain into root chain gas
    bool zeroForOneOnInflow;
    uint24 priceImpactPercentage; //Price impact percentage
    address poolAddress; //Uniswap V3 Pool Address
}

enum SettlementStatus {
    Success, //Settlement was successful
    Pending, //Settlement is pending
    Failed //Settlement failed
}

struct Settlement {
    uint24 toChain; //Destination chain for interaction.
    uint128 gasOwed; //Gas owed to user
    address owner; //Owner of the settlement
    SettlementStatus status; //Status of the settlement
    address[] hTokens; //Input Local hTokens Addresses.
    address[] tokens; //Input Native / underlying Token Addresses.
    uint256[] amounts; //Amount of Local hTokens deposited for interaction.
    uint256[] deposits; //Amount of native tokens deposited for interaction.
    bytes callData; //Call data for settlement
}

struct SettlementInput {
    //Deposit Info
    address hToken; //Input Local hTokens Address.
    address token; //Input Native / underlying Token Address.
    uint256 amount; //Amount of Local hTokens deposited for interaction.
    uint256 deposit; //Amount of native tokens deposited for interaction.
    uint24 toChain; //Destination chain for interaction.
}

struct SettlementMultipleInput {
    //Deposit Info
    address[] hTokens; //Input Local hTokens Address.
    address[] tokens; //Input Native / underlying Token Address.
    uint256[] amounts; //Amount of Local hTokens deposited for interaction.
    uint256[] deposits; //Amount of native tokens deposited for interaction.
    uint24 toChain; //Destination chain for interaction.
}

struct SettlementParams {
    uint32 settlementNonce; //Settlement nonce.
    address recipient; //Recipient of the settlement.
    address hToken; //Input Local hTokens Address.
    address token; //Input Native / underlying Token Address.
    uint256 amount; //Amount of Local hTokens deposited for interaction.
    uint256 deposit; //Amount of native tokens deposited for interaction.
}

struct SettlementMultipleParams {
    uint8 numberOfAssets; //Number of assets to deposit.
    uint32 settlementNonce; //Settlement nonce.
    address recipient; //Recipient of the settlement.
    address[] hTokens; //Input Local hTokens Addresses.
    address[] tokens; //Input Native / underlying Token Addresses.
    uint256[] amounts; //Amount of Local hTokens deposited for interaction.
    uint256[] deposits; //Amount of native tokens deposited for interaction.
}

struct DepositParams {
    //Deposit Info
    uint32 depositNonce; //Deposit nonce.
    address hToken; //Input Local hTokens Address.
    address token; //Input Native / underlying Token Address.
    uint256 amount; //Amount of Local hTokens deposited for interaction.
    uint256 deposit; //Amount of native tokens deposited for interaction.
    uint24 toChain; //Destination chain for interaction.
}

struct DepositMultipleParams {
    //Deposit Info
    uint8 numberOfAssets; //Number of assets to deposit.
    uint32 depositNonce; //Deposit nonce.
    address[] hTokens; //Input Local hTokens Address.
    address[] tokens; //Input Native / underlying Token Address.
    uint256[] amounts; //Amount of Local hTokens deposited for interaction.
    uint256[] deposits; //Amount of native tokens deposited for interaction.
    uint24 toChain; //Destination chain for interaction.
}

/**
 * @title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
 * @author MaiaDAO
 * @dev Base Root Router for Anycall cross-chain messaging.
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

    function factoryAddress() external view returns (address);

    function getBranchBridgeAgent(uint256 _chainId) external view returns (address);

    function isBranchBridgeAgentAllowed(uint256 _chainId) external view returns (bool);

    /*///////////////////////////////////////////////////////////////
                        TOKEN BRIDGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice External function performs call to AnycallProxy Contract for cross-chain messaging.
     * @param _recipient recipient address for any outstanding gas on the destination chain.
     * @param _calldata Calldata for function call.
     * @param _toChain Chain to bridge to.
     * @dev Internal function performs call to AnycallProxy Contract for cross-chain messaging.
     */
    function callOut(address _recipient, bytes memory _calldata, uint24 _toChain) external payable;

    /**
     * @dev External function to move assets from root chain to branch omnichain envirsonment.
     *   @param _recipient recipient of bridged tokens.
     *   @param _data parameters for function call on branch chain.
     *   @param _globalAddress global token to be moved.
     *   @param _amount amount of ´token´.
     *   @param _deposit amount of native / underlying token.
     *   @param _toChain chain to bridge to.
     *
     */
    function callOutAndBridge(
        address _recipient,
        bytes memory _data,
        address _globalAddress,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain
    ) external payable;

    /**
     * @dev External function to move assets from branch chain to root omnichain environment.
     *   @param _recipient recipient of bridged tokens.
     *   @param _data parameters for function call on branch chain.
     *   @param _globalAddresses global tokens to be moved.
     *   @param _amounts amounts of token.
     *   @param _deposits amounts of underlying / token.
     *   @param _toChain chain to bridge to.
     *
     *
     */
    function callOutAndBridgeMultiple(
        address _recipient,
        bytes memory _data,
        address[] memory _globalAddresses,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain
    ) external payable;

    /*///////////////////////////////////////////////////////////////
                        SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Function that returns the current settlement nonce.
     *     @return nonce bridge agent's current settlement nonce
     *
     */
    function settlementNonce() external view returns (uint32 nonce);

    /**
     * @dev Function to retry a user's Settlement balance.
     *     @param _settlementNonce Identifier for token settlement.
     *     @param _remoteExecutionGas Identifier for token settlement.
     *
     */
    function clearSettlement(uint32 _settlementNonce, uint128 _remoteExecutionGas) external payable;

    /**
     * @dev External function that returns a given settlement entry.
     *     @param _settlementNonce Identifier for token settlement.
     *
     */
    function getSettlementEntry(uint32 _settlementNonce) external view returns (Settlement memory);

    /**
     * @dev External function that
     *
     */
    function syncBranchBridgeAgent(address _newBranchBridgeAgent, uint24 _branchChainId) external;

    /*///////////////////////////////////////////////////////////////
                    GAS SWAP INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if a pool is eligible to call uniswapV3SwapCallback
     * @param amount0 amount of token0 to swap
     * @param amount1 amount of token1 to swap
     * @param _data abi encoded data
     */
    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata _data) external;

    /*///////////////////////////////////////////////////////////////
                        ANYCALL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function responsible of executing a crosschain request when one is received.
     *   @param data data received from messaging layer.
     *
     *
     */
    function anyExecute(bytes calldata data) external returns (bool success, bytes memory result);

    /**
     * @notice Function to responsible of calling clearDeposit() if a cross-chain call fails/reverts.
     *       @param data data from reverted func.
     *
     */
    function anyFallback(bytes calldata data) external returns (bool success, bytes memory result);

    /*///////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new branch bridge agent to a given branch chainId
     * @param _branchChainId chainId of the branch chain
     */
    function approveBranchBridgeAgent(uint256 _branchChainId) external;

    /*///////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////*/

    event LogCallin(bytes1 selector, bytes data, uint24 fromChainId);
    event LogCallout(bytes1 selector, bytes data, uint256, uint24 toChainId);
    event LogCalloutFail(bytes1 selector, bytes data, uint24 toChainId);

    event RouterFallbackFailed(bytes data);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error AnycallUnauthorizedCaller();
    error UnauthorizedCaller();

    error AlreadyAddedBridgeAgent();

    error UnrecognizedPort();
    error UnrecognizedBridgeAgentManager();
    error UnrecognizedUnderlyingAddress();
    error UnrecognizedLocalAddress();
    error UnrecognizedGlobalAddress();
    error UnrecognizedAddressInDestination();

    error InsufficientBalanceForSettlement();
    error InsufficientGasForFees();
    error InvalidInputParams();
    error InvalidGasPool();

    error CallerIsNotPool();
    error AmountsAreZero();
}
