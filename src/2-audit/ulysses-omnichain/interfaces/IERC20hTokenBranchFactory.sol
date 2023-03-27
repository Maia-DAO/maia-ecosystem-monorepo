// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "solady/auth/Ownable.sol";

import { ERC20hTokenBranch, ERC20 } from "../token/ERC20hTokenBranch.sol";

/**
@title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
@author MaiaDAO
@dev
*/
interface IERC20hTokenBranchFactory {
    /*///////////////////////////////////////////////////////////////
                            hTOKEN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Function to create a new hToken.
    /// @param _name Name of the Token.
    /// @param _symbol Symbol of the Token.
    function createToken(string memory _name, string memory _symbol)
        external
        returns (ERC20hTokenBranch newToken);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedCoreRouter();

    error UnrecognizedPort();
}
