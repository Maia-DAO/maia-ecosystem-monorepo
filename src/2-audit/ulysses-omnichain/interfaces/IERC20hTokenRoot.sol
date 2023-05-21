// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

/**
 * @title IERC20hTokenRoot.
 * @author MaiaDAO.
 * @notice This contract is used to interact with the ERC20 hToken contracts deployed in the Root Chain of the Hermes Omnichain Incentives System.
 */
interface IERC20hTokenRoot {
    /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev View Function returns Token's Local Address.
    function getTokenBalance(uint256 chainId) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                        ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Function to mint hTokens in the Root Chain to match Branch Chain deposit.
    function mint(address to, uint256 amount, uint256 chainId) external returns (bool);

    /// @dev Function to burn hTokens in the Root Chain to match Branch Chain withdrawal.
    function burn(address from, uint256 value, uint256 chainId) external;

    /*///////////////////////////////////////////////////////////////
                                ERRORS 
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedPort();
}
