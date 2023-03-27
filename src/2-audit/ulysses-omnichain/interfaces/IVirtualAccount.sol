// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import {ERC721} from "solmate/tokens/ERC721.sol";

import {IRootPort} from "./IRootPort.sol";

// import "./token/ERC20hTokenBranch.sol";

struct Call {
    address target;
    bytes callData;
}

struct Result {
    bool success;
    bytes returnData;
}

/**
 * @title VirtualAccount
 * @dev VirtualAccount is a contract that allows hApps to keep encapsulated user balance for accounting purposes.
 */
interface IVirtualAccount {
    /**
     * @notice Returns the address of the user that owns the VirtualAccount.
     * @return The address of the user that owns the VirtualAccount.
     */
    function userAddress() external view returns (address);

    /**
     * @notice Withdraws ERC20 tokens from the VirtualAccount.
     * @param _token The address of the ERC20 token to withdraw.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdrawERC20(address _token, uint256 _amount) external;

    /**
     * @notice Withdraws ERC721 tokens from the VirtualAccount.
     * @param _token The address of the ERC721 token to withdraw.
     * @param _tokenId The id of the token to withdraw.
     */
    function withdrawERC721(address _token, uint256 _tokenId) external;

    /**
     * @notice
     * @param callInput The call to make.
     */
    function call(Call[] memory callInput) external returns (uint256 blockNumber, bytes[] memory );

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error CallFailed();
    error UnauthorizedCaller();
}
