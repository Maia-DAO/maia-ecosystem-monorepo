// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";

import "./CoreBranchRouter.sol";

import { ERC20hTokenBranch as ERC20hToken } from "./token/ERC20hTokenBranch.sol";

import { ISwapRouter } from "./interfaces/ISwapRouter.sol";
import { IERC20hTokenBranchFactory as IFactory } from "./interfaces/IERC20hTokenBranchFactory.sol";

/**
@title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
@author MaiaDAO
@dev
* 
*   CROSS-CHAIN MESSAGING FUNCIDs
*   -----------------------------
*   FUNC ID      | FUNC NAME 
*   -------------+---------------
*   1            | clearDeposit   
*   2            | finalizeDeposit      
*   3            | finalizeWithdraw      
*   4            | clearToken
*   5            | clearTokens             
*   6            | addGlobalToken             
*
*/
contract ArbitrumCoreBranchRouter is CoreBranchRouter {
    constructor(address _hTokenFactoryAddress) CoreBranchRouter(_hTokenFactoryAddress) {}

    /*///////////////////////////////////////////////////////////////
                    ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function anyExecuteNoSettlement(
        bytes memory
    ) external override returns (bool success, bytes memory result) {
        /// Unrecognized Function Selector

        return (false, "unknown selector");
    }
}
