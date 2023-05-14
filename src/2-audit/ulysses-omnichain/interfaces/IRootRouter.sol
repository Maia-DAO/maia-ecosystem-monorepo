// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH9} from "../interfaces/IWETH9.sol";

import {RLPDecoder} from "@rlp/RLPDecoder.sol";
import {IRootPort as IPort} from "../interfaces/IRootPort.sol";
import {DepositParams, DepositMultipleParams} from "../interfaces/IRootBridgeAgent.sol";

/**
 * @title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
 * @author MaiaDAO
 * @dev
 */
interface IRootRouter {
    /*///////////////////////////////////////////////////////////////
                        ANYCALL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     *     @notice Function responsible of executing a branch router response.
     *     @param funcId 1 byte called Router function identifier.
     *     @param encodedData data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     *      2            | _addLocalToken
     *      3            | _setLocalToken
     *
     */
    function anyExecuteResponse(bytes1 funcId, bytes memory encodedData, uint24 fromChainId)
        external
        payable
        returns (bool success, bytes memory result);

    /**
     *     @notice Function responsible of executing a crosschain request without any deposit.
     *     @param funcId 1 byte Router function identifier.
     *     @param encodedData data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     *      1            | _addGlobalToken
     *      4            | _syncBranchBridgeAgent
     *
     */
    function anyExecute(bytes1 funcId, bytes memory encodedData, uint24 fromChainId)
        external
        payable
        returns (bool success, bytes memory result);

    /**
     *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information attached.
     *   @param funcId 1 byte Router function identifier.
     *   @param encodedData execution data received from messaging layer.
     *   @param dParams cross-chain deposit information.
     *   @param fromChainId chain where the request originated from.
     *
     */
    function anyExecuteDepositSingle(
        bytes1 funcId,
        bytes memory encodedData,
        DepositParams memory dParams,
        uint24 fromChainId
    ) external payable returns (bool success, bytes memory result);

    /**
     *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information for multiple assets attached.
     *   @param funcId 1 byte Router function identifier.
     *   @param encodedData execution data received from messaging layer.
     *   @param dParams cross-chain multiple deposit information.
     *   @param fromChainId chain where the request originated from.
     *
     */
    function anyExecuteDepositMultiple(
        bytes1 funcId,
        bytes memory encodedData,
        DepositMultipleParams memory dParams,
        uint24 fromChainId
    ) external payable returns (bool success, bytes memory result);

    /**
     * @notice Reverts when called
     * @param funcId 1 byte Router function identifier.
     * @param encodedData execution data received from messaging layer.
     * @param userAccount user account address.
     * @param fromChainId chain where the request originated from.
     */
    function anyExecuteSigned(bytes1 funcId, bytes memory encodedData, address userAccount, uint24 fromChainId)
        external
        payable
        returns (bool success, bytes memory result);

    /**
     * @notice Reverts when called
     * @param funcId 1 byte Router function identifier.
     * @param encodedData execution data received from messaging layer.
     * @param dParams cross-chain deposit information.
     * @param userAccount user account address.
     * @param fromChainId chain where the request originated from.
     */
    function anyExecuteSignedDepositSingle(
        bytes1 funcId,
        bytes memory encodedData,
        DepositParams memory dParams,
        address userAccount,
        uint24 fromChainId
    ) external payable returns (bool success, bytes memory result);

    /**
     * @notice Reverts when called
     * @param funcId 1 byte Router function identifier.
     * @param encodedData execution data received from messaging layer.
     * @param dParams cross-chain multiple deposit information.
     * @param userAccount user account address.
     * @param fromChainId chain where the request originated from.
     */
    function anyExecuteSignedDepositMultiple(
        bytes1 funcId,
        bytes memory encodedData,
        DepositMultipleParams memory dParams,
        address userAccount,
        uint24 fromChainId
    ) external payable returns (bool success, bytes memory result);

    /**
     * @notice  Fallback function for anycall
     * @param data calldata
     */
    function anyFallback(bytes calldata data) external returns (bool success, bytes memory result);

    /*///////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedBridgeAgentExecutor();

    /*///////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////*/

    event LogCallin(bytes4 selector, bytes data, uint24 fromChainId);
    event LogCallout(bytes4 selector, bytes data, uint256, uint24 toChainId);
    event LogCalloutFail(bytes4 selector, bytes data, uint24 toChainId);
}
