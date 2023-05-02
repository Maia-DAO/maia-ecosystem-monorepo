// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {console2} from "forge-std/console2.sol";
import {stdError} from "forge-std/StdError.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {UlyssesToken, IUlyssesToken} from "@ulysses-amm/UlyssesToken.sol";

import {UlyssesTokenHandler} from "../../test-utils/invariant/handlers/UlyssesTokenHandler.t.sol";

contract InvariantUlyssesToken is UlyssesTokenHandler {
    function setUp() public override {
        _underlyings_.push(address(new MockERC20("Mock ERC20", "MERC20", 18)));
        _underlyings_.push(address(new MockERC20("Mock1 ERC20", "MERC20", 18)));
        _underlyings_.push(address(new MockERC20("Mock2 ERC20", "MERC20", 18)));
        _underlyings_.push(address(new MockERC20("Mock3 ERC20", "MERC20", 18)));
        // _underlyings_.push(address(new MockERC20("Mock4 ERC20", "MERC20", 18)));
        // _underlyings_.push(address(new MockERC20("Mock5 ERC20", "MERC20", 18)));
        // _underlyings_.push(address(new MockERC20("Mock6 ERC20", "MERC20", 18)));
        // _underlyings_.push(address(new MockERC20("Mock7 ERC20", "MERC20", 18)));
        // _underlyings_.push(address(new MockERC20("Mock8 ERC20", "MERC20", 18)));
        // _underlyings_.push(address(new MockERC20("Mock9 ERC20", "MERC20", 18)));

        address[] memory assets = new address[](4);
        assets[0] = _underlyings_[0];
        assets[1] = _underlyings_[1];
        assets[2] = _underlyings_[2];
        assets[3] = _underlyings_[3];
        uint256[] memory weights = new uint256[](4);
        weights[0] = 10;
        weights[1] = 10;
        weights[2] = 20;
        weights[3] = 5;
        _vault_ = address(new UlyssesToken(1, assets, weights, "Mock ERC4626", "MERC4626", address(this)));
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = false;
    }

    function test_removeAsset(uint256 assetNum, address asset) internal {
        // save weight
        uint256 weight = UlyssesToken(_vault_).weights(assetNum);
        // save total weights
        uint256 totalWeights = UlyssesToken(_vault_).totalWeights();
        // save length
        uint256 length = UlyssesToken(_vault_).getAssets().length;

        UlyssesToken(_vault_).removeAsset(asset);

        // check total weights
        assertEq(UlyssesToken(_vault_).totalWeights(), totalWeights - weight);
        // check length
        assertEq(UlyssesToken(_vault_).getAssets().length, length - 1);
    }

    function test_removeAsset(uint256 assetNum) external {
        assetNum = assetNum % _underlyings_.length;
        test_removeAsset(assetNum, _underlyings_[assetNum]);
    }

    function test_removeAssetFailInvalidAsset(address asset) external {
        // check address is not in underlyings
        for (uint256 i = 0; i < _underlyings_.length; i++) {
            if (_underlyings_[i] == asset) {
                asset = address(0);
                break;
            }
        }

        vm.expectRevert(stdError.arithmeticError);
        UlyssesToken(_vault_).removeAsset(asset);
    }

    function test_removeAssetFailRemoveLastAsset_1() external {
        while (_underlyings_.length > 1) {
            test_removeAsset(_underlyings_.length - 1, _underlyings_[_underlyings_.length - 1]);
            _underlyings_.pop();
        }

        assertEq(UlyssesToken(_vault_).getAssets().length, 1);

        vm.expectRevert(IUlyssesToken.CannotRemoveLastAsset.selector);
        UlyssesToken(_vault_).removeAsset(_underlyings_[0]);
    }

    function test_removeAssetFailRemoveLastAsset_2() external {
        for (uint256 i = 0; i < _underlyings_.length - 1; i++) {
            test_removeAsset(0, _underlyings_[i]);
        }

        assertEq(UlyssesToken(_vault_).getAssets().length, 1);

        vm.expectRevert(IUlyssesToken.CannotRemoveLastAsset.selector);
        UlyssesToken(_vault_).removeAsset(_underlyings_[_underlyings_.length - 1]);
    }
}
