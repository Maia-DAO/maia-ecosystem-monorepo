// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


/**
 * @title Ulysses Token
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice ERC4626 multiple token implementation for Ulysses.
 *          Balances are always 1 : 1 with the underlying assets.
 *  @dev Allows to add/remove new tokens and change exisiting weights
 *       but there needs to be at least 1 token and the caller is
 *       responsible of making sure the Ulysses Token has the correct
 *       number of assets to change weights or add a new token, or
 *       the call will fail.
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
 */
 interface IUlyssesToken {
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the total amount of assets of a given Ulysses token.
     *  @param asset The address of the asset to add.
     *  @param _weight The weight of the asset to add.
     */
    function addAsset(address asset, uint256 _weight) external;

    /**
     * @notice Removes an asset from the Ulysses token.
     *  @param asset The address of the asset to remove.
     */
    function removeAsset(address asset) external;

    /**
     * @notice Sets the weights of the assets in the Ulysses token.
     *  @param _weights The weights of the assets in the Ulysses token.
     */
    function setWeights(uint256[] memory _weights) external;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error AssetAlreadyAdded();

    error CannotRemoveLastAsset();
    error InvalidWeightsLength();
}
