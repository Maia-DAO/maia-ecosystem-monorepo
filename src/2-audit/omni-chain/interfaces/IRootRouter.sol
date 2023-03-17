// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { WETH9 } from "../interfaces/IWETH9.sol";

import { RLPDecoder } from "@rlp/RLPDecoder.sol";
import { IRootPort as IPort } from "../interfaces/IRootPort.sol";
import { DepositParams, DepositMultipleParams } from "../interfaces/IRootBridgeAgent.sol";

/**
@title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
@author MaiaDAO
@dev
*/
interface IRootRouter {
    function anyExecuteResponse(
        bytes1 funcId,
        bytes memory rlpEncodedCallData,
        uint256 fromChainId
    ) external payable returns (bool success, bytes memory result);

    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedCallData,
        uint256 fromChainId
    ) external payable returns (bool success, bytes memory result);

    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedCallData,
        DepositParams memory dParams,
        uint256 fromChainId
    ) external payable returns (bool success, bytes memory result);

    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedCallData,
        DepositMultipleParams memory dParams,
        uint256 fromChainId
    ) external payable returns (bool success, bytes memory result);

    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedCallData,
        address userAccount,
        uint256 fromChainId
    ) external payable returns (bool success, bytes memory result);

    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedCallData,
        DepositParams memory dParams,
        address userAccount,
        uint256 fromChainId
    ) external payable returns (bool success, bytes memory result);

    function anyExecute(
        bytes1 funcId,
        bytes memory rlpEncodedCallData,
        DepositMultipleParams memory dParams,
        address userAccount,
        uint256 fromChainId
    ) external payable returns (bool success, bytes memory result);

    function anyFallback(bytes calldata data) external returns (bool success, bytes memory result);

    /*///////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////*/

    event LogCallin(bytes4 selector, bytes data, uint256 fromChainId);
    event LogCallout(bytes4 selector, bytes data, uint256, uint256 toChainId);
    event LogCalloutFail(bytes4 selector, bytes data, uint256 toChainId);
}
