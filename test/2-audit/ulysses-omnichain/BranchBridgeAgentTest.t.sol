//SPDX-License-Identifier: AGPL-3.0-only

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockBranchBridgeAgent, WETH9, DepositParams, DepositMultipleParams} from "./mocks/MockBranchBridgeAgent.t.sol";
import {
    IBranchRouter,
    Deposit,
    DepositStatus,
    DepositMultipleInput,
    DepositInput
} from "@omni/interfaces/IBranchRouter.sol";
import {BaseBranchRouter} from "@omni/BaseBranchRouter.sol";
import {BranchPort} from "@omni/BranchPort.sol";
import {ERC20hTokenBranch} from "@omni/token/ERC20hTokenBranch.sol";
import {RLPDecoder} from "@rlp/RLPDecoder.sol";

import {stdError} from "forge-std/StdError.sol";

import {WETH9 as WETH} from "./mocks/WETH9.sol";

import {console2} from "forge-std/console2.sol";

contract BranchBridgeAgentTest is DSTestPlus {
    MockERC20 underlyingToken;

    MockERC20 rewardToken;

    ERC20hTokenBranch testToken;

    BaseBranchRouter bRouter;

    MockBranchBridgeAgent bAgent;

    address wrappedNativeToken;

    uint24 rootChainId = uint24(42161);

    uint256 localChainId = uint256(1088);

    address rootBridgeAgentAddress = address(0xBEEF);

    address localAnyCallAddress = address(0xCAFE);

    address localAnyCongfig = address(0xCAFF);

    address localAnyCallExecutorAddress = address(0xABCD);

    address localPortAddress;

    address owner = address(this);

    function setUp() public {
        wrappedNativeToken = address(new WETH());

        underlyingToken = new MockERC20("underlying token", "UNDER", 18);

        rewardToken = new MockERC20("hermes token", "HERMES", 18);

        localPortAddress = address(new BranchPort(owner));

        testToken = new ERC20hTokenBranch("Hermes underlying token", "hUNDER", address(this));

        hevm.mockCall(
            localAnyCallAddress, abi.encodeWithSignature("executor()"), abi.encode(localAnyCallExecutorAddress)
        );

        hevm.mockCall(localAnyCallAddress, abi.encodeWithSignature("config()"), abi.encode(localAnyCongfig));

        bRouter = new BaseBranchRouter();

        BranchPort(localPortAddress).initialize(address(bRouter), address(this));

        bAgent = new MockBranchBridgeAgent(
            WETH9(wrappedNativeToken),
            rootChainId,
            localChainId,
            rootBridgeAgentAddress,
            localAnyCallAddress,
            localAnyCallExecutorAddress,
            address(bRouter),
            localPortAddress
        );

        bRouter.initialize(address(bAgent));

        BranchPort(localPortAddress).addBridgeAgent(address(bAgent));
    }

    function testCallOut() public {
        //Get some gas.
        hevm.deal(address(this), 1 ether);

        console2.logUint(1);
        console2.log(address(testToken), address(underlyingToken));

        //Call Deposit function
        IBranchRouter(bRouter).callOut{value: 1 ether}("testdata", 0.5 ether);

        console2.log("done bA");

        console2.log(address(this));

        //Test If Deposit was successful
        testCreateDepositSingle(uint32(1), address(this), address(0), address(0), 0, 0, 1 ether);
    }

    function testCallOutNotEnoughGas() public {
        //Get some gas.
        hevm.deal(address(this), 1 ether);

        console2.logUint(1);
        console2.log(address(testToken), address(underlyingToken));

        hevm.expectRevert(abi.encodeWithSignature("InsufficientGas()"));

        //Call Deposit function
        IBranchRouter(bRouter).callOut{value: 200}("testdata", 0);
    }

    function testFuzzCallOut(address _user, uint256 _amount, uint256 _toChain) public {
        // Input restrictions
        hevm.assume(_user > address(2) && _amount > 0 && _toChain > 0);

        // Prank into user account
        hevm.startPrank(_user);

        //Get some gas.
        hevm.deal(_user, 1 ether);

        //Call Deposit function
        IBranchRouter(bRouter).callOut{value: 1 ether}("testdata", 0.5 ether);

        // Prank out of user account
        hevm.stopPrank();

        // Test If Deposit was successful
        testCreateDepositSingle(uint32(1), _user, address(0), address(0), 0, 0, 1 ether);
    }

    function testCallOutWithDeposit() public {
        //Get some gas.
        hevm.deal(address(this), 1 ether);

        //Mint Test tokens.
        underlyingToken.mint(address(this), 100 ether);

        //Approve spend by router
        underlyingToken.approve(localPortAddress, 100 ether);

        console2.logUint(1);
        console2.log(address(testToken), address(underlyingToken));

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(testToken),
            token: address(underlyingToken),
            amount: 100 ether,
            deposit: 100 ether,
            toChain: rootChainId
        });

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}(bytes("test"), depositInput, 0.5 ether);

        //Test If Deposit was successful
        testCreateDepositSingle(
            uint32(1), address(this), address(testToken), address(underlyingToken), 100 ether, 100 ether, 1 ether
        );
    }

    function testCallOutInsufficientAmount() public {
        //Get some gas.
        hevm.deal(address(this), 1 ether);

        //Mint Test tokens.
        underlyingToken.mint(address(this), 90 ether);

        //Approve spend by router
        underlyingToken.approve(localPortAddress, 100 ether);

        console2.logUint(1);
        console2.log(address(testToken), address(underlyingToken));

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(testToken),
            token: address(underlyingToken),
            amount: 100 ether,
            deposit: 100 ether,
            toChain: rootChainId
        });

        hevm.expectRevert(abi.encodeWithSignature("TransferFromFailed()"));

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}(bytes("test"), depositInput, 0.5 ether);
    }

    function testCallOutIncorrectAmount() public {
        //Get some gas.
        hevm.deal(address(this), 1 ether);

        //Mint Test tokens.
        underlyingToken.mint(address(this), 100 ether);

        //Approve spend by router
        underlyingToken.approve(localPortAddress, 100 ether);

        console2.logUint(1);
        console2.log(address(testToken), address(underlyingToken));

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(testToken),
            token: address(underlyingToken),
            amount: 90 ether,
            deposit: 100 ether,
            toChain: rootChainId
        });

        hevm.expectRevert(stdError.arithmeticError);

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}(bytes("test"), depositInput, 0.5 ether);
    }

    function testFuzzCallOutWithDeposit(address _user, uint256 _amount, uint256 _deposit, uint256 _toChain) public {
        // Input restrictions
        hevm.assume(_user != address(0) && _amount > 0 && _amount > _deposit && _toChain > 0);

        //Get some gas.
        hevm.deal(_user, 1 ether);

        // Prank into Port
        hevm.startPrank(localPortAddress);

        // Mint Test tokens.
        ERC20hTokenBranch fuzzToken = new ERC20hTokenBranch("fuzz token", "FUZZ", localPortAddress);
        fuzzToken.mint(_user, _amount - _deposit);

        // Mint under tokens.
        ERC20hTokenBranch uunderToken = new ERC20hTokenBranch(
            "uunder token",
            "UU",
            localPortAddress
        );
        uunderToken.mint(_user, _deposit);

        hevm.stopPrank();

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(fuzzToken),
            token: address(uunderToken),
            amount: _amount,
            deposit: _deposit,
            toChain: rootChainId
        });

        // Prank into user account
        hevm.startPrank(_user);

        // Approve spend by router
        fuzzToken.approve(localPortAddress, _amount);
        uunderToken.approve(localPortAddress, _deposit);

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}(bytes("testdata"), depositInput, 0.5 ether);

        // Prank out of user account
        hevm.stopPrank();

        // Test If Deposit was successful
        testCreateDepositSingle(uint32(1), _user, address(fuzzToken), address(uunderToken), _amount, _deposit, 1 ether);
    }

    function testClearDeposit() public {
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(rootBridgeAgentAddress, rootChainId, 22)
        );

        // Create Test Deposit
        testCallOutWithDeposit();

        //Prepare deposit info
        DepositParams memory depositParams = DepositParams({
            hToken: address(testToken),
            token: address(underlyingToken),
            amount: 100 ether,
            deposit: 100 ether,
            toChain: rootChainId,
            depositNonce: 1,
            depositedGas: 1 ether
        });

        // Encode AnyFallback message
        bytes memory anyFallbackData = abi.encodePacked(
            bytes1(0x02),
            depositParams.depositNonce,
            depositParams.hToken,
            depositParams.token,
            depositParams.amount,
            depositParams.deposit,
            depositParams.toChain,
            bytes("testdata"),
            depositParams.depositedGas,
            depositParams.depositedGas / 2
        );

        hevm.mockCall(
            address(localAnyCongfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), rootChainId, anyFallbackData.length
            ),
            abi.encode(0)
        );

        // Call 'anyFallback'
        hevm.prank(localAnyCallExecutorAddress);
        bAgent.anyFallback(anyFallbackData);

        //Call redeemDeposit
        bAgent.redeemDeposit(1);

        // Check balances
        require(testToken.balanceOf(address(this)) == 0);
        require(underlyingToken.balanceOf(address(this)) == 100 ether);
        require(testToken.balanceOf(localPortAddress) == 0);
        require(underlyingToken.balanceOf(localPortAddress) == 0);
    }

    function testFuzzClearDeposit(address _user, uint256 _amount, uint256 _deposit, uint24 _toChain) public {
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(rootBridgeAgentAddress, rootChainId, 22)
        );

        // Input restrictions
        hevm.assume(_user != address(0) && _amount > 0 && _deposit <= _amount && _toChain > 0);

        hevm.startPrank(localPortAddress);

        // Mint Test tokens.
        ERC20hTokenBranch fuzzToken = new ERC20hTokenBranch(
            "Hermes omni token",
            "hUNDER",
            localPortAddress
        );
        fuzzToken.mint(_user, _amount - _deposit);
        MockERC20 underToken = new MockERC20("u token", "U", 18);
        underToken.mint(_user, _deposit);

        hevm.stopPrank();

        // Perform deposit
        makeTestCallWithDeposit(
            _user, address(fuzzToken), address(underToken), _amount, _deposit, _toChain, uint128(0.5 ether)
        );

        //Prepare deposit info
        DepositParams memory depositParams = DepositParams({
            hToken: address(fuzzToken),
            token: address(underlyingToken),
            amount: _amount,
            deposit: _deposit,
            toChain: rootChainId,
            depositNonce: 1,
            depositedGas: 1 ether
        });

        // Encode AnyFallback message
        bytes memory anyFallbackData = abi.encodePacked(
            bytes1(0x02),
            depositParams.depositNonce,
            depositParams.hToken,
            depositParams.token,
            depositParams.amount,
            depositParams.deposit,
            depositParams.toChain,
            bytes("testdata"),
            depositParams.depositedGas,
            depositParams.depositedGas / 2
        );

        hevm.mockCall(
            address(localAnyCongfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), rootChainId, anyFallbackData.length
            ),
            abi.encode(0)
        );

        // Call 'anyFallback'
        hevm.prank(localAnyCallExecutorAddress);
        bAgent.anyFallback(anyFallbackData);

        //Call redeemDeposit
        bAgent.redeemDeposit(1);

        // Check balances
        require(fuzzToken.balanceOf(address(_user)) == _amount - _deposit);
        require(underToken.balanceOf(address(_user)) == _deposit);
        require(fuzzToken.balanceOf(localPortAddress) == 0);
        require(underToken.balanceOf(localPortAddress) == 0);
    }

    // function testFuzzClearDeposit(
    //     address _user,
    //     uint256 _amount,
    //     uint256 _deposit,
    //     uint24 _toChain
    // ) public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(rootBridgeAgentAddress, _toChain, 22)
    //     );

    //     // Input restrictions
    //     hevm.assume(_user != address(0) && _amount > 0 && _deposit <= _amount && _toChain > 0);

    //     // Mint Test tokens.
    //     ERC20hTokenBranch fuzzToken = new ERC20hTokenBranch(
    //         "Hermes omni token",
    //         "hUNDER",
    //         localPortAddress
    //     );
    //     hevm.prank(localPortAddress);
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
    //     bAgent.anyExecute(clearDepositData);

    //     // Check balances
    //     require(fuzzToken.balanceOf(_user) == _amount - _deposit);
    //     require(underToken.balanceOf(_user) == _deposit);
    //     require(fuzzToken.balanceOf(localPortAddress) == 0);
    //     require(underToken.balanceOf(localPortAddress) == 0);
    // }

    function testFuzzClearToken(address _recipient, uint256 _amount, uint256 _deposit, uint24 _toChain) public {
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(rootBridgeAgentAddress, _toChain, 22)
        );

        // Input restrictions
        hevm.assume(_recipient > address(3) && _amount > 0 && _deposit <= _amount && _toChain > 0);

        hevm.startPrank(localPortAddress);

        // Mint Test tokens.
        ERC20hTokenBranch fuzzToken = new ERC20hTokenBranch(
            "Hermes omni token",
            "hUNDER",
            localPortAddress
        );
        fuzzToken.mint(_recipient, _amount - _deposit);

        MockERC20 underToken = new MockERC20("u token", "U", 18);
        underToken.mint(_recipient, _deposit);

        hevm.stopPrank();

        console2.log("DAAAAAAAATAAAAAAAAAAA");
        console2.log(_recipient);
        console2.log(address(fuzzToken));
        console2.log(address(underToken));
        console2.log(_amount);
        console2.log(_deposit);
        console2.log(_toChain);

        // Perform deposit
        makeTestCallWithDeposit(
            _recipient, address(fuzzToken), address(underToken), _amount, _deposit, _toChain, uint128(0.5 ether)
        );

        // // Encode Clear Token Execution Data
        // bytes memory clearTokenData = abi.encode(
        //     bytes1(0x04),
        //     _recipient,
        //     address(fuzzToken),
        //     address(underToken),
        //     _amount,
        //     _deposit,
        //     uint32(1)
        // );

        // Encode Settlement Data for Clear Token Execution
        bytes memory settlementData = abi.encodePacked(
            bytes1(0x01),
            _recipient,
            uint32(1),
            address(fuzzToken),
            address(underToken),
            _amount,
            _deposit,
            bytes(""),
            uint128(0.5 ether)
        );

        // Mock anycall fees
        hevm.mockCall(
            address(localAnyCongfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), rootChainId, settlementData.length
            ),
            abi.encode(0.1 ether)
        );

        // Call 'clearToken'
        hevm.prank(localAnyCallExecutorAddress);
        bAgent.anyExecute(settlementData);

        require(fuzzToken.balanceOf(_recipient) == _amount - _deposit);
        require(underToken.balanceOf(_recipient) == _deposit);
        require(fuzzToken.balanceOf(localPortAddress) == 0);
        require(underToken.balanceOf(localPortAddress) == 0);
    }

    address[] public hTokens;
    address[] public tokens;
    uint256[] public amounts;
    uint256[] public deposits;

    function testFuzzClearTokens(
        address _recipient,
        uint256 _amount0,
        uint256 _amount1,
        uint256 _deposit0,
        uint256 _deposit1,
        uint24 _toChain
    ) public {
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(rootBridgeAgentAddress, _toChain, 22)
        );

        // Input restrictions
        hevm.assume(
            _recipient > address(3) && _amount0 > 0 && _deposit0 <= _amount0 && _amount1 > 0 && _deposit1 <= _amount1
                && _toChain > 0
        );

        hevm.startPrank(localPortAddress);

        // Mint Test tokens.
        ERC20hTokenBranch fuzzToken0 = new ERC20hTokenBranch(
            "Hermes omni token 0",
            "hToken0",
            localPortAddress
        );
        fuzzToken0.mint(_recipient, _amount0 - _deposit0);
        ERC20hTokenBranch fuzzToken1 = new ERC20hTokenBranch(
            "Hermes omni token 1",
            "hToken1",
            localPortAddress
        );
        fuzzToken1.mint(_recipient, _amount1 - _deposit1);
        MockERC20 underToken0 = new MockERC20("u0 token", "U0", 18);
        MockERC20 underToken1 = new MockERC20("u1 token", "U1", 18);
        underToken0.mint(_recipient, _deposit0);
        underToken1.mint(_recipient, _deposit1);

        console2.log("DATA");
        console2.log(_recipient);
        console2.log(address(fuzzToken0));
        console2.log(address(fuzzToken1));
        console2.log(address(underToken0));
        console2.log(address(underToken1));
        console2.log(_amount0);
        console2.log(_amount1);
        console2.log(_deposit0);
        console2.log(_deposit1);
        console2.log(_toChain);

        hevm.stopPrank();

        // Cast to Dynamic
        hTokens.push(address(fuzzToken0));
        hTokens.push(address(fuzzToken1));
        tokens.push(address(underToken0));
        tokens.push(address(underToken1));
        amounts.push(_amount0);
        amounts.push(_amount1);
        deposits.push(_deposit0);
        deposits.push(_deposit1);

        console2.log("TOKENS");
        console2.log(hTokens[0], tokens[0]);
        console2.log(hTokens[1], tokens[1]);

        // Perform deposit
        makeTestCallWithDepositMultiple(_recipient, hTokens, tokens, amounts, deposits, _toChain, uint128(0.5 ether));

        // Encode Settlement Data for Clear Token Execution
        bytes memory settlementData = abi.encodePacked(
            bytes1(0x02),
            _recipient,
            uint8(2),
            uint32(1),
            hTokens,
            tokens,
            amounts,
            deposits,
            bytes(""),
            uint128(0.5 ether)
        );

        hevm.mockCall(
            address(localAnyCongfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), rootChainId, settlementData.length
            ),
            abi.encode(0)
        );

        // Call 'clearToken'
        hevm.prank(localAnyCallExecutorAddress);
        bAgent.anyExecute(settlementData);

        require(fuzzToken0.balanceOf(localPortAddress) == 0);
        require(fuzzToken1.balanceOf(localPortAddress) == 0);
        require(fuzzToken0.balanceOf(_recipient) == _amount0 - _deposit0);
        require(fuzzToken1.balanceOf(_recipient) == _amount1 - _deposit1);
        require(underToken0.balanceOf(localPortAddress) == 0);
        require(underToken1.balanceOf(localPortAddress) == 0);
        require(underToken0.balanceOf(_recipient) == _deposit0);
        require(underToken1.balanceOf(_recipient) == _deposit1);
    }

    function testCreateDeposit(
        uint32 _depositNonce,
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits
    ) private {
        // Get Deposit.
        Deposit memory deposit = bRouter.getDepositEntry(_depositNonce);

        // Check deposit
        require(deposit.owner == _user, "Deposit owner doesn't match");

        require(
            keccak256(abi.encodePacked(deposit.hTokens)) == keccak256(abi.encodePacked(_hTokens)),
            "Deposit local hToken doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.tokens)) == keccak256(abi.encodePacked(_tokens)),
            "Deposit underlying token doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.amounts)) == keccak256(abi.encodePacked(_amounts)),
            "Deposit amount doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.deposits)) == keccak256(abi.encodePacked(_deposits)),
            "Deposit deposit doesn't match"
        );

        require(deposit.status == DepositStatus.Success, "Deposit status should be success");

        for (uint256 i = 0; i < _hTokens.length; i++) {
            if (_amounts[i] - _deposits[i] > 0 && _deposits[i] == 0) {
                require(MockERC20(_hTokens[i]).balanceOf(_user) == 0);
            } else if (_amounts[i] - _deposits[i] > 0 && _deposits[i] > 0) {
                require(MockERC20(_hTokens[i]).balanceOf(_user) == 0);
                require(MockERC20(_tokens[i]).balanceOf(_user) == 0);
                require(MockERC20(_tokens[i]).balanceOf(localPortAddress) == _deposits[i]);
            } else {
                require(MockERC20(_tokens[i]).balanceOf(_user) == 0);
                require(MockERC20(_tokens[i]).balanceOf(localPortAddress) == _deposits[i]);
            }
        }
    }

    function testCreateDepositSingle(
        uint32 _depositNonce,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint128 _depositedGas
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
        Deposit memory deposit = bRouter.getDepositEntry(_depositNonce);

        // Check deposit
        require(deposit.owner == _user, "Deposit owner doesn't match");

        if (_amount != 0 || _deposit != 0) {
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
        }

        require(deposit.status == DepositStatus.Success, "Deposit status should be succesful.");

        console2.log("TEST DEPOSIT~");
        console2.logUint(deposit.depositedGas);
        console2.logUint(WETH9(wrappedNativeToken).balanceOf(localPortAddress));

        require(deposit.depositedGas == _depositedGas, "Deposit depositedGas doesn't match");
        require(
            WETH9(wrappedNativeToken).balanceOf(localPortAddress) == _depositedGas,
            "Deposit depositedGas balance doesn't match"
        );

        console2.log("1");
        console2.logUint(amounts[0]);
        console2.logUint(deposits[0]);

        if (hTokens[0] != address(0) || tokens[0] != address(0)) {
            if (amounts[0] > 0 && deposits[0] == 0) {
                console2.log("whyyyyy");

                require(MockERC20(hTokens[0]).balanceOf(_user) == 0, "Deposit hToken balance doesn't match");

                console2.log("2");
                require(MockERC20(hTokens[0]).balanceOf(localPortAddress) == 0, "Deposit hToken balance doesn't match");
            } else if (amounts[0] - deposits[0] > 0 && deposits[0] > 0) {
                console2.log("3");
                console2.log(_user);
                console2.log(localPortAddress);

                require(MockERC20(hTokens[0]).balanceOf(_user) == 0, "Deposit hToken balance doesn't match");
                console2.log("4");

                require(MockERC20(tokens[0]).balanceOf(_user) == 0, "Deposit token balance doesn't match");
                console2.log("5");
                require(
                    MockERC20(tokens[0]).balanceOf(localPortAddress) == _deposit, "Deposit token balance doesn't match"
                );
            } else {
                console2.log("6");
                require(MockERC20(tokens[0]).balanceOf(_user) == 0, "Deposit token balance doesn't match");
                console2.log("7");
                require(
                    MockERC20(tokens[0]).balanceOf(localPortAddress) == _deposit, "Deposit token balance doesn't match"
                );

                console2.log("8");
            }
        }
    }

    function makeTestCallWithDeposit(
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain,
        uint128 _rootExecGas
    ) private {
        //Prepare deposit info
        DepositInput memory depositInput =
            DepositInput({hToken: _hToken, token: _token, amount: _amount, deposit: _deposit, toChain: _toChain});

        // Prank into user account
        hevm.startPrank(_user);

        //Get some gas.
        hevm.deal(_user, 1 ether);

        // Approve spend by router
        ERC20hTokenBranch(_hToken).approve(localPortAddress, _amount - _deposit);
        MockERC20(_token).approve(localPortAddress, _deposit);

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}(bytes("testdata"), depositInput, _rootExecGas);

        // Prank out of user account
        hevm.stopPrank();

        // Test If Deposit was successful
        testCreateDepositSingle(uint32(1), _user, address(_hToken), address(_token), _amount, _deposit, 1 ether);
    }

    function makeTestCallWithDepositMultiple(
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain,
        uint128 _rootExecGas
    ) private {
        //Prepare deposit info
        DepositMultipleInput memory depositInput = DepositMultipleInput({
            hTokens: _hTokens,
            tokens: _tokens,
            amounts: _amounts,
            deposits: _deposits,
            toChain: _toChain
        });

        // Prank into user account
        hevm.startPrank(_user);

        //Get some gas.
        hevm.deal(_user, 1 ether);

        console2.log(_hTokens[0], _deposits[0]);

        // Approve spend by router
        MockERC20(_hTokens[0]).approve(localPortAddress, _amounts[0] - _deposits[0]);
        MockERC20(_tokens[0]).approve(localPortAddress, _deposits[0]);
        MockERC20(_hTokens[1]).approve(localPortAddress, _amounts[1] - _deposits[1]);
        MockERC20(_tokens[1]).approve(localPortAddress, _deposits[1]);

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridgeMultiple{value: 1 ether}(bytes("test"), depositInput, _rootExecGas);

        // Prank out of user account
        hevm.stopPrank();

        // Test If Deposit was successful
        testCreateDeposit(uint32(1), _user, _hTokens, _tokens, _amounts, _deposits);
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
    //         abi.encode(rootBridgeAgentAddress, rootChainId, 22)
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
    //     bAgent.anyExecute(finalizeDepositData);

    //     require(underlyingToken.balanceOf(address(this)) == 0);
    //     require(testToken.balanceOf(address(this)) == 100 ether);
    //     require(underlyingToken.balanceOf(localPortAddress) == 100 ether);
    //     require(testToken.balanceOf(localPortAddress) == 0);
    // }

    // function testFuzzFinalizeDeposit(address _user, uint256 _amount, uint256 _toChain) public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(rootBridgeAgentAddress, _toChain, 22)
    //     );

    //     // Input restrictions
    //     hevm.assume(_user != address(0) && _amount > 0 && _toChain > 0);

    //     // Mint Test tokens.
    //     MockERC20 underToken = new MockERC20("u token", "U", 18);
    //     underToken.mint(_user, _amount);
    //     ERC20hTokenBranch fuzzToken = new ERC20hTokenBranch(
    //         "Hermes omni token",
    //         "hUNDER",
    //         localPortAddress
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
    //     bAgent.anyExecute(finalizeDepositData);

    //     require(underToken.balanceOf(_user) == 0);
    //     require(fuzzToken.balanceOf(_user) == _amount);
    //     require(underToken.balanceOf(localPortAddress) == _amount);
    //     require(fuzzToken.balanceOf(localPortAddress) == 0);
    // }

    // function testFinalizeWithdraw() public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(rootBridgeAgentAddress, rootChainId, 22)
    //     );

    //     //Mint Test tokens.
    //     hevm.prank(localPortAddress);
    //     testToken.mint(address(this), 100 ether);
    //     underlyingToken.mint(localPortAddress, 100 ether);

    //     //Approve spend by router
    //     testToken.approve(localPortAddress, 100 ether);

    //     //Prepare deposit info
    //     DepositInput memory depositInput = DepositInput({
    //         hToken: address(testToken),
    //         token: address(underlyingToken),
    //         amount: 100 ether,
    //         deposit: 0,
    //         toChain: rootChainId
    //     });

    //     //Call Deposit function
    //     IBranchRouter(bRouter).callOut(bytes1(uint8(1)), bytes("test"), depositInput);

    //     //Test If Deposit was successful
    //     testCreateDepositSingle(
    //         uint32(1),
    //         address(this),
    //         address(testToken),
    //         address(underlyingToken),
    //         100 ether,
    //         0
    //     );

    //     // Encode Finalize Withdraw Execution Data
    //     bytes memory finalizeWithdrawData = abi.encode(
    //         bytes1(uint8(3)),
    //         uint32(1),
    //         address(underlyingToken)
    //     );

    //     // Call 'finalizeDeposit'
    //     hevm.prank(localAnyCallExecutorAddress);
    //     bAgent.anyExecute(finalizeWithdrawData);

    //     require(testToken.balanceOf(address(this)) == 0);
    //     require(underlyingToken.balanceOf(address(this)) == 100 ether);
    //     require(testToken.balanceOf(localPortAddress) == 0);
    //     require(underlyingToken.balanceOf(localPortAddress) == 0);
    // }

    // function testFuzzFinalizeWithdraw(address _user, uint256 _amount, uint256 _toChain) public {
    //     hevm.mockCall(
    //         localAnyCallExecutorAddress,
    //         abi.encodeWithSignature("context()"),
    //         abi.encode(rootBridgeAgentAddress, _toChain, 22)
    //     );

    //     // Input restrictions
    //     hevm.assume(_user != address(0) && _amount > 0 && _toChain > 0);

    //     // Mint Test tokens.
    //     ERC20hTokenBranch fuzzToken = new ERC20hTokenBranch(
    //         "Hermes omni token",
    //         "hUNDER",
    //         localPortAddress
    //     );
    //     hevm.prank(localPortAddress);
    //     fuzzToken.mint(_user, _amount);

    //     MockERC20 underToken = new MockERC20("u token", "U", 18);
    //     underToken.mint(localPortAddress, _amount);

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
    //     bAgent.anyExecute(finalizeWithdrawData);

    //     require(fuzzToken.balanceOf(_user) == 0);
    //     require(underToken.balanceOf(_user) == _amount);
    //     require(fuzzToken.balanceOf(localPortAddress) == 0);
    //     require(underToken.balanceOf(localPortAddress) == 0);
    // }
}
