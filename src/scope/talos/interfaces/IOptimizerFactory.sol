// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TalosOptimizer } from "../TalosOptimizer.sol";

/**
 * @title Talos Optimizer Factory
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is responsible for creating new Talos Optimizers.
 */
interface IOptimizerFactory {
    /*//////////////////////////////////////////////////////////////
                        OPTIMIZER FACTORY STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice list of all created optimizers
    function optimizers(uint256) external view returns (TalosOptimizer);

    /// @notice mapping of optimizer to its index in the optimizers array
    function optimizerIds(TalosOptimizer) external view returns (uint256);

    /// @notice Returns all optimizers created by the factory.
    function getOptimizers() external view returns (TalosOptimizer[] memory);

    /*//////////////////////////////////////////////////////////////
                            CREATE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new optimizer
    /// @param owner The owner of the optimizer
    function createTalosOptimizer(
        uint32 _twapDuration,
        int24 _maxTwapDeviation,
        int24 _tickRangeMultiplier,
        uint24 _priceImpactPercentage,
        uint256 _maxTotalSupply,
        address owner
    ) external;
}
