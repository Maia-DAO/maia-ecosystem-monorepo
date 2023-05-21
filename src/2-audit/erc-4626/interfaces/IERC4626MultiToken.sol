// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC4626MultiToken {
    /**
     * @notice Calculates the total amount of assets of a given Ulysses token.
     * @return _totalAssets total number of underlying assets of a Ulysses token.
     */
    function totalAssets() external view returns (uint256 _totalAssets);

    /**
     * @notice Deposit assets into the Vault.
     * @param assetsAmounts The amount of assets to deposit.
     * @param receiver The address to receive the shares.
     */
    function deposit(uint256[] memory assetsAmounts, address receiver) external returns (uint256 shares);

    /**
     * @notice Mint shares from the Vault.
     * @param shares The amount of shares to mint.
     * @param receiver The address to receive the shares.
     */
    function mint(uint256 shares, address receiver) external returns (uint256[] memory assetsAmounts);

    /**
     * @notice Withdraw assets from the Vault.
     * @param assetsAmounts The amount of assets to withdraw.
     * @param receiver The address to receive the assets.
     * @param owner The address of the owner of the shares.
     */
    function withdraw(uint256[] memory assetsAmounts, address receiver, address owner)
        external
        returns (uint256 shares);

    /**
     * @notice Redeem shares from the Vault.
     * @param shares The amount of shares to redeem.
     * @param receiver The address to receive the assets.
     */
    function redeem(uint256 shares, address receiver, address owner)
        external
        returns (uint256[] memory assetsAmounts);

    /**
     * @notice Calculates the amount of shares that would be received for a given amount of assets.
     *  @param assetsAmounts The amount of assets to deposit.
     */
    function convertToShares(uint256[] memory assetsAmounts) external view returns (uint256 shares);

    /**
     * @notice Calculates the amount of assets that would be received for a given amount of shares.
     *  @param shares The amount of shares to redeem.
     */
    function convertToAssets(uint256 shares) external view returns (uint256[] memory assetsAmounts);

    /**
     * @notice Previews the amount of shares that would be received for depositinga given amount of assets.
     *  @param assetsAmounts The amount of assets to deposit.
     */
    function previewDeposit(uint256[] memory assetsAmounts) external view returns (uint256);

    /**
     * @notice Previews the amount of assets that would be received for minting a given amount of shares
     *  @param shares The amount of shares to mint
     */
    function previewMint(uint256 shares) external view returns (uint256[] memory assetsAmounts);

    /**
     * @notice Previews the amount of shares that would be received for a given amount of assets.
     *  @param assetsAmounts The amount of assets to withdraw.
     */
    function previewWithdraw(uint256[] memory assetsAmounts) external view returns (uint256 shares);

    /**
     * @notice Previews the amount of assets that would be received for redeeming a given amount of shares
     *  @param shares The amount of shares to redeem
     */
    function previewRedeem(uint256 shares) external view returns (uint256[] memory);

    /**
     * @notice Returns the maximum amount of assets that can be deposited.
     *  @param owner The address of the owner of the assets.
     */
    function maxDeposit(address owner) external view returns (uint256);

    /**
     * @notice Returns the maximum amount of shares that can be minted.
     *  @param owner The address of the owner of the shares.
     */
    function maxMint(address owner) external view returns (uint256);

    /**
     * @notice Returns the maximum amount of assets that can be withdrawn.
     *  @param owner The address of the owner of the assets.
     */
    function maxWithdraw(address owner) external view returns (uint256[] memory);

    /**
     * @notice Returns the maximum amount of shares that can be redeemed.
     *  @param owner The address of the owner of the shares.
     */
    function maxRedeem(address owner) external view returns (uint256);
}
