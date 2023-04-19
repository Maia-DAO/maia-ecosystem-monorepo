// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";

import {MockERC20, ERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {UlyssesToken} from "@ulysses-amm/UlyssesToken.sol";

import {ERC4626MultiToken} from "@ERC4626/ERC4626MultiToken.sol";

abstract contract UlyssesTokenProp is Test {
    uint internal _delta_;

    address[] internal _underlyings_;
    address internal _vault_;

    bool internal _vaultMayBeEmpty;
    bool internal _unlimitedAmount;

    function getAssetsBalances(address user) internal view returns (uint[] memory) {
        uint[] memory balances = new uint[](_underlyings_.length);
        for (uint i = 0; i < _underlyings_.length; i++) {
            balances[i] = MockERC20(_underlyings_[i]).balanceOf(user);
        }
        return balances;
    }

    function getAssetsAllowances(address user, address spender) internal view returns (uint[] memory) {
        uint[] memory allowances = new uint[](_underlyings_.length);
        for (uint i = 0; i < _underlyings_.length; i++) {
            allowances[i] = MockERC20(_underlyings_[i]).allowance(user, spender);
        }
        return allowances;
    }

    //
    // asset
    //

    // asset
    // "MUST NOT revert."
    function prop_asset(address caller) public {
        vm.prank(caller); UlyssesToken(_vault_).getAssets();
    }

    // totalAssets
    // "MUST NOT revert."
    function prop_totalAssets(address caller) public {
        vm.prank(caller); UlyssesToken(_vault_).totalAssets();
    }

    //
    // convert
    //

    // convertToShares
    // "MUST NOT show any variations depending on the caller."
    function prop_convertToShares(address caller1, address caller2, uint[] memory assets) public {
        vm.prank(caller1); uint res1 = vault_convertToShares(assets); // "MAY revert due to integer overflow caused by an unreasonably large input."
        vm.prank(caller2); uint res2 = vault_convertToShares(assets); // "MAY revert due to integer overflow caused by an unreasonably large input."
        assertEq(res1, res2);
    }

    // convertToAssets
    // "MUST NOT show any variations depending on the caller."
    function prop_convertToAssets(address caller1, address caller2, uint shares) public {
        vm.prank(caller1); uint[] memory res1 = vault_convertToAssets(shares); // "MAY revert due to integer overflow caused by an unreasonably large input."
        vm.prank(caller2); uint[] memory res2 = vault_convertToAssets(shares); // "MAY revert due to integer overflow caused by an unreasonably large input."
        assertEq(res1, res2);
    }

    //
    // deposit
    //

    // maxDeposit
    // "MUST NOT revert."
    function prop_maxDeposit(address caller, address receiver) public {
        vm.prank(caller); UlyssesToken(_vault_).maxDeposit(receiver);
    }

    // previewDeposit
    // "MUST return as close to and no more than the exact amount of Vault
    // shares that would be minted in a deposit call in the same transaction.
    // I.e. deposit should return the same or more shares as previewDeposit if
    // called in the same transaction."
    function prop_previewDeposit(address caller, address receiver, address other, uint[] memory assets) public {
        vm.prank(other); uint sharesPreview = vault_previewDeposit(assets); // "MAY revert due to other conditions that would also cause deposit to revert."
        vm.prank(caller); uint sharesActual = vault_deposit(assets, receiver);
        assertApproxGeAbs(sharesActual, sharesPreview, _delta_);
    }

    // deposit
    function prop_deposit(address caller, address receiver, uint[] memory assets) public {
        uint[] memory oldCallerAsset = getAssetsBalances(caller);
        uint oldReceiverShare = MockERC20(_vault_).balanceOf(receiver);
        uint[] memory oldAllowance = getAssetsAllowances(caller, _vault_);

        vm.prank(caller); uint shares = vault_deposit(assets, receiver);

        uint[] memory newCallerAsset = getAssetsBalances(caller);
        uint newReceiverShare = MockERC20(_vault_).balanceOf(receiver);
        uint[] memory newAllowance = getAssetsAllowances(caller, _vault_);

        for (uint i = 0; i < UlyssesToken(_vault_).getAssets().length; i++) {
            assertApproxEqAbs(newCallerAsset[i], oldCallerAsset[i] - assets[i], _delta_, "asset");
            if (oldAllowance[i] != type(uint).max) assertApproxEqAbs(newAllowance[i], oldAllowance[i] - assets[i], _delta_, "allowance");
        }
        assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, _delta_, "share");
    }

    //
    // mint
    //

    // maxMint
    // "MUST NOT revert."
    function prop_maxMint(address caller, address receiver) public {
        vm.prank(caller); UlyssesToken(_vault_).maxMint(receiver);
    }

    // previewMint
    // "MUST return as close to and no fewer than the exact amount of assets
    // that would be deposited in a mint call in the same transaction. I.e. mint
    // should return the same or fewer assets as previewMint if called in the
    // same transaction."
    function prop_previewMint(address caller, address receiver, address other, uint shares) public {
        vm.prank(other); uint[] memory assetsPreview = vault_previewMint(shares);
        vm.prank(caller); uint[] memory assetsActual = vault_mint(shares, receiver);

        for (uint i = 0; i < assetsPreview.length; i++) {
            assertApproxLeAbs(assetsActual[i], assetsPreview[i], _delta_);
        }
    }

    // mint
    function prop_mint(address caller, address receiver, uint shares) public {
        uint[] memory oldCallerAsset = getAssetsBalances(caller);
        uint oldReceiverShare = MockERC20(_vault_).balanceOf(receiver);
        uint[] memory oldAllowance = getAssetsAllowances(caller, _vault_);

        vm.prank(caller); uint[] memory assets = vault_mint(shares, receiver);

        uint[] memory newCallerAsset = getAssetsBalances(caller);
        uint newReceiverShare = MockERC20(_vault_).balanceOf(receiver);
        uint[] memory newAllowance = getAssetsAllowances(caller, _vault_);

        for (uint i = 0; i < UlyssesToken(_vault_).getAssets().length; i++) {
            assertApproxEqAbs(newCallerAsset[i], oldCallerAsset[i] - assets[i], _delta_, "asset");
            if (oldAllowance[i] != type(uint).max) assertApproxEqAbs(newAllowance[i], oldAllowance[i] - assets[i], _delta_, "allowance");
        }
        assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, _delta_, "share");
    }

    //
    // withdraw
    //

    // maxWithdraw
    // "MUST NOT revert."
    // NOTE: some implementations failed due to arithmetic overflow
    function prop_maxWithdraw(address caller, address owner) public {
        vm.prank(caller); UlyssesToken(_vault_).maxWithdraw(owner);
    }

    // previewWithdraw
    // "MUST return as close to and no fewer than the exact amount of Vault
    // shares that would be burned in a withdraw call in the same transaction.
    // I.e. withdraw should return the same or fewer shares as previewWithdraw
    // if called in the same transaction."
    function prop_previewWithdraw(address caller, address receiver, address owner, address other, uint[] memory assets) public {
        vm.prank(other); uint preview = vault_previewWithdraw(assets);
        vm.prank(caller); uint actual = vault_withdraw(assets, receiver, owner);
        assertApproxLeAbs(actual, preview, _delta_);
    }

    // withdraw
    function prop_withdraw(address caller, address receiver, address owner, uint[] memory assets) public {
        uint[] memory oldReceiverAsset = getAssetsBalances(receiver);
        uint oldOwnerShare = MockERC20(_vault_).balanceOf(owner);
        uint oldAllowance = MockERC20(_vault_).allowance(owner, caller);

        vm.prank(caller); uint shares = vault_withdraw(assets, receiver, owner);

        uint[] memory newReceiverAsset = getAssetsBalances(receiver);
        uint newOwnerShare = MockERC20(_vault_).balanceOf(owner);
        uint newAllowance = MockERC20(_vault_).allowance(owner, caller);

        assertApproxEqAbs(newOwnerShare, oldOwnerShare - shares, _delta_, "share");
        if (caller != owner && oldAllowance != type(uint).max) assertApproxEqAbs(newAllowance, oldAllowance - shares, _delta_, "allowance");


        for (uint i = 0; i < UlyssesToken(_vault_).getAssets().length; i++) {
            assertApproxEqAbs(newReceiverAsset[i], oldReceiverAsset[i] + assets[i], _delta_, "asset"); // NOTE: this may fail if the receiver is a contract in which the asset is stored
            assertTrue(caller == owner || oldAllowance != 0 || (shares == 0 && assets[i] == 0), "access control");
        }
    }

    //
    // redeem
    //

    // maxRedeem
    // "MUST NOT revert."
    function prop_maxRedeem(address caller, address owner) public {
        vm.prank(caller); UlyssesToken(_vault_).maxRedeem(owner);
    }

    // previewRedeem
    // "MUST return as close to and no more than the exact amount of assets that
    // would be withdrawn in a redeem call in the same transaction. I.e. redeem
    // should return the same or more assets as previewRedeem if called in the
    // same transaction."
    function prop_previewRedeem(address caller, address receiver, address owner, address other, uint shares) public {
        vm.prank(other); uint[] memory preview = vault_previewRedeem(shares);
        vm.prank(caller); uint[] memory actual = vault_redeem(shares, receiver, owner);

        for (uint i = 0; i < preview.length; i++) {
            assertApproxLeAbs(actual[i], preview[i], _delta_);
        }    
    }

    // redeem
    function prop_redeem(address caller, address receiver, address owner, uint shares) public {
        uint[] memory oldReceiverAsset = getAssetsBalances(receiver);
        uint oldOwnerShare = MockERC20(_vault_).balanceOf(owner);
        uint oldAllowance = MockERC20(_vault_).allowance(owner, caller);

        vm.prank(caller); uint[] memory assets = vault_redeem(shares, receiver, owner);

        uint[] memory newReceiverAsset = getAssetsBalances(receiver);
        uint newOwnerShare = MockERC20(_vault_).balanceOf(owner);
        uint newAllowance = MockERC20(_vault_).allowance(owner, caller);

        assertApproxEqAbs(newOwnerShare, oldOwnerShare - shares, _delta_, "share");
        if (caller != owner && oldAllowance != type(uint).max) assertApproxEqAbs(newAllowance, oldAllowance - shares, _delta_, "allowance");


        for (uint i = 0; i < UlyssesToken(_vault_).getAssets().length; i++) {
            assertApproxEqAbs(newReceiverAsset[i], oldReceiverAsset[i] + assets[i], _delta_, "asset"); // NOTE: this may fail if the receiver is a contract in which the asset is stored
            assertTrue(caller == owner || oldAllowance != 0 || (shares == 0 && assets[i] == 0), "access control");
        }
    }

    //
    // round trip properties
    //

    // redeem(deposit(a)) <= a
    function prop_RT_deposit_redeem(address caller, uint[] memory assets) public {
        if (!_vaultMayBeEmpty) vm.assume(MockERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint shares = vault_deposit(assets, caller);
        vm.prank(caller); uint[] memory assets2 = vault_redeem(shares, caller, caller);

        for (uint i = 0; i < assets2.length; i++) {
            assertApproxLeAbs(assets2[i], assets[i], _delta_);
        }    
    }

    // s = deposit(a)
    // s' = withdraw(a)
    // s' >= s
    function prop_RT_deposit_withdraw(address caller, uint[] memory assets) public {
        if (!_vaultMayBeEmpty) vm.assume(MockERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint shares1 = vault_deposit(assets, caller);
        vm.prank(caller); uint shares2 = vault_withdraw(assets, caller, caller);
        assertApproxGeAbs(shares2, shares1, _delta_);
    }

    // deposit(redeem(s)) <= s
    function prop_RT_redeem_deposit(address caller, uint shares) public {
        vm.prank(caller); uint[] memory assets = vault_redeem(shares, caller, caller);
        if (!_vaultMayBeEmpty) vm.assume(MockERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint shares2 = vault_deposit(assets, caller);
        assertApproxLeAbs(shares2, shares, _delta_);
    }

    // a = redeem(s)
    // a' = mint(s)
    // a' >= a
    function prop_RT_redeem_mint(address caller, uint shares) public {
        vm.prank(caller); uint[] memory assets1 = vault_redeem(shares, caller, caller);
        if (!_vaultMayBeEmpty) vm.assume(MockERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint[] memory assets2 = vault_mint(shares, caller);

        for (uint i = 0; i < assets2.length; i++) {
            assertApproxLeAbs(assets2[i], assets1[i], _delta_);
        }   
    }

    // withdraw(mint(s)) >= s
    function prop_RT_mint_withdraw(address caller, uint shares) public {
        if (!_vaultMayBeEmpty) vm.assume(MockERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint[] memory assets = vault_mint(shares, caller);
        vm.prank(caller); uint shares2 = vault_withdraw(assets, caller, caller);
        assertApproxGeAbs(shares2, shares, _delta_);
    }

    // a = mint(s)
    // a' = redeem(s)
    // a' <= a
    function prop_RT_mint_redeem(address caller, uint shares) public {
        if (!_vaultMayBeEmpty) vm.assume(MockERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint[] memory assets1 = vault_mint(shares, caller);
        vm.prank(caller); uint[] memory assets2 = vault_redeem(shares, caller, caller);

        for (uint i = 0; i < assets2.length; i++) {
            assertApproxLeAbs(assets2[i], assets1[i], _delta_);
        }   
    }

    // mint(withdraw(a)) >= a
    function prop_RT_withdraw_mint(address caller, uint[] memory assets) public {
        vm.prank(caller); uint shares = vault_withdraw(assets, caller, caller);
        if (!_vaultMayBeEmpty) vm.assume(MockERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint[] memory assets2 = vault_mint(shares, caller);

        for (uint i = 0; i < assets2.length; i++) {
            assertApproxLeAbs(assets2[i], assets[i], _delta_);
        }   
    }

    // s = withdraw(a)
    // s' = deposit(a)
    // s' <= s
    function prop_RT_withdraw_deposit(address caller, uint[] memory assets) public {
        vm.prank(caller); uint shares1 = vault_withdraw(assets, caller, caller);
        if (!_vaultMayBeEmpty) vm.assume(MockERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint shares2 = vault_deposit(assets, caller);
        assertApproxLeAbs(shares2, shares1, _delta_);
    }

    //
    // utils
    //

    function vault_convertToShares(uint[] memory assets) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(ERC4626MultiToken.convertToShares.selector, assets));
    }
    function vault_convertToAssets(uint shares) internal returns (uint[] memory) {
        return _call_vault_array(abi.encodeWithSelector(ERC4626MultiToken.convertToAssets.selector, shares));
    }

    function vault_maxDeposit(address receiver) internal returns (uint[] memory) {
        return _call_vault_array(abi.encodeWithSelector(ERC4626MultiToken.maxDeposit.selector, receiver));
    }
    function vault_maxMint(address receiver) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(ERC4626MultiToken.maxMint.selector, receiver));
    }
    function vault_maxWithdraw(address owner) internal returns (uint[] memory) {
        return _call_vault_array(abi.encodeWithSelector(ERC4626MultiToken.maxWithdraw.selector, owner));
    }
    function vault_maxRedeem(address owner) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(ERC4626MultiToken.maxRedeem.selector, owner));
    }

    function vault_previewDeposit(uint[] memory assets) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(ERC4626MultiToken.previewDeposit.selector, assets));
    }
    function vault_previewMint(uint shares) internal returns (uint[] memory) {
        return _call_vault_array(abi.encodeWithSelector(ERC4626MultiToken.previewMint.selector, shares));
    }
    function vault_previewWithdraw(uint[] memory assets) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(ERC4626MultiToken.previewWithdraw.selector, assets));
    }
    function vault_previewRedeem(uint shares) internal returns (uint[] memory) {
        return _call_vault_array(abi.encodeWithSelector(ERC4626MultiToken.previewRedeem.selector, shares));
    }

    function vault_deposit(uint[] memory assets, address receiver) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(ERC4626MultiToken.deposit.selector, assets, receiver));
    }
    function vault_mint(uint shares, address receiver) internal returns (uint[] memory) {
        return _call_vault_array(abi.encodeWithSelector(ERC4626MultiToken.mint.selector, shares, receiver));
    }
    function vault_withdraw(uint[] memory assets, address receiver, address owner) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(ERC4626MultiToken.withdraw.selector, assets, receiver, owner));
    }
    function vault_redeem(uint shares, address receiver, address owner) internal returns (uint[] memory) {
        return _call_vault_array(abi.encodeWithSelector(ERC4626MultiToken.redeem.selector, shares, receiver, owner));
    }

    function _call_vault(bytes memory data) internal returns (uint) {
        (bool success, bytes memory retdata) = _vault_.call(data);
        if (success) return abi.decode(retdata, (uint));
        vm.assume(false); // if reverted, discard the current fuzz inputs, and let the fuzzer to start a new fuzz run
        return 0; // silence warning
    }

    function _call_vault_array(bytes memory data) internal returns (uint[] memory) {
        (bool success, bytes memory retdata) = _vault_.call(data);
        if (success) return abi.decode(retdata, (uint[]));
        vm.assume(false); // if reverted, discard the current fuzz inputs, and let the fuzzer to start a new fuzz run
        uint[] memory assets = new uint[](UlyssesToken(_vault_).getAssets().length); // silence warning
        for (uint i = 0; i < assets.length; i++) {
            assets[i] = 0; // silence warning
        }
        return assets;
    }

    function assertApproxGeAbs(uint a, uint b, uint maxDelta) internal {
        if (!(a >= b)) {
            uint dt = b - a;
            if (dt > maxDelta) {
                emit log                ("Error: a >=~ b not satisfied [uint]");
                emit log_named_uint     ("   Value a", a);
                emit log_named_uint     ("   Value b", b);
                emit log_named_uint     (" Max Delta", maxDelta);
                emit log_named_uint     ("     Delta", dt);
                fail();
            }
        }
    }

    function assertApproxLeAbs(uint a, uint b, uint maxDelta) internal {
        if (!(a <= b)) {
            uint dt = a - b;
            if (dt > maxDelta) {
                emit log                ("Error: a <=~ b not satisfied [uint]");
                emit log_named_uint     ("   Value a", a);
                emit log_named_uint     ("   Value b", b);
                emit log_named_uint     (" Max Delta", maxDelta);
                emit log_named_uint     ("     Delta", dt);
                fail();
            }
        }
    }
}
