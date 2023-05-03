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
import {BranchPort} from "@omni/BranchPort.sol";

import {RootBridgeAgent, WETH9} from "./mocks/MockRootBridgeAgent.t.sol";
import {BranchBridgeAgent} from "./mocks/MockBranchBridgeAgent.t.sol";
import {ArbitrumBranchBridgeAgent} from "@omni/ArbitrumBranchBridgeAgent.sol";

import {BaseBranchRouter} from "@omni/BaseBranchRouter.sol";
import {MulticallRootRouter} from "@omni/MulticallRootRouter.sol";
import {CoreRootRouter} from "@omni/CoreRootRouter.sol";
import {CoreBranchRouter} from "@omni/CoreBranchRouter.sol";
import {ArbitrumCoreBranchRouter} from "@omni/ArbitrumCoreBranchRouter.sol";

import {ERC20hTokenBranch} from "@omni/token/ERC20hTokenBranch.sol";
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
import {RLPEncoder} from "@rlp/RLPEncoder.sol";

interface IAnycallApp {
    /// (required) call on the destination chain to exec the interaction
    function anyExecute(bytes calldata _data) external returns (bool success, bytes memory result);

    /// (optional,advised) call back on the originating chain if the cross chain interaction fails
    /// `_data` is the orignal interaction arguments exec on the destination chain
    function anyFallback(bytes calldata _data) external returns (bool success, bytes memory result);
}

contract MockAnycall is DSTestPlus {
    address lastFrom;

    function executor() external view returns (address) {
        return address(0xABFD);
    }

    function config() external view returns (address) {
        return address(0xCAFF);
    }

    function anyCall(address _to, bytes calldata _data, uint256 _toChainID, uint256 _flags, bytes calldata _extdata)
        external
        payable
    {
        lastFrom = msg.sender;

        console2.log("anycall");
        console2.log("from", lastFrom);
        console2.log("fromChain", BranchBridgeAgent(payable(msg.sender)).localChainId());

        // Mock anycall context
        hevm.mockCall(
            address(0xABFD),
            abi.encodeWithSignature("context()"),
            abi.encode(address(msg.sender), BranchBridgeAgent(payable(msg.sender)).localChainId(), 22)
        );

        //Mock Anycallconfig fees
        hevm.mockCall(
            address(0xCAFF),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)",
                address(0),
                BranchBridgeAgent(payable(msg.sender)).localChainId(),
                _data.length
            ),
            abi.encode(0)
        );

        hevm.prank(address(0xABFD));
        IAnycallApp(_to).anyExecute(_data);
    }

    function anyCall(
        string calldata _to,
        bytes calldata _data,
        uint256 _toChainID,
        uint256 _flags,
        bytes calldata _extdata
    ) external payable {
        lastFrom = msg.sender;

        hevm.prank(address(0xABFD));
        IAnycallApp(address(bytes20(bytes(_to)))).anyExecute(_data);
    }
}

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external;
}

contract MockPool is Test {
    struct SwapCallbackData {
        address tokenIn;
    }

    address arbitrumWrappedNativeTokenAddress;
    address globalGasToken;

    constructor(address _arbitrumWrappedNativeTokenAddress, address _globalGasToken) {
        arbitrumWrappedNativeTokenAddress = _arbitrumWrappedNativeTokenAddress;
        globalGasToken = _globalGasToken;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        SwapCallbackData memory _data = abi.decode(data, (SwapCallbackData));

        address tokenOut =
            (_data.tokenIn == arbitrumWrappedNativeTokenAddress ? globalGasToken : arbitrumWrappedNativeTokenAddress);

        console2.log("Gas Swap Data");
        console2.log("tokenIn", _data.tokenIn);
        console2.log("tokenOut", tokenOut);
        console2.log("isWrappedGasToken", _data.tokenIn != arbitrumWrappedNativeTokenAddress);

        if (tokenOut == arbitrumWrappedNativeTokenAddress) {
            deal(address(this), uint256(amountSpecified));
            WETH(arbitrumWrappedNativeTokenAddress).deposit{value: uint256(amountSpecified)}();
            MockERC20(arbitrumWrappedNativeTokenAddress).transfer(msg.sender, uint256(amountSpecified));
        } else {
            deal({token: tokenOut, to: msg.sender, give: uint256(amountSpecified)});
        }

        if (zeroForOne) {
            amount1 = amountSpecified;
        } else {
            amount0 = amountSpecified;
        }

        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
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

contract BranchPortTest is DSTestPlus {
    // Consts

    uint24 constant rootChainId = uint24(42161);

    uint24 constant avaxChainId = uint24(43114);

    uint24 constant ftmChainId = uint24(2040);

    //// System contracts

    // Root

    RootPort rootPort;

    ERC20hTokenRootFactory hTokenFactory;

    RootBridgeAgentFactory bridgeAgentFactory;

    RootBridgeAgent coreBridgeAgent;

    RootBridgeAgent multicallBridgeAgent;

    CoreRootRouter rootCoreRouter;

    MulticallRootRouter rootMulticallRouter;

    // Arbitrum Branch

    ArbitrumBranchPort arbitrumPort;

    ERC20hTokenBranchFactory localHTokenFactory;

    ArbitrumBranchBridgeAgentFactory arbitrumBranchBridgeAgentFactory;

    ArbitrumBranchBridgeAgent arbitrumCoreBridgeAgent;

    ArbitrumBranchBridgeAgent arbitrumMulticallBridgeAgent;

    ArbitrumCoreBranchRouter arbitrumCoreRouter;

    BaseBranchRouter arbitrumMulticallRouter;

    // Avax Branch

    BranchPort avaxPort;

    ERC20hTokenBranchFactory avaxHTokenFactory;

    BranchBridgeAgentFactory avaxBranchBridgeAgentFactory;

    BranchBridgeAgent avaxCoreBridgeAgent;

    BranchBridgeAgent avaxMulticallBridgeAgent;

    CoreBranchRouter avaxCoreRouter;

    BaseBranchRouter avaxMulticallRouter;

    // Ftm Branch

    BranchPort ftmPort;

    ERC20hTokenBranchFactory ftmHTokenFactory;

    BranchBridgeAgentFactory ftmBranchBridgeAgentFactory;

    BranchBridgeAgent ftmCoreBridgeAgent;

    BranchBridgeAgent ftmMulticallBridgeAgent;

    CoreBranchRouter ftmCoreRouter;

    BaseBranchRouter ftmMulticallRouter;

    // ERC20s from different chains.

    address avaxMockAssethToken;

    MockERC20 avaxMockAssetToken;

    address ftmMockAssethToken;

    MockERC20 ftmMockAssetToken;

    ERC20hTokenRoot arbitrumMockAssethToken;

    MockERC20 arbitrumMockToken;

    // Mocks

    address arbitrumGlobalToken;
    address avaxGlobalToken;
    address ftmGlobalToken;

    address arbitrumWrappedNativeToken;
    address avaxWrappedNativeToken;
    address ftmWrappedNativeToken;

    address arbitrumLocalWrappedNativeToken;
    address avaxLocalWrappedNativeToken;
    address ftmLocalWrappedNativeToken;

    address multicallAddress;

    address testGasPoolAddress = address(0xFFFF);

    address nonFungiblePositionManagerAddress = address(0xABAD);

    address avaxLocalarbitrumWrappedNativeTokenAddress = address(0xBFFF);
    address avaxUnderlyingarbitrumWrappedNativeTokenAddress = address(0xFFFB);

    address ftmLocalarbitrumWrappedNativeTokenAddress = address(0xABBB);
    address ftmUnderlyingarbitrumWrappedNativeTokenAddress = address(0xAAAB);

    address avaxCoreBridgeAgentAddress = address(0xBEEF);

    address avaxMulticallBridgeAgentAddress = address(0xEBFE);

    address avaxPortAddress = address(0xFEEB);

    address ftmCoreBridgeAgentAddress = address(0xCACA);

    address ftmMulticallBridgeAgentAddress = address(0xACAC);

    address ftmPortAddressM = address(0xABAC);

    address localAnyCallAddress = address(new MockAnycall());

    address localAnyConfig = address(0xCAFF);

    address localAnyCallExecutorAddress = address(0xABFD);

    address owner = address(this);

    address dao = address(this);

    function setUp() public {
        //Mock calls (currently redundant)
        hevm.mockCall(
            localAnyCallAddress, abi.encodeWithSignature("executor()"), abi.encode(localAnyCallExecutorAddress)
        );

        hevm.mockCall(localAnyCallAddress, abi.encodeWithSignature("config()"), abi.encode(localAnyConfig));

        /////////////////////////////////
        //      Deploy Root Utils      //
        /////////////////////////////////

        arbitrumWrappedNativeToken = address(new WETH());
        avaxWrappedNativeToken = address(new WETH());
        ftmWrappedNativeToken = address(new WETH());

        multicallAddress = address(new Multicall2());

        /////////////////////////////////
        //    Deploy Root Contracts    //
        /////////////////////////////////

        rootPort = new RootPort(rootChainId, arbitrumWrappedNativeToken);

        bridgeAgentFactory = new RootBridgeAgentFactory(
            rootChainId,
            WETH9(arbitrumWrappedNativeToken),
            localAnyCallAddress,
            address(rootPort),
            dao
        );

        rootCoreRouter = new CoreRootRouter(rootChainId, arbitrumWrappedNativeToken, address(rootPort));

        rootMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        hTokenFactory = new ERC20hTokenRootFactory(rootChainId, address(rootPort));

        /////////////////////////////////
        //  Initialize Root Contracts  //
        /////////////////////////////////

        rootPort.initialize(address(bridgeAgentFactory), address(rootCoreRouter));

        hevm.deal(address(rootPort), 1 ether);
        hevm.prank(address(rootPort));
        WETH(arbitrumWrappedNativeToken).deposit{value: 1 ether}();

        hTokenFactory.initialize(address(rootCoreRouter));

        coreBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(rootCoreRouter)))
        );

        multicallBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(rootMulticallRouter)))
        );

        rootCoreRouter.initialize(address(coreBridgeAgent), address(hTokenFactory));

        rootMulticallRouter.initialize(address(multicallBridgeAgent));

        /////////////////////////////////
        //Deploy Local Branch Contracts//
        /////////////////////////////////

        arbitrumPort = new ArbitrumBranchPort(rootChainId, address(rootPort), owner);

        arbitrumMulticallRouter = new BaseBranchRouter();

        arbitrumCoreRouter = new ArbitrumCoreBranchRouter(address(0), address(arbitrumPort));

        arbitrumBranchBridgeAgentFactory = new ArbitrumBranchBridgeAgentFactory(
            rootChainId,
            address(bridgeAgentFactory),
            WETH9(arbitrumWrappedNativeToken),
            localAnyCallAddress,
            localAnyCallExecutorAddress,
            address(arbitrumCoreRouter),
            address(arbitrumPort),
            owner
        );

        arbitrumPort.initialize(address(arbitrumCoreRouter), address(arbitrumBranchBridgeAgentFactory));

        arbitrumBranchBridgeAgentFactory.initialize(address(coreBridgeAgent));
        arbitrumCoreBridgeAgent = ArbitrumBranchBridgeAgent(payable(arbitrumPort.bridgeAgents(0)));

        arbitrumCoreRouter.initialize(address(arbitrumCoreBridgeAgent));
        // arbitrumMulticallRouter.initialize(address(arbitrumMulticallBridgeAgent));

        //////////////////////////////////
        // Deploy Avax Branch Contracts //
        //////////////////////////////////

        avaxPort = new BranchPort(owner);

        avaxHTokenFactory = new ERC20hTokenBranchFactory(rootChainId, address(avaxPort));

        avaxMulticallRouter = new BaseBranchRouter();

        avaxCoreRouter = new CoreBranchRouter(address(avaxHTokenFactory), address(avaxPort));

        avaxBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            avaxChainId,
            rootChainId,
            address(bridgeAgentFactory),
            WETH9(avaxWrappedNativeToken),
            localAnyCallAddress,
            localAnyCallExecutorAddress,
            address(avaxCoreRouter),
            address(avaxPort),
            owner
        );

        avaxPort.initialize(address(avaxCoreRouter), address(avaxBranchBridgeAgentFactory));

        avaxBranchBridgeAgentFactory.initialize(address(coreBridgeAgent));
        avaxCoreBridgeAgent = BranchBridgeAgent(payable(avaxPort.bridgeAgents(0)));

        avaxHTokenFactory.initialize(avaxWrappedNativeToken, address(avaxCoreRouter));
        avaxLocalWrappedNativeToken = 0xfA0e6015e8AD40Aa4535C477142a2eCdb824F2f7;

        avaxCoreRouter.initialize(address(avaxCoreBridgeAgent));

        //////////////////////////////////
        // Deploy Ftm Branch Contracts //
        //////////////////////////////////

        ftmPort = new BranchPort(owner);

        ftmHTokenFactory = new ERC20hTokenBranchFactory(rootChainId, address(ftmPort));

        ftmMulticallRouter = new BaseBranchRouter();

        ftmCoreRouter = new CoreBranchRouter(address(ftmHTokenFactory), address(ftmPort));

        ftmBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            ftmChainId,
            rootChainId,
            address(bridgeAgentFactory),
            WETH9(ftmWrappedNativeToken),
            localAnyCallAddress,
            localAnyCallExecutorAddress,
            address(ftmCoreRouter),
            address(ftmPort),
            owner
        );

        ftmPort.initialize(address(ftmCoreRouter), address(ftmBranchBridgeAgentFactory));

        ftmBranchBridgeAgentFactory.initialize(address(coreBridgeAgent));
        ftmCoreBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(0)));

        ftmHTokenFactory.initialize(ftmWrappedNativeToken, address(ftmCoreRouter));
        ftmLocalWrappedNativeToken = 0x1f8FC9dBEbe2d5471b686313fd2546f2d3D4f9Cc;

        ftmCoreRouter.initialize(address(ftmCoreBridgeAgent));

        /////////////////////////////
        //  Add new branch chains  //
        /////////////////////////////

        avaxGlobalToken = 0xDDA0a8D7486686d36449792617565E6C474fBa3f;

        ftmGlobalToken = 0x19a75C5AE908D442fbdbe3F03AfECF6231107e27;

        hevm.mockCall(
            nonFungiblePositionManagerAddress,
            abi.encodeWithSignature(
                "createAndInitializePoolIfNecessary(address,address,uint24,uint160)",
                arbitrumWrappedNativeToken,
                avaxGlobalToken,
                uint24(100),
                uint160(200)
            ),
            abi.encode(address(new MockPool(arbitrumWrappedNativeToken,avaxGlobalToken)))
        );

        RootPort(rootPort).addNewChain(
            address(avaxCoreBridgeAgent),
            avaxChainId,
            "Avalanche",
            "AVAX",
            100,
            50,
            200,
            nonFungiblePositionManagerAddress,
            avaxLocalWrappedNativeToken,
            avaxWrappedNativeToken,
            address(hTokenFactory)
        );

        // address _newLocalBranchWrappedNativeTokenAddress,
        // address _newUnderlyingBranchWrappedNativeTokenAddress,

        //Mock calls
        hevm.mockCall(
            nonFungiblePositionManagerAddress,
            abi.encodeWithSignature(
                "createAndInitializePoolIfNecessary(address,address,uint24,uint160)",
                ftmGlobalToken,
                arbitrumWrappedNativeToken,
                uint24(100),
                uint160(200)
            ),
            abi.encode(address(new MockPool(arbitrumWrappedNativeToken, ftmGlobalToken)))
        );

        RootPort(rootPort).addNewChain(
            address(ftmCoreBridgeAgent),
            ftmChainId,
            "Fantom Opera",
            "FTM",
            100,
            50,
            200,
            nonFungiblePositionManagerAddress,
            ftmLocalWrappedNativeToken,
            ftmWrappedNativeToken,
            address(hTokenFactory)
        );

        //Ensure there are gas tokens from each chain in the system.
        hevm.startPrank(address(rootPort));
        ERC20hTokenRoot(avaxGlobalToken).mint(address(rootPort), 1 ether, avaxChainId);
        hevm.stopPrank();

        hevm.deal(address(this), 1 ether);
        WETH9(avaxWrappedNativeToken).deposit{value: 1 ether}();
        ERC20hTokenRoot(avaxWrappedNativeToken).transfer(address(avaxPort), 1 ether);

        hevm.startPrank(address(rootPort));
        ERC20hTokenRoot(ftmGlobalToken).mint(address(rootPort), 1 ether, ftmChainId);
        hevm.stopPrank();

        hevm.deal(address(this), 1 ether);
        WETH9(ftmWrappedNativeToken).deposit{value: 1 ether}();
        ERC20hTokenRoot(ftmWrappedNativeToken).transfer(address(ftmPort), 1 ether);
        hevm.stopPrank();

        //////////////////////
        // Verify Addition  //
        //////////////////////

        require(RootPort(rootPort).isGlobalAddress(avaxGlobalToken), "Token should be added");

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxLocalWrappedNativeToken), avaxChainId)
                == avaxGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(avaxGlobalToken, avaxChainId)
                == address(avaxLocalWrappedNativeToken),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(avaxLocalWrappedNativeToken), avaxChainId)
                == address(avaxWrappedNativeToken),
            "Token should be added"
        );

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(ftmLocalWrappedNativeToken), ftmChainId)
                == ftmGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(ftmGlobalToken, ftmChainId)
                == address(ftmLocalWrappedNativeToken),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(ftmLocalWrappedNativeToken), ftmChainId)
                == address(ftmWrappedNativeToken),
            "Token should be added"
        );

        ///////////////////////////////////
        //  Approve new Branchs in Root  //
        ///////////////////////////////////

        rootPort.initializeCore(address(coreBridgeAgent), address(arbitrumCoreBridgeAgent), address(arbitrumPort));

        multicallBridgeAgent.approveBranchBridgeAgent(rootChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(avaxChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        ///////////////////////////////////////
        //  Add new branches to  Root Agents //
        ///////////////////////////////////////

        hevm.deal(address(this), 3 ether);

        rootCoreRouter.addBranchToBridgeAgent{value: 1 ether}(
            address(multicallBridgeAgent),
            address(avaxBranchBridgeAgentFactory),
            address(avaxMulticallRouter),
            address(avaxCoreRouter),
            avaxChainId,
            0.01 ether
        );

        rootCoreRouter.addBranchToBridgeAgent{value: 1 ether}(
            address(multicallBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(ftmMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            0.5 ether
        );

        rootCoreRouter.addBranchToBridgeAgent(
            address(multicallBridgeAgent),
            address(arbitrumBranchBridgeAgentFactory),
            address(arbitrumMulticallRouter),
            address(arbitrumCoreRouter),
            rootChainId,
            0
        );

        /////////////////////////////////////
        //  Initialize new Branch Routers  //
        /////////////////////////////////////

        arbitrumMulticallBridgeAgent = ArbitrumBranchBridgeAgent(payable(arbitrumPort.bridgeAgents(1)));
        avaxMulticallBridgeAgent = BranchBridgeAgent(payable(avaxPort.bridgeAgents(1)));
        ftmMulticallBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(1)));

        arbitrumMulticallRouter.initialize(address(arbitrumMulticallBridgeAgent));
        avaxMulticallRouter.initialize(address(avaxMulticallBridgeAgent));
        ftmMulticallRouter.initialize(address(ftmMulticallBridgeAgent));

        //////////////////////////////////////
        //Deploy Underlying Tokens and Mocks//
        //////////////////////////////////////

        // avaxMockAssethToken = new MockERC20("hTOKEN-AVAX", "LOCAL hTOKEN FOR TOKEN IN AVAX", 18);
        avaxMockAssetToken = new MockERC20("underlying token", "UNDER", 18);

        // ftmMockAssethToken = new MockERC20("hTOKEN-FTM", "LOCAL hTOKEN FOR TOKEN IN FMT", 18);
        ftmMockAssetToken = new MockERC20("underlying token", "UNDER", 18);

        //arbitrumMockAssethToken is global
        arbitrumMockToken = new MockERC20("underlying token", "UNDER", 18);
    }

    fallback() external payable {}

    struct OutputParams {
        address recipient;
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
    }

    struct OutputMultipleParams {
        address recipient;
        address[] outputTokens;
        uint256[] amountsOut;
        uint256[] depositsOut;
    }

    function testAddBridgeAgent() public {
        uint256 balanceBefore = MockERC20(arbitrumWrappedNativeToken).balanceOf(address(coreBridgeAgent));

        //Get some gas
        hevm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        // Create Bridge Agent
        multicallBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Save Bridge Agent Address
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(payable(rootPort.bridgeAgents(2)));

        //Create Branch Router
        BaseBranchRouter ftmTestRouter = new BaseBranchRouter();

        //Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        //Create Branch Bridge Agent
        rootCoreRouter.addBranchToBridgeAgent{value: 0.00005 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(this),
            ftmChainId,
            0.0000025 ether
        );

        BranchBridgeAgent ftmTestBranchBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(2)));

        testMulticallRouter.initialize(address(ftmTestBranchBridgeAgent));

        uint256 balanceAfter = MockERC20(arbitrumWrappedNativeToken).balanceOf(address(coreBridgeAgent));

        // require(balanceAfter - balanceBefore == 0.00005 ether, "Fee should be paid");
    }

    address public newAvaxAssetGlobalAddress;

    function testAddLocalToken() public {
        uint256 balanceBefore = MockERC20(arbitrumWrappedNativeToken).balanceOf(address(coreBridgeAgent));

        hevm.deal(address(this), 1 ether);

        avaxCoreRouter.addLocalToken{value: 0.00005 ether}(address(avaxMockAssetToken));

        avaxMockAssethToken = RootPort(rootPort).getLocalTokenFromUnder(address(avaxMockAssetToken), avaxChainId);

        newAvaxAssetGlobalAddress = RootPort(rootPort).getGlobalTokenFromLocal(avaxMockAssethToken, avaxChainId);

        console2.log("New Global: ", newAvaxAssetGlobalAddress);
        console2.log("New Local: ", avaxMockAssethToken);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(avaxMockAssethToken, avaxChainId) == newAvaxAssetGlobalAddress,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, avaxChainId) == avaxMockAssethToken,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(avaxMockAssethToken, avaxChainId)
                == address(avaxMockAssetToken),
            "Token should be added"
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);
    }

    address public newFtmAssetGlobalAddress;

    address public newAvaxAssetLocalToken;

    function testAddGlobalToken() public {
        //Add Local Token from Avax
        testAddLocalToken();

        uint256 balanceBefore = MockERC20(arbitrumWrappedNativeToken).balanceOf(address(coreBridgeAgent));

        avaxCoreRouter.addGlobalToken{value: 0.0005 ether}(
            newAvaxAssetGlobalAddress, ftmChainId, 0.000025 ether, 0.00001 ether
        );

        newAvaxAssetLocalToken = RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId);

        newFtmAssetGlobalAddress = RootPort(rootPort).getGlobalTokenFromLocal(newAvaxAssetLocalToken, ftmChainId);

        console2.log("New Global: ", newFtmAssetGlobalAddress);
        console2.log("New Local: ", newAvaxAssetLocalToken);

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(newAvaxAssetLocalToken, ftmChainId) == address(0),
            "Underlying should not be added"
        );
    }

    address public mockApp = address(0xDAFA);

    address public newArbitrumAssetGlobalAddress;

    function testAddLocalTokenArbitrum() public {
        //Set up
        testAddGlobalToken();

        //Get some gas.
        hevm.deal(address(this), 1 ether);

        //Add new localToken
        arbitrumCoreRouter.addLocalToken{value: 0.0005 ether}(address(arbitrumMockToken));

        uint256 balanceBefore = MockERC20(arbitrumWrappedNativeToken).balanceOf(address(coreBridgeAgent));

        newArbitrumAssetGlobalAddress =
            RootPort(rootPort).getLocalTokenFromUnder(address(arbitrumMockToken), rootChainId);

        console2.log("New: ", newArbitrumAssetGlobalAddress);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(newArbitrumAssetGlobalAddress), rootChainId)
                == address(newArbitrumAssetGlobalAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newArbitrumAssetGlobalAddress, rootChainId)
                == address(newArbitrumAssetGlobalAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(newArbitrumAssetGlobalAddress), rootChainId)
                == address(arbitrumMockToken),
            "Token should be added"
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);
    }

    // ftmLocalarbitrumWrappedNativeTokenAddress
    // ftmUnderlyingarbitrumWrappedNativeTokenAddress

    function testCallOutWithDeposit() public {
        //Set up
        testAddLocalTokenArbitrum();

        //Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newArbitrumAssetGlobalAddress;
            amountOut = 100 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 100 hAVAX form virtual account to Mock App (could be bribes)
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});
            // callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)

            //Output Params
            OutputParams memory outputParams = OutputParams(address(this), outputToken, amountOut, depositOut);

            //toChain
            uint24 toChain = rootChainId;

            //RLP Encode Calldata
            bytes memory data = RLPEncoder.encodeCallData(abi.encode(calls, outputParams, toChain), 0);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        //Get some gas.
        hevm.deal(address(this), 1 ether);

        //Mint Underlying Token.
        arbitrumMockToken.mint(address(this), 100 ether);

        //Approve spend by router
        arbitrumMockToken.approve(address(arbitrumPort), 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumMockToken),
            amount: 100 ether,
            deposit: 100 ether,
            toChain: rootChainId
        });

        //Call Deposit function
        arbitrumMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, 0.5 ether);

        // Test If Deposit was successful
        testCreateDepositSingle(
            arbitrumMulticallBridgeAgent,
            uint32(1),
            address(this),
            address(newArbitrumAssetGlobalAddress),
            address(arbitrumMockToken),
            100 ether,
            100 ether,
            1 ether,
            0.5 ether
        );

        console2.log("LocalPort Balance:", MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)));
        require(
            MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)) == 50 ether, "LocalPort should have 50 tokens"
        );

        console2.log("User Balance:", MockERC20(arbitrumMockToken).balanceOf(address(this)));
        require(MockERC20(arbitrumMockToken).balanceOf(address(this)) == 50 ether, "User should have 50 tokens");

        console2.log("User Global Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(this)));
        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(this)) == 50 ether,
            "User should have 50 global tokens"
        );
    }

    function testFuzzCallOutWithDeposit(
        address _user,
        uint256 _amount,
        uint256 _deposit,
        uint256 _amountOut,
        uint256 _depositOut
    ) public {
        // Input restrictions
        // hevm.assume(_user != address(0) && _amount > 0 && _amount > _deposit);
        hevm.assume(
            _user != address(0) && _amount > 0 && _amount > _deposit && _amount >= _amountOut
                && _amount - _amountOut >= _depositOut && _depositOut < _amountOut
        );

        //Set up
        testAddLocalTokenArbitrum();

        //Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 100 hAVAX form virtual account to Mock App (could be bribes)
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});
            // callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)

            //Output Params
            OutputParams memory outputParams =
                OutputParams(_user, newArbitrumAssetGlobalAddress, _amountOut, _depositOut);

            //RLP Encode Calldata
            bytes memory data = RLPEncoder.encodeCallData(abi.encode(calls, outputParams, rootChainId), 0);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        //Get some gas.
        hevm.deal(_user, 1 ether);

        if (_amount - _deposit > 0) {
            //assure there is enough balance for mock action
            hevm.startPrank(address(rootPort));
            ERC20hTokenRoot(newArbitrumAssetGlobalAddress).mint(_user, _amount - _deposit, rootChainId);
            hevm.stopPrank();
            arbitrumMockToken.mint(address(arbitrumPort), _amount - _deposit);
        }

        //Mint Underlying Token.
        if (_deposit > 0) arbitrumMockToken.mint(_user, _deposit);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumMockToken),
            amount: _amount,
            deposit: _deposit,
            toChain: rootChainId
        });

        console2.log("BALANCE BEFORE:");
        console2.log("arbitrumMockToken Balance:", MockERC20(arbitrumMockToken).balanceOf(_user));
        console2.log(
            "newArbitrumAssetGlobalAddress Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user)
        );

        //Call Deposit function
        hevm.startPrank(_user);
        arbitrumMockToken.approve(address(arbitrumPort), _deposit);
        ERC20hTokenRoot(newArbitrumAssetGlobalAddress).approve(address(rootPort), _amount - _deposit);
        arbitrumMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, 0.5 ether);
        hevm.stopPrank();

        // Test If Deposit was successful
        testCreateDepositSingle(
            arbitrumMulticallBridgeAgent,
            uint32(1),
            _user,
            address(newArbitrumAssetGlobalAddress),
            address(arbitrumMockToken),
            _amount,
            _deposit,
            1 ether,
            0.5 ether
        );

        console2.log("ROUND UP");
        console2.log(_amount);
        console2.log(_deposit);
        console2.log(_amountOut);
        console2.log(_depositOut);

        address userAccount = address(RootPort(rootPort).getUserAccount(_user));

        console2.log("LocalPort Balance:", MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)));
        console2.log("Expected:", _amount - _deposit + _deposit - _depositOut);
        require(
            MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)) == _amount - _deposit + _deposit - _depositOut,
            "LocalPort tokens"
        );

        console2.log("RootPort Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootPort)));
        // console2.log("Expected:", 0); SINCE ORIGIN == DESTINATION == ARBITRUM
        require(MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootPort)) == 0, "RootPort tokens");

        console2.log("User Balance:", MockERC20(arbitrumMockToken).balanceOf(_user));
        console2.log("Expected:", _depositOut);
        require(MockERC20(arbitrumMockToken).balanceOf(_user) == _depositOut, "User tokens");

        console2.log("User Global Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user));
        console2.log("Expected:", _amountOut - _depositOut);
        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user) == _amountOut - _depositOut, "User Global tokens"
        );

        console2.log("User Account Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(userAccount));
        console2.log("Expected:", _amount - _amountOut);
        console2.log("Expected:", _amount);
        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(userAccount) == _amount - _amountOut,
            "User Account tokens"
        );
    }

    function testCreateDepositSingle(
        ArbitrumBranchBridgeAgent _bridgeAgent,
        uint32 _depositNonce,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint128 _depositedGas,
        uint128 _gasToBridgeOut
    ) private {
        // Cast to Dynamic TODO clean up
        address[] memory hTokens = new address[](1);
        hTokens[0] = _hToken;
        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = _deposit;

        // Get Deposit
        Deposit memory deposit = _bridgeAgent.getDepositEntry(_depositNonce);

        console2.logUint(1);
        console2.log(deposit.hTokens[0], hTokens[0]);
        console2.log(deposit.tokens[0], tokens[0]);

        // Check deposit
        require(deposit.owner == _user, "Deposit owner doesn't match");

        require(
            keccak256(abi.encodePacked(deposit.hTokens)) == keccak256(abi.encodePacked(hTokens)),
            "Deposit local hToken doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.tokens)) == keccak256(abi.encodePacked(tokens)),
            "Deposit underlying token doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.amounts)) == keccak256(abi.encodePacked(amounts)),
            "Deposit amount doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.deposits)) == keccak256(abi.encodePacked(deposits)),
            "Deposit deposit doesn't match"
        );

        require(deposit.status == DepositStatus.Success, "Deposit status should be succesful.");

        console2.log("TEST DEPOSIT~");
        console2.logUint(deposit.depositedGas);
        console2.logUint(WETH9(arbitrumWrappedNativeToken).balanceOf(address(arbitrumPort)));

        // require(deposit.depositedGas == _depositedGas, "Deposit depositedGas doesn't match");
        // require(
        //     WETH9(arbitrumWrappedNativeToken).balanceOf(address(rootPort)) == _depositedGas - _gasToBridgeOut,
        //     "Deposit depositedGas balance doesn't match"
        // );

        console2.log("1");
        console2.logUint(amounts[0]);
        console2.logUint(deposits[0]);

        // if (hTokens[0] != address(0) || tokens[0] != address(0)) {
        //     if (amounts[0] > 0 && deposits[0] == 0) {
        //         console2.log("whyyyyy");

        //         require(MockERC20(hTokens[0]).balanceOf(_user) == 0, "Deposit hToken balance doesn't match");

        //         console2.log("2");
        //         require(
        //             MockERC20(hTokens[0]).balanceOf(address(arbitrumPort)) == 0,
        //             "Deposit hToken balance doesn't match"
        //         );
        //     } else if (amounts[0] - deposits[0] > 0 && deposits[0] > 0) {
        //         console2.log("3");
        //         console2.log(_user);
        //         console2.log(address(arbitrumPort));

        //         require(MockERC20(hTokens[0]).balanceOf(_user) == 0, "Deposit hToken balance doesn't match");
        //         console2.log("4");

        //         require(MockERC20(tokens[0]).balanceOf(_user) == 0, "Deposit token balance doesn't match");
        //         console2.log("5");
        //         require(
        //             MockERC20(tokens[0]).balanceOf(address(arbitrumPort)) == _deposit,
        //             "Deposit token balance doesn't match"
        //         );
        //     } else {
        //         console2.log("6");
        //         // require(MockERC20(tokens[0]).balanceOf(_user) == 0, "Deposit token balance doesn't match");
        //         // console2.log("7");
        //         // require(
        //         //     MockERC20(tokens[0]).balanceOf(address(arbitrumPort)) == _deposit,
        //         //     "Deposit token balance doesn't match"
        //         // );

        //         console2.log("8");
        //     }
        // }
    }

    //////////////////////////////////////////////////////////////////////////   HELPERS   ////////////////////////////////////////////////////////////////////

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
            address(localAnyConfig),
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

        console2.log("HERES SUPERE IMPORTANTNDSTRE AJLAFJSFJKAJKS");
        console2.log(_remoteExecGas);
        console2.logBytes(inputCalldata);

        hevm.mockCall(
            address(localAnyConfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), _fromChainId, inputCalldata.length
            ),
            abi.encode(0)
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

    function encodeCallNoDepositSigned(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        address _user,
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
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x04), _user, _nonce, _data, _rootExecGas, _remoteExecGas);

        hevm.mockCall(
            address(localAnyConfig),
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

    function encodeCallWithDeposit(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint24 _fromChainId,
        bytes memory _packedData
    ) private {
        // Mock anycall context
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(_fromBridgeAgent, _fromChainId, 22)
        );

        hevm.mockCall(
            address(localAnyConfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), _fromChainId, _packedData.length
            ),
            abi.encode(0)
        );

        // Prank into user account
        hevm.startPrank(localAnyCallExecutorAddress);

        //Get some gas.
        // hevm.deal(_user, 1 ether);

        //Call Deposit function
        RootBridgeAgent(_toBridgeAgent).anyExecute(_packedData);

        // Prank out of user account
        hevm.stopPrank();
    }

    function encodeCallWithDepositMultiple(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint24 _fromChainId,
        bytes memory _packedData
    ) private {
        // Mock anycall context
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(_fromBridgeAgent, _fromChainId, 22)
        );

        hevm.mockCall(
            address(localAnyConfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), _fromChainId, _packedData.length
            ),
            abi.encode(0)
        );

        // Prank into user account
        hevm.startPrank(localAnyCallExecutorAddress);

        //Call Deposit function
        RootBridgeAgent(_toBridgeAgent).anyExecute(_packedData);

        // Prank out of user account
        hevm.stopPrank();
    }

    function _encodeSystemCall(uint32 _nonce, bytes memory _data, uint128 _rootExecGas, uint128 _remoteExecGas)
        internal
        returns (bytes memory inputCalldata)
    {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x00), _nonce, _data, _rootExecGas, _remoteExecGas);
    }

    function _encodeNoDeposit(uint32 _nonce, bytes memory _data, uint128 _rootExecGas, uint128 _remoteExecGas)
        internal
        returns (bytes memory inputCalldata)
    {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x01), _nonce, _data, _rootExecGas, _remoteExecGas);
    }

    function _encodeNoDepositSigned(
        uint32 _nonce,
        address _user,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x04), _user, _nonce, _data, _rootExecGas, _remoteExecGas);
    }

    function _encode(
        uint32 _nonce,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x02), _nonce, _hToken, _token, _amount, _deposit, _toChain, _data, _rootExecGas, _remoteExecGas
        );
    }

    function _encodeSigned(
        uint32 _nonce,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x05),
            _user,
            _nonce,
            _hToken,
            _token,
            _amount,
            _deposit,
            _toChain,
            _data,
            _rootExecGas,
            _remoteExecGas
        );
    }

    function _encodeMultiple(
        uint32 _nonce,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
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
    }

    function _encodeMultipleSigned(
        uint32 _nonce,
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x06),
            _user,
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
    }

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
    //     DepositInput memory depositInput =
    //         DepositInput({hToken: _hToken, token: _token, amount: _amount, deposit: _deposit, toChain: _toChain});

    //     // Prank into user account
    //     hevm.startPrank(_user);

    //     //Get some gas.
    //     hevm.deal(_user, 1 ether);

    //     // Approve spend by router
    //     ERC20hTokenBranch(_hToken).approve(arbitrumPort, _amount - _deposit);
    //     MockERC20(_token).approve(arbitrumPort, _deposit);

    //     //Call Deposit function
    //     IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}(bytes("testdata"), depositInput, _rootExecGas);

    //     // Prank out of user account
    //     hevm.stopPrank();

    //     // Test If Deposit was successful
    //     testCreateDepositSingle(uint32(1), _user, address(_hToken), address(_token), _amount, _deposit, 1 ether);
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
    //     MockERC20(_hTokens[0]).approve(arbitrumPort, _amounts[0] - _deposits[0]);
    //     MockERC20(_tokens[0]).approve(arbitrumPort, _deposits[0]);
    //     MockERC20(_hTokens[1]).approve(arbitrumPort, _amounts[1] - _deposits[1]);
    //     MockERC20(_tokens[1]).approve(arbitrumPort, _deposits[1]);

    //     //Call Deposit function
    //     IBranchRouter(bRouter).callOutAndBridgeMultiple{value: 1 ether}(bytes("test"), depositInput, _rootExecGas);

    //     // Prank out of user account
    //     hevm.stopPrank();

    //     // Test If Deposit was successful
    //     testCreateDeposit(uint32(1), _user, _hTokens, _tokens, _amounts, _deposits);
    // }

    function compareDynamicArrays(bytes memory a, bytes memory b) public pure returns (bool aEqualsB) {
        assembly {
            aEqualsB := eq(a, b)
        }
    }
}
