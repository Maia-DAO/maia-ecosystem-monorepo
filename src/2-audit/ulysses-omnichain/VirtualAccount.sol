// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IVirtualAccount.sol";

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title VirtualAccount
 * @dev VirtualAccount is a contract that allows hApps to keep encapsulated user balance for accounting purposes.
 */
contract VirtualAccount is IVirtualAccount {
    using SafeTransferLib for address;

    /// @notice The address of the user who owns this account.
    address public immutable userAddress;

    /// @notice Address for Local Port Address where funds deposited from this chain are stored.
    address public localPortAddress;

    constructor(address _userAddress, address _localPortAddress) {
        userAddress = _userAddress;
        localPortAddress = _localPortAddress;
    }

    /// @inheritdoc IVirtualAccount
    function withdrawERC20(address _token, uint256 _amount) external requiresApprovedCaller {
        _token.safeTransfer(msg.sender, _amount);
    }

    /// @inheritdoc IVirtualAccount
    function withdrawERC721(address _token, uint256 _tokenId) external requiresApprovedCaller {
        ERC721(_token).transferFrom(address(this), msg.sender, _tokenId);
    }

    /// @inheritdoc IVirtualAccount
    function call(Call[] memory calls) external requiresApprovedCaller returns (uint256, bytes[] memory data) {
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success,) = calls[i].target.call(calls[i].callData);
            if (!success) revert CallFailed();
        }
        return (block.number, data);
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresApprovedCaller() {
        if ((!IRootPort(localPortAddress).isRouterApproved(this, msg.sender)) && (msg.sender != userAddress)) {
            revert UnauthorizedCaller();
        }
        _;
    }
}
