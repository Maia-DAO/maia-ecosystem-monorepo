// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import "@rewards/base/FlywheelCore.sol";
import "../mocks/MockRewardsStream.sol";
import {FlywheelGaugeRewards, IBaseV2Minter} from "@rewards/rewards/FlywheelGaugeRewards.sol";

import {MockBooster} from "../mocks/MockBooster.sol";

import {bHermes as bHERMES} from "@hermes/bHermes.sol";

// Full integration tests across Flywheel Core, Flywheel Gauge Rewards and bHermes
contract bHermesTest is DSTestPlus {
    FlywheelCore flywheel;
    FlywheelGaugeRewards rewards;
    MockRewardsStream stream;

    MockERC20 strategy;
    MockERC20 hermes;
    MockBooster booster;

    bHERMES bHermes;

    function setUp() public {
        hermes = new MockERC20("test hermes", "TKN", 18);

        strategy = new MockERC20("test strategy", "TKN", 18);

        // flywheel = new FlywheelCore(
        //     hermes,
        //     MockRewards(address(0)),
        //     IFlywheelBooster(address(booster)),
        //     address(this),
        //     Authority(address(0))
        // );

        // stream = new MockRewardsStream(hermes, 0);

        bHermes = new bHERMES(
            hermes,
            address(this),
            1000, // cycle of 1000
            100 // freeze window of 100
        );

        rewards = new FlywheelGaugeRewards(
            address(hermes),
            address(this),
            bHermes.gaugeWeight(),
            IBaseV2Minter(address(stream))
        );

        // flywheel.setFlywheelRewards(rewards);
    }

    ////////////////////////////////////////////////////////////////////////////////////////
    // TODO: THIS NEEEDS TO BE ADDED TO THE TESTS

    // function testClaimMultipleInsufficientShares(uint256 amount) public {
    //     bHermes.setClaimableWeight(address(this), 0);
    //     bHermes.setClaimableBoost(address(this), 0);
    //     bHermes.setClaimableGovernance(address(this), 0);
    //     bHermes.gaugeWeight().mint(address(bHermes), amount);
    //     bHermes.gaugeBoost().mint(address(bHermes), amount);
    //     bHermes.governance().mint(address(bHermes), amount);

    //     if (amount != 0) hevm.expectRevert(UtilityManager.InsufficientShares.selector);
    //     bHermes.claimMultiple(amount);
    // }

    // function testClaimMultipleAmountsInsufficientShares(
    //     uint256 weight,
    //     uint256 boost,
    //     uint256 governance
    // ) public {
    //     bHermes.setClaimableWeight(address(this), 0);
    //     bHermes.setClaimableBoost(address(this), 0);
    //     bHermes.setClaimableGovernance(address(this), 0);
    //     bHermes.gaugeWeight().mint(address(bHermes), weight);
    //     bHermes.gaugeBoost().mint(address(bHermes), boost);
    //     bHermes.governance().mint(address(bHermes), governance);

    //     if (weight != 0 || boost != 0 || governance != 0) {
    //         hevm.expectRevert(UtilityManager.InsufficientShares.selector);
    //     }
    //     bHermes.claimMultipleAmounts(weight, boost, governance);
    // }

    // function testClaimWeightInsufficientShares(uint256 amount) public {
    //     bHermes.setClaimableWeight(address(this), 0);
    //     bHermes.gaugeWeight().mint(address(bHermes), amount);

    //     if (amount != 0) hevm.expectRevert(UtilityManager.InsufficientShares.selector);
    //     bHermes.claimWeight(amount);
    // }

    // function testClaimBoostInsufficientShares(uint256 amount) public {
    //     bHermes.setClaimableBoost(address(this), 0);
    //     bHermes.gaugeBoost().mint(address(bHermes), amount);

    //     if (amount != 0) hevm.expectRevert(UtilityManager.InsufficientShares.selector);
    //     bHermes.claimBoost(amount);
    // }

    // function testClaimGovernanceInsufficientShares(uint256 amount) public {
    //     bHermes.setClaimableGovernance(address(this), 0);
    //     bHermes.governance().mint(address(bHermes), amount);

    //     if (amount != 0) hevm.expectRevert(UtilityManager.InsufficientShares.selector);
    //     bHermes.claimGovernance(amount);
    // }

    ////////////////////////////////////////////////////////////////////////////////////////
    // TODO: STUFF BEFORE THIS IS IMPORT
    ///////////////////////////////////

    // /**
    //  * @notice tests the "ERC20MultiVotes" functionality of bHermes
    //  *   Ensures that delegations successfully apply
    //  */
    // function testbHermesDelegations(
    //     address user,
    //     address delegate,
    //     uint128 mintAmount,
    //     uint128 delegationAmount,
    //     uint128 transferAmount
    // ) public {
    //     // setup
    //     hevm.assume(mintAmount != 0 && transferAmount <= mintAmount && user != address(0) && delegate != address(0));
    //     hermes.mint(user, mintAmount);
    //     bHermes.setMaxDelegates(1);

    //     // deposit to bHermes for user
    //     hevm.startPrank(user);
    //     hermes.approve(address(bHermes), mintAmount);
    //     bHermes.deposit(mintAmount, user);

    //     require(bHermes.balanceOf(user) == mintAmount);

    //     // expect revert and early return if user tries to delegate more than they have
    //     if (delegationAmount > mintAmount) {
    //         hevm.expectRevert(abi.encodeWithSignature("DelegationError()"));
    //         bHermes.incrementDelegation(delegate, delegationAmount);
    //         return;
    //     }

    //     // user can successfully delegate
    //     bHermes.incrementDelegation(delegate, delegationAmount);
    //     require(bHermes.userDelegatedVotes(user) == delegationAmount);
    //     require(bHermes.numCheckpoints(delegate) == 1);
    //     require(bHermes.checkpoints(delegate, 0).votes == delegationAmount);

    //     // roll forward and check transfer snapshot and undelegation logic
    //     hevm.roll(block.number + 10);
    //     bHermes.transfer(delegate, transferAmount);

    //     // If user is transferring so much that they need to undelegate, check those conditions, otherwise check assuming no change
    //     if (mintAmount - transferAmount < delegationAmount) {
    //         require(bHermes.userDelegatedVotes(user) == 0);
    //         require(bHermes.numCheckpoints(delegate) == 2);
    //         require(bHermes.checkpoints(delegate, 0).votes == delegationAmount);
    //         require(bHermes.checkpoints(delegate, 1).votes == 0);
    //     } else {
    //         require(bHermes.userDelegatedVotes(user) == delegationAmount);
    //         require(bHermes.numCheckpoints(delegate) == 1);
    //         require(bHermes.checkpoints(delegate, 0).votes == delegationAmount);
    //     }
    // }

    // /**
    //  * @notice tests the "FlywheelGaugeRewards + ERC20Gauges" functionality of bHermes
    //  *   A single user will allocate weight across 20 gauges.
    //  *   This user will also be hold a portion of the total strategy on each gauge.
    //  *   Lastly, the test will warp part of the way through a cycle.
    //  *
    //  *   The test ensures that all 3 proportions above are accounted appropriately.
    //  */
    // function testbHermesFlywheel(
    //     address user,
    //     address[20] memory gauges,
    //     uint104[20] memory gaugeAmounts,
    //     uint104[20] memory userGaugeBalance,
    //     uint104[20] memory gaugeTotalSupply,
    //     uint112 quantity,
    //     uint32 warp
    // ) public {
    //     hevm.assume(quantity != 0);
    //     bHermes.setMaxGauges(20);

    //     // setup loop summing the gauge amounts
    //     uint112 sum;
    //     {
    //         address[] memory gaugeList = new address[](20);
    //         uint112[] memory amounts = new uint112[](20);
    //         for (uint256 i = 0; i < 20; i++) {
    //             hevm.assume(
    //                 gauges[i] != address(0) // no zero gauge
    //                     && !bHermes.isGauge(gauges[i]) // no same gauge twice
    //                     && gaugeTotalSupply[i] != 0 // no zero supply
    //             );
    //             userGaugeBalance[i] = uint104(bound(userGaugeBalance[i], 1, gaugeTotalSupply[i]));
    //             sum += gaugeAmounts[i];
    //             amounts[i] = gaugeAmounts[i];
    //             gaugeList[i] = gauges[i];

    //             // add gauge and strategy
    //             bHermes.addGauge(gauges[i]);
    //             flywheel.addStrategyForRewards(ERC20(gauges[i]));

    //             // use the booster to virtually set the balance and totalSupply of the user
    //             booster.setUserBoost(ERC20(gauges[i]), user, userGaugeBalance[i]);
    //             booster.setTotalSupplyBoost(ERC20(gauges[i]), gaugeTotalSupply[i]);
    //         }

    //         // deposit the user amount and increment the gauges
    //         deposit(user, sum);
    //         hevm.prank(user);
    //         bHermes.incrementGauges(gaugeList, amounts);
    //     }
    //     hevm.warp(bHermes.getGaugeCycleEnd());

    //     // set the rewards and queue for the rewards cycle
    //     hermes.mint(address(stream), quantity);
    //     stream.setRewardAmount(quantity);
    //     rewards.queueRewardsForCycle();

    //     // warp partially through cycle
    //     hevm.warp(block.timestamp + (warp % bHermes.gaugeCycleLength()));

    //     // assert gauge rewards, flywheel indices, and useer amounts all are as expected
    //     for (uint256 i = 0; i < 20; i++) {
    //         (, uint112 queued,) = rewards.gaugeQueuedRewards(ERC20(gauges[i]));
    //         assertEq(bHermes.calculateGaugeAllocation(gauges[i], quantity), queued);
    //         uint256 accruedBefore = flywheel.rewardsAccrued(user);
    //         flywheel.accrue(ERC20(gauges[i]), user);
    //         uint256 diff = (
    //             ((uint256(queued) * (warp % bHermes.gaugeCycleLength())) / bHermes.gaugeCycleLength()) * flywheel.ONE()
    //         ) / gaugeTotalSupply[i];
    //         (uint224 index,) = flywheel.strategyState(ERC20(gauges[i]));
    //         assertEq(index, flywheel.ONE() + diff);
    //         assertEq(flywheel.rewardsAccrued(user), accruedBefore + ((diff * userGaugeBalance[i]) / flywheel.ONE()));
    //     }
    // }

    // /**
    //  * @notice test an array of 20 users allocating different amounts to different gauges.
    //  *  Includes a forward warp of [0, cycle length) each time to test different conditions
    //  */
    // function testbHermesGauges(
    //     address[20] memory users,
    //     address[20] memory gauges,
    //     uint104[20] memory gaugeAmount,
    //     uint32[20] memory warps,
    //     uint128 quantity
    // ) public {
    //     bHermes.setMaxGauges(20);
    //     for (uint256 i = 0; i < 20; i++) {
    //         hevm.assume(!(bHermes.isGauge(gauges[i]) || gauges[i] == address(0)));
    //         uint32 warp = warps[i] % bHermes.gaugeCycleLength();
    //         address user = users[i];
    //         address gauge = gauges[i];
    //         bHermes.addGauge(gauge);
    //         uint256 shares = deposit(users[i], gaugeAmount[i]);

    //         uint256 userWeightBefore = bHermes.getUserWeight(user);
    //         uint256 gaugeWeightBefore = bHermes.getGaugeWeight(gauge);
    //         uint256 totalWeightBefore = bHermes.totalWeight();

    //         uint32 cycleEnd = bHermes.getGaugeCycleEnd();

    //         hevm.startPrank(user);
    //         // Test the two major cases of successfull increment and failed increment
    //         if (cycleEnd - bHermes.incrementFreezeWindow() <= block.timestamp) {
    //             hevm.expectRevert(abi.encodeWithSignature("IncrementFreezeError()"));
    //             bHermes.incrementGauge(gauge, uint112(shares));
    //             require(bHermes.getUserWeight(user) == userWeightBefore);
    //             require(bHermes.getGaugeWeight(gauge) == gaugeWeightBefore);
    //             require(bHermes.totalWeight() == totalWeightBefore);

    //             hevm.warp(block.timestamp + warp);
    //         } else {
    //             bHermes.incrementGauge(gauge, uint112(shares));
    //             require(
    //                 bHermes.storedTotalWeight() == 0
    //                     || bHermes.calculateGaugeAllocation(gauge, quantity)
    //                         == (gaugeWeightBefore * quantity) / bHermes.storedTotalWeight()
    //             );
    //             require(bHermes.getUserWeight(user) == userWeightBefore + shares);
    //             require(bHermes.getGaugeWeight(gauge) == gaugeWeightBefore + shares);
    //             require(bHermes.totalWeight() == totalWeightBefore + shares);

    //             hevm.warp(block.timestamp + warp);
    //             if (block.timestamp >= cycleEnd) {
    //                 require(bHermes.getStoredGaugeWeight(gauge) == gaugeWeightBefore + shares);
    //                 require(
    //                     bHermes.calculateGaugeAllocation(gauge, quantity)
    //                         == ((gaugeWeightBefore + shares) * quantity) / bHermes.storedTotalWeight()
    //                 );
    //             }
    //         }
    //         hevm.stopPrank();
    //     }
    // }

    function testMint() public {
        uint256 amount = 100 ether;
        hermes.mint(address(this), 100 ether);
        hermes.approve(address(bHermes), amount);
        bHermes.mint(amount, address(1));
        assertEq(bHermes.balanceOf(address(1)), amount);
        assertEq(bHermes.gaugeWeight().balanceOf(address(bHermes)), amount);
        assertEq(bHermes.gaugeBoost().balanceOf(address(bHermes)), amount);
        assertEq(bHermes.governance().balanceOf(address(bHermes)), amount);
    }

    function testTransfer() public {
        testMint();
        hevm.prank(address(1));
        bHermes.transfer(address(2), 100 ether);
        assertEq(bHermes.balanceOf(address(1)), 0);
        assertEq(bHermes.balanceOf(address(2)), 100 ether);

        assertEq(bHermes.gaugeWeight().balanceOf(address(1)), 0);
        assertEq(bHermes.gaugeWeight().balanceOf(address(bHermes)), 100 ether);

        assertEq(bHermes.gaugeBoost().balanceOf(address(1)), 0);
        assertEq(bHermes.gaugeBoost().balanceOf(address(bHermes)), 100 ether);

        assertEq(bHermes.governance().balanceOf(address(1)), 0);
        assertEq(bHermes.governance().balanceOf(address(bHermes)), 100 ether);
    }

    function testTransferFailed() public {
        testMint();
        hevm.prank(address(1));
        bHermes.claimWeight(1);
        hevm.expectRevert(abi.encodeWithSignature("InsufficientUnderlying()"));
        bHermes.transfer(address(2), 100 ether);
    }

    /**
     * @notice test the bHermes rewards accrual over a cycle
     */
    function testbHermesRewards(
        address user1,
        address user2,
        uint128 user1Amount,
        uint128 user2Amount,
        uint128 rewardAmount,
        uint32 rewardTimestamp,
        uint32 user2DepositTimestamp
    ) public {
        rewardTimestamp = rewardTimestamp % bHermes.gaugeWeight().gaugeCycleLength();
        user2DepositTimestamp = user2DepositTimestamp % bHermes.gaugeWeight().gaugeCycleLength();
        hevm.assume(
            user1Amount != 0 && user2Amount != 0 && user2Amount != type(uint128).max && rewardAmount != 0
                && rewardTimestamp <= user2DepositTimestamp && user1Amount < type(uint128).max / user2Amount
        );

        hermes.mint(user1, user1Amount);
        hermes.mint(user2, user2Amount);

        hevm.startPrank(user1);
        hermes.approve(address(bHermes), user1Amount);
        bHermes.deposit(user1Amount, user1);
        hevm.stopPrank();

        // require(bHermes.previewRedeem(user1Amount) == user1Amount);
        require(bHermes.balanceOf(user1) == user1Amount);

        hevm.warp(rewardTimestamp);
        hermes.mint(address(bHermes), rewardAmount);
        // bHermes.syncRewards();

        // require(bHermes.previewRedeem(user1Amount) == user1Amount);

        hevm.warp(user2DepositTimestamp);

        hevm.startPrank(user2);
        hermes.approve(address(bHermes), user2Amount);
        if (bHermes.convertToShares(user2Amount) == 0) {
            hevm.expectRevert(bytes("ZERO_SHARES"));
            bHermes.deposit(user2Amount, user2);
            return;
        }
        uint256 shares2 = bHermes.deposit(user2Amount, user2);
        hevm.stopPrank();

        // assertApproxEq(
        //     bHermes.previewRedeem(shares2),
        //     user2Amount,
        //     (bHermes.totalAssets() / bHermes.totalSupply()) + 1
        // );

        uint256 effectiveCycleLength = bHermes.gaugeWeight().gaugeCycleLength() - rewardTimestamp;
        uint256 beforeUser2Time = user2DepositTimestamp - rewardTimestamp;
        uint256 beforeUser2Rewards = (rewardAmount * beforeUser2Time) / effectiveCycleLength;

        // assertApproxEq(
        //     bHermes.previewRedeem(user1Amount),
        //     user1Amount + beforeUser2Rewards,
        //     (bHermes.totalAssets() / bHermes.totalSupply()) + 1
        // );

        hevm.warp(bHermes.gaugeWeight().getGaugeCycleEnd());

        uint256 remainingRewards = rewardAmount - beforeUser2Rewards;
        uint256 user1Rewards = (remainingRewards * user1Amount) / (user1Amount + shares2);
        uint256 user2Rewards = (remainingRewards * shares2) / (user1Amount + shares2);

        hevm.assume(shares2 < type(uint128).max / bHermes.totalAssets());
        // assertApproxEq(
        //     bHermes.previewRedeem(shares2),
        //     user2Amount + user2Rewards,
        //     (bHermes.totalAssets() / bHermes.totalSupply()) + 1
        // );

        hevm.assume(user1Amount < type(uint128).max / bHermes.totalAssets());
        // assertApproxEq(
        //     bHermes.previewRedeem(user1Amount),
        //     user1Amount + beforeUser2Rewards + user1Rewards,
        //     (bHermes.totalAssets() / bHermes.totalSupply()) + 1
        // );
    }

    function deposit(address user, uint256 mintAmount) internal returns (uint256 shares) {
        hevm.assume(bHermes.previewDeposit(mintAmount) != 0);

        hermes.mint(user, mintAmount);

        hevm.startPrank(user);
        hermes.approve(address(bHermes), mintAmount);
        shares = bHermes.deposit(mintAmount, user);
        hevm.stopPrank();
    }
}
