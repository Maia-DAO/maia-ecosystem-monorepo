//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;
//TEST
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {stdError} from "forge-std/StdError.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

//COMPONENTS
import {RootPort} from "@omni/RootPort.sol";
import {ArbitrumBranchPort} from "@omni/ArbitrumBranchPort.sol";

import {RootBridgeAgent, WETH9} from "./mocks/MockRootBridgeAgent.t.sol";
import {BranchBridgeAgent} from "./mocks/MockBranchBridgeAgent.t.sol";
import {ArbitrumBranchBridgeAgent} from "@omni/ArbitrumBranchBridgeAgent.sol";

import {BaseBranchRouter} from "@omni/BaseBranchRouter.sol";
import {MulticallRootRouter} from "@omni/MulticallRootRouter.sol";
import {CoreRootRouter} from "@omni/CoreRootRouter.sol";
import {ArbitrumCoreBranchRouter} from "@omni/ArbitrumCoreBranchRouter.sol";

import {ERC20hTokenRoot} from "@omni/token/ERC20hTokenRoot.sol";
import {ERC20hTokenRootFactory} from "@omni/factories/ERC20hTokenRootFactory.sol";
import {ERC20hTokenBranchFactory} from "@omni/factories/ERC20hTokenBranchFactory.sol";
import {RootBridgeAgentFactory} from "@omni/factories/RootBridgeAgentFactory.sol";
import {BranchBridgeAgentFactory} from "@omni/factories/BranchBridgeAgentFactory.sol";
import {ArbitrumBranchBridgeAgentFactory} from "@omni/factories/ArbitrumBranchBridgeAgentFactory.sol";

//UTILS
import {DepositParams, DepositMultipleParams} from "./mocks/MockRootBridgeAgent.t.sol";
import {Deposit, DepositStatus, DepositMultipleInput, DepositInput} from "@omni/interfaces/IBranchRouter.sol";

import {WETH9 as WETH} from "./mocks/WETH9.sol";
import {Multicall2} from "@omni/lib/Multicall2.sol";
import {RLPDecoder} from "@rlp/RLPDecoder.sol";

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external;
}

contract MockPool is Test {
    struct SwapCallbackData {
        address tokenIn;
    }

    address wrappedNativeTokenAddress;

    constructor(address _wrappedNativeTokenAddress) {
        wrappedNativeTokenAddress = _wrappedNativeTokenAddress;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        SwapCallbackData memory _data = abi.decode(data, (SwapCallbackData));
        address tokenOut = (_data.tokenIn != wrappedNativeTokenAddress ? _data.tokenIn : wrappedNativeTokenAddress);
        // hevm.deal(msg.sender)
        deal(address(this), uint256(amountSpecified));
        WETH(wrappedNativeTokenAddress).deposit{value: uint256(amountSpecified)}();
        MockERC20(wrappedNativeTokenAddress).transfer(msg.sender, uint256(amountSpecified));

        console2.log(MockERC20(tokenOut).balanceOf(msg.sender));
        console2.log("asdsadsa");
        console2.log(amountSpecified);

        if (zeroForOne) {
            amount1 = amountSpecified;
        } else {
            amount0 = amountSpecified;
        }
        console2.log("ugh");

        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
        console2.log("asdsadsa");
    }

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        return (100, 0, 0, 0, 0, 0, true);
    }
}

contract CoreRootBridgeAgentTest is DSTestPlus {
    MockERC20 wAvaxLocalhToken;

    MockERC20 wAvaxUnderlyingNativeToken;

    MockERC20 rewardToken;

    MockERC20 arbAssetToken;

    ERC20hTokenRoot testToken;

    ERC20hTokenRootFactory hTokenFactory;

    RootPort rootPort;

    CoreRootRouter rootCoreRouter;

    MulticallRootRouter rootMulticallRouter;

    RootBridgeAgentFactory bridgeAgentFactory;

    RootBridgeAgent coreBridgeAgent;

    RootBridgeAgent multicallBridgeAgent;

    ArbitrumBranchPort localPortAddress;

    ArbitrumCoreBranchRouter arbitrumCoreRouter;

    BaseBranchRouter arbitrumMulticallRouter;

    ArbitrumBranchBridgeAgent arbitrumCoreBridgeAgent;

    ArbitrumBranchBridgeAgent arbitrumMulticallBridgeAgent;

    ERC20hTokenBranchFactory localHTokenFactory;

    ArbitrumBranchBridgeAgentFactory localBranchBridgeAgentFactory;

    uint24 rootChainId = uint24(42161);

    uint24 avaxChainId = uint24(1088);

    uint24 ftmChainId = uint24(2040);

    address wrappedNativeToken;

    address multicallAddress;

    address testGasPoolAddress = address(0xFFFF);

    address nonFungiblePositionManagerAddress = address(0xABAD);

    address avaxLocalWrappedNativeTokenAddress = address(0xBFFF);
    address avaxUnderlyingWrappedNativeTokenAddress = address(0xFFFB);

    address ftmLocalWrappedNativeTokenAddress = address(0xABBB);
    address ftmUnderlyingWrappedNativeTokenAddress = address(0xAAAB);

    address avaxCoreBridgeAgentAddress = address(0xBEEF);

    address avaxMulticallBridgeAgentAddress = address(0xEBFE);

    address avaxPortAddress = address(0xFEEB);

    address ftmCoreBridgeAgentAddress = address(0xCACA);

    address ftmMulticallBridgeAgentAddress = address(0xACAC);

    address ftmPortAddressM = address(0xABAC);

    address localAnyCallAddress = address(0xCAFE);

    address localAnyCongfig = address(0xCAFF);

    address localAnyCallExecutorAddress = address(0xABCD);

    address owner = address(this);

    address dao = address(this);

    function setUp() public {
        //Mock calls
        hevm.mockCall(
            localAnyCallAddress, abi.encodeWithSignature("executor()"), abi.encode(localAnyCallExecutorAddress)
        );

        hevm.mockCall(localAnyCallAddress, abi.encodeWithSignature("config()"), abi.encode(localAnyCongfig));

        //Deploy Root Utils
        wrappedNativeToken = address(new WETH());

        multicallAddress = address(new Multicall2());

        //Deploy Root Contracts
        rootPort = new RootPort(rootChainId, wrappedNativeToken);

        bridgeAgentFactory = new RootBridgeAgentFactory(
            rootChainId,
            WETH9(wrappedNativeToken),
            localAnyCallAddress,
            address(rootPort),
            dao
        );

        rootCoreRouter = new CoreRootRouter(rootChainId, wrappedNativeToken, address(rootPort));

        rootMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        hTokenFactory = new ERC20hTokenRootFactory(rootChainId, address(rootPort));

        //Initialize Root Contracts
        rootPort.initialize(address(bridgeAgentFactory), address(rootCoreRouter));

        hevm.deal(address(rootPort), 1 ether);
        hevm.prank(address(rootPort));
        WETH(wrappedNativeToken).deposit{value: 1 ether}();

        hTokenFactory.initialize(address(rootCoreRouter));

        coreBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(rootCoreRouter)))
        );

        multicallBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(rootMulticallRouter)))
        );

        rootCoreRouter.initialize(address(coreBridgeAgent), address(hTokenFactory));

        rootMulticallRouter.initialize(address(multicallBridgeAgent));

        // Deploy Local Branch Contracts
        localPortAddress = new ArbitrumBranchPort(rootChainId, address(rootPort), owner);

        arbitrumMulticallRouter = new BaseBranchRouter();

        arbitrumCoreRouter = new ArbitrumCoreBranchRouter(address(0), address(localPortAddress));

        localBranchBridgeAgentFactory = new ArbitrumBranchBridgeAgentFactory(
            rootChainId,
            WETH9(wrappedNativeToken),
            localAnyCallAddress,
            localAnyCallExecutorAddress,
            address(arbitrumCoreRouter),
            address(localPortAddress),
            owner
        );

        localPortAddress.initialize(address(arbitrumCoreRouter), address(localBranchBridgeAgentFactory));

        arbitrumCoreBridgeAgent = ArbitrumBranchBridgeAgent(
            payable(
                localBranchBridgeAgentFactory.createBridgeAgent(address(arbitrumCoreRouter), address(coreBridgeAgent))
            )
        );
        console2.log("wqWWWWWWWWWWWWWWWWW");
        console2.log(localPortAddress.coreBranchRouterAddress());

        arbitrumMulticallBridgeAgent = ArbitrumBranchBridgeAgent(
            payable(
                localBranchBridgeAgentFactory.createBridgeAgent(
                    address(arbitrumMulticallRouter), address(rootMulticallRouter)
                )
            )
        );

        arbitrumCoreRouter.initialize(address(arbitrumCoreBridgeAgent));
        arbitrumMulticallRouter.initialize(address(arbitrumMulticallBridgeAgent));

        // Deploy Remote Branchs Contracts

        //////////////////////////////////

        //Sync Root with new branches

        rootPort.initializeCore(address(coreBridgeAgent), address(arbitrumCoreBridgeAgent), address(localPortAddress));

        coreBridgeAgent.approveBranchBridgeAgent(avaxCoreBridgeAgentAddress, avaxChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(avaxMulticallBridgeAgentAddress, avaxChainId);

        coreBridgeAgent.approveBranchBridgeAgent(ftmCoreBridgeAgentAddress, ftmChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(ftmMulticallBridgeAgentAddress, ftmChainId);

        hevm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            avaxCoreBridgeAgentAddress, address(coreBridgeAgent), avaxChainId
        );

        hevm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            avaxMulticallBridgeAgentAddress, address(multicallBridgeAgent), avaxChainId
        );

        hevm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            ftmCoreBridgeAgentAddress, address(coreBridgeAgent), ftmChainId
        );

        hevm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            ftmMulticallBridgeAgentAddress, address(multicallBridgeAgent), ftmChainId
        );

        //Mock calls
        hevm.mockCall(
            nonFungiblePositionManagerAddress,
            abi.encodeWithSignature(
                "createAndInitializePoolIfNecessary(address,address,uint24,uint160)",
                0x45C92C2Cd0dF7B2d705EF12CfF77Cb0Bc557Ed22,
                wrappedNativeToken,
                uint24(100),
                uint160(200)
            ),
            abi.encode(address(new MockPool(wrappedNativeToken)))
        );

        RootPort(rootPort).addNewChain(
            avaxChainId,
            "Avalanche",
            "AVAX",
            100,
            50,
            200,
            nonFungiblePositionManagerAddress,
            avaxLocalWrappedNativeTokenAddress,
            avaxUnderlyingWrappedNativeTokenAddress,
            address(hTokenFactory)
        );

        //Mock calls
        hevm.mockCall(
            nonFungiblePositionManagerAddress,
            abi.encodeWithSignature(
                "createAndInitializePoolIfNecessary(address,address,uint24,uint160)",
                wrappedNativeToken,
                0x9914ff9347266f1949C557B717936436402fc636,
                uint24(100),
                uint160(200)
            ),
            abi.encode(address(new MockPool(wrappedNativeToken)))
        );

        RootPort(rootPort).addNewChain(
            ftmChainId,
            "Fantom Opera",
            "FTM",
            100,
            50,
            200,
            nonFungiblePositionManagerAddress,
            ftmLocalWrappedNativeTokenAddress,
            ftmUnderlyingWrappedNativeTokenAddress,
            address(hTokenFactory)
        );

        testToken = new ERC20hTokenRoot(
            rootChainId,
            address(bridgeAgentFactory),
            address(rootPort),
            "Hermes Global hToken 1",
            "hGT1"
        );

        wAvaxLocalhToken = new MockERC20("hAVAX-AVAX", "LOCAL hTOKEN FOR AVAX IN AVAX", 18);

        wAvaxUnderlyingNativeToken = new MockERC20("underlying token", "UNDER", 18);

        rewardToken = new MockERC20("hermes token", "HERMES", 18);
        arbAssetToken = new MockERC20("A", "AAA", 18);
    }

    address public newGlobalAddress;

    function testAddLocalToken() public {
        //Encode Data
        bytes memory data =
            abi.encode(address(wAvaxUnderlyingNativeToken), address(wAvaxLocalhToken), "UnderLocal Coin", "UL");

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

        //Call Deposit function
        encodeSystemCall(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.00005 ether,
            0,
            avaxChainId
        );

        newGlobalAddress = RootPort(rootPort).getGlobalTokenFromLocal(address(wAvaxLocalhToken), avaxChainId);

        console2.log("New: ", newGlobalAddress);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(wAvaxLocalhToken), avaxChainId) != address(0),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newGlobalAddress, avaxChainId) == address(wAvaxLocalhToken),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(wAvaxLocalhToken), avaxChainId)
                == address(wAvaxUnderlyingNativeToken),
            "Token should be added"
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);

        // require (balanceBefore == MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent)), "Balance should not change");
    }

    function testAddLocalTokenAlreadyAdded() public {
        //Add once
        testAddLocalToken();

        //Encode Data
        bytes memory data =
            abi.encode(address(wAvaxUnderlyingNativeToken), address(wAvaxLocalhToken), "UnderLocal Coin", "UL");

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

        //Expect revert
        hevm.expectRevert(abi.encodeWithSignature("TokenAlreadyAdded()"));

        //Call Deposit function
        encodeSystemCall(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.00005 ether,
            0,
            avaxChainId
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);

        // require (balanceBefore == MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent)), "Balance should not change");
    }

    function testAddLocalTokenNotEnoughGas() public {
        //Encode Data
        bytes memory data =
            abi.encode(address(wAvaxUnderlyingNativeToken), address(wAvaxLocalhToken), "UnderLocal Coin", "UL");

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        //Expect revert
        hevm.expectRevert(abi.encodeWithSignature("InsufficientGasForFees()"));

        //Call Deposit function
        encodeSystemCall(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            200,
            0,
            avaxChainId
        );
    }

    function testAddLocalTokenFromArbitrum() public {
        //Encode Data
        bytes memory data = abi.encode(address(arbAssetToken));

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

        hevm.deal(address(this), 0.00005 ether);

        arbitrumCoreRouter.addLocalToken{value: 0.00005 ether}(address(arbAssetToken));

        newGlobalAddress = RootPort(rootPort).getLocalTokenFromUnder(address(arbAssetToken), rootChainId);

        console2.log("New: ", newGlobalAddress);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(newGlobalAddress), rootChainId)
                == address(newGlobalAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newGlobalAddress, rootChainId) == address(newGlobalAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(newGlobalAddress), rootChainId)
                == address(arbAssetToken),
            "Token should be added"
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);

        // require (balanceBefore == MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent)), "Balance should not change");
    }

    function testAddGlobalToken() public {
        //Add Local Token from Avax
        testAddLocalToken();

        //Encode Call Data
        bytes memory data = abi.encode(ftmCoreBridgeAgentAddress, newGlobalAddress, ftmChainId, 0.0005 ether);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

        //Call Deposit function
        encodeSystemCall(
            payable(ftmCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.00005 ether,
            0,
            ftmChainId
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);

        // require (balanceBefore == MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent)), "Balance should not change");
    }

    function testAddGlobalTokenAlreadyAdded() public {
        //Add Local Token from Avax
        testAddGlobalToken();

        //Encode Call Data
        bytes memory data = abi.encode(ftmCoreBridgeAgentAddress, newGlobalAddress, avaxChainId, 0.0005 ether);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

        //Call Deposit function
        encodeSystemCall(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.00005 ether,
            0,
            avaxChainId
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);

        // require (balanceBefore == MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent)), "Balance should not change");
    }

    function testAddGlobalTokenNotEnoughGas() public {
        //Add Local Token from Avax
        testAddLocalToken();

        //Encode Call Data
        bytes memory data = abi.encode(ftmCoreBridgeAgentAddress, newGlobalAddress, avaxChainId, 200);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

        //Call Deposit function
        encodeSystemCall(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.00005 ether,
            0,
            avaxChainId
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);

        // require (balanceBefore == MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent)), "Balance should not change");
    }

    address public newLocalToken = address(0xFAFA);

    function testSetLocalToken() public {
        //Add Local Token from Avax
        testAddGlobalToken();

        //Encode Data
        bytes memory data = abi.encode(newGlobalAddress, newLocalToken, "UnderLocal Coin", "UL");

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x03), data);

        uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

        //Call Deposit function
        encodeSystemCall(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.00001 ether,
            0,
            avaxChainId
        );

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(newLocalToken, avaxChainId) == newGlobalAddress,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newGlobalAddress, avaxChainId) == newLocalToken,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(newLocalToken), avaxChainId) == address(0),
            "Token should be added"
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);
        // require (balanceBefore == MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent)), "Balance should not change");
    }

    // function testAddGlobalTokenAlreadyAdded() public {
    //     //Add once
    //     testAddGlobalToken();

    //     //Encode Data
    //     bytes memory data = abi.encode(
    //         address(wAvaxUnderlyingNativeToken),
    //         address(wAvaxLocalhToken),
    //         "UnderLocal Coin",
    //         "UL"
    //     );

    //     //Pack FuncId
    //     bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

    //     uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

    //     //Expect revert
    //     hevm.expectRevert(abi.encodeWithSignature("TokenAlreadyAdded()"));

    //     //Call Deposit function
    //     encodeSystemCall(
    //         payable(address(coreBridgeAgent)),
    //         uint32(1),
    //         packedData,
    //         0.00005 ether,
    //         0
    //     );

    //     console2.log("Balance Before: ", balanceBefore);
    //     console2.log("Balance After: ", address(coreBridgeAgent).balance);

    //     // require (balanceBefore == MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent)), "Balance should not change");
    // }

    // function testAddGlobalTokenNotEnoughGas() public {
    //     //Encode Data
    //     bytes memory data = abi.encode(
    //         address(wAvaxUnderlyingNativeToken),
    //         address(wAvaxLocalhToken),
    //         "UnderLocal Coin",
    //         "UL"
    //     );

    //     //Pack FuncId
    //     bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

    //     //Expect revert
    //     hevm.expectRevert(abi.encodeWithSignature("InsufficientGasForFees()"));

    //     //Call Deposit function
    //     encodeSystemCall(payable(address(coreBridgeAgent)), uint32(1), packedData, 200, 0);
    // }

    // function testCallOutWithDeposit() public {
    //     //Get some gas.
    //     hevm.deal(address(this), 1 ether);

    //     //Mint Test tokens.
    //     wAvaxUnderlyingNativeToken.mint(address(this), 100 ether);

    //     //Approve spend by router
    //     wAvaxUnderlyingNativeToken.approve(rootPort, 100 ether);

    //     console2.logUint(1);
    //     console2.log(address(testToken), address(wAvaxUnderlyingNativeToken));

    //     //Prepare deposit info
    //     DepositInput memory depositInput = DepositInput({
    //         hToken: address(testToken),
    //         token: address(wAvaxUnderlyingNativeToken),
    //         amount: 100 ether,
    //         deposit: 100 ether,
    //         toChain: rootChainId
    //     });

    //     //Call Deposit function
    //     CoreRootBridgeAgent(coreBridgeAgent).callOutAndBridge{ value: 1 ether }(
    //         bytes("test"),
    //         depositInput,
    //         0.5 ether
    //     );

    //     //Test If Deposit was successful
    //     testCreateDepositSingle(
    //         uint32(1),
    //         address(this),
    //         address(testToken),
    //         address(wAvaxUnderlyingNativeToken),
    //         100 ether,
    //         100 ether,
    //         1 ether
    //     );
    // }

    // function testCallOutInsufficientAmount() public {
    //     //Get some gas.
    //     hevm.deal(address(this), 1 ether);

    //     //Mint Test tokens.
    //     wAvaxUnderlyingNativeToken.mint(address(this), 90 ether);

    //     //Approve spend by router
    //     wAvaxUnderlyingNativeToken.approve(rootPort, 100 ether);

    //     console2.logUint(1);
    //     console2.log(address(testToken), address(wAvaxUnderlyingNativeToken));

    //     //Prepare deposit info
    //     DepositInput memory depositInput = DepositInput({
    //         hToken: address(testToken),
    //         token: address(wAvaxUnderlyingNativeToken),
    //         amount: 100 ether,
    //         deposit: 100 ether,
    //         toChain: rootChainId
    //     });

    //     hevm.expectRevert(abi.encodeWithSignature("TransferFromFailed()"));

    //     //Call Deposit function
    //     CoreRootBridgeAgent(coreBridgeAgent).callOutAndBridge{ value: 1 ether }(
    //         bytes("test"),
    //         depositInput,
    //         0.5 ether
    //     );
    // }

    // function testCallOutIncorrectAmount() public {
    //     //Get some gas.
    //     hevm.deal(address(this), 1 ether);

    //     //Mint Test tokens.
    //     wAvaxUnderlyingNativeToken.mint(address(this), 100 ether);

    //     //Approve spend by router
    //     wAvaxUnderlyingNativeToken.approve(rootPort, 100 ether);

    //     console2.logUint(1);
    //     console2.log(address(testToken), address(wAvaxUnderlyingNativeToken));

    //     //Prepare deposit info
    //     DepositInput memory depositInput = DepositInput({
    //         hToken: address(testToken),
    //         token: address(wAvaxUnderlyingNativeToken),
    //         amount: 90 ether,
    //         deposit: 100 ether,
    //         toChain: rootChainId
    //     });

    //     hevm.expectRevert(stdError.arithmeticError);

    //     //Call Deposit function
    //     CoreRootBridgeAgent(coreBridgeAgent).callOutAndBridge{ value: 1 ether }(
    //         bytes("test"),
    //         depositInput,
    //         0.5 ether
    //     );
    // }

    // function testFuzzCallOutWithDeposit(
    //     address _user,
    //     uint256 _amount,
    //     uint256 _deposit,
    //     uint256 _toChain
    // ) public {
    //     // Input restrictions
    //     hevm.assume(_user != address(0) && _amount > 0 && _amount > _deposit && _toChain > 0);

    //     //Get some gas.
    //     hevm.deal(_user, 1 ether);

    //     // Prank into Port
    //     hevm.startPrank(rootPort);

    //     // Mint Test tokens.
    //     ERC20hTokenRoot fuzzToken = new ERC20hTokenRoot("fuzz token", "FUZZ", rootPort);
    //     fuzzToken.mint(_user, _amount - _deposit);

    //     // Mint under tokens.
    //     ERC20hTokenRoot uunderToken = new ERC20hTokenRoot("uunder token", "UU", rootPort);
    //     uunderToken.mint(_user, _deposit);

    //     hevm.stopPrank();

    //     //Prepare deposit info
    //     DepositInput memory depositInput = DepositInput({
    //         hToken: address(fuzzToken),
    //         token: address(uunderToken),
    //         amount: _amount,
    //         deposit: _deposit,
    //         toChain: rootChainId
    //     });

    //     // Prank into user account
    //     hevm.startPrank(_user);

    //     // Approve spend by router
    //     fuzzToken.approve(rootPort, _amount);
    //     uunderToken.approve(rootPort, _deposit);

    //     //Call Deposit function
    //     CoreRootBridgeAgent(coreBridgeAgent).callOutAndBridge{ value: 1 ether }(
    //         bytes("testdata"),
    //         depositInput,
    //         0.5 ether
    //     );

    //     // Prank out of user account
    //     hevm.stopPrank();

    //     // Test If Deposit was successful
    //     testCreateDepositSingle(
    //         uint32(1),
    //         _user,
    //         address(fuzzToken),
    //         address(uunderToken),
    //         _amount,
    //         _deposit,
    //         1 ether
    //     );
    // }

    // function testClearDeposit() public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(avaxCoreBridgeAgentAddress, rootChainId, 22)
    //     );

    //     // Create Test Deposit
    //     testCallOutWithDeposit();

    //     //Prepare deposit info
    //     DepositParams memory depositParams = DepositParams({
    //         hToken: address(testToken),
    //         token: address(wAvaxUnderlyingNativeToken),
    //         amount: 100 ether,
    //         deposit: 100 ether,
    //         toChain: rootChainId,
    //         depositNonce: 1,
    //         depositedGas: 1 ether
    //     });

    //     // Encode AnyFallback message
    //     bytes memory anyFallbackData = abi.encodePacked(
    //         bytes1(0x02),
    //         depositParams.depositNonce,
    //         depositParams.hToken,
    //         depositParams.token,
    //         depositParams.amount,
    //         depositParams.deposit,
    //         depositParams.toChain,
    //         bytes("testdata"),
    //         depositParams.depositedGas,
    //         depositParams.depositedGas / 2
    //     );

    //     hevm.mockCall(
    //         address(localAnyCongfig),
    //         abi.encodeWithSignature(
    //             "calcSrcFees(address,uint256,uint256)",
    //             address(0),
    //             rootChainId,
    //             anyFallbackData.length
    //         ),
    //         abi.encode(0)
    //     );

    //     // Call 'anyFallback'
    //     hevm.prank(localAnyCallExecutorAddress);
    //     coreBridgeAgent.anyFallback(anyFallbackData);

    //     //Call redeemDeposit
    //     coreBridgeAgent.redeemDeposit(1);

    //     // Check balances
    //     require(testToken.balanceOf(address(this)) == 0);
    //     require(wAvaxUnderlyingNativeToken.balanceOf(address(this)) == 100 ether);
    //     require(testToken.balanceOf(rootPort) == 0);
    //     require(wAvaxUnderlyingNativeToken.balanceOf(rootPort) == 0);
    // }

    // function testFuzzClearDeposit(
    //     address _user,
    //     uint256 _amount,
    //     uint256 _deposit,
    //     uint24 _toChain
    // ) public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(avaxCoreBridgeAgentAddress, rootChainId, 22)
    //     );

    //     // Input restrictions
    //     hevm.assume(_user != address(0) && _amount > 0 && _deposit <= _amount && _toChain > 0);

    //     hevm.startPrank(rootPort);

    //     // Mint Test tokens.
    //     ERC20hTokenRoot fuzzToken = new ERC20hTokenRoot(
    //         "Hermes omni token",
    //         "hUNDER",
    //         rootPort
    //     );
    //     fuzzToken.mint(_user, _amount - _deposit);
    //     MockERC20 underToken = new MockERC20("u token", "U", 18);
    //     underToken.mint(_user, _deposit);

    //     hevm.stopPrank();

    //     // Perform deposit
    //     makeTestCallWithDeposit(
    //         _user,
    //         address(fuzzToken),
    //         address(underToken),
    //         _amount,
    //         _deposit,
    //         _toChain,
    //         uint128(0.5 ether)
    //     );

    //     //Prepare deposit info
    //     DepositParams memory depositParams = DepositParams({
    //         hToken: address(fuzzToken),
    //         token: address(wAvaxUnderlyingNativeToken),
    //         amount: _amount,
    //         deposit: _deposit,
    //         toChain: rootChainId,
    //         depositNonce: 1,
    //         depositedGas: 1 ether
    //     });

    //     // Encode AnyFallback message
    //     bytes memory anyFallbackData = abi.encodePacked(
    //         bytes1(0x02),
    //         depositParams.depositNonce,
    //         depositParams.hToken,
    //         depositParams.token,
    //         depositParams.amount,
    //         depositParams.deposit,
    //         depositParams.toChain,
    //         bytes("testdata"),
    //         depositParams.depositedGas,
    //         depositParams.depositedGas / 2
    //     );

    //     hevm.mockCall(
    //         address(localAnyCongfig),
    //         abi.encodeWithSignature(
    //             "calcSrcFees(address,uint256,uint256)",
    //             address(0),
    //             rootChainId,
    //             anyFallbackData.length
    //         ),
    //         abi.encode(0)
    //     );

    //     // Call 'anyFallback'
    //     hevm.prank(localAnyCallExecutorAddress);
    //     coreBridgeAgent.anyFallback(anyFallbackData);

    //     //Call redeemDeposit
    //     coreBridgeAgent.redeemDeposit(1);

    //     // Check balances
    //     require(fuzzToken.balanceOf(address(_user)) == _amount - _deposit);
    //     require(underToken.balanceOf(address(_user)) == _deposit);
    //     require(fuzzToken.balanceOf(rootPort) == 0);
    //     require(underToken.balanceOf(rootPort) == 0);
    // }

    // function testFuzzClearDeposit(
    //     address _user,
    //     uint256 _amount,
    //     uint256 _deposit,
    //     uint24 _toChain
    // ) public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(avaxCoreBridgeAgentAddress, _toChain, 22)
    //     );

    //     // Input restrictions
    //     hevm.assume(_user != address(0) && _amount > 0 && _deposit <= _amount && _toChain > 0);

    //     // Mint Test tokens.
    //     ERC20hTokenRoot fuzzToken = new ERC20hTokenRoot(
    //         "Hermes omni token",
    //         "hUNDER",
    //         rootPort
    //     );
    //     hevm.prank(rootPort);
    //     fuzzToken.mint(_user, _amount - _deposit);
    //     MockERC20 underToken = new MockERC20("u token", "U", 18);
    //     underToken.mint(_user, _deposit);

    //     // Perform deposit
    //     makeTestCallWithDeposit(
    //         _user,
    //         address(fuzzToken),
    //         address(underToken),
    //         _amount,
    //         _deposit,
    //         _toChain,
    //         uint128(0.5 ether)
    //     );

    //     // Encode Clear Token Execution Data
    //     bytes memory clearDepositData = abi.encode(bytes1(uint8(1)), uint32(1));

    //     // Call 'clearDeposit'
    //     hevm.prank(localAnyCallExecutorAddress);
    //     coreBridgeAgent.anyExecute(clearDepositData);

    //     // Check balances
    //     require(fuzzToken.balanceOf(_user) == _amount - _deposit);
    //     require(underToken.balanceOf(_user) == _deposit);
    //     require(fuzzToken.balanceOf(rootPort) == 0);
    //     require(underToken.balanceOf(rootPort) == 0);
    // }

    // function testFuzzClearToken(
    //     address _recipient,
    //     uint256 _amount,
    //     uint256 _deposit,
    //     uint24 _toChain
    // ) public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(avaxCoreBridgeAgentAddress, _toChain, 22)
    //     );

    //     // Input restrictions
    //     hevm.assume(_recipient > address(3) && _amount > 0 && _deposit <= _amount && _toChain > 0);

    //     hevm.startPrank(rootPort);

    //     // Mint Test tokens.
    //     ERC20hTokenRoot fuzzToken = new ERC20hTokenRoot(
    //         "Hermes omni token",
    //         "hUNDER",
    //         rootPort
    //     );
    //     fuzzToken.mint(_recipient, _amount - _deposit);

    //     MockERC20 underToken = new MockERC20("u token", "U", 18);
    //     underToken.mint(_recipient, _deposit);

    //     hevm.stopPrank();

    //     console2.log("DAAAAAAAATAAAAAAAAAAA");
    //     console2.log(_recipient);
    //     console2.log(address(fuzzToken));
    //     console2.log(address(underToken));
    //     console2.log(_amount);
    //     console2.log(_deposit);
    //     console2.log(_toChain);

    //     // Perform deposit
    //     makeTestCallWithDeposit(
    //         _recipient,
    //         address(fuzzToken),
    //         address(underToken),
    //         _amount,
    //         _deposit,
    //         _toChain,
    //         uint128(0.5 ether)
    //     );

    //     // // Encode Clear Token Execution Data
    //     // bytes memory clearTokenData = abi.encode(
    //     //     bytes1(0x04),
    //     //     _recipient,
    //     //     address(fuzzToken),
    //     //     address(underToken),
    //     //     _amount,
    //     //     _deposit,
    //     //     uint32(1)
    //     // );

    //     // Encode Settlement Data for Clear Token Execution
    //     bytes memory settlementData = abi.encodePacked(
    //         bytes1(0x01),
    //         _recipient,
    //         uint32(1),
    //         address(fuzzToken),
    //         address(underToken),
    //         _amount,
    //         _deposit,
    //         bytes("payload"),
    //         uint24(300000)
    //     );

    //     // Call 'clearToken'
    //     hevm.prank(localAnyCallExecutorAddress);
    //     coreBridgeAgent.anyExecute(settlementData);

    //     require(fuzzToken.balanceOf(_recipient) == _amount - _deposit);
    //     require(underToken.balanceOf(_recipient) == _deposit);
    //     require(fuzzToken.balanceOf(rootPort) == 0);
    //     require(underToken.balanceOf(rootPort) == 0);
    // }

    // address[] public hTokens;
    // address[] public tokens;
    // uint256[] public amounts;
    // uint256[] public deposits;

    // function testFuzzClearTokens(
    //     address _recipient,
    //     uint256 _amount0,
    //     uint256 _amount1,
    //     uint256 _deposit0,
    //     uint256 _deposit1,
    //     uint24 _toChain
    // ) public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(avaxCoreBridgeAgentAddress, _toChain, 22)
    //     );

    //     // Input restrictions
    //     hevm.assume(
    //         _recipient > address(3) &&
    //             _amount0 > 0 &&
    //             _deposit0 <= _amount0 &&
    //             _amount1 > 0 &&
    //             _deposit1 <= _amount1 &&
    //             _toChain > 0
    //     );

    //     hevm.startPrank(rootPort);

    //     // Mint Test tokens.
    //     ERC20hTokenRoot fuzzToken0 = new ERC20hTokenRoot(
    //         "Hermes omni token 0",
    //         "hToken0",
    //         rootPort
    //     );
    //     fuzzToken0.mint(_recipient, _amount0 - _deposit0);
    //     ERC20hTokenRoot fuzzToken1 = new ERC20hTokenRoot(
    //         "Hermes omni token 1",
    //         "hToken1",
    //         rootPort
    //     );
    //     fuzzToken1.mint(_recipient, _amount1 - _deposit1);
    //     MockERC20 underToken0 = new MockERC20("u0 token", "U0", 18);
    //     MockERC20 underToken1 = new MockERC20("u1 token", "U1", 18);
    //     underToken0.mint(_recipient, _deposit0);
    //     underToken1.mint(_recipient, _deposit1);

    //     console2.log("DAAAAAAAATAAAAAAAAAAA");
    //     console2.log(_recipient);
    //     console2.log(address(fuzzToken0));
    //     console2.log(address(fuzzToken1));
    //     console2.log(address(underToken0));
    //     console2.log(address(underToken1));
    //     console2.log(_amount0);
    //     console2.log(_amount1);
    //     console2.log(_deposit0);
    //     console2.log(_deposit1);
    //     console2.log(_toChain);

    //     hevm.stopPrank();

    //     // Cast to Dynamic
    //     hTokens.push(address(fuzzToken0));
    //     hTokens.push(address(fuzzToken1));
    //     tokens.push(address(underToken0));
    //     tokens.push(address(underToken1));
    //     amounts.push(_amount0);
    //     amounts.push(_amount1);
    //     deposits.push(_deposit0);
    //     deposits.push(_deposit1);

    //     console2.log("here");
    //     console2.log(hTokens[0], tokens[0]);
    //     console2.log(hTokens[1], tokens[1]);

    //     // Perform deposit
    //     makeTestCallWithDepositMultiple(
    //         _recipient,
    //         hTokens,
    //         tokens,
    //         amounts,
    //         deposits,
    //         _toChain,
    //         uint128(0.5 ether)
    //     );

    //     // Encode Settlement Data for Clear Token Execution
    //     bytes memory settlementData = abi.encodePacked(
    //         bytes1(0x02),
    //         _recipient,
    //         uint8(2),
    //         uint32(1),
    //         hTokens,
    //         tokens,
    //         amounts,
    //         deposits,
    //         bytes(""),
    //         uint128(0.5 ether)
    //     );

    //     hevm.mockCall(
    //         address(localAnyCongfig),
    //         abi.encodeWithSignature(
    //             "calcSrcFees(address,uint256,uint256)",
    //             address(0),
    //             rootChainId,
    //             settlementData.length
    //         ),
    //         abi.encode(100)
    //     );

    //     // Call 'clearToken'
    //     hevm.prank(localAnyCallExecutorAddress);
    //     coreBridgeAgent.anyExecute(settlementData);

    //     require(fuzzToken0.balanceOf(rootPort) == 0);
    //     require(fuzzToken1.balanceOf(rootPort) == 0);
    //     require(fuzzToken0.balanceOf(_recipient) == _amount0 - _deposit0);
    //     require(fuzzToken1.balanceOf(_recipient) == _amount1 - _deposit1);
    //     require(underToken0.balanceOf(rootPort) == 0);
    //     require(underToken1.balanceOf(rootPort) == 0);
    //     require(underToken0.balanceOf(_recipient) == _deposit0);
    //     require(underToken1.balanceOf(_recipient) == _deposit1);
    // }

    // function testCreateDeposit(
    //     uint32 _depositNonce,
    //     address _user,
    //     address[] memory _hTokens,
    //     address[] memory _tokens,
    //     uint256[] memory _amounts,
    //     uint256[] memory _deposits
    // ) private {
    //     // Get Deposit.
    //     Deposit memory deposit = coreBridgeAgent.getDepositEntry(_depositNonce);

    //     // Check deposit
    //     require(deposit.owner == _user, "Deposit owner doesn't match");

    //     require(
    //         keccak256(abi.encodePacked(deposit.hTokens)) == keccak256(abi.encodePacked(_hTokens)),
    //         "Deposit local hToken doesn't match"
    //     );
    //     require(
    //         keccak256(abi.encodePacked(deposit.tokens)) == keccak256(abi.encodePacked(_tokens)),
    //         "Deposit underlying token doesn't match"
    //     );
    //     require(
    //         keccak256(abi.encodePacked(deposit.amounts)) == keccak256(abi.encodePacked(_amounts)),
    //         "Deposit amount doesn't match"
    //     );
    //     require(
    //         keccak256(abi.encodePacked(deposit.deposits)) == keccak256(abi.encodePacked(_deposits)),
    //         "Deposit deposit doesn't match"
    //     );

    //     require(deposit.status == DepositStatus.Success, "Deposit status should be success");

    //     for (uint256 i = 0; i < _hTokens.length; i++) {
    //         if (_amounts[i] - _deposits[i] > 0 && _deposits[i] == 0) {
    //             require(MockERC20(_hTokens[i]).balanceOf(_user) == 0);
    //         } else if (_amounts[i] - _deposits[i] > 0 && _deposits[i] > 0) {
    //             require(MockERC20(_hTokens[i]).balanceOf(_user) == 0);
    //             require(MockERC20(_tokens[i]).balanceOf(_user) == 0);
    //             require(MockERC20(_tokens[i]).balanceOf(rootPort) == _deposits[i]);
    //         } else {
    //             require(MockERC20(_tokens[i]).balanceOf(_user) == 0);
    //             require(MockERC20(_tokens[i]).balanceOf(rootPort) == _deposits[i]);
    //         }
    //     }
    // }

    // function testCreateDepositSingle(
    //     uint32 _depositNonce,
    //     address _user,
    //     address _hToken,
    //     address _token,
    //     uint256 _amount,
    //     uint256 _deposit,
    //     uint128 _depositedGas
    // ) private {
    //     // Cast to Dynamic TODO clean up
    //     address[] memory hTokens = new address[](1);
    //     hTokens[0] = _hToken;
    //     address[] memory tokens = new address[](1);
    //     tokens[0] = _token;
    //     uint256[] memory amounts = new uint256[](1);
    //     amounts[0] = _amount;
    //     uint256[] memory deposits = new uint256[](1);
    //     deposits[0] = _deposit;

    //     // Get Deposit
    //     Deposit memory deposit = coreBridgeAgent.getDepositEntry(_depositNonce);

    //     console2.logUint(1);
    //     console2.log(deposit.hTokens[0], hTokens[0]);
    //     console2.log(deposit.tokens[0], tokens[0]);

    //     // Check deposit
    //     require(deposit.owner == _user, "Deposit owner doesn't match");

    //     require(
    //         keccak256(abi.encodePacked(deposit.hTokens)) == keccak256(abi.encodePacked(hTokens)),
    //         "Deposit local hToken doesn't match"
    //     );
    //     require(
    //         keccak256(abi.encodePacked(deposit.tokens)) == keccak256(abi.encodePacked(tokens)),
    //         "Deposit underlying token doesn't match"
    //     );
    //     require(
    //         keccak256(abi.encodePacked(deposit.amounts)) == keccak256(abi.encodePacked(amounts)),
    //         "Deposit amount doesn't match"
    //     );
    //     require(
    //         keccak256(abi.encodePacked(deposit.deposits)) == keccak256(abi.encodePacked(deposits)),
    //         "Deposit deposit doesn't match"
    //     );

    //     require(deposit.status == DepositStatus.Success, "Deposit status should be succesful.");

    //     console2.log("TEST DEPOSIT~");
    //     console2.logUint(deposit.depositedGas);
    //     console2.logUint(WETH9(wrappedNativeToken).balanceOf(rootPort));

    //     require(deposit.depositedGas == _depositedGas, "Deposit depositedGas doesn't match");
    //     require(
    //         WETH9(wrappedNativeToken).balanceOf(rootPort) == _depositedGas,
    //         "Deposit depositedGas balance doesn't match"
    //     );

    //     console2.log("1");
    //     console2.logUint(amounts[0]);
    //     console2.logUint(deposits[0]);

    //     if (hTokens[0] != address(0) || tokens[0] != address(0)) {
    //         if (amounts[0] > 0 && deposits[0] == 0) {
    //             console2.log("whyyyyy");

    //             require(
    //                 MockERC20(hTokens[0]).balanceOf(_user) == 0,
    //                 "Deposit hToken balance doesn't match"
    //             );

    //             console2.log("2");
    //             require(
    //                 MockERC20(hTokens[0]).balanceOf(rootPort) == 0,
    //                 "Deposit hToken balance doesn't match"
    //             );
    //         } else if (amounts[0] - deposits[0] > 0 && deposits[0] > 0) {
    //             console2.log("3");
    //             console2.log(_user);
    //             console2.log(rootPort);

    //             require(
    //                 MockERC20(hTokens[0]).balanceOf(_user) == 0,
    //                 "Deposit hToken balance doesn't match"
    //             );
    //             console2.log("4");

    //             require(
    //                 MockERC20(tokens[0]).balanceOf(_user) == 0,
    //                 "Deposit token balance doesn't match"
    //             );
    //             console2.log("5");
    //             require(
    //                 MockERC20(tokens[0]).balanceOf(rootPort) == _deposit,
    //                 "Deposit token balance doesn't match"
    //             );
    //         } else {
    //             console2.log("6");
    //             require(
    //                 MockERC20(tokens[0]).balanceOf(_user) == 0,
    //                 "Deposit token balance doesn't match"
    //             );
    //             console2.log("7");
    //             require(
    //                 MockERC20(tokens[0]).balanceOf(rootPort) == _deposit,
    //                 "Deposit token balance doesn't match"
    //             );

    //             console2.log("8");
    //         }
    //     }
    // }

    // function makeTestCallWithDeposit(
    //     address _user,
    //     address _hToken,
    //     address _token,
    //     uint256 _amount,
    //     uint256 _deposit,
    //     uint24 _toChain,
    //     uint128 _rootExecGas
    // ) private {
    //     //Prepare deposit info
    //     DepositInput memory depositInput = DepositInput({
    //         hToken: _hToken,
    //         token: _token,
    //         amount: _amount,
    //         deposit: _deposit,
    //         toChain: _toChain
    //     });

    //     // Prank into user account
    //     hevm.startPrank(_user);

    //     //Get some gas.
    //     hevm.deal(_user, 1 ether);

    //     // Approve spend by router
    //     ERC20hTokenRoot(_hToken).approve(rootPort, _amount - _deposit);
    //     MockERC20(_token).approve(rootPort, _deposit);

    //     //Call Deposit function
    //     CoreRootBridgeAgent(coreBridgeAgent).callOutAndBridge{ value: 1 ether }(
    //         bytes("testdata"),
    //         depositInput,
    //         _rootExecGas
    //     );

    //     // Prank out of user account
    //     hevm.stopPrank();

    //     // Test If Deposit was successful
    //     testCreateDepositSingle(
    //         uint32(1),
    //         _user,
    //         address(_hToken),
    //         address(_token),
    //         _amount,
    //         _deposit,
    //         1 ether
    //     );
    // }

    // function makeTestCallWithDepositMultiple(
    //     address _user,
    //     address[] memory _hTokens,
    //     address[] memory _tokens,
    //     uint256[] memory _amounts,
    //     uint256[] memory _deposits,
    //     uint24 _toChain,
    //     uint128 _rootExecGas
    // ) private {
    //     //Prepare deposit info
    //     DepositMultipleInput memory depositInput = DepositMultipleInput({
    //         hTokens: _hTokens,
    //         tokens: _tokens,
    //         amounts: _amounts,
    //         deposits: _deposits,
    //         toChain: _toChain
    //     });

    //     // Prank into user account
    //     hevm.startPrank(_user);

    //     //Get some gas.
    //     hevm.deal(_user, 1 ether);

    //     console2.log(_hTokens[0], _deposits[0]);

    //     // Approve spend by router
    //     MockERC20(_hTokens[0]).approve(rootPort, _amounts[0] - _deposits[0]);
    //     MockERC20(_tokens[0]).approve(rootPort, _deposits[0]);
    //     MockERC20(_hTokens[1]).approve(rootPort, _amounts[1] - _deposits[1]);
    //     MockERC20(_tokens[1]).approve(rootPort, _deposits[1]);

    //     //Call Deposit function
    //     CoreRootBridgeAgent(coreBridgeAgent).callOutAndBridgeMultiple{ value: 1 ether }(
    //         bytes("test"),
    //         depositInput,
    //         _rootExecGas
    //     );

    //     // Prank out of user account
    //     hevm.stopPrank();

    //     // Test If Deposit was successful
    //     testCreateDeposit(uint32(1), _user, _hTokens, _tokens, _amounts, _deposits);
    // }

    function encodeSystemCall(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas,
        uint24 _fromChainId
    ) private {
        // Mock anycall context
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(_fromBridgeAgent, _fromChainId, 22)
        );

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x00), _nonce, _data, _rootExecGas, _remoteExecGas);

        hevm.mockCall(
            address(localAnyCongfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), _fromChainId, inputCalldata.length
            ),
            abi.encode(0)
        );

        // Prank into user account
        hevm.startPrank(localAnyCallExecutorAddress);

        //Call Deposit function
        RootBridgeAgent(_toBridgeAgent).anyExecute(inputCalldata);

        // Prank out of user account
        hevm.stopPrank();
    }

    function encodeCallNoDeposit(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas,
        uint24 _fromChainId
    ) private {
        // Mock anycall context
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(_fromBridgeAgent, _fromChainId, 22)
        );

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x01), _nonce, _data, _rootExecGas, _remoteExecGas);

        // Prank into user account
        hevm.startPrank(localAnyCallExecutorAddress);

        //Get some gas.
        // hevm.deal(_user, 1 ether);

        //Call Deposit function
        RootBridgeAgent(_toBridgeAgent).anyExecute(inputCalldata);

        // Prank out of user account
        hevm.stopPrank();
    }

    function encodeCallWithDeposit(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas,
        uint24 _fromChainId
    ) private {
        // Mock anycall context
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(_fromBridgeAgent, _fromChainId, 22)
        );

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(
            bytes1(0x02), _nonce, _hToken, _token, _amount, _deposit, _toChain, _data, _rootExecGas, _remoteExecGas
        );

        // Prank into user account
        hevm.startPrank(localAnyCallExecutorAddress);

        //Get some gas.
        // hevm.deal(_user, 1 ether);

        //Call Deposit function
        RootBridgeAgent(_toBridgeAgent).anyExecute(inputCalldata);

        // Prank out of user account
        hevm.stopPrank();
    }

    function encodeCallWithDepositMultiple(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas,
        uint24 _fromChainId
    ) private {
        // Mock anycall context
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(_fromBridgeAgent, _fromChainId, 22)
        );

        //Encode Data for cross-chain call.
        bytes memory inputCalldata = abi.encodePacked(
            bytes1(0x03),
            uint8(_hTokens.length),
            _nonce,
            _hTokens,
            _tokens,
            _amounts,
            _deposits,
            _toChain,
            _data,
            _rootExecGas,
            _remoteExecGas
        );

        // Prank into user account
        hevm.startPrank(localAnyCallExecutorAddress);

        //Call Deposit function
        RootBridgeAgent(_toBridgeAgent).anyExecute(inputCalldata);

        // Prank out of user account
        hevm.stopPrank();
    }

    function compareDynamicArrays(bytes memory a, bytes memory b) public pure returns (bool aEqualsB) {
        assembly {
            aEqualsB := eq(a, b)
        }
    }

    // function testFinalizeDeposit() public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(avaxCoreBridgeAgentAddress, rootChainId, 22)
    //     );

    //     // Create Test Deposit
    //     testCallWithDeposit();

    //     // Encode Finalize Deposit Execution Data
    //     bytes memory finalizeDepositData = abi.encode(
    //         bytes1(uint8(2)),
    //         uint32(1),
    //         address(testToken)
    //     );

    //     // Call 'finalizeDeposit'
    //     hevm.prank(localAnyCallExecutorAddress);
    //     coreBridgeAgent.anyExecute(finalizeDepositData);

    //     require(wAvaxUnderlyingNativeToken.balanceOf(address(this)) == 0);
    //     require(testToken.balanceOf(address(this)) == 100 ether);
    //     require(wAvaxUnderlyingNativeToken.balanceOf(rootPort) == 100 ether);
    //     require(testToken.balanceOf(rootPort) == 0);
    // }

    // function testFuzzFinalizeDeposit(address _user, uint256 _amount, uint256 _toChain) public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(avaxCoreBridgeAgentAddress, _toChain, 22)
    //     );

    //     // Input restrictions
    //     hevm.assume(_user != address(0) && _amount > 0 && _toChain > 0);

    //     // Mint Test tokens.
    //     MockERC20 underToken = new MockERC20("u token", "U", 18);
    //     underToken.mint(_user, _amount);
    //     ERC20hTokenRoot fuzzToken = new ERC20hTokenRoot(
    //         "Hermes omni token",
    //         "hUNDER",
    //         rootPort
    //     );

    //     // Perform deposit
    //     makeTestCallWithDeposit(
    //         _user,
    //         address(fuzzToken),
    //         address(underToken),
    //         _amount,
    //         _amount,
    //         _toChain
    //     );

    //     // Encode Finalize Deposit Execution Data
    //     bytes memory finalizeDepositData = abi.encode(
    //         bytes1(uint8(2)),
    //         uint32(1),
    //         address(fuzzToken)
    //     );

    //     // Call 'finalizeDeposit'
    //     hevm.prank(localAnyCallExecutorAddress);
    //     coreBridgeAgent.anyExecute(finalizeDepositData);

    //     require(underToken.balanceOf(_user) == 0);
    //     require(fuzzToken.balanceOf(_user) == _amount);
    //     require(underToken.balanceOf(rootPort) == _amount);
    //     require(fuzzToken.balanceOf(rootPort) == 0);
    // }

    // function testFinalizeWithdraw() public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(avaxCoreBridgeAgentAddress, rootChainId, 22)
    //     );

    //     //Mint Test tokens.
    //     hevm.prank(rootPort);
    //     testToken.mint(address(this), 100 ether);
    //     wAvaxUnderlyingNativeToken.mint(rootPort, 100 ether);

    //     //Approve spend by router
    //     testToken.approve(rootPort, 100 ether);

    //     //Prepare deposit info
    //     DepositInput memory depositInput = DepositInput({
    //         hToken: address(testToken),
    //         token: address(wAvaxUnderlyingNativeToken),
    //         amount: 100 ether,
    //         deposit: 0,
    //         toChain: rootChainId
    //     });

    //     //Call Deposit function
    //     IBranchRouter(coreBridgeAgent).callOut(bytes1(uint8(1)), bytes("test"), depositInput);

    //     //Test If Deposit was successful
    //     testCreateDepositSingle(
    //         uint32(1),
    //         address(this),
    //         address(testToken),
    //         address(wAvaxUnderlyingNativeToken),
    //         100 ether,
    //         0
    //     );

    //     // Encode Finalize Withdraw Execution Data
    //     bytes memory finalizeWithdrawData = abi.encode(
    //         bytes1(uint8(3)),
    //         uint32(1),
    //         address(wAvaxUnderlyingNativeToken)
    //     );

    //     // Call 'finalizeDeposit'
    //     hevm.prank(localAnyCallExecutorAddress);
    //     coreBridgeAgent.anyExecute(finalizeWithdrawData);

    //     require(testToken.balanceOf(address(this)) == 0);
    //     require(wAvaxUnderlyingNativeToken.balanceOf(address(this)) == 100 ether);
    //     require(testToken.balanceOf(rootPort) == 0);
    //     require(wAvaxUnderlyingNativeToken.balanceOf(rootPort) == 0);
    // }

    // function testFuzzFinalizeWithdraw(address _user, uint256 _amount, uint256 _toChain) public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(avaxCoreBridgeAgentAddress, _toChain, 22)
    //     );

    //     // Input restrictions
    //     hevm.assume(_user != address(0) && _amount > 0 && _toChain > 0);

    //     // Mint Test tokens.
    //     ERC20hTokenRoot fuzzToken = new ERC20hTokenRoot(
    //         "Hermes omni token",
    //         "hUNDER",
    //         rootPort
    //     );
    //     hevm.prank(rootPort);
    //     fuzzToken.mint(_user, _amount);

    //     MockERC20 underToken = new MockERC20("u token", "U", 18);
    //     underToken.mint(rootPort, _amount);

    //     // Perform deposit
    //     makeTestCallWithDeposit(
    //         _user,
    //         address(fuzzToken),
    //         address(underToken),
    //         _amount,
    //         0,
    //         _toChain
    //     );

    //     // Encode Finalize Withdraw Execution Data
    //     bytes memory finalizeWithdrawData = abi.encode(
    //         bytes1(uint8(3)),
    //         uint32(1),
    //         address(underToken)
    //     );

    //     // Call 'finalizeDeposit'
    //     hevm.prank(localAnyCallExecutorAddress);
    //     coreBridgeAgent.anyExecute(finalizeWithdrawData);

    //     require(fuzzToken.balanceOf(_user) == 0);
    //     require(underToken.balanceOf(_user) == _amount);
    //     require(fuzzToken.balanceOf(rootPort) == 0);
    //     require(underToken.balanceOf(rootPort) == 0);
    // }
}
