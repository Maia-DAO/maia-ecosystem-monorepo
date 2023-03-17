// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Ownable } from "solady/auth/Ownable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IBranchPort } from "./IBranchPort.sol";
import { IRootPort } from "./IRootPort.sol";

import { ArbitrumBranchBridgeAgent } from "../ArbitrumBranchBridgeAgent.sol";

import { ERC20hTokenBranch } from "../token/ERC20hTokenBranch.sol";

interface IArbBranchPort is IBranchPort {
    /*///////////////////////////////////////////////////////////////
                        PORT STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositToPort(
        address _depositor,
        address _recipient,
        address _underlyingAddress,
        uint256 _amount
    ) external;

    function withdrawFromPort(
        address _depositor,
        address _recipient,
        address _globalAddress,
        uint256 _amount
    ) external;

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnknownToken();
    error UnknownUnderlyingToken();
}
