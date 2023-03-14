// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import { FlywheelCoreInstant, IFlywheelBooster, IFlywheelRewards } from "@rewards/FlywheelCoreInstant.sol";
import { FlywheelInstantRewards } from "@rewards/rewards/FlywheelInstantRewards.sol";

import { TalosBaseStrategy } from "../base/TalosBaseStrategy.sol";
import { BoostAggregator, BoostAggregatorFactory } from "./BoostAggregatorFactory.sol";
import { OptimizerFactory } from "./OptimizerFactory.sol";
import { TalosBaseStrategyFactory } from "./TalosBaseStrategyFactory.sol";
import { TalosStrategyStaked } from "../TalosStrategyStaked.sol";

import { ITalosOptimizer } from "../interfaces/ITalosOptimizer.sol";
import { ITalosStrategyStakedFactory } from "../interfaces/ITalosStrategyStakedFactory.sol";

library DeployStaked {
    function createTalosV3Strategy(
        IUniswapV3Pool pool,
        ITalosOptimizer optimizer,
        BoostAggregator boostAggregator,
        address strategyManager,
        FlywheelCoreInstant flywheel,
        address owner
    ) public returns (TalosBaseStrategy) {
        return
            new TalosStrategyStaked(
                pool,
                optimizer,
                boostAggregator,
                strategyManager,
                flywheel,
                owner
            );
    }
}

/// @title Talos Strategy Staked Factory
contract TalosStrategyStakedFactory is TalosBaseStrategyFactory, ITalosStrategyStakedFactory {
    /*//////////////////////////////////////////////////////////////
                        TALOS STAKED STRATEGY STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosStrategyStakedFactory
    BoostAggregatorFactory public immutable boostAggregatorFactory;

    /// @inheritdoc ITalosStrategyStakedFactory
    FlywheelCoreInstant public immutable flywheel;

    /// @inheritdoc ITalosStrategyStakedFactory
    FlywheelInstantRewards public immutable rewards;

    /**
     * @notice Construct a new Talos Strategy Staked Factory
     * @param _nonfungiblePositionManager The Uniswap V3 NFT Manager
     * @param _optimizerFactory The Optimizer Factory
     * @param _boostAggregatorFactory The Boost Aggregator Factory
     */
    constructor(
        INonfungiblePositionManager _nonfungiblePositionManager,
        OptimizerFactory _optimizerFactory,
        BoostAggregatorFactory _boostAggregatorFactory
    ) TalosBaseStrategyFactory(_nonfungiblePositionManager, _optimizerFactory) {
        boostAggregatorFactory = _boostAggregatorFactory;

        flywheel = new FlywheelCoreInstant(
            address(_boostAggregatorFactory.hermes()),
            IFlywheelRewards(address(0)),
            IFlywheelBooster(address(0)),
            address(this)
        );
        rewards = new FlywheelInstantRewards(flywheel);
        flywheel.setFlywheelRewards(address(rewards));
    }

    /*//////////////////////////////////////////////////////////////
                            CREATE LOGIC
    //////////////////////////////////////////////////////////////*/

    function createTalosV3Strategy(
        IUniswapV3Pool pool,
        ITalosOptimizer optimizer,
        address strategyManager,
        bytes memory data
    ) internal override returns (TalosBaseStrategy strategy) {
        BoostAggregator boostAggregator = abi.decode(data, (BoostAggregator));
        strategy = DeployStaked.createTalosV3Strategy(
            pool,
            optimizer,
            boostAggregator,
            strategyManager,
            flywheel,
            owner()
        );

        flywheel.addStrategyForRewards(strategy);
    }
}
