// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {UlyssesToken} from "@ulysses-amm/UlyssesToken.sol";

import {
    UlyssesTokenHandler
} from "../../test-utils/invariant/handlers/UlyssesTokenHandler.t.sol";

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
}