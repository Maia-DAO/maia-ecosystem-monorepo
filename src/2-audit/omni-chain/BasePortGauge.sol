// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Ownable } from "solady/auth/Ownable.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { CoreBranchRouter } from "./CoreBranchRouter.sol";

abstract contract BasePortGauge {
    /*///////////////////////////////////////////////////////////////
                        BASE BRANCH GAUGE STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Core Branch Router Contract.
    CoreBranchRouter bRouter;

    /// @dev Core Branch Router Contract.
    uint256 globalGaugeId;

    constructor(CoreBranchRouter _bRouter) {
        bRouter = _bRouter;
    }

    /*///////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev require msg sender == active branch interface
    modifier requiresRouter() {
        _requiresRouter();
        _;
    }

    /// @dev reuse to reduce contract bytesize
    function _requiresRouter() internal view {
        require(msg.sender == address(bRouter), "Unauthorized caller");
    }

    /*///////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev View Function returns total rewards amount pending to be claimed.
    function getPendingRewards() public view virtual {}

    /*///////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Function that transfers a given depositAsset from caller to this contract.
    function stake() external virtual requiresRouter {}

    /// @dev Function that transfers a given depositAsset from this contract to it's caller.
    function unstake() external virtual requiresRouter {}

    /// @dev Function claims total pending rewards amount.
    function claimPendingRewards() external virtual {}

    /// @dev Function deposits total pending rewards amount to corresponding gauge.
    function depositClaimedRewards() external virtual {}
}
