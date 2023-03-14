// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity >=0.8.0;

// import {TalosBaseStrategy, ERC20} from "../../../src/talos-v3-optimizer/base/TalosBaseStrategy.sol";
// import {IOptimizerStrategy} from "../../../src/talos-v3-optimizer/interfaces/IOptimizerStrategy.sol";

// import {IUniswapV3Staker, IERC20Minimal} from "../../../src/uni-v3-staker/interfaces/IUniswapV3Staker.sol";

// import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
// import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

// contract MockERC4626 is TalosBaseStrategy {
//     uint256 public beforeWithdrawHookCalledCounter = 0;
//     uint256 public afterDepositHookCalledCounter = 0;

//     constructor(
//         IUniswapV3Pool _pool,
//         IOptimizerStrategy _strategy,
//         INonfungiblePositionManager _nonfungiblePositionManager,
//         string memory _name,
//         string memory _symbol
//     ) TalosBaseStrategy(_pool, _strategy, _nonfungiblePositionManager, _name, _symbol) {}

//     function beforeWithdraw(uint256) internal override {
//         beforeWithdrawHookCalledCounter++;
//     }

//     function afterWithdraw(uint256) internal override {
//         beforeWithdrawHookCalledCounter++;
//     }

//     function beforeDeposit(uint256) internal override {
//         afterDepositHookCalledCounter++;
//     }

//     function afterDeposit(uint256) internal override {
//         afterDepositHookCalledCounter++;
//     }
// }
