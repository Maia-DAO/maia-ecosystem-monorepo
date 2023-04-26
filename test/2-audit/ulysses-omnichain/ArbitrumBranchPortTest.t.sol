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
import {RLPEncoder} from "@rlp/RLPEncoder.sol";

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external;
}

contract MockPool is Test {
    struct SwapCallbackData {
        address tokenIn;
    }

    address wrappedNativeTokenAddress;
    address globalGasToken;

    constructor(address _wrappedNativeTokenAddress, address _globalGasToken) {
        wrappedNativeTokenAddress = _wrappedNativeTokenAddress;
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

        address tokenOut = (_data.tokenIn == wrappedNativeTokenAddress ? globalGasToken : wrappedNativeTokenAddress);

        console2.log("swapp");
        console2.log("tokenIn", _data.tokenIn);
        console2.log("tokenOut", tokenOut);
        console2.log("isWrappedGasToken");
        console2.log(_data.tokenIn != wrappedNativeTokenAddress);

        if (tokenOut == wrappedNativeTokenAddress) {
            // hevm.deal(msg.sender)
            deal(address(this), uint256(amountSpecified));
            WETH(wrappedNativeTokenAddress).deposit{value: uint256(amountSpecified)}();
            MockERC20(wrappedNativeTokenAddress).transfer(msg.sender, uint256(amountSpecified));
        } else {
            deal({token: tokenOut, to: msg.sender, give: uint256(amountSpecified)});
            // hevm.startPrank(address(0xF62849F9A0B5Bf2913b396098F7c7019b51A820a));
            // ERC20hTokenRoot(tokenOut).mint(msg.sender, uint256(-amountSpecified), 2040);
            // hevm.stopPrank();
        }
        console2.log(MockERC20(tokenOut).balanceOf(msg.sender));
        console2.log(amountSpecified);

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

contract ArbitrumBranchPortTest is DSTestPlus {
    MockERC20 avaxNativeAssethToken;

    MockERC20 avaxNativeToken;

    MockERC20 ftmNativeAssethToken;

    MockERC20 ftmNativeToken;

    ERC20hTokenRoot arbitrumNativeAssethToken;

    MockERC20 arbitrumNativeToken;

    MockERC20 rewardToken;

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

    address avaxGlobalToken;

    address ftmGlobalToken;

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

    address localAnyCallExecutorAddress = address(0xABFD);

    address owner = address(this);

    address dao = address(this);

    function setUp() public {
        //Mock calls
        hevm.mockCall(
            localAnyCallAddress, abi.encodeWithSignature("executor()"), abi.encode(localAnyCallExecutorAddress)
        );

        hevm.mockCall(localAnyCallAddress, abi.encodeWithSignature("config()"), abi.encode(localAnyCongfig));

        /////////////////////////////////
        //      Deploy Root Utils      //
        /////////////////////////////////
        wrappedNativeToken = address(new WETH());

        multicallAddress = address(new Multicall2());

        /////////////////////////////////
        //    Deploy Root Contracts    //
        /////////////////////////////////
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

        /////////////////////////////////
        //  Initialize Root Contracts  //
        /////////////////////////////////
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

        /////////////////////////////////
        //Deploy Local Branch Contracts//
        /////////////////////////////////

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

        arbitrumMulticallBridgeAgent = ArbitrumBranchBridgeAgent(
            payable(
                localBranchBridgeAgentFactory.createBridgeAgent(
                    address(arbitrumMulticallRouter), address(multicallBridgeAgent)
                )
            )
        );

        arbitrumCoreRouter.initialize(address(arbitrumCoreBridgeAgent));
        arbitrumMulticallRouter.initialize(address(arbitrumMulticallBridgeAgent));

        ///////////////////////////////////
        //Deploy Remote Branchs Contracts//
        ///////////////////////////////////

        ///////////////////////////////////
        //  Sync Root with new branches  //
        ///////////////////////////////////

        rootPort.initializeCore(address(coreBridgeAgent), address(arbitrumCoreBridgeAgent), address(localPortAddress));

        multicallBridgeAgent.approveBranchBridgeAgent(address(arbitrumMulticallBridgeAgent), rootChainId);

        coreBridgeAgent.approveBranchBridgeAgent(avaxCoreBridgeAgentAddress, avaxChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(avaxMulticallBridgeAgentAddress, avaxChainId);

        coreBridgeAgent.approveBranchBridgeAgent(ftmCoreBridgeAgentAddress, ftmChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(ftmMulticallBridgeAgentAddress, ftmChainId);

        hevm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            address(arbitrumMulticallBridgeAgent), address(multicallBridgeAgent), rootChainId
        );

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
            abi.encode(address(new MockPool(wrappedNativeToken,address(0x45C92C2Cd0dF7B2d705EF12CfF77Cb0Bc557Ed22))))
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
            abi.encode(address(new MockPool(wrappedNativeToken, address(0x9914ff9347266f1949C557B717936436402fc636))))
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

        avaxGlobalToken = 0x45C92C2Cd0dF7B2d705EF12CfF77Cb0Bc557Ed22;

        ftmGlobalToken = 0x9914ff9347266f1949C557B717936436402fc636;

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxLocalWrappedNativeTokenAddress), avaxChainId)
                == avaxGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(avaxGlobalToken, avaxChainId)
                == address(avaxLocalWrappedNativeTokenAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(avaxLocalWrappedNativeTokenAddress), avaxChainId)
                == address(avaxUnderlyingWrappedNativeTokenAddress),
            "Token should be added"
        );

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(ftmLocalWrappedNativeTokenAddress), ftmChainId)
                == ftmGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(ftmGlobalToken, ftmChainId)
                == address(ftmLocalWrappedNativeTokenAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(ftmLocalWrappedNativeTokenAddress), ftmChainId)
                == address(ftmUnderlyingWrappedNativeTokenAddress),
            "Token should be added"
        );

        //////////////////////////////////////
        //Deploy Underlying Tokens and Mocks//
        //////////////////////////////////////

        rewardToken = new MockERC20("hermes token", "HERMES", 18);

        avaxNativeAssethToken = new MockERC20("hTOKEN-AVAX", "LOCAL hTOKEN FOR TOKEN IN AVAX", 18);
        avaxNativeToken = new MockERC20("underlying token", "UNDER", 18);

        ftmNativeAssethToken = new MockERC20("hTOKEN-FTM", "LOCAL hTOKEN FOR TOKEN IN FMT", 18);
        ftmNativeToken = new MockERC20("underlying token", "UNDER", 18);

        // arbitrumNativeAssethToken
        arbitrumNativeToken = new MockERC20("underlying token", "UNDER", 18);
    }

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

    address public newAvaxAssetGlobalAddress;

    function testAddLocalToken() public {
        //Encode Data
        bytes memory data =
            abi.encode(address(avaxNativeToken), address(avaxNativeAssethToken), "UnderLocal Coin", "UL");

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

        newAvaxAssetGlobalAddress =
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxNativeAssethToken), avaxChainId);

        console2.log("New: ", newAvaxAssetGlobalAddress);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxNativeAssethToken), avaxChainId) != address(0),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, avaxChainId)
                == address(avaxNativeAssethToken),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(avaxNativeAssethToken), avaxChainId)
                == address(avaxNativeToken),
            "Token should be added"
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);

        // require (balanceBefore == MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent)), "Balance should not change");
    }

    address public newFtmAssetGlobalAddress;

    function testAddGlobalToken() public {
        //Add Local Token from Avax
        testAddLocalToken();

        //Encode Call Data
        bytes memory data = abi.encode(ftmCoreBridgeAgentAddress, newAvaxAssetGlobalAddress, ftmChainId, 0.0005 ether);

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

    address public newAvaxAssetLocalToken = address(0xFAFA);

    function testSetLocalToken() public {
        //Add Local Token from Avax
        testAddGlobalToken();

        //Encode Data
        bytes memory data = abi.encode(newAvaxAssetGlobalAddress, newAvaxAssetLocalToken, "UnderLocal Coin", "UL");

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x03), data);

        uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

        //Call Deposit function
        encodeSystemCall(
            payable(ftmCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.00001 ether,
            0,
            ftmChainId
        );

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(newAvaxAssetLocalToken, ftmChainId) == newAvaxAssetGlobalAddress,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(newAvaxAssetLocalToken), ftmChainId) == address(0),
            "Token should not exist"
        );
    }

    address public mockApp = address(0xDAFA);

    address public newArbitrumAssetGlobalAddress;

    function testAddLocalTokenArbitrum() public {
        //Set up
        testSetLocalToken();

        //Get some gas.
        hevm.deal(address(this), 1 ether);

        //Add new localToken
        arbitrumCoreRouter.addLocalToken{value: 0.0005 ether}(address(arbitrumNativeToken));

        uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

        newArbitrumAssetGlobalAddress =
            RootPort(rootPort).getLocalTokenFromUnder(address(arbitrumNativeToken), rootChainId);

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
                == address(arbitrumNativeToken),
            "Token should be added"
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);

        // require (balanceBefore == MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent)), "Balance should not change");
    }

    // ftmLocalWrappedNativeTokenAddress
    // ftmUnderlyingWrappedNativeTokenAddress

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
        arbitrumNativeToken.mint(address(this), 100 ether);

        //Approve spend by router
        arbitrumNativeToken.approve(address(localPortAddress), 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumNativeToken),
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
            address(arbitrumNativeToken),
            100 ether,
            100 ether,
            1 ether,
            0.5 ether
        );

        console2.log("LocalPort Balance:", MockERC20(arbitrumNativeToken).balanceOf(address(localPortAddress)));
        require(
            MockERC20(arbitrumNativeToken).balanceOf(address(localPortAddress)) == 50 ether,
            "LocalPort should have 50 tokens"
        );

        console2.log("User Balance:", MockERC20(arbitrumNativeToken).balanceOf(address(this)));
        require(MockERC20(arbitrumNativeToken).balanceOf(address(this)) == 50 ether, "User should have 50 tokens");

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
            arbitrumNativeToken.mint(address(localPortAddress), _amount - _deposit);
        }

        //Mint Underlying Token.
        if (_deposit > 0) arbitrumNativeToken.mint(_user, _deposit);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumNativeToken),
            amount: _amount,
            deposit: _deposit,
            toChain: rootChainId
        });

        console2.log("BALANCE BEFORE:");
        console2.log("arbitrumNativeToken Balance:", MockERC20(arbitrumNativeToken).balanceOf(_user));
        console2.log(
            "newArbitrumAssetGlobalAddress Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user)
        );

        //Call Deposit function
        hevm.startPrank(_user);
        arbitrumNativeToken.approve(address(localPortAddress), _deposit);
        ERC20hTokenRoot(newArbitrumAssetGlobalAddress).approve(address(rootPort), _amount - _deposit);
        arbitrumMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, 0.5 ether);
        hevm.stopPrank();

        // Test If Deposit was successful
        testCreateDepositSingle(
            arbitrumMulticallBridgeAgent,
            uint32(1),
            _user,
            address(newArbitrumAssetGlobalAddress),
            address(arbitrumNativeToken),
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

        console2.log("LocalPort Balance:", MockERC20(arbitrumNativeToken).balanceOf(address(localPortAddress)));
        console2.log("Expected:",_amount - _deposit + _deposit - _depositOut);
        require(
            MockERC20(arbitrumNativeToken).balanceOf(address(localPortAddress)) == _amount - _deposit + _deposit - _depositOut,
            "LocalPort tokens"
        );

        console2.log("RootPort Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootPort)));
        // console2.log("Expected:", 0); SINCE ORIGIN == DESTINATION == ARBITRUM
        require(MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootPort)) == 0, "RootPort tokens");

        console2.log("User Balance:", MockERC20(arbitrumNativeToken).balanceOf(_user));
        console2.log("Expected:", _depositOut);
        require(MockERC20(arbitrumNativeToken).balanceOf(_user) == _depositOut, "User tokens");

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
        console2.logUint(WETH9(wrappedNativeToken).balanceOf(address(localPortAddress)));

        // require(deposit.depositedGas == _depositedGas, "Deposit depositedGas doesn't match");
        // require(
        //     WETH9(wrappedNativeToken).balanceOf(address(rootPort)) == _depositedGas - _gasToBridgeOut,
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
        //             MockERC20(hTokens[0]).balanceOf(address(localPortAddress)) == 0,
        //             "Deposit hToken balance doesn't match"
        //         );
        //     } else if (amounts[0] - deposits[0] > 0 && deposits[0] > 0) {
        //         console2.log("3");
        //         console2.log(_user);
        //         console2.log(address(localPortAddress));

        //         require(MockERC20(hTokens[0]).balanceOf(_user) == 0, "Deposit hToken balance doesn't match");
        //         console2.log("4");

        //         require(MockERC20(tokens[0]).balanceOf(_user) == 0, "Deposit token balance doesn't match");
        //         console2.log("5");
        //         require(
        //             MockERC20(tokens[0]).balanceOf(address(localPortAddress)) == _deposit,
        //             "Deposit token balance doesn't match"
        //         );
        //     } else {
        //         console2.log("6");
        //         // require(MockERC20(tokens[0]).balanceOf(_user) == 0, "Deposit token balance doesn't match");
        //         // console2.log("7");
        //         // require(
        //         //     MockERC20(tokens[0]).balanceOf(address(localPortAddress)) == _deposit,
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

        console2.log("HERES SUPERE IMPORTANTNDSTRE AJLAFJSFJKAJKS");
        console2.log(_remoteExecGas);
        console2.logBytes(inputCalldata);

        hevm.mockCall(
            address(localAnyCongfig),
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
            address(localAnyCongfig),
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
            address(localAnyCongfig),
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
    //     ERC20hTokenBranch(_hToken).approve(localPortAddress, _amount - _deposit);
    //     MockERC20(_token).approve(localPortAddress, _deposit);

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
    //     MockERC20(_hTokens[0]).approve(localPortAddress, _amounts[0] - _deposits[0]);
    //     MockERC20(_tokens[0]).approve(localPortAddress, _deposits[0]);
    //     MockERC20(_hTokens[1]).approve(localPortAddress, _amounts[1] - _deposits[1]);
    //     MockERC20(_tokens[1]).approve(localPortAddress, _deposits[1]);

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
