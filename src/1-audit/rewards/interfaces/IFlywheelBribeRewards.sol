// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/FlywheelDynamicRewards.sol)
pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { RewardsDepot } from "../depots/RewardsDepot.sol";

import { IFlywheelAcummulatedRewards } from "./IFlywheelAcummulatedRewards.sol";

/**
 * @title Flywheel Accumulated Bribes Reward Stream
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Distributes rewards for allocation to voters periodically in accordance to votes.
 */
interface IFlywheelBribeRewards is IFlywheelAcummulatedRewards {
    /*//////////////////////////////////////////////////////////////
                        REWARDS CONTRACT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice RewardsDepot for each strategy
    function rewardsDepots(ERC20) external view returns (RewardsDepot);

    /**
     * @notice swap out the flywheel rewards contract
     *  @param rewardsDepot the new rewards depot to set
     */
    function setRewardsDepot(RewardsDepot rewardsDepot) external;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event AddRewardsDepot(address indexed strategy, RewardsDepot indexed rewardsDepot);
}
