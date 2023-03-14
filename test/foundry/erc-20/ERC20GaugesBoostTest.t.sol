// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity ^0.8.0;

// import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
// import {console2} from "forge-std/console2.sol";
// import {MockERC20GaugesBoost} from "../mocks/MockERC20GaugesBoost.sol";
// import {ERC20Gauges} from "src/flywheel-toolkit/token/ERC20Gauges.sol";
// import {
//     MockBaseV2Gauge, FlywheelGaugeRewards, ERC20, MultiRewardsDepot, Authority
// } from "../mocks/MockBaseV2Gauge.sol";

// contract ERC20GaugesBoostTest is DSTestPlus {
//     MockERC20GaugesBoost token;
//     address gauge1;
//     address gauge2;

//     function setUp() public {
//         token = new MockERC20GaugesBoost(address(this), 3600, 600); // 1 hour cycles, 10 minute freeze

//         hevm.mockCall(address(0), abi.encodeWithSignature("rewardToken()"), abi.encode(ERC20(address(0xDEAD))));
//         hevm.mockCall(address(0), abi.encodeWithSignature("gaugeToken()"), abi.encode(ERC20Gauges(address(0xBEEF))));

//         gauge1 = address(
//             new MockBaseV2Gauge(
//                 FlywheelGaugeRewards(address(0)),
//                 address(0),
//                 address(0),
//                 Authority(address(0))
//             )
//         );
//         gauge2 = address(
//             new MockBaseV2Gauge(
//                 FlywheelGaugeRewards(address(0)),
//                 address(0),
//                 address(0),
//                 Authority(address(0))
//             )
//         );
//     }

//     /*///////////////////////////////////////////////////////////////
//                         TEST USER BOOST OPERATIONS
//     //////////////////////////////////////////////////////////////*/

//     function testIncrement(address[8] memory from, address[8] memory gauges, uint256[8] memory amounts) public {
//         token.setMaxGauges(8);
//         unchecked {
//             uint256 sum;
//             for (uint256 i = 0; i < 8; i++) {
//                 gauges[i] = address(
//                     new MockBaseV2Gauge(
//                         FlywheelGaugeRewards(address(0)),
//                         address(0),
//                         address(0),
//                         Authority(address(0))
//                     )
//                 );
//                 hevm.assume(sum + amounts[i] >= sum && !token.isGauge(gauges[i]) && gauges[i] != address(0));
//                 sum += amounts[i];

//                 token.mint(from[i], amounts[i]);

//                 uint256 userBoostBefore = token.getUserBoost(from[i]);
//                 uint256 userGaugeBoostBefore = token.getUserGaugeBoost(from[i], gauges[i]);

//                 token.addGauge(gauges[i]);
//                 hevm.prank(from[i]);
//                 token.incrementGaugeBoost(gauges[i], amounts[i]);

//                 require(token.getUserBoost(from[i]) == userBoostBefore + amounts[i]);
//                 require(token.getUserGaugeBoost(from[i], gauges[i]) == userGaugeBoostBefore + amounts[i]);
//             }
//         }
//     }

//     /// @notice test incrementing over user max
//     function testIncrementOverMax() public {
//         token.mint(address(this), 2e18);

//         token.setMaxGauges(1);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         token.incrementGaugeBoost(gauge1, 1e18);
//         hevm.expectRevert(abi.encodeWithSignature("MaxGaugeError()"));
//         token.incrementGaugeBoost(gauge2, 1e18);
//     }

//     /// @notice test incrementing at user max
//     function testIncrementAtMax() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(1);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         token.incrementGaugeBoost(gauge1, 1e18);
//         token.incrementGaugeBoost(gauge1, 1e18);

//         require(token.getUserGaugeBoost(address(this), gauge1) == 2e18);
//         require(token.getUserBoost(address(this)) == 2e18);
//     }

//     /// @notice test incrementing over user max
//     function testIncrementOverMaxApproved(address[8] memory gauges, uint256[8] memory amounts, uint8 max) public {
//         token.setMaxGauges(max % 8);
//         token.setContractExceedMaxGauges(address(this), true);

//         unchecked {
//             uint256 sum;
//             for (uint256 i = 0; i < 8; i++) {
//                 gauges[i] = address(
//                     new MockBaseV2Gauge(
//                         FlywheelGaugeRewards(address(0)),
//                         address(0),
//                         address(0),
//                         Authority(address(0))
//                     )
//                 );
//                 hevm.assume(sum + amounts[i] >= sum && !token.isGauge(gauges[i]) && gauges[i] != address(0));
//                 sum += amounts[i];

//                 token.mint(address(this), amounts[i]);

//                 uint256 userGaugeBoostBefore = token.getUserGaugeBoost(address(this), gauges[i]);

//                 token.addGauge(gauges[i]);
//                 token.incrementGaugeBoost(gauges[i], amounts[i]);

//                 require(token.getUserBoost(address(this)) == sum);
//                 require(token.getUserGaugeBoost(address(this), gauges[i]) == userGaugeBoostBefore + amounts[i]);
//             }
//         }
//     }

//     function testIncrementOnDeprecated(uint256 amount) public {
//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.removeGauge(gauge1);
//         hevm.expectRevert(abi.encodeWithSignature("InvalidGaugeError()"));
//         token.incrementGaugeBoost(gauge1, amount);
//     }

//     function testIncrementOverBoost(uint256 amount) public {
//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         hevm.assume(amount != type(uint256).max);
//         token.mint(address(this), amount);

//         require(token.incrementGaugeBoost(gauge1, amount) == amount);
//         hevm.expectRevert(abi.encodeWithSignature("OverBoostError()"));
//         token.incrementGaugeBoost(gauge2, 1);
//     }

//     /// @notice test incrementing multiple gauges with different boosts after already incrementing once
//     function testIncrementGauges() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         token.incrementGaugeBoost(gauge1, 1e18);

//         address[] memory gaugeList = new address[](2);
//         uint256[] memory boosts = new uint256[](2);
//         gaugeList[0] = gauge2;
//         gaugeList[1] = gauge1;
//         boosts[0] = 2e18;
//         boosts[1] = 4e18;

//         require(token.incrementGaugesBoosts(gaugeList, boosts) == 7e18);

//         require(token.getUserGaugeBoost(address(this), gauge2) == 2e18);
//         require(token.getUserGaugeBoost(address(this), gauge1) == 5e18);
//         require(token.getUserBoost(address(this)) == 7e18);
//     }

//     function testIncrementGaugesDeprecated() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);
//         token.removeGauge(gauge2);

//         address[] memory gaugeList = new address[](2);
//         uint256[] memory boosts = new uint256[](2);
//         gaugeList[0] = gauge2;
//         gaugeList[1] = gauge1;
//         boosts[0] = 2e18;
//         boosts[1] = 4e18;
//         hevm.expectRevert(abi.encodeWithSignature("InvalidGaugeError()"));
//         token.incrementGaugesBoosts(gaugeList, boosts);
//     }

//     function testIncrementGaugesOver() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         address[] memory gaugeList = new address[](2);
//         uint256[] memory boosts = new uint256[](2);
//         gaugeList[0] = gauge2;
//         gaugeList[1] = gauge1;
//         boosts[0] = 50e18;
//         boosts[1] = 51e18;
//         hevm.expectRevert(abi.encodeWithSignature("OverBoostError()"));
//         token.incrementGaugesBoosts(gaugeList, boosts);
//     }

//     function testIncrementGaugesSizeMismatch() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);
//         token.removeGauge(gauge2);

//         address[] memory gaugeList = new address[](2);
//         uint256[] memory boosts = new uint256[](3);
//         gaugeList[0] = gauge2;
//         gaugeList[1] = gauge1;
//         boosts[0] = 1e18;
//         boosts[1] = 2e18;
//         hevm.expectRevert(abi.encodeWithSignature("SizeMismatchError()"));
//         token.incrementGaugesBoosts(gaugeList, boosts);
//     }

//     /// @notice test decrement twice, 2 tokens each after incrementing by 4.
//     function testDecrement() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         require(token.incrementGaugeBoost(gauge1, 4e18) == 4e18);

//         require(token.decrementGaugeBoost(gauge1, 2e18) == 2e18);
//         require(token.getUserGaugeBoost(address(this), gauge1) == 2e18);
//         require(token.getUserBoost(address(this)) == 2e18);

//         require(token.decrementGaugeBoost(gauge1, 2e18) == 0);
//         require(token.getUserGaugeBoost(address(this), gauge1) == 0);
//         require(token.getUserBoost(address(this)) == 0);
//     }

//     /// @notice test decrement all removes user gauge.
//     function testDecrementAllRemovesGauge() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         require(token.incrementGaugeBoost(gauge1, 4e18) == 4e18);

//         require(token.numUserBoostedGauges(address(this)) == 1);
//         require(token.userBoostedGauges(address(this))[0] == gauge1);

//         require(token.decrementGaugeBoost(gauge1, 4e18) == 0);

//         require(token.numUserBoostedGauges(address(this)) == 0);
//     }

//     function testDecrementOverBoost(uint256 amount) public {
//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         token.mint(address(this), amount);

//         hevm.assume(amount != type(uint256).max);

//         require(token.incrementGaugeBoost(gauge1, amount) == amount);
//         hevm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 17));
//         token.decrementGaugeBoost(gauge1, amount + 1);
//     }

//     function testDecrementGauges() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         token.incrementGaugeBoost(gauge1, 1e18);

//         address[] memory gaugeList = new address[](2);
//         uint256[] memory boosts = new uint256[](2);
//         gaugeList[0] = gauge2;
//         gaugeList[1] = gauge1;
//         boosts[0] = 2e18;
//         boosts[1] = 4e18;

//         require(token.incrementGaugesBoosts(gaugeList, boosts) == 7e18);

//         boosts[1] = 2e18;
//         require(token.decrementGaugesBoosts(gaugeList, boosts) == 3e18);

//         require(token.getUserGaugeBoost(address(this), gauge2) == 0);
//         require(token.getUserGaugeBoost(address(this), gauge1) == 3e18);
//         require(token.getUserBoost(address(this)) == 3e18);
//     }

//     function testDecrementGaugesOver() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         address[] memory gaugeList = new address[](2);
//         uint256[] memory boosts = new uint256[](2);
//         gaugeList[0] = gauge2;
//         gaugeList[1] = gauge1;
//         boosts[0] = 5e18;
//         boosts[1] = 5e18;

//         require(token.incrementGaugesBoosts(gaugeList, boosts) == 10e18);

//         boosts[1] = 10e18;
//         hevm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 17));
//         token.decrementGaugesBoosts(gaugeList, boosts);
//     }

//     function testDecrementGaugesSizeMismatch() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         address[] memory gaugeList = new address[](2);
//         uint256[] memory boosts = new uint256[](2);
//         gaugeList[0] = gauge2;
//         gaugeList[1] = gauge1;
//         boosts[0] = 1e18;
//         boosts[1] = 2e18;

//         require(token.incrementGaugesBoosts(gaugeList, boosts) == 3e18);
//         hevm.expectRevert(abi.encodeWithSignature("SizeMismatchError()"));
//         token.decrementGaugesBoosts(gaugeList, new uint256[](0));
//     }

//     /*///////////////////////////////////////////////////////////////
//                             TEST ERC20 LOGIC
//     //////////////////////////////////////////////////////////////*/

//     function testDecrementUntilFreeWhenFree() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         require(token.incrementGaugeBoost(gauge1, 10e18) == 10e18);
//         require(token.incrementGaugeBoost(gauge2, 20e18) == 30e18);
//         require(token.userUnusedBoost(address(this)) == 70e18);

//         token.burn(address(this), 50e18);
//         require(token.userUnusedBoost(address(this)) == 20e18);

//         require(token.getUserGaugeBoost(address(this), gauge1) == 10e18);
//         require(token.getUserBoost(address(this)) == 30e18);
//         require(token.getUserGaugeBoost(address(this), gauge2) == 20e18);
//     }

//     function testDecrementUntilFreeSingle() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         require(token.incrementGaugeBoost(gauge1, 10e18) == 10e18);
//         require(token.incrementGaugeBoost(gauge2, 20e18) == 30e18);
//         require(token.userUnusedBoost(address(this)) == 70e18);

//         token.transfer(address(1), 80e18);
//         require(token.userUnusedBoost(address(this)) == 0);

//         require(token.getUserGaugeBoost(address(this), gauge1) == 0);
//         require(token.getUserBoost(address(this)) == 20e18);
//         require(token.getUserGaugeBoost(address(this), gauge2) == 20e18);
//     }

//     function testDecrementUntilFreeDouble() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         require(token.incrementGaugeBoost(gauge1, 10e18) == 10e18);
//         require(token.incrementGaugeBoost(gauge2, 20e18) == 30e18);
//         require(token.userUnusedBoost(address(this)) == 70e18);

//         token.approve(address(1), 100e18);
//         hevm.prank(address(1));
//         token.transferFrom(address(this), address(1), 90e18);

//         require(token.userUnusedBoost(address(this)) == 10e18);

//         require(token.getUserGaugeBoost(address(this), gauge1) == 0);
//         require(token.getUserBoost(address(this)) == 0);
//         require(token.getUserGaugeBoost(address(this), gauge2) == 0);
//     }

//     function testDecrementUntilFreeDeprecated() public {
//         token.mint(address(this), 100e18);

//         token.setMaxGauges(2);
//         token.addGauge(gauge1);
//         token.addGauge(gauge2);

//         require(token.incrementGaugeBoost(gauge1, 10e18) == 10e18);
//         require(token.incrementGaugeBoost(gauge2, 20e18) == 30e18);
//         require(token.userUnusedBoost(address(this)) == 70e18);

//         token.removeGauge(gauge1);

//         token.burn(address(this), 100e18);

//         require(token.userUnusedBoost(address(this)) == 0);

//         require(token.getUserGaugeBoost(address(this), gauge1) == 0);
//         require(token.getUserBoost(address(this)) == 0);
//         require(token.getUserGaugeBoost(address(this), gauge2) == 0);
//     }
// }
