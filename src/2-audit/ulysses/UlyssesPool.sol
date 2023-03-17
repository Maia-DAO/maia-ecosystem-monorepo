// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Ownable } from "solady/auth/Ownable.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { UlyssesERC4626, ERC20 } from "@ERC4626/UlyssesERC4626.sol";

import { UlyssesFactory } from "./UlyssesFactory.sol";

import { console2 } from "forge-std/console2.sol";

/**
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄⠀⠀⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡆⠀⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣉⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢇⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀⠈⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡺⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⠃⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠤⠔⠒⢁⣀⣀⣿⢿⣿⡿⠹⣿⣿⣿⣿⣿⠛⣿⣿⣿⣿⣿⣿⣿⣿⡏⠀⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠹⠿⣿⣿⣿⣿⣿⣿⡏⡟⡹⣃⣴⠖⠛⠉⠉⠉⢻⢸⣿⣷⡀⠹⣿⣿⣿⡏⠀⢧⠹⣿⣿⣿⣿⣿⣿⡟⡄⠀
 * ⣿⣿⣿⣿⣿⣿⠏⡏⠀⠉⠙⠂⠙⢿⣿⣿⣿⣿⠇⠀⠙⢹⠃⠀⠀⠀⠀⠀⠀⠨⡿⠘⢷⠀⠈⢿⣿⡇⠀⢸⢠⣿⣿⣿⣿⣿⣿⣿⠀⠀
 * ⣿⣿⣿⣿⣿⣿⡶⠟⠛⠛⠛⠻⣆⠀⠻⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⢀⡀⠀⢸⠃⠀⠈⣧⠀⠀⢻⡇⠀⠸⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀
 * ⣿⣿⣿⣿⣿⣿⠀⠈⠀⠀⠀⠀⠀⠀⠀⠈⠟⠀⠀⠀⠀⠀⠀⠀⠀⠐⠇⠈⠢⡈⠀⠀⠀⣿⡇⠀⠘⡇⠀⢀⠙⢿⣿⣿⡟⠑⠋⠀⠀⠀
 * ⣿⣿⣿⣿⣇⢿⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢦⡀⠀⠁⠢⢰⢻⣇⠀⠀⡇⠀⢸⣄⠀⠹⣿⠀⠀⠀⠀⠀⠀
 * ⣿⣿⣿⣿⣿⣌⠙⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢎⡷⡄⠀⠐⣼⣿⠀⠀⢈⠀⠈⣿⠆⠀⠈⣧⣀⠀⠀⠀⠀
 * ⣿⣿⣿⣿⣿⣿⡦⡀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⢳⡀⠀⠘⣿⡆⠀⢸⠀⠀⢻⠀⠀⡼⢴⣹⡧⣄⡀⠀
 * ⣿⣿⣿⣿⣿⣿⣷⡈⠁⠀⠀⠀⠀⠀⠀⠀⠀⠉⠀⠀⠀⠀⠀⠀⠀⣀⠔⠉⠀⠀⠘⣇⠀⠀⠘⡇⠀⠀⡇⠀⡞⠀⣼⢓⢶⣡⢟⣉⢉⠳
 * ⠻⣿⣿⣿⣿⣿⣿⣿⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡠⠔⠊⠀⠀⠀⠀⠀⣰⡿⠀⠀⠠⠁⠀⢀⠃⢀⡇⣼⡗⣡⢓⣴⢫⡴⠉⡴
 * ⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⡂⠀⠀⠀⠀⠰⠂⠀⠀⠀⠀⠁⠀⠀⠀⠀⠀⠀⢀⡼⠋⠀⠀⠀⠀⠀⠀⠀⠀⠘⣰⠣⡏⣱⢻⣴⢻⣜⠃⢌
 * ⠀⠀⠀⢹⣿⣿⣿⣿⣿⣿⣷⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡴⢿⠀⠀⠀⠀⠀⠀⠀⠀⢀⠄⢠⢻⢻⢚⣱⠻⡤⢳⢜⡢⠦
 * ⠀⠀⠀⠀⠉⠻⢯⡙⠿⣿⣿⣿⣿⣶⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⠈⢢⠀⠀⠀⠀⠀⠀⡠⠃⣠⠃⢸⡼⢏⡼⣩⢾⡹⢞⡰⢮
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢧⠹⣿⡿⡏⠛⣿⣦⣄⡀⠀⠀⠀⣨⠞⠁⠀⠁⠀⠀⠑⢄⡀⠀⠀⠎⢀⠔⠁⠀⢸⡗⢊⣲⡭⠞⣽⠣⡥⢪
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⡇⠃⡰⠋⠀⠉⠛⠷⢶⣾⠏⠀⠀⠀⠀⠀⠀⠀⠀⠈⠒⢠⡴⠃⠀⠀⠀⢸⡝⣫⢮⡹⢯⢼⣫⠡⠆
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⠂⡼⠁⠀⠀⠀⠀⠀⢠⡏⡈⠂⠄⣀⠀⠀⠀⠀⠀⢀⡴⠋⠀⠀⠀⠀⠀⣿⣞⣱⣚⢮⣙⢮⡡⠆⡚
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣷⣦⣀⠀⠀⠀⠀⢸⠃⠀⠁⠐⠂⠀⠀⠁⢉⠿⣿⣦⡀⠀⠀⠀⠀⢠⡿⣏⢲⣸⢬⣊⢾⡱⢽⠰
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⢻⣷⣦⣀⠀⣸⠀⠀⠀⠀⠀⠀⠀⣴⢿⠀⠘⣿⣿⣦⠀⠀⠀⡘⡷⡊⠱⣘⠶⢉⢎⠱⠄⠁
 *
 *  Input: Transaction amount t, destination chain ID d
 *
 *  # On the source LP:
 *  1: aₛ ← aₛ + t
 *  2: bₛ,𝒹 ← bₛ,𝒹 − t
 *  3: for x != s do
 *  4:     diffₛ,ₓ ← max(0, lpₛ * wₛ,ₓ − lkbₓ,ₛ))
 *  5: end for
 *  6: Total ← ∑ₓ diffₛ,ₓ
 *  7: for x != s do
 *  8:     diffₛ,ₓ ← min(Total, t) * diffₛ,ₓ / Total
 *  9: end for
 *  10: t′ ← t - min(Total, t)
 *  11: for ∀x do
 *  12:     bₛ,ₓ ← bₛ,ₓ + diffₛ,ₓ + t′ * wₛ,ₓ
 *  13: end for
 *  14: msg = (t)
 *  15: Send msg to chain d
 *
 *  # On the destination LP:
 *  16: Receive (t) from a source LP
 *  17: if bₛ,𝒹 < t then
 *  18:     Reject the transfer
 *  19: end if
 *  20: a𝒹 ← a𝒹 − t
 *  21: bₛ,𝒹 ← bₛ,𝒹 − t
 *  Adapted from: Figure 4 from https://www.dropbox.com/s/gf3606jedromp61/Ulysses-Solving.The.Bridging-Trilemma.pdf?dl=0
 * @dev NOTE: Can't remove a destination, only add new ones
 */
contract UlyssesPool is UlyssesERC4626, Ownable {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint128;
    using SafeCastLib for uint256;

    /// @notice Throw when trying to re-add LP
    error AlreadyAddedLP();

    /// @notice Throw when trying to add a destination that is not a Ulysses LP
    error NotUlyssesLP();

    /// @notice Throw when fee would overflow
    error FeeError();

    /// @notice Throw when input amount is too small
    error AmountTooSmall();

    /// @notice Throw when weight is 0 or exceeds MAX_TOTAL_WEIGHT
    error InvalidWeight();

    /// @notice Throw when setting an invalid fee
    error InvalidFee();

    /// @notice Throw when weight is 0 or exceeds MAX_TOTAL_WEIGHT
    error TooManyDestinations();

    struct ChainState {
        uint128 bandwidth;
        uint128 targetBandwidth;
        uint88 rebalancingFee;
        uint8 weight;
        UlyssesPool destination;
    }

    struct Fees {
        uint64 lambda1;
        uint64 lambda2;
        uint64 sigma1;
        uint64 sigma2;
    }

    UlyssesFactory public immutable factory;

    /// @notice ID of this Ulysses LP
    uint256 public immutable id;

    /// @notice List of all added LPs
    ChainState[] public chainStateList;

    /// @notice destinations[destinationId] => chainStateList index
    mapping(uint256 => uint256) public destinations;

    /// @notice destinationIds[address] => destinationId
    mapping(address => uint256) public destinationIds;

    /// @notice Sum of all weights
    uint256 public totalWeights;

    /// @notice The maximum sum of all weights
    uint256 private constant MAX_TOTAL_WEIGHT = 1e4;

    /// @notice The maximum destinations that can be added
    uint256 private constant MAX_DESTINATIONS = 15;

    /// @notice The maximum protocol fee that can be set (1%)
    uint256 private constant MAX_PROTOCOL_FEE = 1e16;

    /// @notice The maximum lambda1 that can be set (10%)
    uint256 private constant MAX_LAMBDA1 = 1e17;

    /// @notice The minimum sigma2 that can be set (1%)
    uint256 private constant MIN_SIGMA2 = 1e16;

    /*//////////////////////////////////////////////////////////////
                            FEE PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /// @notice The divisioner for fee calculations
    uint256 private constant DIVISIONER = 1 ether;

    uint192 public claimable;

    uint64 public protocolFee = 1e14;

    /// @notice The current rebalancing fees
    Fees public fees = Fees({ lambda1: 40e14, lambda2: 9960e14, sigma1: 6000e14, sigma2: 500e14 });

    /// @param _id the Ulysses LP ID
    /// @param _asset the underlying asset
    /// @param _name the name of the LP
    /// @param _symbol the symbol of the LP
    /// @param _owner the owner of this contract
    constructor(
        uint256 _id,
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _owner
    ) UlyssesERC4626(_asset, _name, _symbol) {
        factory = UlyssesFactory(msg.sender);
        _initializeOwner(_owner);
        require(_id != 0);
        id = _id;

        chainStateList.push(
            ChainState({
                destination: UlyssesPool(address(0)),
                weight: 0,
                rebalancingFee: 0,
                bandwidth: 0,
                targetBandwidth: 0
            })
        );
    }

    /// @notice Gets the available bandwidth for the given pool's ID, if it doesn't have a connection it will return 0
    /// @param destinationId The ID of a Ulysses LP
    /// @return bandwidth The available bandwidth for the given pool's ID
    function getBandwidth(uint256 destinationId) external view returns (uint256) {
        /// @dev chainStateList first element has always 0 bandwidth, so this line will never fail and return 0 instead
        return chainStateList[destinations[destinationId]].bandwidth;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Sends all outstanding protocol fees to factory owner
    /// @dev Anyone can call this function
    function claimProtocolFees() external returns (uint256 claimed) {
        claimed = claimable;

        if (claimed > 0) {
            claimable = 0;
            address(asset).safeTransfer(factory.owner(), claimed);
        }
    }

    /// @notice Adds a new Ulysses LP with the requested weight
    /// @dev Can't remove a destination, only add new ones
    /// @param poolId The ID of the destination Ulysses LP to be added
    /// @param weight The weight to calculate the bandwidth for the given pool's ID
    /// @return index The index of chainStateList of the newly added Ulysses LP
    function addDestination(uint256 poolId, uint8 weight)
        external
        onlyOwner
        returns (uint256 index)
    {
        if (weight == 0) revert InvalidWeight();

        UlyssesPool destination = factory.pools(poolId);
        if (destinationIds[address(destination)] != 0) revert AlreadyAddedLP();

        uint256 destinationId = destination.id();

        if (destinationId == 0) revert NotUlyssesLP();

        index = chainStateList.length;

        // TODO: Take into account removed destinations
        if (index > MAX_DESTINATIONS) revert TooManyDestinations();

        uint256 oldTotalWeights = totalWeights;
        uint256 newTotalWeights = oldTotalWeights + weight;
        totalWeights = newTotalWeights;

        if (newTotalWeights > MAX_TOTAL_WEIGHT) revert InvalidWeight();

        uint128 leftOverBandwidth;
        uint88 leftOverRebalancingFee;

        for (uint256 i = 1; i < index; ) {
            ChainState storage chainState = chainStateList[i];

            uint128 oldBandwidth = chainState.bandwidth.min(chainState.targetBandwidth).toUint128();
            if (oldBandwidth > 0) {
                chainState.bandwidth = oldBandwidth
                    .mulDivUp(oldTotalWeights, newTotalWeights)
                    .toUint128();

                leftOverBandwidth += oldBandwidth - chainState.bandwidth;
            }
            chainState.targetBandwidth = totalSupply
                .mulDivUp(chainState.weight, newTotalWeights)
                .toUint128();

            uint88 oldRebalancingFee = chainState.rebalancingFee;

            chainState.rebalancingFee = _calculateRebalancingFee(
                chainState.targetBandwidth,
                chainState.bandwidth,
                chainState.targetBandwidth,
                true
            ).toUint88();

            leftOverRebalancingFee += oldRebalancingFee - chainState.rebalancingFee;

            unchecked {
                ++i;
            }
        }

        uint128 targetBandwidth = totalSupply.mulDivUp(weight, newTotalWeights).toUint128();
        uint88 rebalancingFee = _calculateRebalancingFee(
            targetBandwidth,
            leftOverBandwidth,
            targetBandwidth,
            true
        ).toUint88();

        chainStateList.push(
            ChainState({
                destination: destination,
                bandwidth: leftOverBandwidth,
                targetBandwidth: targetBandwidth,
                weight: weight,
                rebalancingFee: rebalancingFee
            })
        );

        destinations[destinationId] = index;
        destinationIds[address(destination)] = index;

        if (leftOverRebalancingFee > rebalancingFee) {
            claimable += leftOverRebalancingFee - rebalancingFee;
        } else if (leftOverRebalancingFee < rebalancingFee) {
            address(asset).safeTransferFrom(
                msg.sender,
                address(this),
                rebalancingFee - leftOverRebalancingFee
            );
        }
    }

    /// @notice Changes the weight of a exisiting Ulysses LP with the given ID
    /// @param poolId The ID of the destination Ulysses LP to be removed
    /// @param weight The new weight to calculate the bandwidth for the given pool's ID
    function setWeight(uint256 poolId, uint8 weight) external onlyOwner {
        if (weight == 0) revert InvalidWeight();

        uint256 poolIndex = destinations[poolId];

        if (poolIndex == 0) revert NotUlyssesLP();

        uint256 oldTotalWeights = totalWeights;
        uint256 weightsWithoutPool = oldTotalWeights - chainStateList[poolIndex].weight;
        uint256 newTotalWeights = weightsWithoutPool + weight;
        totalWeights = newTotalWeights;

        if (totalWeights > MAX_TOTAL_WEIGHT || oldTotalWeights == newTotalWeights)
            revert InvalidWeight();

        uint256 leftOverRebalancingFee;
        uint256 missingRebalancingFee;
        uint128 leftOverBandwidth;

        ChainState storage chain = chainStateList[poolIndex];
        chain.weight = weight;

        if (oldTotalWeights > newTotalWeights) {
            for (uint256 i = 1; i < chainStateList.length; ) {
                if (i != poolIndex) {
                    ChainState storage chainState = chainStateList[i];

                    uint128 oldBandwidth = chainState
                        .bandwidth
                        .min(chainState.targetBandwidth)
                        .toUint128();
                    if (oldBandwidth > 0) {
                        chainState.bandwidth = oldBandwidth
                            .mulDivUp(oldTotalWeights, newTotalWeights)
                            .toUint128();

                        leftOverBandwidth += oldBandwidth - chainState.bandwidth;
                    }
                    chainState.targetBandwidth = totalSupply
                        .mulDivUp(chainState.weight, newTotalWeights)
                        .toUint128();

                    uint88 prevRebalancingFee = chainState.rebalancingFee;

                    chainState.rebalancingFee = _calculateRebalancingFee(
                        chainState.targetBandwidth,
                        chainState.bandwidth,
                        chainState.targetBandwidth,
                        true
                    ).toUint88();

                    leftOverRebalancingFee += prevRebalancingFee - chainState.rebalancingFee;
                }

                unchecked {
                    ++i;
                }
            }

            uint128 targetBandwidth = totalSupply.mulDivUp(weight, newTotalWeights).toUint128();
            uint88 oldRebalancingFee = chain.rebalancingFee;
            chain.rebalancingFee = _calculateRebalancingFee(
                targetBandwidth,
                leftOverBandwidth,
                targetBandwidth,
                true
            ).toUint88();

            chain.bandwidth = leftOverBandwidth;
            chain.targetBandwidth = targetBandwidth;

            if (oldRebalancingFee > chain.rebalancingFee)
                missingRebalancingFee += oldRebalancingFee - chain.rebalancingFee;
            else if (oldRebalancingFee < chain.rebalancingFee)
                leftOverRebalancingFee += chain.rebalancingFee - oldRebalancingFee;
        } else {
            {
                uint128 oldBandwidth = chain.bandwidth;
                if (oldBandwidth > 0) {
                    chain.bandwidth = oldBandwidth
                        .mulDivUp(oldTotalWeights, newTotalWeights)
                        .toUint128();

                    leftOverBandwidth += oldBandwidth - chain.bandwidth;
                }
                chain.targetBandwidth = totalSupply.mulDivUp(weight, newTotalWeights).toUint128();

                uint88 oldRebalancingFee = chain.rebalancingFee;
                chain.rebalancingFee = _calculateRebalancingFee(
                    chain.targetBandwidth,
                    chain.bandwidth,
                    chain.targetBandwidth,
                    true
                ).toUint88();

                if (oldRebalancingFee > chain.rebalancingFee)
                    missingRebalancingFee += oldRebalancingFee - chain.rebalancingFee;
                else if (oldRebalancingFee < chain.rebalancingFee)
                    leftOverRebalancingFee += chain.rebalancingFee - oldRebalancingFee;
            }

            for (uint256 i = 1; i < chainStateList.length; ) {
                if (i != poolIndex) {
                    ChainState storage chainState = chainStateList[i];

                    if (i == chainStateList.length - 1) {
                        chainState.bandwidth += leftOverBandwidth;
                    } else if (leftOverBandwidth > 0) {
                        chainState.bandwidth += leftOverBandwidth
                            .mulDiv(chainState.weight, weightsWithoutPool)
                            .toUint128();
                    }
                    chainState.targetBandwidth = totalSupply
                        .mulDivUp(chainState.weight, newTotalWeights)
                        .toUint128();

                    uint88 oldRebalancingFee = chainState.rebalancingFee;
                    chainState.rebalancingFee = _calculateRebalancingFee(
                        chainState.targetBandwidth,
                        chainState.bandwidth,
                        chainState.targetBandwidth,
                        true
                    ).toUint88();

                    if (oldRebalancingFee > chainState.rebalancingFee)
                        missingRebalancingFee += oldRebalancingFee - chainState.rebalancingFee;
                    else if (oldRebalancingFee < chainState.rebalancingFee)
                        leftOverRebalancingFee += chainState.rebalancingFee - oldRebalancingFee;
                }

                unchecked {
                    ++i;
                }
            }
        }

        if (leftOverRebalancingFee > missingRebalancingFee) {
            claimable += (leftOverRebalancingFee - missingRebalancingFee).toUint88();
        } else if (leftOverRebalancingFee < missingRebalancingFee) {
            address(asset).safeTransferFrom(
                msg.sender,
                address(this),
                missingRebalancingFee - leftOverRebalancingFee
            );
        }
    }

    /// @notice Sets the protocol and rebalancing fees
    /// @param _fees The new fees to be set
    function setFees(Fees calldata _fees) external onlyOwner {
        // Lower fee must be lower than 1%
        if (_fees.lambda1 > MAX_LAMBDA1) revert InvalidFee();
        // Sum of both fees must be 100%
        if (_fees.lambda1 + _fees.lambda2 != DIVISIONER) revert InvalidFee();

        // Upper bound must be lower than 100%
        if (_fees.sigma1 > DIVISIONER) revert InvalidFee();
        // Lower bound must be lower than Upper bound and higher than 1%
        if (_fees.sigma1 <= _fees.sigma2 || _fees.sigma2 < MIN_SIGMA2) revert InvalidFee();

        fees = _fees;
    }

    /// @notice Sets the protocol fee
    /// @param _protocolFee The new protocol fee to be set
    /// @dev Only factory owner can call this function
    function setProtocolFee(uint64 _protocolFee) external {
        if (msg.sender != factory.owner()) revert Unauthorized();

        // Revert if the protocol fee is larger than 1%
        if (_protocolFee > MAX_PROTOCOL_FEE) revert InvalidFee();

        protocolFee = _protocolFee;
    }

    /*//////////////////////////////////////////////////////////////
                            ULYSSES LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds to bandwidths from the amount swapped and returns a positive rebalancing fee
    /// @param amount The amount to be distributed between all bandwidths
    /// @return output The positive rebalancing fee for amount
    function ulyssesSwap(uint256 amount) private returns (uint256) {
        uint256 length = chainStateList.length;
        uint256[] memory diffs = new uint256[](length);
        uint256 total;

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, chainStateList.slot)
            let location := keccak256(0x00, 0x20)
            for {
                let i := 1
            } lt(i, length) {
                i := add(i, 1)
            } {
                let slot := sload(add(location, mul(i, 2)))
                let target := shr(128, slot)
                let current := and(0xffffffffffffffffffffffffffffffff, slot)

                if gt(target, current) {
                    let diff := sub(target, current)
                    total := add(total, diff)
                    mstore(add(diffs, add(mul(i, 0x20), 0x20)), diff)
                }
            }
        }

        uint256 transfered = amount.min(total);
        uint256 transferedChange;
        /// @solidity memory-safe-assembly
        assembly {
            transferedChange := sub(amount, transfered)
        }
        uint256 _totalWeights = totalWeights;

        for (uint256 i = 1; i < length; ) {
            ChainState storage chainState = chainStateList[i];

            uint128 difference;
            {
                uint256 diffTransfered;
                if (transfered > 0) {
                    diffTransfered = transfered.mulDiv(diffs[i], total);
                }
                uint256 diffTransferedChange;
                if (transferedChange > 0) {
                    diffTransferedChange = transferedChange.mulDiv(
                        chainState.weight,
                        _totalWeights
                    );
                }
                /// @solidity memory-safe-assembly
                assembly {
                    difference := add(diffTransfered, diffTransferedChange)
                }
            }

            if (difference > 0) {
                uint256 bandwidth;
                /// @solidity memory-safe-assembly
                assembly {
                    bandwidth := add(
                        and(0xffffffffffffffffffffffffffffffff, sload(chainState.slot)),
                        difference
                    )
                }

                uint256 _rebalancingFee = _calculateRebalancingFee(
                    bandwidth,
                    chainState.bandwidth,
                    chainState.targetBandwidth,
                    true
                );

                /// @solidity memory-safe-assembly
                assembly {
                    amount := add(amount, _rebalancingFee)

                    sstore(
                        add(chainState.slot, 0x01),
                        sub(sload(add(chainState.slot, 0x01)), _rebalancingFee)
                    )

                    sstore(
                        chainState.slot,
                        add(add(sload(chainState.slot), difference), _rebalancingFee)
                    )
                }
            }

            unchecked {
                ++i;
            }
        }

        return amount;
    }

    /// @notice Adds to bandwidths from the amount added as LP and returns a positive rebalancing fee
    /// @param amount The amount to be distributed between all bandwidths
    /// @return output The positive rebalancing fee for amount
    function ulyssesAddLP(uint256 amount) private returns (uint256) {
        uint256 length = chainStateList.length;
        uint256[] memory diffs = new uint256[](length);
        uint256 total;

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, chainStateList.slot)
            let location := keccak256(0x00, 0x20)
            for {
                let i := 1
            } lt(i, length) {
                i := add(i, 1)
            } {
                let slot := sload(add(location, mul(i, 2)))
                let target := shr(128, slot)
                let current := and(0xffffffffffffffffffffffffffffffff, slot)

                if gt(target, current) {
                    let diff := sub(target, current)
                    total := add(total, diff)
                    mstore(add(diffs, add(mul(i, 0x20), 0x20)), diff)
                }
            }
        }

        uint256 transfered = amount.min(total);
        uint256 transferedChange;
        /// @solidity memory-safe-assembly
        assembly {
            transferedChange := sub(amount, transfered)
        }
        uint256 _totalWeights = totalWeights;

        // approximation, does not take into account possible increase due to rebalancing fees
        uint256 futureTotalSupply;
        /// @solidity memory-safe-assembly
        assembly {
            let _totalSupply := sload(totalSupply.slot)
            futureTotalSupply := add(_totalSupply, amount)
        }

        for (uint256 i = 1; i < length; ) {
            ChainState storage chainState = chainStateList[i];

            chainState.targetBandwidth = futureTotalSupply
                .mulDiv(chainState.weight, _totalWeights)
                .toUint128();

            uint128 difference;
            {
                uint256 diffTransfered;
                if (transfered > 0) {
                    diffTransfered = transfered.mulDiv(diffs[i], total);
                }
                uint256 diffTransferedChange;
                if (transferedChange > 0) {
                    diffTransferedChange = transferedChange.mulDiv(
                        chainState.weight,
                        _totalWeights
                    );
                }
                /// @solidity memory-safe-assembly
                assembly {
                    difference := add(diffTransfered, diffTransferedChange)
                }
            }

            if (difference > 0) {
                uint256 bandwidth;
                /// @solidity memory-safe-assembly
                assembly {
                    bandwidth := add(
                        and(0xffffffffffffffffffffffffffffffff, sload(chainState.slot)),
                        difference
                    )
                }

                uint256 _rebalancingFee = _calculateRebalancingFee(
                    chainState.targetBandwidth,
                    bandwidth,
                    chainState.targetBandwidth,
                    true
                );

                /// @solidity memory-safe-assembly
                assembly {
                    let rebalancingFeeIncrease := sub(
                        _rebalancingFee,
                        and(sload(add(chainState.slot, 0x01)), 0xffffffffffffffffffffff)
                    )
                    amount := sub(amount, rebalancingFeeIncrease)

                    sstore(
                        add(chainState.slot, 0x01),
                        add(sload(add(chainState.slot, 0x01)), rebalancingFeeIncrease)
                    )

                    sstore(
                        chainState.slot,
                        add(add(sload(chainState.slot), difference), _rebalancingFee)
                    )
                }
            }

            unchecked {
                ++i;
            }
        }

        return amount;
    }

    /// @notice Removes from bandwidths from the amount removed as LP and returns a negative rebalancing fee
    /// @param amount The amount to be removed between all bandwidths
    /// @return output The negative rebalancing fee for amount
    function ulyssesRemoveLP(uint256 amount) private returns (uint256) {
        uint256 length = chainStateList.length;
        uint256[] memory diffs = new uint256[](length);
        uint256 total;

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, chainStateList.slot)
            let location := keccak256(0x00, 0x20)
            for {
                let i := 1
            } lt(i, length) {
                i := add(i, 1)
            } {
                let slot := sload(add(location, mul(i, 2)))
                let target := shr(128, slot)
                let current := and(0xffffffffffffffffffffffffffffffff, slot)

                if gt(current, target) {
                    let diff := sub(current, target)
                    total := add(total, diff)
                    mstore(add(diffs, add(mul(i, 0x20), 0x20)), diff)
                }
            }
        }

        uint256 transfered = amount.min(total);
        uint256 transferedChange;
        /// @solidity memory-safe-assembly
        assembly {
            transferedChange := sub(amount, transfered)
        }
        uint256 _totalWeights = totalWeights;
        uint256 _totalSupply = totalSupply;

        for (uint256 i = 1; i < length; ) {
            ChainState storage chainState = chainStateList[i];

            chainState.targetBandwidth = _totalSupply
                .mulDiv(chainState.weight, _totalWeights)
                .toUint128();

            uint128 difference;
            {
                uint256 diffTransfered;
                if (transfered > 0) {
                    diffTransfered = transfered.mulDiv(diffs[i], total);
                }
                uint256 diffTransferedChange;
                if (transferedChange > 0) {
                    diffTransferedChange = transferedChange.mulDiv(
                        chainState.weight,
                        _totalWeights
                    );
                }
                /// @solidity memory-safe-assembly
                assembly {
                    difference := add(diffTransfered, diffTransferedChange)
                }
            }
            if (difference > 0) {
                /// @solidity memory-safe-assembly
                assembly {
                    let slot := sload(chainState.slot)
                    let oldBandwidth := and(0xffffffffffffffffffffffffffffffff, slot)
                    let newBandwidth := sub(oldBandwidth, difference)

                    if gt(newBandwidth, oldBandwidth) {
                        mstore(0x00, "underflow")
                        revert(0x00, 0x20)
                    }

                    sstore(chainState.slot, sub(slot, difference))
                }

                uint256 _rebalancingFee = _calculateRebalancingFee(
                    chainState.targetBandwidth,
                    chainState.bandwidth,
                    chainState.targetBandwidth,
                    false
                );

                /// @solidity memory-safe-assembly
                assembly {
                    let slot := sload(add(chainState.slot, 0x01))
                    let rebalancingFeeIncrease := sub(
                        _rebalancingFee,
                        and(slot, 0xffffffffffffffffffffff)
                    )
                    amount := sub(amount, rebalancingFeeIncrease)

                    sstore(add(chainState.slot, 0x01), add(slot, rebalancingFeeIncrease))
                }
            }

            unchecked {
                ++i;
            }
        }

        return amount;
    }

    /// @notice Calculates the positive or negative rebalancing fee for a bandwidth change
    /// @param largestBandwidth The largest bandwidth, before decreasing or after increasing the bandwidth
    /// @param smallestBandwidth The smallest bandwidth, after decreasing or before increasing the bandwidth
    /// @param targetBandwidth The ideal bandwidth according to weight and totalSupply
    /// @param positiveTransfer True if adding LP or from the source chain when swapping
    /// @return fee The rebalancing fee for this action
    function _calculateRebalancingFee(
        uint256 largestBandwidth,
        uint256 smallestBandwidth,
        uint256 targetBandwidth,
        bool positiveTransfer
    ) private view returns (uint256 fee) {
        if (largestBandwidth <= smallestBandwidth) return 0;

        uint256 lowerBound1 = targetBandwidth.mulDiv(fees.sigma1, DIVISIONER);
        uint256 lowerBound2 = targetBandwidth.mulDiv(fees.sigma2, DIVISIONER);

        if (smallestBandwidth >= lowerBound1) {
            fee = 0;
        } else if (smallestBandwidth >= lowerBound2) {
            uint256 maxWidth;

            /// @solidity memory-safe-assembly
            assembly {
                maxWidth := sub(lowerBound1, lowerBound2)
            }

            fee = calcFee(
                fees.lambda1,
                lowerBound1,
                maxWidth,
                largestBandwidth.min(lowerBound1),
                smallestBandwidth,
                0,
                positiveTransfer
            );
        } else if (largestBandwidth >= lowerBound2) {
            uint256 maxWidth;

            /// @solidity memory-safe-assembly
            assembly {
                maxWidth := sub(lowerBound1, lowerBound2)
            }

            fee = calcFee(
                fees.lambda1,
                lowerBound1,
                maxWidth,
                largestBandwidth.min(lowerBound1),
                lowerBound2,
                0,
                positiveTransfer
            );

            uint256 secondFee = calcFee(
                fees.lambda2,
                lowerBound2,
                lowerBound2,
                lowerBound2,
                smallestBandwidth,
                fees.lambda1,
                positiveTransfer
            );

            /// @solidity memory-safe-assembly
            assembly {
                fee := add(fee, secondFee)
            }
        } else {
            fee = calcFee(
                fees.lambda2,
                lowerBound2,
                lowerBound2,
                largestBandwidth,
                smallestBandwidth,
                fees.lambda1,
                positiveTransfer
            );
        }
    }

    // / @notice Calculates fee, rounds up if it is a negative fee/transfer and down if it's a positive fee/transfer
    // / @param numerator The numerator to multiply by the amount
    // / @param amount The amount of change in bandwidth
    // / @param denominator The denominator to multiply by the targetBandwidth
    // / @param positiveTransfer True if adding LP or from the source chain when swapping
    // / @return fee The rebalancing fee for this action

    function calcFee(
        uint256 feeTier,
        uint256 upperBound,
        uint256 maxWidth,
        uint256 largestBandwidth,
        uint256 smallestBandwidth,
        uint256 offset,
        bool positiveTransfer
    ) private pure returns (uint256 fee) {
        /// @solidity memory-safe-assembly
        assembly {
            let width := sub(upperBound, shr(1, add(largestBandwidth, smallestBandwidth)))

            if gt(width, upperBound) {
                mstore(0x00, "underflow")
                revert(0x00, 0x20)
            }

            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(maxWidth, iszero(mul(feeTier, gt(width, div(not(0), feeTier)))))) {
                // Store the function selector of `MulDivFailed()`.
                mstore(0x00, "MulDivFailed") // 0xad251c27
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            let finalWidth := add(div(mul(width, feeTier), maxWidth), offset)

            let height := sub(largestBandwidth, smallestBandwidth)

            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(DIVISIONER, iszero(mul(height, gt(finalWidth, div(not(0), height)))))) {
                // Store the function selector of `MulDivFailed()`.
                mstore(0x00, "MulDivFailed") // 0xad251c27
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            switch positiveTransfer
            case false {
                fee := div(mul(finalWidth, height), DIVISIONER)
            }
            default {
                fee := add(
                    iszero(iszero(mod(mul(finalWidth, height), DIVISIONER))),
                    div(mul(finalWidth, height), DIVISIONER)
                )
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Swaps from this Ulysses LP's underlying to the destination Ulysses LP's underlying.
    ///      Distributes amount between bandwidths in the source, having a positive rebalancing fee
    ///      Calls swapDestination of the destination Ulysses LP
    /// @param amount The amount to be dsitributed to bandwidth
    /// @param poolId The ID of the destination Ulysses LP
    /// @return output The output amount transfered to user from the destination Ulysses LP
    function swapSource(uint256 amount, uint256 poolId) external returns (uint256 output) {
        if (amount < MAX_TOTAL_WEIGHT) revert AmountTooSmall();

        uint256 index = destinations[poolId]; // Saves an extra SLOAD if poolId is valid

        if (index == 0) revert NotUlyssesLP();

        address(asset).safeTransferFrom(msg.sender, address(this), amount);

        /// @solidity memory-safe-assembly
        assembly {
            let _protocolFee := shr(192, sload(protocolFee.slot))

            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(
                mul(DIVISIONER, iszero(mul(_protocolFee, gt(amount, div(not(0), _protocolFee)))))
            ) {
                // Store the function selector of `MulDivFailed()`.
                mstore(0x00, "MulDivFailed") // 0xad251c27
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
            let baseFee := div(mul(amount, _protocolFee), DIVISIONER)

            sstore(claimable.slot, add(sload(claimable.slot), baseFee))

            amount := sub(amount, baseFee)
        }

        amount = ulyssesSwap(amount);

        output = chainStateList[index].destination.swapDestination(amount, msg.sender);
    }

    /// @notice Swaps from the caller (source Ulysses LP's) underlying to this Ulysses LP's underlying.
    ///      Called from swapSource of the source Ulysses LP
    ///      Removes amount from the source's bandwidth, having a negative rebalancing fee
    /// @param amount The amount to be removed from source's bandwidth
    /// @param user The user to be transfered the output
    /// @return output The output amount transfered to user
    function swapDestination(uint256 amount, address user) external returns (uint256 output) {
        uint256 index = destinationIds[msg.sender]; // Saves an extra SLOAD if msg.sender is valid

        if (index == 0) revert NotUlyssesLP();

        ChainState storage sourceChainState = chainStateList[index];

        uint256 oldBandwidth;
        uint128 newBandwidth;

        /// @solidity memory-safe-assembly
        assembly {
            let slot := sload(sourceChainState.slot)
            oldBandwidth := and(0xffffffffffffffffffffffffffffffff, slot)
            newBandwidth := sub(oldBandwidth, amount)

            if gt(newBandwidth, oldBandwidth) {
                mstore(0x00, "underflow")
                revert(0x00, 0x20)
            }

            sstore(sourceChainState.slot, sub(slot, amount))
        }

        uint256 rebalancingFee = _calculateRebalancingFee(
            oldBandwidth,
            newBandwidth,
            sourceChainState.targetBandwidth,
            false
        );

        /// @solidity memory-safe-assembly
        assembly {
            sstore(
                add(sourceChainState.slot, 0x01),
                add(sload(add(sourceChainState.slot, 0x01)), rebalancingFee)
            )

            output := sub(amount, rebalancingFee)

            if gt(output, amount) {
                mstore(0x00, "underflow")
                revert(0x00, 0x20)
            }
        }

        address(asset).safeTransfer(user, output);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets total supply of a Ulysses pool.
    function totalAssets() public view override returns (uint256) {
        return totalSupply;
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the maximum amount of withdrawable assets.
    /// @param owner address that is used to get the amount assets.
    /// @return assetAmount maximum amount of withdrawable assets
    function maxWithdraw(address owner) public view override returns (uint256) {
        uint256 balanceUser = balanceOf[owner];
        uint256 balanceThisChain = address(asset).balanceOf(address(this));
        return balanceUser.min(balanceThisChain);
    }

    /// @notice Gets the maxium amount of withdrawable shares.
    /// @param owner address that's used to get the amount of redeemable shares.
    /// @return balance returns the maximum amount of redeemable shares.
    function maxRedeem(address owner) public view override returns (uint256) {
        uint256 balanceUser = balanceOf[owner];
        uint256 balanceThisChain = asset.balanceOf(address(this));
        return balanceUser.min(balanceThisChain);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Performs the necessary steps to make after depositing.
    /// @param assets to be deposited
    function beforeDeposit(uint256 assets) internal override returns (uint256 shares) {
        // Update deposit/mint
        shares = ulyssesAddLP(assets);
    }

    /// @notice Performs the necessary steps to take before withdrawing assets
    /// @param assets to be withdrawn
    function afterWithdraw(uint256 shares) internal override returns (uint256 assets) {
        // Update withdraw/redeem
        assets = ulyssesRemoveLP(shares);
    }
}
