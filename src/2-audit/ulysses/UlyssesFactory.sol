// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Ownable } from "solady/auth/Ownable.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { UlyssesPool } from "./UlyssesPool.sol";
import { UlyssesToken } from "./UlyssesToken.sol";

/**
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡴⠲⠚⠙⢛⣶⣶⣯⣷⣒⠶⣍⠀⠂⠀⠀⠉⠉⠒⢦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⡾⠁⠀⢠⣶⠟⠛⠿⠟⠛⠣⣍⠙⠒⢷⣦⡀⠀⠀⠀⠀⠀⠈⠲⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣾⠟⠀⢀⡴⠋⠀⣠⣾⠟⠙⢧⠀⠀⢱⠀⠀⠀⠙⢦⡀⠀⠀⠀⠀⠀⠈⠳⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⡿⠃⠀⢠⡞⠀⢠⣴⣏⡞⠀⠀⠈⡇⠀⠀⢷⠀⠀⠀⠀⠙⢦⠀⠀⠀⠀⠀⠀⠙⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⣰⠋⣠⠀⠀⡾⠀⢠⠏⡇⣼⠃⠀⠀⠀⢸⠀⠀⠈⡆⢰⡀⠀⠀⠀⢳⡀⠀⠀⠀⠀⠀⠈⢆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢰⠟⣄⡇⠀⣸⠁⠀⠁⢸⠀⠋⠀⠀⠀⠀⠀⣇⠀⠀⡇⠀⢣⠀⠀⠀⠀⢧⠀⠀⠀⢀⠀⠀⠘⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⣿⣾⢹⡧⢪⡇⠀⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⢻⠀⠀⠀⢀⠘⣇⠀⠀⠀⠘⣆⠀⠀⠈⠀⠀⠀⠹⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⢰⣻⣯⠟⠁⢸⠁⠀⠀⢰⡉⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⢸⡀⠀⠀⠀⢹⡀⠀⠀⠀⠀⠀⠀⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⣾⣿⠁⣸⠀⡇⠀⠀⠀⣾⣇⠀⢧⠀⠀⠀⠀⠀⠀⠀⠀⡆⠀⡇⠀⣷⠀⠀⡄⠀⡇⠀⠀⠀⢀⠀⠀⣾⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⢠⣿⡇⠀⣾⠀⡇⠀⠀⣄⣿⣽⠀⢸⡆⠀⠀⠀⠀⠀⡄⢠⠇⠀⣿⡀⣿⡇⠀⢱⠀⢹⠀⠀⠀⢸⠀⠀⢱⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⢸⠁⡇⠀⡟⡆⡇⡄⠀⣹⠟⠸⣳⠈⢷⡄⠀⠀⠀⢠⢧⡟⠀⡆⣿⡇⢸⢻⡀⠘⣇⢸⡇⠀⠀⢸⡆⠀⢸⢻⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⢸⣧⠇⢀⠁⢻⣷⡇⠀⡯⠤⠖⢳⡏⠙⣧⣀⠀⢠⣿⣿⡄⠀⣷⠋⡇⠈⠉⢧⠀⡿⣜⡇⠀⠀⢸⡇⠀⠀⡏⡄⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⢸⡿⠀⢻⠀⠸⣷⣧⢰⠁⠀⠀⠀⢳⣀⡟⣷⢴⡿⢻⣿⡇⣸⡟⢀⡁⠀⠀⠈⡀⠁⢻⡇⢰⠀⢸⡇⠀⠀⢰⡇⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⢀⣸⡿⡀⠘⡆⠀⢿⣟⣿⠠⠤⣄⠀⠀⠀⠈⠊⠿⣦⣟⠏⣧⠟⠛⣩⣤⣤⣦⣬⣵⣦⣼⣇⡼⠀⣼⠁⢰⠀⠘⡇⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⢀⣾⢿⡟⡇⠀⢷⠱⢼⣿⠾⢿⣿⣿⣿⣿⡷⣄⠀⠀⠈⠉⠀⠃⠠⠞⢻⣿⣿⣿⣿⠋⠁⡟⢩⡇⠀⡿⠀⣾⠀⠀⠁⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⢀⣾⠏⢸⠁⢳⠀⢘⣇⠀⢽⠀⠈⠻⣿⣗⣿⠃⠈⠀⠀⠀⠀⠀⠀⠀⠀⠈⢻⣯⣛⡥⠀⠀⢠⡿⠁⢸⠁⠀⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⣾⡟⠀⢸⡀⢸⡆⠀⢻⣆⠘⣆⠀⠀⠈⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⠟⡵⢀⣿⠀⢀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⢸⢽⠃⢀⣼⡇⠘⣿⠀⢸⣿⡣⣙⡅⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡜⠁⡼⢃⣾⡏⠀⣸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠸⢼⣧⣴⣿⣿⠀⢿⣟⢆⢳⡫⣿⣝⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠀⠀⠀⠀⠐⠁⢠⠞⣠⡾⡟⠀⢰⠿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⢙⣿⣿⣿⠀⢸⠘⣞⣎⢧⠈⢻⠷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠀⠀⠀⠀⣠⠞⠋⠔⢩⠰⠁⢀⡞⠀⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⣿⣿⡆⠸⡇⢸⣞⢯⣧⢈⠀⢈⠓⠦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⡾⠁⠀⠇⢀⡇⠀⢀⣼⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⢀⡀⠀⡇⣿⢧⠀⡇⢸⡌⢳⡙⢦⠍⡞⠀⠀⠀⠹⡗⠦⢄⣀⣀⣀⡴⠚⠁⢈⣇⢀⠀⢀⡾⠀⠀⣾⠈⡇⠀⢿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⣸⡇⢀⢧⣿⠻⣆⣿⣾⡇⠸⣽⡎⢵⠃⠀⠀⠀⣠⡧⠂⠀⠀⠁⠀⠀⠀⠀⣸⠻⣄⡆⢘⡇⠀⣸⣿⢰⠇⢸⡈⠀⣄⠄⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠈⢹⡇⡸⣿⣿⣷⠥⠐⠈⢹⡄⣿⣀⣚⣀⡤⠖⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠀⠈⠙⣺⠁⣰⣿⣿⣾⣿⠀⠓⣇⣿⠸⡆⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠐⠙⢳⣤⣿⣿⠁⠀⠀⣠⡤⢷⢿⡞⠉⠁⠀⠀⠀⠀⠀⢲⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⢿⠀⣿⣿⣿⡷⡿⡅⠀⠀⠉⠲⢧⣄⠀⠀⠀⠀⠀⠀
 * ⠀⠀⡰⡏⠁⣾⡟⠀⠀⣸⣿⣵⣼⣷⣧⠀⠀⡘⢦⣄⠀⠀⠀⢇⠀⠀⠀⠀⠀⠀⠀⣀⣀⡟⠀⠀⣿⣿⠂⢹⡍⠀⠀⠀⠀⠀⣸⣟⠷⡄⠀⠀⠀⠀
 * ⠀⠸⡷⠃⣰⣿⣁⡤⢴⡷⠻⣯⣿⠹⢯⢦⠀⠳⡀⠨⠍⠛⠲⣾⣄⡠⢖⡾⠗⠋⠉⣠⣿⣰⢠⠀⢉⣿⣲⣸⠀⠀⠁⠀⠀⢻⠇⠈⢹⣇⠀⠀⠀⠀
 * ⠀⢰⠇⠈⠉⣠⠞⠀⡞⠀⠲⣿⡇⢢⡈⠻⡳⠤⠽⣦⣀⣀⠀⠀⠉⠛⠉⠀⠀⣀⡴⠋⠃⡏⠘⡆⠸⢿⣿⡿⠀⠀⠀⠘⢀⡟⠀⠀⢘⣿⣦⡀⠀⠀
 * ⣰⣿⣤⠤⠄⡇⠀⣸⠁⠀⠀⢟⠀⠀⠑⠦⣝⠦⣄⠀⠈⠉⠀⠀⠀⠀⠀⠐⠚⠁⠀⣴⢸⡇⠀⣇⠀⠸⣿⠁⠀⠀⠀⢀⣾⠁⠀⣠⢾⣿⡅⠉⡂⠄
 * ⢹⢻⡄⠀⠀⣣⢠⢇⡀⠀⠀⣹⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣼⡇⠠⢿⠀⠀⢿⡇⠀⠀⢀⡼⠁⠀⠞⣡⠞⢯⢿⡄⢠⡀
 * ⣸⡧⢳⡀⠀⣿⡾⠉⠀⠐⢻⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⡇⣿⠀⢻⡀⠀⢸⣇⡀⢹⣿⠃⣀⡴⣾⠁⠀⠘⢺⣷⡇⡀
 * ⡿⡃⠈⢳⣴⠏⠀⠀⠀⣠⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢷⡘⡷⣄⢳⡀⠈⣿⢳⡀⠻⣿⡉⠉⠁⠀⠀⠀⠈⡏⡇⣷
 * ⣟⠁⠠⢴⣿⣦⣀⣀⣴⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠙⢮⠳⢽⣦⣾⣇⠱⣄⢈⣻⣄⠀⠀⠀⠀⠀⣧⡇⢹
 *
 */

/**
@title Factory responsible for managing Ulysses instances.
 */
contract UlyssesFactory is Ownable {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    error ParameterLengthError();

    uint256 public poolId = 1;

    uint256 public tokenId = 1;

    mapping(uint256 => UlyssesPool) public pools;

    mapping(uint256 => UlyssesToken) public tokens;

    /*//////////////////////////////////////////////////////////////
                           NEW LP LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Creates a new Ullysses pool based on a given ERC20 passed through param.
        @param asset represents the asset we want to create a Ulysses pool around
        @return poolId returns the poolId 
     */
    function createPool(ERC20 asset, address owner) external returns (uint256) {
        return _createPool(asset, owner);
    }

    /**
    @notice Private function that holds the logic for creating a new Ulysses pool.
    @param asset represents the asset that we want to create a Ulysses pool for.F
    @return _poolId id of the pool that was created 
     */
    function _createPool(ERC20 asset, address owner) private returns (uint256 _poolId) {
        _poolId = ++poolId;
        pools[_poolId] = new UlyssesPool(_poolId, asset, asset.name(), asset.symbol(), owner);
    }

    /**
    @notice Takes an array of assets and their respective weights and creates a Ulysses token. 
            First it creates a Ulysses pool for each asset and then it links
            them together according to the specified weight.
    @param assets erc20 array that represents all the assets that are part of the Ulysses Token
    @param weights weights array that holds the weights for the corresponding assets.
     */
    function createPools(
        ERC20[] calldata assets,
        uint8[][] calldata weights,
        address owner
    ) external returns (uint256[] memory poolIds) {
        uint256 length = assets.length;

        if (length != weights.length) revert ParameterLengthError();

        for (uint256 i = 0; i < length; ) {
            poolIds[i] = _createPool(assets[i], address(this));

            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < length; ) {
            if (length != weights[i].length) revert ParameterLengthError();

            for (uint256 j = 0; j < length; ) {
                if (j != i) pools[poolIds[i]].addDestination(poolIds[j], weights[i][j]);

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < length; ) {
            pools[poolIds[i]].transferOwnership(owner);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                           NEW TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     @notice Responsible for creating a unified liquidity token (Ulysses token).
     @param poolIds ids of the pools that the unified liquidity token should take into consideration
     @param weights weights of the pools to link to the Ulysses Token
     @return _tokenId id of the newly created Ulysses token
     */
    function createToken(
        uint256[] calldata poolIds,
        uint256[] calldata weights,
        address owner
    ) external returns (uint256 _tokenId) {
        _tokenId = ++tokenId;

        uint256 length = poolIds.length;
        ERC20[] memory destinations = new ERC20[](length);
        for (uint256 i = 0; i < length; ) {
            destinations[i] = pools[poolIds[i]];

            unchecked {
                ++i;
            }
        }

        tokens[_tokenId] = new UlyssesToken(_tokenId, destinations, weights, "name", "symbol", owner);
    }
}
