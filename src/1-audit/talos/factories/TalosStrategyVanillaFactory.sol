// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import { TalosBaseStrategy } from "../base/TalosBaseStrategy.sol";
import { TalosStrategyVanilla } from "../TalosStrategyVanilla.sol";
import { TalosManager } from "../TalosManager.sol";

import { OptimizerFactory } from "./OptimizerFactory.sol";
import { TalosBaseStrategyFactory } from "./TalosBaseStrategyFactory.sol";

import { ITalosOptimizer } from "../interfaces/ITalosOptimizer.sol";

/// @title Deploy Vanilla
/// @notice This library deploys talos vanilla strategies
library DeployVanilla {
    function createTalosV3Vanilla(
        IUniswapV3Pool pool,
        ITalosOptimizer optimizer,
        INonfungiblePositionManager nonfungiblePositionManager,
        address strategyManager,
        address owner
    ) public returns (TalosBaseStrategy) {
        return
            new TalosStrategyVanilla(
                pool,
                optimizer,
                nonfungiblePositionManager,
                strategyManager,
                owner
            );
    }
}

/// @title Talos Strategy Vanilla Factory
contract TalosStrategyVanillaFactory is TalosBaseStrategyFactory {
    /**
     * @notice Construct a new Talos Strategy Vanilla Factory
     * @param _nonfungiblePositionManager The Uniswap V3 NFT Manager
     * @param _optimizerFactory The Optimizer Factory
     */
    constructor(
        INonfungiblePositionManager _nonfungiblePositionManager,
        OptimizerFactory _optimizerFactory
    ) TalosBaseStrategyFactory(_nonfungiblePositionManager, _optimizerFactory) {}

    /*//////////////////////////////////////////////////////////////
                         GAUGE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function responsible for calling to create a new Talos Strategy
    function createTalosV3Strategy(
        IUniswapV3Pool pool,
        ITalosOptimizer optimizer,
        address strategyManager,
        bytes memory
    ) internal override returns (TalosBaseStrategy) {
        return
            DeployVanilla.createTalosV3Vanilla(
                pool,
                optimizer,
                nonfungiblePositionManager,
                strategyManager,
                owner()
            );
    }
}
