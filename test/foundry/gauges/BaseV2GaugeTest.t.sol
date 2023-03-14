// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockERC20Gauges} from "../erc-20/mocks/MockERC20Gauges.t.sol";
import {MockRewardsStream} from "../mocks/MockRewardsStream.sol";
import {MockBaseV2Gauge, MultiRewardsDepot} from "./mocks/MockBaseV2Gauge.sol";

import {FlywheelCore, ERC20} from "@rewards/FlywheelCoreStrategy.sol";
import {FlywheelBoosterGaugeWeight, bHermesGauges} from "@rewards/booster/FlywheelBoosterGaugeWeight.sol";
import {FlywheelBribeRewards} from "@rewards/rewards/FlywheelBribeRewards.sol";

import {FlywheelGaugeRewards, IBaseV2Minter} from "@rewards/rewards/FlywheelGaugeRewards.sol";

contract BaseV2GaugeTest is DSTestPlus {
    MockERC20 public strategy;
    MockERC20 public rewardToken;
    MockERC20 public hermes;
    MockERC20Gauges public gaugeToken;
    MockRewardsStream public rewardsStream;
    FlywheelGaugeRewards public rewards;
    MultiRewardsDepot public depot;
    FlywheelBoosterGaugeWeight public booster;

    MockBaseV2Gauge public gauge;

    uint256 constant WEEK = 604800;

    event Distribute(uint256 indexed amount, uint256 indexed epoch);

    event AddedBribeFlywheel(FlywheelCore indexed bribeFlywheel);

    event RemoveBribeFlywheel(FlywheelCore indexed bribeFlywheel);

    function setUp() public {
        hermes = new MockERC20("hermes", "HERMES", 18);

        rewardToken = new MockERC20("test token", "TKN", 18);
        strategy = new MockERC20("test strategy", "TKN", 18);

        rewardsStream = new MockRewardsStream(rewardToken, 100e18);
        rewardToken.mint(address(rewardsStream), 100e25);

        gaugeToken = new MockERC20Gauges(address(this), 604800, 604800 / 7);
        gaugeToken.setMaxGauges(10);

        booster = new FlywheelBoosterGaugeWeight(bHermesGauges(address(gaugeToken)));

        rewards = new FlywheelGaugeRewards(
            address(hermes),
            address(this),
            gaugeToken,
            IBaseV2Minter(address(rewardsStream))
        );

        hevm.mockCall(address(this), abi.encodeWithSignature("bHermesBoostToken()"), abi.encode(address(0)));
        hevm.mockCall(address(0), abi.encodeWithSignature("gaugeBoost()"), abi.encode(gaugeToken));
        hevm.mockCall(address(rewardsStream), abi.encodeWithSignature("updatePeriod()"), abi.encode(0));

        gauge = new MockBaseV2Gauge(rewards, address(strategy), address(this));

        depot = gauge.multiRewardsDepot();

        gaugeToken.addGauge(address(gauge));
    }

    function testGetBribeFlywheelsEmpty() public {
        require(gauge.getBribeFlywheels().length == 0);
    }

    function createFlywheel(MockERC20 token) private returns (FlywheelCore flywheel) {
        flywheel = new FlywheelCore(address(token), FlywheelBribeRewards(address(0)), booster, address(this));
        FlywheelBribeRewards bribeRewards = new FlywheelBribeRewards(flywheel, 1000);
        flywheel.setFlywheelRewards(address(bribeRewards));
        flywheel.addStrategyForRewards(ERC20(address(gauge)));
    }

    function createFlywheel() private returns (FlywheelCore flywheel) {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        flywheel = createFlywheel(token);
    }

    function testAddBribeFlywheels() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        require(gauge.getBribeFlywheels().length == 1);
        require(gauge.getBribeFlywheels()[0] == flywheel);
        require(gauge.isActive(flywheel));
        require(gauge.added(flywheel));
    }

    function testAddBribeFlywheelsAlreadyAdded() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        require(gauge.getBribeFlywheels().length == 1);
        require(gauge.getBribeFlywheels()[0] == flywheel);
        require(gauge.isActive(flywheel));
        require(gauge.added(flywheel));

        hevm.expectRevert(abi.encodeWithSignature("FlywheelAlreadyAdded()"));
        gauge.addBribeFlywheel(flywheel);
    }

    function testAddBribeFlywheelsUnauthorized() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.prank(address(1));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        gauge.addBribeFlywheel(flywheel);
    }

    function testRemoveBribeFlywheels() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        hevm.expectEmit(true, true, true, true);
        emit RemoveBribeFlywheel(flywheel);

        gauge.removeBribeFlywheel(flywheel);

        require(gauge.getBribeFlywheels().length == 1);
        require(gauge.getBribeFlywheels()[0] == flywheel);
        require(!gauge.isActive(flywheel));
        require(gauge.added(flywheel));
    }

    function testRemoveBribeFlywheelsNotActive() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.expectRevert(abi.encodeWithSignature("FlywheelNotActive()"));
        gauge.removeBribeFlywheel(flywheel);
    }

    function testRemoveBribeFlywheelsAlreadyRemoved() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        hevm.expectEmit(true, true, true, true);
        emit RemoveBribeFlywheel(flywheel);

        gauge.removeBribeFlywheel(flywheel);

        hevm.expectRevert(abi.encodeWithSignature("FlywheelNotActive()"));
        gauge.removeBribeFlywheel(flywheel);
    }

    function testRemoveBribeFlywheelsUnauthorized() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.prank(address(1));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        gauge.addBribeFlywheel(flywheel);
    }

    // function testBoostedBalanceOfNoBoost() public {
    //     require(gauge.boostedBalanceOf(address(this), 10e18) == 4e18);
    // }

    // function testBoostedBalanceOfNoBoost(uint256 balance) public {
    //     balance = (balance % type(uint128).max);
    //     require(gauge.boostedBalanceOf(address(this), balance) == (balance * 4) / 10);
    // }

    // function testBoostedBalanceOfMaxBoost() public {
    //     hermes.mint(address(this), 100e18);
    //     hermes.approve(address(gaugeToken), 100e18);
    //     gaugeToken.deposit(100e18, address(this));
    //     gaugeToken.incrementGaugeBoost(address(gauge), 100e18);

    //     hevm.prank(address(strategy));
    //     gauge.attachUser(address(this));

    //     gauge.setTotalSupply(10e18);

    //     require(gauge.boostedBalanceOf(address(this), 10e18) == 10e18);
    // }

    // function testBoostedBalanceOfMaxBoost(uint256 balance) public {
    //     hermes.mint(address(this), 100e18);
    //     hermes.approve(address(gaugeToken), 100e18);
    //     gaugeToken.deposit(100e18, address(this));
    //     gaugeToken.incrementGaugeBoost(address(gauge), 100e18);

    //     hevm.prank(address(strategy));
    //     gauge.attachUser(address(this));

    //     balance = (balance % type(uint128).max);

    //     gauge.setTotalSupply(balance);

    //     require(gauge.boostedBalanceOf(address(this), balance) / 10 == balance / 10);
    // }

    // function testBoostedBalanceOfHalfBoost() public {
    //     hermes.mint(address(this), 100e18);
    //     hermes.approve(address(gaugeToken), 100e18);
    //     gaugeToken.deposit(100e18, address(this));
    //     gaugeToken.incrementGaugeBoost(address(gauge), 50e18);

    //     hevm.prank(address(strategy));
    //     gauge.attachUser(address(this));

    //     gauge.setTotalSupply(10e18);

    //     require(gauge.boostedBalanceOf(address(this), 10e18) == 7e18);
    // }

    // function testBoostedBalanceOfHalfBoost(uint256 balance) public {
    //     hermes.mint(address(this), 100e18);
    //     hermes.approve(address(gaugeToken), 100e18);
    //     gaugeToken.deposit(100e18, address(this));
    //     gaugeToken.incrementGaugeBoost(address(gauge), 50e18);

    //     hevm.prank(address(strategy));
    //     gauge.attachUser(address(this));

    //     balance = (balance % type(uint128).max);

    //     gauge.setTotalSupply(balance);

    //     uint256 _derived = (balance * 4) / 10 + ((50e18 * balance * 6) / 10) / 100e18;

    //     require(
    //         gauge.boostedBalanceOf(address(this), balance) / 100 == (_derived >= balance ? balance : _derived) / 100
    //     );
    // }

    // function testBoostedBalanceOfSomeBoost(uint256 boost) public {
    //     hermes.mint(address(this), 100e18);
    //     hermes.approve(address(gaugeToken), 100e18);
    //     gaugeToken.deposit(100e18, address(this));

    //     boost %= 100e18;
    //     gaugeToken.incrementGaugeBoost(address(gauge), boost);

    //     hevm.prank(address(strategy));
    //     gauge.attachUser(address(this));

    //     gauge.setTotalSupply(10e18);

    //     require(gauge.boostedBalanceOf(address(this), 10e18) / 1000 == (4e18 + (boost * 6e18) / 100e18) / 1000);
    // }

    // function testBoostedBalanceOfSomeBoost(uint256 boost, uint256 balance) public {
    //     hermes.mint(address(this), 100e18);
    //     hermes.approve(address(gaugeToken), 100e18);
    //     gaugeToken.deposit(100e18, address(this));

    //     boost %= 100e18;
    //     gaugeToken.incrementGaugeBoost(address(gauge), boost);

    //     hevm.prank(address(strategy));
    //     gauge.attachUser(address(this));

    //     balance = (balance % type(uint128).max);

    //     gauge.setTotalSupply(balance);

    //     require(
    //         gauge.boostedBalanceOf(address(this), balance) / 1000 ==
    //             ((balance * 4) / 10 + ((boost * balance * 6) / 10) / 100e18) / 1000
    //     );
    // }

    // function testAttachUserFail() public {
    //     hermes.mint(address(this), 100e18);
    //     hermes.approve(address(gaugeToken), 100e18);
    //     gaugeToken.deposit(100e18, address(this));
    //     gaugeToken.incrementGaugeBoost(address(gauge), 50e18);

    //     hevm.prank(address(this));
    //     hevm.expectRevert(abi.encodeWithSignature("StrategyError()"));
    //     gauge.attachUser(address(this));

    //     (uint128 userBoost, uint128 boostTotalSupply) = gauge.userBoost(address(this));

    //     require(userBoost == 0);
    //     require(boostTotalSupply == 0);
    // }

    // function testAttachUser() public {
    //     hermes.mint(address(this), 100e18);
    //     hermes.approve(address(gaugeToken), 100e18);
    //     gaugeToken.deposit(100e18, address(this));
    //     gaugeToken.incrementGaugeBoost(address(gauge), 50e18);

    //     hevm.prank(address(strategy));
    //     gauge.attachUser(address(this));

    //     (uint128 userBoost, uint128 boostTotalSupply) = gauge.userBoost(address(this));

    //     require(userBoost == 50e18);
    //     require(boostTotalSupply == 100e18);
    // }

    // function testAttachUser(uint256 boost) public {
    //     hermes.mint(address(this), 100e18);
    //     hermes.approve(address(gaugeToken), 100e18);
    //     gaugeToken.deposit(100e18, address(this));

    //     boost %= 100e18;
    //     gaugeToken.incrementGaugeBoost(address(gauge), boost);

    //     hevm.prank(address(strategy));
    //     gauge.attachUser(address(this));

    //     (uint128 userBoost, uint128 boostTotalSupply) = gauge.userBoost(address(this));

    //     require(userBoost == boost);
    //     require(boostTotalSupply == 100e18);
    // }

    // function testAttachUser(uint256 boost, uint256 boostTotal) public {
    //     boostTotal %= type(uint128).max;
    //     boostTotal++;

    //     hermes.mint(address(this), boostTotal);
    //     hermes.approve(address(gaugeToken), boostTotal);
    //     gaugeToken.deposit(boostTotal, address(this));

    //     boost %= boostTotal;
    //     gaugeToken.incrementGaugeBoost(address(gauge), boost);

    //     hevm.prank(address(strategy));
    //     gauge.attachUser(address(this));

    //     (uint128 userBoost, uint128 boostTotalSupply) = gauge.userBoost(address(this));

    //     require(userBoost == boost);
    //     require(boostTotalSupply == boostTotal);
    // }

    // function testDetachUserFail() public {
    //     testAttachUser();

    //     hevm.prank(address(this));
    //     hevm.expectRevert(abi.encodeWithSignature("StrategyError()"));
    //     gauge.detachUser(address(this));

    //     (uint128 userBoost, uint128 boostTotalSupply) = gauge.userBoost(address(this));

    //     require(userBoost == 50e18);
    //     require(boostTotalSupply == 100e18);
    // }

    // function testDetachUser() public {
    //     testAttachUser();

    //     hevm.prank(address(strategy));
    //     gauge.detachUser(address(this));

    //     (uint128 userBoost, uint128 boostTotalSupply) = gauge.userBoost(address(this));

    //     require(userBoost == 0);
    //     require(boostTotalSupply == 0);
    // }

    // function testDetachUser(uint256 boost) public {
    //     testAttachUser(boost);

    //     hevm.prank(address(strategy));
    //     gauge.detachUser(address(this));

    //     (uint128 userBoost, uint128 boostTotalSupply) = gauge.userBoost(address(this));

    //     require(userBoost == 0);
    //     require(boostTotalSupply == 0);
    // }

    // function testDetachUser(uint256 boost, uint256 boostTotal) public {
    //     testAttachUser(boost, boostTotal);

    //     hevm.prank(address(strategy));
    //     gauge.detachUser(address(this));

    //     (uint128 userBoost, uint128 boostTotalSupply) = gauge.userBoost(address(this));

    //     require(userBoost == 0);
    //     require(boostTotalSupply == 0);
    // }

    function testNewEpochFail() external {
        uint256 epoch = gauge.epoch();
        gauge.newEpoch();
        assertEq(epoch, gauge.epoch());
    }

    function testNewEpochWorkThenFail() external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.expectEmit(true, true, true, true);
        emit Distribute(0, WEEK);

        gauge.newEpoch();
        uint256 epoch = gauge.epoch();
        gauge.newEpoch();
        assertEq(epoch, gauge.epoch());
    }

    function testNewEpochEmpty() external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.expectEmit(true, true, true, true);
        emit Distribute(0, WEEK);

        gauge.newEpoch();
    }

    function testNewEpoch() external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.mockCall(address(rewards), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(100e18));

        hevm.expectEmit(true, true, true, true);
        emit Distribute(100e18, WEEK);

        gauge.newEpoch();
    }

    function testNewEpoch(uint256 amount) external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.mockCall(address(rewards), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(amount));

        hevm.expectEmit(true, true, true, true);
        emit Distribute(amount, WEEK);

        gauge.newEpoch();
    }

    function testNewEpochTwice(uint256 amount) external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.mockCall(address(rewards), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(amount));

        hevm.expectEmit(true, true, true, true);
        emit Distribute(amount, WEEK);

        gauge.newEpoch();

        hevm.warp(2 * WEEK); // skip to cycle 2

        hevm.expectEmit(true, true, true, true);
        emit Distribute(amount, 2 * WEEK);

        gauge.newEpoch();
    }

    function testNewEpochTwiceSecondHasNothing(uint256 amount) external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.mockCall(address(rewards), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(amount));

        hevm.expectEmit(true, true, true, true);
        emit Distribute(amount, WEEK);

        gauge.newEpoch();

        hevm.warp(2 * WEEK); // skip to cycle 2

        hevm.mockCall(address(rewards), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(0));

        hevm.expectEmit(true, true, true, true);
        emit Distribute(0, 2 * WEEK);

        gauge.newEpoch();
    }

    function testAccrueBribesBeforeAddBribeFlyWheel() external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));

        token.mint(address(depot), 100 ether);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == 0 ether);

        // Note: rewards can still be accrued directly through the flywheel
    }

    function testAccrueBribesBeforeAddBribeFlyWheel(uint256 amount) external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));
        amount %= type(uint128).max;

        token.mint(address(depot), amount);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == 0);

        // Note: rewards can still be accrued directly through the flywheel
    }

    function testAccrueBribes() external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));

        token.mint(address(depot), 100 ether);

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == 100 ether);
    }

    function testAccrueBribes(uint256 amount) external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));
        amount %= type(uint128).max;

        token.mint(address(depot), amount);

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == amount);
    }

    function testAccrueAndClaimBribes() external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));

        token.mint(address(depot), 100 ether);

        hermes.mint(address(this), 100e18);
        hermes.approve(address(gaugeToken), 100e18);
        gaugeToken.mint(address(this), 100e18);
        gaugeToken.setMaxDelegates(1);
        gaugeToken.delegate(address(this));
        gaugeToken.incrementGauge(address(gauge), 100e18);

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == 100 ether);

        flywheel.claimRewards(address(this));

        require(token.balanceOf(address(bribeRewards)) == 0);
        require(token.balanceOf(address(this)) == 100 ether);
    }

    function testAccrueAndClaimBribes(uint256 amount) external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));
        amount %= type(uint128).max;

        token.mint(address(depot), amount);

        hermes.mint(address(this), 100e18);
        hermes.approve(address(gaugeToken), 100e18);
        gaugeToken.mint(address(this), 100e18);
        gaugeToken.setMaxDelegates(1);
        gaugeToken.delegate(address(this));
        gaugeToken.incrementGauge(address(gauge), 100e18);

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == amount);

        flywheel.claimRewards(address(this));

        require(token.balanceOf(address(bribeRewards)) / 100 == 0);
        require(token.balanceOf(address(this)) / 100 == amount / 100);
        require(token.balanceOf(address(bribeRewards)) + token.balanceOf(address(this)) == amount);
    }

    function testAccrueAndClaimBribesTwoCycles() external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        hermes.mint(address(this), 100e18);
        hermes.approve(address(gaugeToken), 100e18);
        gaugeToken.mint(address(this), 100e18);
        gaugeToken.setMaxDelegates(1);
        gaugeToken.delegate(address(this));
        gaugeToken.incrementGauge(address(gauge), 100e18);

        token.mint(address(depot), 100 ether);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == 0);

        hevm.warp(WEEK); // skip to cycle 1

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == 100 ether);

        flywheel.claimRewards(address(this));

        require(token.balanceOf(address(bribeRewards)) == 0);
        require(token.balanceOf(address(this)) == 100 ether);
    }

    function testAccrueAndClaimBribesTwoCycles(uint256 amount) external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));
        amount %= type(uint128).max;

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        hermes.mint(address(this), 100e18);
        hermes.approve(address(gaugeToken), 100e18);
        gaugeToken.mint(address(this), 100e18);
        gaugeToken.setMaxDelegates(1);
        gaugeToken.delegate(address(this));
        gaugeToken.incrementGauge(address(gauge), 100e18);

        token.mint(address(depot), amount);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == 0);

        hevm.warp(WEEK); // skip to cycle 1

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == amount);

        flywheel.claimRewards(address(this));

        require(token.balanceOf(address(bribeRewards)) / 100 == 0);
        require(token.balanceOf(address(this)) / 100 == amount / 100);
        require(token.balanceOf(address(bribeRewards)) + token.balanceOf(address(this)) == amount);
    }
}
