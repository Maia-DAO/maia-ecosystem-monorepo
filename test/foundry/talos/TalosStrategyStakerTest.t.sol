// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;
pragma abicoder v2;

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { IWETH9 } from "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import { SqrtPriceMath as SqrtPriceMathTest } from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import { UniswapV3Factory, UniswapV3Pool } from "@uniswap/v3-core/contracts/UniswapV3Factory.sol";
import { SwapRouter } from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { NonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import { Ownable } from "solady/auth/Ownable.sol";

import { TalosStrategyStaked, BoostAggregator } from "@talos/TalosStrategyStaked.sol";
import { ITalosBaseStrategy, TalosBaseStrategy } from "@talos/base/TalosBaseStrategy.sol";
import { TalosOptimizer } from "@talos/TalosOptimizer.sol";
import { PoolVariables, PoolActions } from "@talos/libraries/PoolActions.sol";

import { FlywheelCoreInstant, IFlywheelBooster } from "@rewards/FlywheelCoreInstant.sol";
import { FlywheelInstantRewards } from "@rewards/rewards/FlywheelInstantRewards.sol";
import { IFlywheelRewards } from "@rewards/interfaces/IFlywheelRewards.sol";

import { PositionKey } from "../libraries/PositionKey.t.sol";
import { TalosTestor } from "./TalosTestor.t.sol";

import { UniswapV3GaugeFactory } from "@gauges/factories/UniswapV3GaugeFactory.sol";
import { IUniswapV3Factory, IUniswapV3Pool, UniswapV3Staker, IUniswapV3Staker, IncentiveTime, IncentiveId, bHermesBoost } from "@v3-staker/UniswapV3Staker.sol";
import { PoolAddress } from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import { IERC20Minimal } from "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { SafeCastLib } from "solmate/utils/SafeCastLib.sol";

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

import { console2 } from "forge-std/console2.sol";

contract TalosStrategyStakedTest is TalosTestor {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint160;
    using FixedPointMathLib for uint128;
    using SafeCastLib for uint256;
    using SafeCastLib for int256;
    // using NFTDescriptor for NonfungibleTokenPositionDescriptor;
    using PoolVariables for IUniswapV3Pool;
    using PoolActions for IUniswapV3Pool;
    using SafeTransferLib for ERC20;
    using SafeTransferLib for MockERC20;

    // using UnsafeMath for uint256;

    //////////////////////////////////////////////////////////////////
    //                          VARIABLES
    //////////////////////////////////////////////////////////////////

    IUniswapV3Staker uniswapV3Staker;
    UniswapV3Staker uniswapV3StakerContract;

    IUniswapV3Staker.IncentiveKey key;
    bytes32 incentiveId;

    FlywheelCoreInstant flywheel;
    FlywheelInstantRewards rewards;

    BoostAggregator boostAggregator;

    bHermesBoost gaugeBoost;

    // //////////////////////////////////////////////////////////////////
    // //                          SET UP
    // //////////////////////////////////////////////////////////////////

    function setUp() public {
        init();
        // rewardToken.approve(address(uniswapV3Staker), 1e18);
        // key = IUniswapV3Staker.IncentiveKey({
        //     rewardToken: IERC20Minimal(address(token0)),
        //     pool: pool,
        //     startTime: 100,
        //     endTime: 10000,
        //     refundee: address(this)
        // });
        // uniswapV3Staker.createIncentive(key, 1e25);
        // incentiveId = IncentiveId.compute(key);

        // (uint256 totalRewardUnclaimed, uint160 totalSecondsClaimedX128, uint96 numberOfStakes) = uniswapV3Staker.incentives(incentiveId);
    }

    function initializeTalos() internal override {
        gaugeBoost = new bHermesBoost(address(this));
        gaugeBoost.addGauge(address(this));

        uniswapV3StakerContract = new UniswapV3Staker(
            uniswapV3Factory,
            nonfungiblePositionManager,
            UniswapV3GaugeFactory(address(this)),
            gaugeBoost,
            31536000,
            address(this),
            address(rewardToken)
        );
        uniswapV3Staker = IUniswapV3Staker(address(uniswapV3StakerContract));

        hevm.mockCall(
            address(this),
            abi.encodeWithSignature("strategyGauges(address)", pool),
            abi.encode(address(this))
        );
        hevm.mockCall(
            address(this),
            abi.encodeWithSignature("multiRewardsDepot()"),
            abi.encode(address(this))
        );
        hevm.mockCall(address(this), abi.encodeWithSignature("minimumWidth()"), abi.encode(10));
        uniswapV3StakerContract.updateGauges(pool);

        uniswapV3StakerContract.gauges(pool);
        uniswapV3StakerContract.gaugePool(address(this));

        rewardToken.approve(address(uniswapV3Staker), type(uint256).max);
        rewardToken.mint(address(this), 6e25);

        hevm.warp(10000000);
        key = IUniswapV3Staker.IncentiveKey({
            startTime: IncentiveTime.computeEnd(block.timestamp),
            pool: pool
        });
        uniswapV3StakerContract.createIncentiveFromGauge(1e25);
        uniswapV3StakerContract.createIncentive(
            IUniswapV3Staker.IncentiveKey({
                startTime: IncentiveTime.computeEnd(block.timestamp + 1 weeks),
                pool: pool
            }),
            1e25
        );
        uniswapV3StakerContract.createIncentive(
            IUniswapV3Staker.IncentiveKey({
                startTime: IncentiveTime.computeEnd(block.timestamp + 2 weeks),
                pool: pool
            }),
            1e25
        );
        uniswapV3StakerContract.createIncentive(
            IUniswapV3Staker.IncentiveKey({
                startTime: IncentiveTime.computeEnd(block.timestamp + 3 weeks),
                pool: pool
            }),
            1e25
        );
        uniswapV3StakerContract.createIncentive(
            IUniswapV3Staker.IncentiveKey({
                startTime: IncentiveTime.computeEnd(block.timestamp + 4 weeks),
                pool: pool
            }),
            1e25
        );
        uniswapV3StakerContract.createIncentive(
            IUniswapV3Staker.IncentiveKey({
                startTime: IncentiveTime.computeEnd(block.timestamp + 5 weeks),
                pool: pool
            }),
            1e25
        );

        hevm.warp(IncentiveTime.computeEnd(block.timestamp));

        flywheel = new FlywheelCoreInstant(
            address(rewardToken),
            IFlywheelRewards(address(0)),
            IFlywheelBooster(address(0)),
            address(this)
        );
        rewards = new FlywheelInstantRewards(flywheel);
        flywheel.setFlywheelRewards(address(rewards));

        boostAggregator = new BoostAggregator(uniswapV3StakerContract, rewardToken, address(this));

        hevm.mockCall(
            address(this),
            abi.encodeWithSignature("attachUser(address)", address(boostAggregator)),
            abi.encode("")
        );
        hevm.mockCall(
            address(this),
            abi.encodeWithSignature("detachUser(address)", address(boostAggregator)),
            abi.encode("")
        );

        talosBaseStrategy = new TalosStrategyStaked(
            pool,
            strategyOptimizer,
            boostAggregator,
            address(this),
            flywheel,
            address(this)
        );

        flywheel.addStrategyForRewards(talosBaseStrategy);

        boostAggregator.addWhitelistedAddress(address(talosBaseStrategy));
    }

    //////////////////////////////////////////////////////////////////
    //                      TESTS DEPOSIT
    //////////////////////////////////////////////////////////////////

    function testDepositSameAmounts(uint256 amount0Desired)
        public
        returns (
            uint256 shares,
            uint256 amount0,
            uint256 amount1
        )
    {
        hevm.assume(amount0Desired > 1e10 && amount0Desired < 1e30);

        return deposit(amount0Desired, amount0Desired, user1);
    }

    function testDepositDifferentAmountsLess(uint256 amount0Desired, uint256 amount1Deviation)
        public
        returns (
            uint256 shares,
            uint256 amount0,
            uint256 amount1
        )
    {
        hevm.assume(amount0Desired > 1e10 && amount0Desired < 1e30);
        hevm.assume(amount1Deviation < 1e5 && amount1Deviation > 0);

        uint256 amount1Desired = amount0Desired - amount1Deviation;

        return deposit(amount0Desired, amount1Desired, user1);
    }

    function testDepositDifferentAmountsMore(uint256 amount0Desired, uint256 amount1Deviation)
        public
        returns (
            uint256 shares,
            uint256 amount0,
            uint256 amount1
        )
    {
        hevm.assume(amount0Desired > 1e10 && amount0Desired < 1e30);
        hevm.assume(amount1Deviation < 1e5 && amount1Deviation > 0);

        uint256 amount1Desired = amount0Desired + amount1Deviation;

        return deposit(amount0Desired, amount1Desired, user1);
    }

    function testDepositZero(address to) public {
        hevm.assume(to != address(0));

        hevm.prank(to);
        hevm.expectRevert(abi.encodePacked(""));
        talosBaseStrategy.deposit(0, 0, to);
    }

    // function testDepositPaused(uint256 amount0Desired, address to) public {
    //     hevm.assume(to != address(0));
    //     hevm.assume(amount0Desired > 1e10 && amount0Desired < 1e30);

    //     token0.mint(to, amount0Desired);
    //     token1.mint(to, amount0Desired);

    //     hevm.prank(to);
    //     token0.approve(address(talosBaseStrategy), amount0Desired);
    //     hevm.prank(to);
    //     token1.approve(address(talosBaseStrategy), amount0Desired);

    //     talosBaseStrategy.pause();

    //     hevm.prank(to);
    //     hevm.expectRevert(abi.encodePacked("P"));
    //     talosBaseStrategy.deposit(amount0Desired, amount0Desired, to);
    // }

    function testDepositSameAmountsMultipleTimes(
        uint256 amount0Desired,
        address toFirst,
        address toSecond
    )
        public
        returns (
            uint256 shares,
            uint256 amount0,
            uint256 amount1
        )
    {
        hevm.assume(toFirst != address(0) && toSecond != address(0));
        hevm.assume(amount0Desired > 1e3 && amount0Desired < 1e30);

        (uint256 sharesFirst, uint256 amount0First, uint256 amount1First) = deposit(
            amount0Desired,
            amount0Desired,
            toFirst
        );

        (uint256 sharesSecond, uint256 amount0Second, uint256 amount1Second) = deposit(
            amount0Desired,
            amount0Desired,
            toSecond
        );
        assertEq(sharesFirst, sharesSecond);
        assertEq(amount0First, amount0Second);
        assertEq(amount1First, amount1Second);

        // require(sharesFirst == sharesSecond);
        // require(amount0First == amount0Second);
        // require(amount1First == amount1Second);

        return (
            sharesFirst + sharesSecond,
            amount0First + amount0Second,
            amount1First + amount1Second
        );
    }

    // //////////////////////////////////////////////////////////////////
    // //                      TESTS WITHDRAW
    // //////////////////////////////////////////////////////////////////

    function testWithdraw(uint256 amount0Desired, uint8 shareRatio)
        public
        returns (uint256 amount0, uint256 amount1)
    {
        hevm.assume(shareRatio > 0);
        hevm.assume(amount0Desired > 1e18 && amount0Desired < 1e30);

        (uint256 totalShares, , ) = deposit(amount0Desired, amount0Desired, user1);

        uint256 sharesToWithdraw = (totalShares * shareRatio) / type(uint8).max;

        return withdraw(sharesToWithdraw, user1);
    }

    function testWithdrawAll(uint256 amount0Desired)
        public
        returns (uint256 amount0, uint256 amount1)
    {
        hevm.assume(amount0Desired > 1e18 && amount0Desired < 1e30);

        (uint256 totalShares, , ) = deposit(amount0Desired, amount0Desired, user1);

        return withdraw(totalShares, user1);
    }

    function testWithdrawZero(uint256 amount0Desired) public {
        hevm.assume(amount0Desired > 1e18 && amount0Desired < 1e30);

        deposit(amount0Desired, amount0Desired, user1);

        hevm.prank(user1);
        hevm.expectRevert(ITalosBaseStrategy.RedeemingZeroShares.selector);
        talosBaseStrategy.redeem(0, 0, 0, user1, user1);
    }

    // function testWithdrawPaused(uint256 amount0Desired) public {
    //     hevm.assume(amount0Desired > 1e18 && amount0Desired < 1e30);

    //     (uint256 totalShares,,) = deposit(amount0Desired, amount0Desired, user1);

    //     talosBaseStrategy.pause();

    //     hevm.prank(user1);
    //     hevm.expectRevert(abi.encodePacked("P"));
    //     talosBaseStrategy.withdraw(totalShares, user1);
    // }

    // //////////////////////////////////////////////////////////////////
    // //                      TESTS RERANGE
    // //////////////////////////////////////////////////////////////////

    function testRerange() public {
        uint256 amount0Desired = 100000;

        deposit(amount0Desired, amount0Desired, user1);
        deposit(amount0Desired, amount0Desired, user2);

        hevm.expectEmit(true, true, true, true);
        emit Rerange(-7980, -6000, 188832, 105900); // From Popsicle

        talosBaseStrategy.rerange();
    }

    function testRerangeFailPermissions(address to) public {
        hevm.assume(to != address(0));
        uint256 amount0Desired = 100000;

        deposit(amount0Desired, amount0Desired, user1);
        deposit(amount0Desired, amount0Desired, user2);

        hevm.prank(to);
        hevm.expectRevert(ITalosBaseStrategy.NotStrategyManager.selector);
        talosBaseStrategy.rerange();
    }

    // //////////////////////////////////////////////////////////////////
    // //                      TESTS REBALANCE
    // //////////////////////////////////////////////////////////////////

    function testRebalance() public {
        uint256 amount0Desired = 100000;

        TalosStrategyStaked secondTalosStrategyStaked = new TalosStrategyStaked(
            pool,
            strategyOptimizer,
            boostAggregator,
            address(this),
            flywheel,
            address(this)
        );

        initTalosStrategy(secondTalosStrategyStaked);

        deposit(amount0Desired, amount0Desired, user1);
        deposit(amount0Desired, amount0Desired, user2);

        _deposit(amount0Desired, amount0Desired, user1, secondTalosStrategyStaked);
        _deposit(amount0Desired, amount0Desired, user2, secondTalosStrategyStaked);

        poolDisbalancer(30);

        hevm.expectEmit(true, true, true, true);
        // Values from Popsicle hardhat test: emit Rerange(-12360, -5280, 59402, 179537);
        emit Rerange(-12480, -5280, 58227, 178916); // Fees are collected by UniswapV3Staker, so deposits slightly less

        talosBaseStrategy.rebalance();
    }

    function testRebalanceFailPermissions(address to) public {
        hevm.assume(to != address(this));

        hevm.prank(to);
        hevm.expectRevert(ITalosBaseStrategy.NotStrategyManager.selector);
        talosBaseStrategy.rebalance();
    }

    //////////////////////////////////////////////////////////////////
    //                      TESTS POSITION
    //////////////////////////////////////////////////////////////////

    // function testPosition() public view {
    //     uint256 tokenId = talosBaseStrategy.tokenId();

    //     bytes32 positionKey = PositionKey.compute(address(talosBaseStrategy), tickLower, tickUpper);
    //     (
    //         uint128 liquidityPredicted,
    //         uint256 feeGrowthInside0LastX128Predicted,
    //         uint256 feeGrowthInside1LastX128Predicted,
    //         uint128 tokensOwed0Predicted,
    //         uint128 tokensOwed1Predicted
    //     ) = pool.positions(positionKey);

    //     (
    //         uint128 liquidity,
    //         uint256 feeGrowthInside0LastX128,
    //         uint256 feeGrowthInside1LastX128,
    //         uint128 tokensOwed0,
    //         uint128 tokensOwed1
    //     ) = talosBaseStrategy.position();

    //     require(liquidity == liquidityPredicted, "Incorrect liquidity");
    //     require(feeGrowthInside0LastX128 == feeGrowthInside0LastX128Predicted, "Incorrect feeGrowthInside0LastX128");
    //     require(feeGrowthInside1LastX128 == feeGrowthInside1LastX128Predicted, "Incorrect feeGrowthInside1LastX128");
    //     require(tokensOwed0 == tokensOwed0Predicted, "Incorrect tokensOwed0");
    //     require(tokensOwed1 == tokensOwed1Predicted, "Incorrect liquidity");
    // }

    //////////////////////////////////////////////////////////////////
    //                TESTS UNISWAP V3 SWAP CALLBACK
    //////////////////////////////////////////////////////////////////

    function testuniswapV3SwapCallback() public {
        hevm.expectRevert(ITalosBaseStrategy.CallerIsNotPool.selector);
        talosBaseStrategy.uniswapV3SwapCallback(0, 0, "0x");
    }

    //////////////////////////////////////////////////////////////////
    //                TESTS COLLECT PROTOCOL FEES
    //////////////////////////////////////////////////////////////////

    function testCollectProtocolFeesZero() public {
        hevm.expectEmit(true, true, true, true);
        emit RewardPaid(address(this), 0, 0);

        talosBaseStrategy.collectProtocolFees(0, 0);
    }

    function testCollectProtocolFeesOnlyGovernance(address to) public {
        hevm.assume(to != address(this));

        hevm.prank(to);
        hevm.expectRevert(Ownable.Unauthorized.selector);
        talosBaseStrategy.collectProtocolFees(0, 0);
    }

    function testCollectProtocolFeesCheckAmount0() public {
        hevm.expectRevert(ITalosBaseStrategy.Token0AmountIsBiggerThanProtocolFees.selector);
        talosBaseStrategy.collectProtocolFees(1, 0);
    }

    function testCollectProtocolFeesCheckAmount1() public {
        hevm.expectRevert(ITalosBaseStrategy.Token1AmountIsBiggerThanProtocolFees.selector);
        talosBaseStrategy.collectProtocolFees(0, 1);
    }
}
