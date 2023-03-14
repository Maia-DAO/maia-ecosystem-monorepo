// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {ERC4626} from "@ERC4626/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {console2} from "forge-std/console2.sol";

import {MockERC4626PartnerManager} from "../mock/MockERC4626PartnerManager.t.sol";
import {MockVault} from "../mock/MockVault.t.sol";

import {PartnerManagerFactory} from "@maia/factories/PartnerManagerFactory.sol";
import {PartnerUtilityManager} from "@maia/PartnerUtilityManager.sol";

import {bHermes} from "@hermes/bHermes.sol";
import {bHermesVotes as ERC20MultiVotes} from "@hermes/tokens/bHermesVotes.sol";

/*
    TODO: Add events
    TODO: Check Libraries
    TODO: Custom Errors
    TODO: Organize functions into sections
    TODO: Check variable names
    
    TODO: DELEGATE VOTING TO CONTRACT    */

contract ERC4626PartnerManagerTest is DSTestPlus {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    MockERC4626PartnerManager public manager;

    MockVault vault;

    MockERC20 public hermes;

    MockERC20 public partnerAsset;

    uint256 bHermesRate;

    bHermes public _bHermes;

    function setUp() public {
        hermes = new MockERC20("test hermes", "RTKN", 18);

        partnerAsset = new MockERC20("test partnerAsset", "tpartnerAsset", 18);

        _bHermes = new bHermes(hermes, address(this), 1 weeks, 1 days / 2);

        bHermesRate = 1;

        vault = new MockVault();

        manager = new MockERC4626PartnerManager(
            PartnerManagerFactory(address(this)),
            bHermesRate,
            partnerAsset,
            "test partner manager",
            "PartnerFi",
            address(_bHermes),
            address(vault),
            address(this)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function testDeposit() public {
        assertEq(manager.bHermesRate(), bHermesRate);

        uint256 amount = 100 ether;

        hermes.mint(address(this), 1000 ether);
        hermes.approve(address(_bHermes), 1000 ether);
        _bHermes.deposit(1000 ether, address(this));

        _bHermes.transfer(address(manager), 1000 ether);

        partnerAsset.mint(address(this), amount);
        partnerAsset.approve(address(manager), amount);

        manager.deposit(amount, address(this));

        assertEq(partnerAsset.balanceOf(address(manager)), amount);
        assertEq(manager.balanceOf(address(this)), amount);
    }

    function testDepositTwoDeposits() public {
        testDeposit();

        assertEq(manager.bHermesRate(), bHermesRate);

        uint256 amount = 150 ether;

        hevm.startPrank(address(2));

        partnerAsset.mint(address(2), amount);
        partnerAsset.approve(address(manager), amount);

        manager.deposit(amount, address(2));

        hevm.stopPrank();

        console2.log(manager.balanceOf(address(2)) / 1e18);

        assertEq(partnerAsset.balanceOf(address(manager)), amount + 100 ether);
        assertEq(manager.balanceOf(address(2)), amount);
    }

    function testWithdraw() public {
        testDeposit();

        uint256 amount = 100 ether;

        // hevm.warp(getFirstDayOfNextMonthUnix());

        manager.withdraw(amount, address(this), address(this));

        assertEq(partnerAsset.balanceOf(address(manager)), 0);
        assertEq(manager.balanceOf(address(this)), 0);
    }

    function testTotalAssets() public {
        testDeposit();

        require(manager.totalSupply() == 100 ether);
    }

    function testConvertToShares() public {
        require(manager.convertToShares(100 ether) == 100 ether);
    }

    function testConvertToSharesOverZeroSupply() public {
        testDepositTwoDeposits();

        require(manager.convertToShares(100 ether) == 100 ether);
    }

    function testConvertToAssets() public {
        require(manager.convertToAssets(100 ether) == 100 ether);
    }

    function testConvertToAssetsOverZeroSupply() public {
        testDepositTwoDeposits();

        require(manager.convertToAssets(100 ether) == 100 ether);
    }

    function testPreviewDeposit() public {
        require(manager.previewDeposit(100 ether) == 100 ether);
    }

    function testPreviewMint() public {
        require(manager.previewDeposit(100 ether) == 100 ether);
    }

    function testPreviewWithdraw() public {
        testDeposit();

        require(manager.previewWithdraw(100 ether) == 100 ether);
    }

    function testPreviewRedeem() public {
        testDeposit();

        require(manager.previewWithdraw(100 ether) == 100 ether);
    }

    function testMaxDeposit() public {
        require(manager.maxDeposit(address(0)) == 0);
        
        hermes.mint(address(this), 1000 ether);
        hermes.approve(address(_bHermes), 1000 ether);
        _bHermes.deposit(1000 ether, address(this));

        _bHermes.transfer(address(manager), 1000 ether);

        require(manager.maxDeposit(address(0)) == 1000 ether);
    }

    function testMaxMint() public {
        require(manager.maxMint(address(0)) == 0);

        hermes.mint(address(this), 1000 ether);
        hermes.approve(address(_bHermes), 1000 ether);
        _bHermes.deposit(1000 ether, address(this));

        _bHermes.transfer(address(manager), 1000 ether);

        require(manager.maxDeposit(address(0)) == 1000 ether);
    }

    function testMaxWithdraw() public {
        testDeposit();
        require(manager.maxWithdraw(address(this)) == 100 ether);
    }

    function maxRedeem() public {
        require(manager.maxRedeem(address(this)) == 100 ether);
    }

    // /*///////////////////////////////////////////////////////////////
    //                          ERC20 LOGIC
    // //////////////////////////////////////////////////////////////*/

    function testTransfer() public {
        testDeposit();
        manager.transfer(address(2), 100 ether);
        assertEq(manager.balanceOf(address(this)), 0);
        assertEq(manager.balanceOf(address(2)), 100 ether);
    }

    function testTransferFailed() public {
        testDeposit();
        console2.log(_bHermes.gaugeWeight().balanceOf(address(vault)));
        manager.claimWeight(1);
        _bHermes.gaugeWeight().transfer(address(2), 1);
        hevm.stopPrank();
        assertEq(_bHermes.gaugeWeight().balanceOf(address(2)), 1);
        hevm.expectRevert(abi.encodeWithSignature("InsufficientUnderlying()")); 
        _bHermes.transfer(address(3), 100 ether);
    }

    function xtestTransfer() public {
        // uint256 userBalance = balanceOf[msg.sender];

        // if (
        //     userBalance - userClaimedWeight[msg.sender] < amount || userBalance - userClaimedBoost[msg.sender] < amount
        //         || userBalance - userClaimedGovernance[msg.sender] < amount
        // ) revert InsufficientUnderlying();

        // accrueUser(msg.sender);
        // accrueUser(to);
        // return super.transfer(to, amount);
    }

    // function testTransferFrom() public {
    //     // uint256 userBalance = balanceOf[msg.sender];

    //     // if (
    //     //     userBalance - userClaimedWeight[from] < amount || userBalance - userClaimedBoost[from] < amount
    //     //         || userBalance - userClaimedGovernance[from] < amount
    //     // ) revert InsufficientUnderlying();

    //     // accrueUser(from);
    //     // accrueUser(to);
    //     // return super.transferFrom(from, to, amount);
    // }

    // /*//////////////////////////////////////////////////////////////
    //                     CONVERSION RATE LOGIC
    // //////////////////////////////////////////////////////////////*/

    // function testAccrueUser() public {
    //     // load indices
    //     // uint256 _index = ONE * bHermesRate;
    //     // uint256 _userIndex = userRate[user];
    //     // // sync user index to glo56l
    //     // userRate[user] = _index;

    //     // if user hasn't yet accrued rewards, grant them interest from the strategy beginning if they have a balance
    //     // private balances will have no effect other than syncing to global index
    //     // if (_userIndex == 0) {
    //     //     _userIndex = ONE;
    //     // }

    //     // uint256 deltaIndex = _index - _userIndex;

    //     // accumulate rewards by multiplying user tokens by rewardsPerToken index and adding on unclaimed
    //     // uint256 userDelta = (balanceOf[user] * deltaIndex) / ONE;
    //     // userAccrued = rewardsAccrued[user] + userDelta;

    //     // rewardsAccrued[user] = userAccrued;

    //     // emit AccrueRewards(user, userDelta, userAccrued);
    // }

    // function testClaimRewards() public {
    //     // uint256 accrued = rewardsAccrued[user];

    //     // if (accrued != 0) {
    //     // rewardsAccrued[user] = 0;

    //     // _mint(user, accrued);

    //     // emit ClaimRewards(user, accrued);
    // }

    // /*///////////////////////////////////////////////////////////////
    //                          MIGRATION LOGIC
    // //////////////////////////////////////////////////////////////*/

    // function testMigrate() public {
    //     // if (factory.partnerIds(to) == 0) revert UnrecognizedManager();
    //     // amount = bHermesToken.balanceOf(address(this)) - totalAssets();
    //     // address(bHermesToken).safeTransferFrom(address(partnerVault), address(to), amount);
    // }

    // /*//////////////////////////////////////////////////////////////
    //                         ADMIN LOGIC
    // //////////////////////////////////////////////////////////////*/

    // function testsIncreaseConversionRate() public {
    //     // if (newRate > (bHermesToken.balanceOf(address(this)) / totalSupply)) revert InsufficientBacking();
    //     // bHermesRate = newRate;
    // }

    // function testSetPartnerVault() public {
    //     // partnerVault = _partnerVault;
    // }
}
