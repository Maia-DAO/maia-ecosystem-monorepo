// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

abstract contract ERC4626MultiToken is ERC20 {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    error ZeroAssets();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed caller, address indexed owner, uint256[] assets, uint256 shares);

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256[] assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    ERC20[] public assets;

    uint256[] public weights;

    uint256 public totalWeights;

    constructor(
        ERC20[] memory _assets,
        uint256[] memory _weights,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol, 18) {
        assets = _assets;
        weights = _weights;

        uint256 length = _weights.length;
        uint256 _totalWeights;
        for (uint256 i = 0; i < length; ) {
            _totalWeights += _weights[i];

            unchecked {
                i++;
            }
        }
        totalWeights = _totalWeights;
    }

    function receiveAssets(uint256[] memory assetsAmounts) private {
        uint256 length = assetsAmounts.length;
        for (uint256 i = 0; i < length; ) {
            address(assets[i]).safeTransferFrom(msg.sender, address(this), assetsAmounts[i]);

            unchecked {
                i++;
            }
        }
    }

    function sendAssets(uint256[] memory assetsAmounts) private {
        uint256 length = assetsAmounts.length;
        for (uint256 i = 0; i < length; ) {
            address(assets[i]).safeTransfer(address(this), assetsAmounts[i]);

            unchecked {
                i++;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256[] memory assetsAmounts, address receiver)
        public
        virtual
        returns (uint256 shares)
    {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assetsAmounts)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        receiveAssets(assetsAmounts);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assetsAmounts, shares);

        afterDeposit(assetsAmounts, shares);
    }

    function mint(uint256 shares, address receiver)
        public
        virtual
        returns (uint256[] memory assetsAmounts)
    {
        assetsAmounts = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        receiveAssets(assetsAmounts);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assetsAmounts, shares);

        afterDeposit(assetsAmounts, shares);
    }

    function withdraw(
        uint256[] memory assetsAmounts,
        address receiver,
        address owner
    ) public virtual returns (uint256 shares) {
        shares = previewWithdraw(assetsAmounts); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        beforeWithdraw(assetsAmounts, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assetsAmounts, shares);

        sendAssets(assetsAmounts);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256[] memory assetsAmounts) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        assetsAmounts = previewRedeem(shares);
        uint256 length = assetsAmounts.length;
        for (uint256 i = 0; i < length; ) {
            // Check for rounding error since we round down in previewRedeem.
            if (assetsAmounts[i] == 0) revert ZeroAssets();
            unchecked {
                i++;
            }
        }

        beforeWithdraw(assetsAmounts, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assetsAmounts, shares);

        sendAssets(assetsAmounts);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view virtual returns (uint256);

    function convertToShares(uint256[] memory assetsAmounts)
        public
        view
        virtual
        returns (uint256 shares)
    {
        uint256 _totalWeights = totalWeights;
        uint256 length = assetsAmounts.length;

        shares = type(uint256).max;
        for (uint256 i = 0; i < length; ) {
            uint256 share = assetsAmounts[i].mulDiv(_totalWeights, weights[i]);
            if (share < shares) shares = share;
            unchecked {
                i++;
            }
        }
    }

    function convertToAssets(uint256 shares)
        public
        view
        virtual
        returns (uint256[] memory assetsAmounts)
    {
        uint256 _totalWeights = totalWeights;
        uint256 length = assets.length;

        for (uint256 i = 0; i < length; ) {
            assetsAmounts[i] = shares.mulDiv(weights[i], _totalWeights);
            unchecked {
                i++;
            }
        }
    }

    function previewDeposit(uint256[] memory assetsAmounts) public view virtual returns (uint256) {
        return convertToShares(assetsAmounts);
    }

    function previewMint(uint256 shares)
        public
        view
        virtual
        returns (uint256[] memory assetsAmounts)
    {
        uint256 _totalWeights = totalWeights;
        uint256 length = assets.length;

        for (uint256 i = 0; i < length; ) {
            assetsAmounts[i] = shares.mulDivUp(weights[i], _totalWeights);
            unchecked {
                i++;
            }
        }
    }

    function previewWithdraw(uint256[] memory assetsAmounts)
        public
        view
        virtual
        returns (uint256 shares)
    {
        uint256 _totalWeights = totalWeights;
        uint256 length = assetsAmounts.length;

        for (uint256 i = 0; i < length; ) {
            uint256 share = assetsAmounts[i].mulDivUp(_totalWeights, weights[i]);
            if (share > shares) shares = share;
            unchecked {
                i++;
            }
        }
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256[] memory) {
        return convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view virtual returns (uint256[] memory) {
        return convertToAssets(balanceOf[owner]);
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(uint256[] memory assetsAmounts, uint256 shares) internal virtual {}

    function afterDeposit(uint256[] memory assetsAmounts, uint256 shares) internal virtual {}
}
