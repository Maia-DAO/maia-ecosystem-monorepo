// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "solady/auth/Ownable.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

/**
@title IERC20hTokenBranch.
@author MaiaDAO.
@notice This interface is used to interact with the ERC20 hToken contracts deployed in the Branch Chains of the Hermes Omnichain Incentives System.
*/
interface IERC20hTokenBranch {
    /*///////////////////////////////////////////////////////////////
                        ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function mint(address account, uint256 amount) external returns (bool);

    function burn(uint256 value) external;
}
