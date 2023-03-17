// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC4626, ERC20 } from "solmate/mixins/ERC4626.sol";

import { UlyssesPool } from "./UlyssesPool.sol";
import { UlyssesFactory } from "./UlyssesFactory.sol";

import { console2 } from "forge-std/console2.sol";

/**
 * source: Figure 4 from https://www.dropbox.com/s/gf3606jedromp61/Ulysses-Solving.The.Bridging-Trilemma.pdf?dl=0
 *         Input: Transaction amount t, destination poolId ID d
 *
 *         # On the source poolId:
 *         1:  if bₛ,𝒹 < t then
 *         2:      Reject the transfer
 *         3:  end if
 *         4:  aₛ ← aₛ + t
 *         5:  bₛ,𝒹 ← bₛ,𝒹 − t
 *         6:  for x != s do
 *         7:      diffₛ,ₓ ← max(0, lpₛ * wₛ,ₓ − (lkbₓ,ₛ + cₛ,ₓ))
 *         8:  end for
 *         9:  Total ← ∑ₓ diffₛ,ₓ
 *         10: for x != s do
 *         11:     diffₛ,ₓ ← min(Total, t) * diffₛ,ₓ / Total
 *         12: end for
 *         13: t′ ← t - min(Total, t)
 *         14: for ∀x do
 *         15:     cₛ,ₓ ← cₛ,ₓ + diffₛ,ₓ + t′ * wₛ,ₓ
 *         16: end for
 *         17: msg = (t, cₛ,𝒹)
 *         18: lkb𝒹,ₛ ← lkb𝒹,ₛ + cₛ,𝒹
 *         19: cₛ,𝒹 ← 0
 *         20: Send msg to poolId d
 *
 *         # On the destination poolId:
 *         21: Receive (t, cₛ,𝒹) from poolIds
 *         22: a𝒹 ← a𝒹 − t
 *         23: b𝒹,ₛ ← b𝒹,ₛ + cₛ,𝒹
 *         24: lkbₛ,𝒹 ← lkbₛ,𝒹 − t
 *
 * ⠀⠀⠀⠀⠀⡂⠀⠀⠀⠁⠀⠀⠀⠀⠀⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣀⡀⠀⠀⠀⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠾⢋⣁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡄⢰⣿⠄
 * ⠀⠀⢰⠀⠀⠂⠔⠀⡂⠐⠀⠠⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⠤⢂⣉⠉⠉⠉⠁⠀⠉⠁⡀⠀⠉⠳⢶⠶⣦⣄⡀⠀⠀⠀⠀⠀⠀⠌⠙⠓⠒⠻⡦⠔⡌⣄⠤⢲⡽⠖⠪⢱⠦⣤
 * ⠀⠀⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠘⠋⣠⣾⣛⣞⡛⢶⣾⣿⣶⣴⣤⣤⣤⣀⣀⢠⠂⠀⠊⡛⢷⣄⡀⠀⠀⠀⠀⠀⠂⣾⣁⢸⠀⠁⠐⢊⣱⣺⡰⠶⣚⡭⠂
 * ⢀⠀⠄⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠄⠀⢠⣤⣴⡟⠇⣶⣠⢭⣿⣿⣿⣿⡌⠙⠻⠿⣿⣿⣿⣶⣄⡀⠀⠈⣯⢻⡷⣄⠀⠄⢀⡆⠠⢀⣤⠀⠀⠀⠀⠛⠐⢓⡁⠤⠐⢁
 * ⡼⠀⠀⢀⠆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠆⠀⠀⣼⣿⣿⣿⣦⣠⠤⢖⣿⣿⣿⣟⣛⣿⡴⣿⣿⣿⣟⢿⣿⣿⣦⣰⠉⠻⢷⡈⢳⡄⢸⠇⢹⡦⢥⢸⠀⡄⠀⠀⠀⠈⠀⠀⢠⠂
 * ⢡⢐⠀⠂⠀⠀⠆⠀⠀⠀⠀⠀⠀⣠⠖⠋⢰⣴⣾⣿⣿⣿⣿⠙⠛⠚⠛⠁⠙⢦⡉⠉⠉⠀⠙⣷⣭⣿⣦⣹⣿⣿⣿⣤⠐⢀⠹⣷⡹⣾⣧⢻⠐⡀⢸⠀⠀⠀⡁⠀⠀⠀⠴⠃⠀
 * ⠂⠀⠀⠀⠈⡘⠀⠀⠀⠀⠀⠀⣰⠏⠀⢰⣾⡿⢋⣽⡿⠟⠉⠀⠀⢴⠀⠙⣆⠀⠳⡄⠀⠀⠀⠈⢿⣆⢹⣿⢿⣿⣿⣿⣆⣂⠀⢿⡇⠘⢿⣿⣷⡅⣼⢸⡇⢸⡇⠀⡀⣰⠁⠀⠀
 * ⠸⠐⠁⢠⠣⠁⠁⠀⠀⢀⣠⣾⡏⡄⣰⣿⣿⣷⣾⠁⠀⠀⠀⠀⠀⢸⡀⠀⠘⣇⠀⠙⣆⠀⠀⠀⠀⢻⣎⠻⣾⣿⣾⣿⣿⣿⠁⣸⣷⣀⠈⢿⣿⠇⡿⢸⡇⢸⠀⠀⣷⠁⠀⠀⠀
 * ⠂⠀⠀⡎⠄⠀⣠⣤⣾⣻⣿⡟⠀⢘⣿⣿⣿⡿⠃⠀⠀⠀⡄⠀⠀⢈⡇⠀⠀⠸⡀⠀⠀⠀⠀⠀⠀⠀⠻⡄⠀⢈⣿⠿⣿⣿⡿⠯⣿⡽⡆⠸⣿⣀⡇⢸⡇⢸⡀⠀⡟⠀⠀⠀⠀
 * ⡈⠀⡸⠼⠐⠌⢡⠹⡍⣷⣿⣁⠰⣾⣿⢿⣿⠁⠀⠀⠀⠀⡇⠀⠀⢸⠁⠀⠀⠀⢷⠀⠀⠀⠀⠀⠀⠀⠀⢷⠀⠈⣿⣿⣿⣿⣿⣛⣿⣿⡇⠀⢻⣻⡇⣼⡇⣹⠊⠀⣧⠀⠀⠀⠀
 * ⠀⢐⡣⢑⣨⠶⠞⠀⠃⣋⣽⣟⡘⣿⣿⣺⡿⠀⠀⠀⠀⠀⠁⠀⠀⠈⠀⠀⠀⠀⠈⡇⠐⡄⠀⠀⠀⠀⠀⠘⡆⡄⠈⠻⢿⣿⣿⣿⣿⣯⣜⠀⠀⡇⢧⣿⡇⣿⡄⢀⣿⠀⠀⠀⠀
 * ⠨⣥⡶⠌⣡⠡⡖⠀⠈⣹⣿⣿⣿⣿⣿⠏⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢳⡀⠀⠀⠀⠀⠀⣇⢷⠀⠀⠀⢼⣿⣿⣍⡟⠻⣷⣄⢻⡈⣿⠁⣿⡇⢸⣿⠀⠀⠀⠀
 * ⠋⠁⠀⠀⠁⠀⢩⡏⢼⣽⣿⣿⣿⣿⢷⡄⡇⠀⠀⠀⠀⠀⠀⡀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣧⠀⠀⠀⠀⠀⢸⠸⡄⠀⠀⢸⣿⣿⣿⣿⣄⠙⣿⣾⡇⠸⡆⣿⠁⢸⣿⣇⠀⠀⠀
 * ⠀⠀⠠⢀⣪⣤⡌⠉⣼⣿⣿⣿⣿⣿⣨⡟⢣⠀⠀⠀⠀⠀⢠⣳⠃⠀⠀⠀⠀⠀⠀⠀⣄⠀⣿⡆⠀⠀⠀⠀⢸⡆⡇⠀⠀⢸⣾⣿⣿⣿⣿⣷⣼⣿⡇⠀⢹⣿⡅⣿⣿⣿⠀⠀⠀
 * ⣤⣵⣾⣿⣿⣿⣿⠂⠝⣿⣿⣿⣿⣿⣿⠀⠈⠀⠀⠀⠀⠀⣼⠋⠀⠀⠀⠀⠀⠀⠀⠀⢿⠀⡿⢣⠀⠀⠀⢀⡼⢻⢿⠀⠀⢸⣿⣿⣿⢿⢹⢿⣿⡅⢹⠀⠀⢿⡆⣿⣿⣿⡆⠀⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣾⣿⣿⣿⣿⣿⣿⣆⠀⡆⠀⠀⠀⣰⠋⠀⣆⠀⠀⠀⠀⠀⠀⠀⢸⣄⣧⣼⣦⡴⠚⢩⠇⠘⢺⣦⡆⢉⣿⣿⣿⣼⣾⡈⢻⣿⣸⡆⠀⠘⡇⣿⣿⣿⡇⠀⠀
 * ⡿⢿⣟⣽⣿⡿⠿⠛⣉⣥⠶⠾⣿⣿⣿⢿⠀⢳⡀⠀⢰⢋⡀⠀⢸⡄⠀⠀⠀⠀⠀⠀⣿⣇⠇⠀⣧⣧⡐⣍⣴⣾⣿⡇⠀⢸⣿⣿⠹⢿⣯⠻⢿⣿⣄⣧⠀⠀⠸⣿⣿⣿⣿⣆⠀
 * ⣿⠿⠟⣋⡡⠔⠚⠋⠁⠀⠀⠀⣧⣿⣿⡇⡆⠘⣧⡄⠀⠀⠉⠛⡓⣿⡎⠀⠀⠀⠀⠀⡿⢿⣄⡀⢹⣶⣿⠟⣻⠿⠚⣿⢀⣾⢾⣿⡀⣿⣿⠂⣺⡇⢻⣿⡆⠀⠀⢻⣿⣿⣿⣿⣆
 * ⢰⠚⠉⠀⡀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣿⣷⡇⠀⢻⣿⣦⣀⢀⡀⢹⣌⣙⣶⠤⢄⣀⠤⠇⠀⠀⠀⠀⠋⠁⠀⠀⠀⠀⢸⣺⡏⡆⢻⣿⣿⣿⠀⣿⣧⢸⣯⢧⠀⠀⠀⢿⣿⣿⣿⣿
 * ⠂⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⠿⣿⣿⣿⣿⣧⠀⢸⣷⡀⠹⣿⡿⣟⠛⠻⣿⣿⣷⣦⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣷⡇⠃⠘⣿⣿⣿⠀⣿⣿⢸⡟⠻⡄⠀⠀⠘⣿⣟⣟⣿
 * ⠀⠀⠀⠀⠀⠀⠀⢠⣾⠟⠁⢰⣿⣿⣿⣿⡟⡇⠀⡿⢻⠶⣄⠻⣄⠑⠶⠦⠶⠚⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠈⣼⡇⠀⠀⢹⣿⡿⢢⣿⣿⣿⣧⢠⢧⠀⠀⠀⠹⣯⣏⠀
 * ⠀⠀⠀⢦⠀⠀⠰⣿⣷⣀⣴⣿⡿⣻⣿⣿⡇⢧⠀⡇⠈⣧⠈⣿⢶⡿⡂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⠀⠀⢠⣾⣿⡇⠀⠠⣿⢿⠀⣼⣿⣿⣿⣿⡎⣿⠀⠀⠀⠀⠹⡥⠀
 * ⠀⠀⠀⣼⣇⠀⠀⠈⠛⢫⣿⣿⢀⣏⣿⣿⡅⢸⣸⡇⠀⣿⡄⢹⠀⠙⣿⣦⠀⠀⠀⠀⠀⠀⠠⣤⡾⢅⡈⠓⠢⡶⠋⢀⡾⠁⢠⣇⣿⣧⣾⣿⣿⣿⣿⣿⣿⣮⣳⡀⠀⠀⠀⠰⠈
 * ⠀⠀⠀⣿⣿⡄⠀⠀⠀⠘⠻⣿⣾⠟⣿⣟⠀⠸⢃⠇⢰⣿⣇⠘⠀⠀⢻⣿⣷⣶⣤⣤⣀⣠⠞⠭⠤⠄⠙⠿⢻⣥⣴⣿⠃⠀⣾⣾⣿⣯⣿⣿⣿⣾⣟⣿⣿⣿⣿⡿⡄⠀⠀⠀⢣
 * ⠀⠀⠀⠻⣿⣿⣆⠀⠀⠀⢀⣼⣟⢠⣿⣿⠀⠀⢸⠀⣼⣿⣿⠆⠀⠀⢸⡟⣿⣿⣿⣿⠟⠁⠀⣀⣤⡖⠂⣴⣿⣯⣿⠋⠀⠐⡿⣹⣾⠋⠗⣯⢿⣿⣿⣿⣿⣿⣿⡇⢳⡀⠀⠀⠀
 * ⠀⠀⡂⢸⣿⣿⣿⣷⡀⢀⣿⣿⣿⣾⡿⣿⠀⠀⡜⢸⣿⣓⣾⣷⠀⠀⢸⣿⣜⣿⣯⡟⠀⠀⠀⣀⣈⠙⢶⣿⣿⣿⠇⠀⢀⣼⣇⣿⡀⢀⣤⣷⣿⣿⣿⣿⣿⣿⣿⡇⠀⠷⡀⠀⠀
 * ⣤⣀⡞⣢⣿⣿⣿⣿⣿⣾⣿⣿⣿⣿⠁⣿⡆⢠⣧⣿⡇⠐⣿⡿⠀⠀⢸⢷⣻⣿⡟⠀⠀⠀⠀⡇⣸⠑⢦⣻⣿⠏⠀⢀⣾⣿⣸⣿⣩⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠙⡣⠀⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠟⠃⣜⣿⣿⣧⣸⣿⠁⠀⠀⣿⣿⣿⡟⠀⠀⠀⠀⢰⣴⡟⠀⢀⡿⠃⠀⣠⠋⣹⡏⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠐⠤⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⣿⣿⣿⡦⣿⡟⠀⠀⣼⣿⣿⣿⠓⢤⣄⣤⣴⣿⣏⣀⣠⢾⠁⠀⡴⢇⣾⣿⢹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⢣
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⡻⠋⠻⠆⠀⠀⣰⣿⣿⣿⣿⣿⠇⠀⣾⣿⣿⡿⡇⠈⠒⠦⠖⢻⡟⠁⣰⠃⠈⠀⡼⢁⣼⣿⡇⣾⢈⣹⣹⣿⣿⣿⣿⣿⣿⣿⣿⣾⣿⣧⠀⠀⠀⠀⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⢟⡵⠁⠀⠀⠀⢠⣲⠟⣿⣿⣿⣿⠏⣠⣾⣿⣿⣧⣰⠁⠀⠀⠀⠀⣾⠹⢾⠁⠀⣧⡾⣡⣾⡟⢻⡇⣿⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⣿⣿⣿⡆⠀⠀⠀⠀
 * ⣿⣿⣿⣿⣿⠿⠋⠀⠞⠀⠀⠀⠀⠀⣿⢏⡾⢃⣼⠟⣡⣾⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⢠⢏⠀⢇⠀⠀⢸⣰⣿⣇⣗⣾⣇⢿⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠀⠀⠀
 * ⢿⣿⠿⠋⣀⣤⠖⠀⠀⠀⠀⠀⠀⣼⣿⢏⣠⣞⣵⣿⣿⣿⣿⣿⣿⣟⣿⠁⠀⠀⠀⠀⣾⠀⠱⣼⡆⠀⢸⠹⣿⡄⣾⣿⣿⣿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠈⢻⣿⡄⠀⠀
 */
contract UlyssesRouter {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    error OutputTooLow();

    error UnrecognizedUlyssesLP();

    mapping(uint256 => UlyssesPool) public pools;

    UlyssesFactory public ulyssesFactory;

    struct Route {
        uint128 from;
        uint128 to;
    }

    constructor(UlyssesFactory _ulyssesFactory) {
        ulyssesFactory = _ulyssesFactory;
    }

    /*//////////////////////////////////////////////////////////////
                        Internal LOGIC
    //////////////////////////////////////////////////////////////*/

    function getUlyssesLP(uint256 id) private returns (UlyssesPool ulysses) {
        ulysses = pools[id];
        if (address(ulysses) == address(0)) {
            ulysses = ulyssesFactory.pools(id);

            if (address(ulysses) == address(0)) revert UnrecognizedUlyssesLP();

            pools[id] = ulysses;
        }
    }

    /*//////////////////////////////////////////////////////////////
                         LIQUIDITY LOGIC
    //////////////////////////////////////////////////////////////*/

    function addLiquidity(
        uint256 amount,
        uint256 minOutput,
        uint256 poolId
    ) external returns (uint256) {
        UlyssesPool ulysses = getUlyssesLP(poolId);

        amount = ulysses.deposit(amount, msg.sender);

        if (amount < minOutput) revert OutputTooLow();
        return amount;
    }

    function removeLiquidity(
        uint256 amount,
        uint256 minOutput,
        uint256 poolId
    ) external returns (uint256) {
        UlyssesPool ulysses = getUlyssesLP(poolId);

        amount = ulysses.withdraw(amount, msg.sender, msg.sender);

        if (amount < minOutput) revert OutputTooLow();
        return amount;
    }

    // TODO: Add/Remove Liquidty + Ulysses Token from/to 1 token
    // TODO: Add/Remove Liquidty + Ulysses Token from/to multiple tokens

    /*//////////////////////////////////////////////////////////////
                            SWAP LOGIC
    //////////////////////////////////////////////////////////////*/

    function swap(
        uint256 amount,
        uint256 minOutput,
        Route[] calldata routes
    ) external returns (uint256) {
        address(getUlyssesLP(routes[0].from).asset()).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        uint256 length = routes.length;

        for (uint256 i = 0; i < length; ) {
            amount = _swap(amount, routes[i].from, routes[i].to);

            unchecked {
                ++i;
            }
        }

        if (amount < minOutput) revert OutputTooLow();

        unchecked {
            --length;
        }

        address(getUlyssesLP(routes[length].to).asset()).safeTransfer(msg.sender, amount);

        return amount;
    }

    function _swap(
        uint256 amount,
        uint256 from,
        uint256 to
    ) private returns (uint256) {
        UlyssesPool ulyssesFrom = getUlyssesLP(from);

        address(ulyssesFrom.asset()).safeApprove(address(ulyssesFrom), amount);
        return ulyssesFrom.swapSource(amount, to);
    }
}
