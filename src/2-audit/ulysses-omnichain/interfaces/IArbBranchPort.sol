// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {IBranchPort} from "./IBranchPort.sol";
import {IRootPort} from "./IRootPort.sol";

import {BranchPort} from "../BranchPort.sol";

import {ArbitrumBranchBridgeAgent} from "../ArbitrumBranchBridgeAgent.sol";

import {ERC20, ERC20hTokenBranch} from "../token/ERC20hTokenBranch.sol";
/**
 * @title IArbBranchPort.
 * @author MaiaDAO.
 * @notice This contract is used to interact with the Branch Port which is in charge of managing the deposit and withdrawal of assets between the branch chains and the omnichain environment.
 */

interface IArbBranchPort is IBranchPort {
    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to deposit underlying / native token amount into Port in exchange for Local hToken.
     *     @param _depositor underlying / native token depositor.
     *     @param _recipient hToken receiver.
     *     @param _underlyingAddress underlying / native token address.
     *     @param _amount amount of tokens.
     */
    function depositToPort(address _depositor, address _recipient, address _underlyingAddress, uint256 _amount)
        external;

    /**
     * @notice Function to withdraw underlying / native token amount into Port in exchange for Local hToken.
     *     @param _depositor underlying / native token depositor.
     *     @param _recipient hToken receiver.
     *     @param _globalAddress global hToken address.
     *     @param _amount amount of tokens.
     */
    function withdrawFromPort(address _depositor, address _recipient, address _globalAddress, uint256 _amount)
        external;

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnknownToken();
    error UnknownUnderlyingToken();
}
