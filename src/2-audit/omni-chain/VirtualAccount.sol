// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { ERC721 } from "solmate/tokens/ERC721.sol";

import { IRootPort } from "./interfaces/IRootPort.sol";

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
contract VirtualAccount {
    using SafeTransferLib for address;

    /// @notice The address of the user who owns this account.
    address public immutable userAddress;

    /// @notice Address for Local Port Address where funds deposited from this chain are stored.
    address public localPortAddress;

    /**
     * @notice Initializes the VirtualAccount.
     * @param _userAddress The address of the user who owns this account.
     */
    constructor(address _userAddress, address _localPortAddress) {
        userAddress = _userAddress;
        localPortAddress = _localPortAddress;
    }

    /**
     * @notice Withdraws ERC20 tokens from the VirtualAccount.
     * @param _token The address of the ERC20 token to withdraw.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdrawERC20(address _token, uint256 _amount) external requiresApprovedCaller {
        _token.safeTransfer(msg.sender, _amount);
    }

    /**
     * @notice Withdraws ERC721 tokens from the VirtualAccount.
     * @param _token The address of the ERC721 token to withdraw.
     * @param _tokenId The id of the token to withdraw.
     */
    function withdrawERC721(address _token, uint256 _tokenId) external requiresApprovedCaller {
        ERC721(_token).transferFrom(address(this), msg.sender, _tokenId);
    }

    function call(Call memory callInput)
        external
        requiresApprovedCaller
        returns (uint256 blockNumber, bytes memory returnData)
    {
        blockNumber = block.number;
        bool success;
        (success, returnData) = callInput.target.call(callInput.callData);
        if (!success) revert CallFailed();
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresApprovedCaller() {
        if (
            (!IRootPort(localPortAddress).isRouterApproved(this, msg.sender)) &&
            (msg.sender != userAddress)
        ) revert UnathorizedCaller();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error CallFailed();
    error UnathorizedCaller();
}
