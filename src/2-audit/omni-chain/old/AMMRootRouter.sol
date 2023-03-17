// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

// import "./interfaces/IRootRouter.sol";
// import { ICoreBridgeAgent as IBridgeAgent } from "./interfaces/ICoreBridgeAgent.sol";
// import { IVirtualAccount, Call } from "./interfaces/IVirtualAccount.sol";

// import { Path } from "./interfaces/Path.sol";
// import { ISwapRouter } from "./interfaces/ISwapRouter.sol";
// import { INonfungiblePositionManager } from "./interfaces/INonfungiblePositionManager.sol";

// import { IUniswapV3Staker } from "@v3-staker/interfaces/IUniswapV3Staker.sol";

// import { ITalosBaseStrategy } from "@talos/interfaces/ITalosBaseStrategy.sol";

// import { IMulticall2 } from "./interfaces/IMulticall2.sol";

// import { ERC20hTokenRoot } from "./token/ERC20hTokenRoot.sol";

// import { IERC20hTokenRootFactory as IFactory } from "./interfaces/IERC20hTokenRootFactory.sol";

// /**
//  * @title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
//  * @author MaiaDAO
//  * @dev Func IDs for calling these  functions through messaging layer.
//  *
//  *   CROSS-CHAIN MESSAGING FUNCIDs
//  *   -----------------------------
//  *   FUNC ID      | FUNC NAME
//  *   -------------+---------------
//  *   0x01         | exactInputSingle
//  *   0x02         | exactInput
//  *   0x03         | exactOutputSingle
//  *   0x04         | exactOutput
//  *   0x05         | mint
//  *   0x06         | increadseLiquidity
//  *   0x07         | decreaseLiquidity
//  *   0x08         | collect
//  *   0x09         | deposit
//  *   0x0a         | redeem
//  *   0x0b         | depositAndStake
//  *   0x0c         | mintDepositAndStake
//  *   0x0d         | unstakeAndWithdraw
//  *   0x0e         | unstakeAndWithdrawAndRemoveLiquidity
//  *   0x0f         | unstakeAndRestake
//  *
//  */
// contract AMMRootRouter is IRootRouter {
//     using Path for bytes;
//     using SafeTransferLib for address;

//     /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
//     uint256 public immutable localChainId;

//     /// @notice Local Wrapped Native Token
//     WETH9 public immutable wrappedNativeToken;

//     /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
//     address public immutable localPortAddress;

//     /// @notice Bridge Agent to maneg communcations and cross-chain assets. TODO
//     address payable public immutable bridgeAgentAddress;

//     /// @notice Ulysses Router Address
//     address public immutable ulyssesRouterAddress;

//     /// @notice Uni V3 Router Address
//     address public immutable uniswapRouterAddress;

//     /// @notice Multicall Address
//     address public immutable multicallAddress;

//     /// @notice Local Non Fungible Position Manager Address
//     address public immutable nonFungiblePositionManagerAddress;

//     /// @notice Local Uniswap V3 Staker Address
//     address public immutable uniswapV3StakerAddress;

//     uint256 public constant MIN_AMOUNT = 10**6;

//     constructor(
//         uint256 _localChainId,
//         address _wrappedNativeToken,
//         address _localPortAddress,
//         address _bridgeAgentAddress,
//         address _ulyssesRouterAddress,
//         address multicallyAddress,
//         address _uniswapRouterAddress,
//         address _nonFungiblePositionManagerAddress,
//         address _uniswapV3StakerAddress
//     ) {
//         localChainId = _localChainId;
//         wrappedNativeToken = WETH9(_wrappedNativeToken);
//         localPortAddress = _localPortAddress;
//         bridgeAgentAddress = payable(_bridgeAgentAddress);
//         ulyssesRouterAddress = _ulyssesRouterAddress;
//         multicallAddress = multicallyAddress;
//         uniswapRouterAddress = _uniswapRouterAddress;
//         nonFungiblePositionManagerAddress = _nonFungiblePositionManagerAddress;
//         uniswapV3StakerAddress = _uniswapV3StakerAddress;
//     }

//     /*///////////////////////////////////////////////////////////////
//                 ERC20 HTOKENS REMOTE FUNCTIONS
//     ////////////////////////////////////////////////////////////*/

//     function transfer(
//         address _token,
//         address _to,
//         uint256 _amount
//     ) internal {
//         _token.safeTransfer(_to, _amount);
//     }

//     /*///////////////////////////////////////////////////////////////
//                         SWAP REMOTE FUNCTIONS
//     ////////////////////////////////////////////////////////////*/

//     /*
//     CROSS CHAIN INTERACTION FLOW:
//     1. Check Local Token
//     2. Bridge In 
//     3. Do smth
//     4. Bridge Out
//     5. Create Settlement
//     6. Refund on fromChain if needed
//     7. Clear Tokens 
//     */

//     /**
//      *   @notice Function to perform a swap given the amount of tokens input.
//      *   @param params Uniswap V3 swap parameters.
//      *   @param outputNative If true, the output token will be underlying / native destination chain token.
//      *   @param dParams Cross Chain swap parameters.
//      *
//      */
//     function exactInputSingle(
//         ISwapRouter.ExactInputSingleParams memory params,
//         bool outputNative,
//         DepositParams memory dParams
//     )
//         internal
//         returns (
//             address outputToken,
//             uint256 amountOut,
//             uint256 depositOut
//         )
//     {
//         //Call desired function
//         amountOut = ISwapRouter(uniswapRouterAddress).exactInputSingle(params);
//         outputToken = params.tokenOut;
//         depositOut = outputNative ? amountOut : 0;
//     }

//     /**
//      *   @notice Function to perform a swap given the amount of token input.
//      *   @param params Uniswap V3 swap parameters.
//      *   @param outputNative If true, the output token will be underlying / native destination chain token.
//      *   @param dParams Cross Chain swap parameters.
//      *
//      */
//     function exactInput(
//         ISwapRouter.ExactInputParams memory params,
//         bool outputNative,
//         DepositParams memory dParams
//     )
//         internal
//         returns (
//             address outputToken,
//             uint256 amountOut,
//             uint256 depositOut
//         )
//     {
//         //Call desired function
//         amountOut = ISwapRouter(uniswapRouterAddress).exactInput(params);
//         outputToken = getOutputToken(params.path);
//         depositOut = outputNative ? amountOut : 0;
//     }

//     /**
//      *   @notice Function to perform a swap given the amount of tokens output.
//      *   @param params Uniswap V3 swap parameters.
//      *   @param outputNative If true, the output token will be underlying / native destination chain token.
//      *   @param dParams Cross Chain swap parameters.
//      *
//      */
//     function exactOutputSingle(
//         ISwapRouter.ExactOutputSingleParams memory params,
//         bool outputNative,
//         DepositParams memory dParams
//     )
//         internal
//         returns (
//             address[] memory outputTokens,
//             uint256[] memory amountsOut,
//             uint256[] memory depositsOut
//         )
//     {
//         outputTokens[0] = params.tokenOut;
//         amountsOut[0] = params.amountOut;
//         depositsOut[0] = outputNative ? params.amountOut : 0;

//         {
//             //Call desired function
//             uint256 amountIn = ISwapRouter(uniswapRouterAddress).exactOutputSingle(params);

//             //Calculate refund hTokens
//             uint256 refund = dParams.amount - amountIn;

//             //Refund extra deposited hTokens in destination chains.
//             if (refund > MIN_AMOUNT) {
//                 outputTokens[1] = params.tokenIn;
//                 amountsOut[1] = refund;
//                 depositsOut[1] = 0;
//             }
//         }
//     }

//     /**
//      *   @notice Function to perform a swap given the amount of tokens output.
//      *   @param params Uniswap V3 swap parameters.
//      *   @param dParams Cross Chain swap parameters.
//      *
//      */
//     function exactOutput(
//         ISwapRouter.ExactOutputParams memory params,
//         bool outputNative,
//         DepositParams memory dParams
//     )
//         internal
//         returns (
//             address[] memory outputTokens,
//             uint256[] memory amountsOut,
//             uint256[] memory depositsOut
//         )
//     {
//         outputTokens[0] = getOutputToken(params.path);
//         amountsOut[0] = params.amountOut;
//         depositsOut[0] = outputNative ? params.amountOut : 0;

//         {
//             //Call desired function
//             uint256 amountIn = ISwapRouter(uniswapRouterAddress).exactOutput(params);

//             //Calculate refund hTokens
//             uint256 refund = dParams.amount - amountIn;

//             //Refund extra deposited hTokens in destination chain.
//             if (refund > MIN_AMOUNT) {
//                 (address tokenIn, , ) = params.path.decodeFirstPool();
//                 outputTokens[1] = tokenIn;
//                 amountsOut[1] = refund;
//                 depositsOut[1] = 0;
//             }
//         }
//     }

//     /**
//      *   @notice Function to perform a swap given the amount of token input.
//      *   @param userAccount Virtual Account address.
//      *   @param calls to perform with Virtual Account balance.
//      *   @param outputToken Token to be bridged.
//      *   @param amountToBridge Amount of token to be bridged.
//      *
//      */
//     function multicallNoDepositInteraction(
//         address userAccount,
//         Call[] memory calls,
//         address outputToken,
//         uint256 amountToBridge
//     ) internal {
//         //Call desired functions
//         (, bytes memory returnData) = IVirtualAccount(userAccount).call(
//             Call({
//                 target: multicallAddress,
//                 callData: abi.encodeWithSignature("aggregate(Call[])", calls)
//             })
//         );

//         //If requested Withdraw assets from Virtual Account
//         if (amountToBridge > 0)
//             IVirtualAccount(userAccount).withdrawERC20(outputToken, amountToBridge);
//     }

//     /**
//      * @notice Function to perform a swap given the amount of token input.
//      *  @param userAccount Virtual Account address.
//      *  @param calls Uniswap V3 and Ulysses Router calls.
//      *  @param outputToken Token to be bridged.
//      *  @param amountToBridge Amount of token to be bridged.
//      *  @param dParams Cross Chain Deposit parameters.
//      *  @param fromChainId Chain Id of the chain where the deposit was made.
//      *
//      */
//     function multicallSingleDepositInteraction(
//         address userAccount,
//         Call[] memory calls,
//         address outputToken,
//         uint256 amountToBridge,
//         DepositParams memory dParams,
//         uint256 fromChainId
//     ) internal {
//         // Get global address of deposited local hToken.
//         address globalAddress = IPort(localPortAddress).getGlobalTokenFromLocal(
//             dParams.hToken,
//             fromChainId
//         );

//         //Transfer assets to Virtual Account
//         if (dParams.amount > 0) globalAddress.safeTransfer(userAccount, dParams.amount);

//         //Call desired functions
//         (, bytes memory returnData) = IVirtualAccount(userAccount).call(
//             Call({
//                 target: multicallAddress,
//                 callData: abi.encodeWithSignature("aggregate(Call[])", calls)
//             })
//         );

//         //If requested Withdraw assets from Virtual Account
//         if (amountToBridge > 0)
//             IVirtualAccount(userAccount).withdrawERC20(outputToken, amountToBridge);
//     }

//     /**
//      *   @notice Function to perform a swap given the amount of token input.
//      *   @param userAccount Virtual Account address.
//      *   @param calls Uniswap V3 and Ulysses Router calls.
//      *   @param outputTokens Tokens to be bridged.
//      *   @param amountsToBridge Amounts of tokens to be bridged.
//      *   @param dParams Cross Chain Deposit parameters.
//      *   @param fromChainId Chain Id of the chain where the deposit was made.
//      *
//      */
//     function multicallMultipleDepositInteraction(
//         address userAccount,
//         Call[] memory calls,
//         address[] memory outputTokens,
//         uint256[] memory amountsToBridge,
//         DepositMultipleParams memory dParams,
//         uint256 fromChainId
//     ) internal {
//         for (uint256 i = 0; i < dParams.hTokens.length; i++) {
//             if (dParams.amounts[i] > 0) {
//                 // Get global address of deposited local hToken.
//                 address globalAddress = IPort(localPortAddress).getGlobalTokenFromLocal(
//                     dParams.hTokens[i],
//                     fromChainId
//                 );

//                 //Transfer assets to Virtual Account
//                 globalAddress.safeTransfer(userAccount, dParams.amounts[i]);
//             }
//         }

//         //Call desired functions
//         (, bytes memory returnData) = IVirtualAccount(userAccount).call(
//             Call({
//                 target: multicallAddress,
//                 callData: abi.encodeWithSignature("aggregate(Call[])", calls)
//             })
//         );

//         for (uint256 i = 0; i < outputTokens.length; i++) {
//             //If requested Withdraw assets from Virtual Account
//             if (amountsToBridge[i] > 0) {
//                 IVirtualAccount(userAccount).withdrawERC20(outputTokens[i], amountsToBridge[i]);
//             }
//         }
//     }

//     /**
//      *  @notice Function to return output global token from uniswap trade path.
//      *  @param _path the path to get the output token from.
//      *
//      */
//     function getOutputToken(bytes memory _path) internal pure returns (address token) {
//         uint256 length = _path.numPools();
//         for (uint256 i = 0; i < length; i++) {
//             (, address tokenB, ) = _path.decodeFirstPool();
//             token = tokenB;
//             if (i < length - 1) _path.skipToken();
//         }
//     }

//     /*///////////////////////////////////////////////////////////////
//          NON FUNGIBLE POSITIONS MANAGEMENT EXTERNAL FUNCTIONS
//     ////////////////////////////////////////////////////////////*/
//     /**
//      *  @notice Function to mint a new NFT position.
//      *  @param userAccount Virtual Account address.
//      *  @param params NFT mint parameters.
//      */
//     function mint(address userAccount, INonfungiblePositionManager.MintParams memory params)
//         internal
//     {
//         // Get address of NFT manager
//         address positionManager = nonFungiblePositionManagerAddress;

//         //Mint NFT
//         (uint256 tokenId, , , ) = INonfungiblePositionManager(positionManager).mint(params);

//         // deposit NFT into user account
//         INonfungiblePositionManager(positionManager).safeTransferFrom(
//             address(this),
//             userAccount,
//             tokenId
//         );
//     }

//     /**
//      *  @notice Function to increase liquidity in an existing NFT position.
//      *  @param userAccount Virtual Account address.
//      *  @param params NFT mint parameters.
//      *  @param localAddress0 Local address of token0.
//      *  @param localAddress1 Local address of token1.
//      *  @param amount0 Amount of token0 to deposit.
//      *  @param amount1 Amount of token1 to deposit.
//      *  @param fromChainId Chain Id of the chain where the deposit was made.
//      */
//     function increaseLiquidity(
//         address userAccount,
//         INonfungiblePositionManager.IncreaseLiquidityParams memory params,
//         address localAddress0,
//         address localAddress1,
//         uint256 amount0,
//         uint256 amount1,
//         uint256 fromChainId
//     ) internal {
//         // Get root port address
//         address portAddress = localPortAddress;

//         // Get global address of deposited local hTokens.
//         address globalAddress0 = IPort(portAddress).getGlobalTokenFromLocal(
//             localAddress0,
//             fromChainId
//         );

//         address globalAddress1 = IPort(portAddress).getGlobalTokenFromLocal(
//             localAddress1,
//             fromChainId
//         );

//         //Transfer assets to Virtual Account
//         if (amount0 > 0) globalAddress0.safeTransfer(userAccount, amount0);
//         if (amount1 > 0) globalAddress1.safeTransfer(userAccount, amount1);

//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: nonFungiblePositionManagerAddress,
//                 callData: abi.encodeWithSignature(
//                     "increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams)",
//                     params
//                 )
//             })
//         );
//     }

//     /**
//      *  @notice Function to decrease liquidity in an existing NFT position.
//      *  @param userAccount Virtual Account address.
//      *  @param params NFT mint parameters.
//      *  @param outputNative Boolean to indicate if output is native.
//      *  @param toChainId Chain Id of the chain where the deposit will be made.
//      */
//     function decreaseLiquidity(
//         address userAccount,
//         INonfungiblePositionManager.DecreaseLiquidityParams memory params,
//         bool outputNative,
//         uint256 toChainId
//     )
//         internal
//         returns (
//             address[] memory outputTokens,
//             uint256[] memory amountsOut,
//             uint256[] memory depositsOut
//         )
//     {
//         // Get address of NFT manager
//         address positionManager = nonFungiblePositionManagerAddress;

//         (, bytes memory returnData) = IVirtualAccount(userAccount).call(
//             Call({
//                 target: positionManager,
//                 callData: abi.encodeWithSignature(
//                     "decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams)",
//                     params
//                 )
//             })
//         );

//         if (toChainId != 0) {
//             //Decode return data
//             (amountsOut[0], amountsOut[1]) = abi.decode(returnData, (uint256, uint256));

//             //Get Token Address
//             (, , outputTokens[0], outputTokens[1], , , , , , , , ) = INonfungiblePositionManager(
//                 positionManager
//             ).positions(params.tokenId);

//             //Withdraw assets from Virtual Account
//             if (amountsOut[0] > 0)
//                 IVirtualAccount(userAccount).withdrawERC20(outputTokens[0], amountsOut[0]);
//             if (amountsOut[1] > 0)
//                 IVirtualAccount(userAccount).withdrawERC20(outputTokens[1], amountsOut[1]);
//         }
//     }

//     /**
//      *  @notice Function to collect fees in an existing NFT position.
//      *  @param userAccount Virtual Account address.
//      *  @param params NFT mint parameters.
//      *  @param outputNative Boolean to indicate if output is native.
//      *  @param toChainId Chain Id of the chain where the deposit will be made.
//      */
//     function collect(
//         address userAccount,
//         INonfungiblePositionManager.CollectParams memory params,
//         bool outputNative,
//         uint256 toChainId
//     )
//         internal
//         returns (
//             address[] memory outputTokens,
//             uint256[] memory amountsOut,
//             uint256[] memory depositsOut
//         )
//     {
//         // Get address of NFT manager
//         address positionManager = nonFungiblePositionManagerAddress;

//         (, bytes memory returnData) = IVirtualAccount(userAccount).call(
//             Call({
//                 target: positionManager,
//                 callData: abi.encodeWithSignature(
//                     "collect(INonfungiblePositionManager.CollectParams)",
//                     params
//                 )
//             })
//         );

//         //If requested withdraw from Virtual Account
//         if (toChainId != 0) {
//             //Decode return data
//             (amountsOut[0], amountsOut[1]) = abi.decode(returnData, (uint256, uint256));

//             //Get Token Address
//             (, , outputTokens[0], outputTokens[1], , , , , , , , ) = INonfungiblePositionManager(
//                 positionManager
//             ).positions(params.tokenId);

//             //Withdraw assets from Virtual Account
//             if (amountsOut[0] > 0)
//                 IVirtualAccount(userAccount).withdrawERC20(outputTokens[0], amountsOut[0]);
//             if (amountsOut[1] > 0)
//                 IVirtualAccount(userAccount).withdrawERC20(outputTokens[1], amountsOut[1]);
//         }
//     }

//     // /*///////////////////////////////////////////////////////////////
//     //      T.A.L.O.S. LIQUIDITY MANAGEMENT REMOTE FUNCTIONS
//     // ////////////////////////////////////////////////////////////*/
//     /**
//      *  @notice Function to deposit assets in a new NFT position.
//      *  @param userAccount Virtual Account address.
//      *  @param talosPositionAddress TALOS Position address.
//      *  @param amount0Desired Amount of token0 desired.
//      *  @param amount1Desired Amount of token1 desired.
//      *  @param localAddress0 Local address of token0.
//      *  @param localAddress1 Local address of token1.
//      *  @param fromChainId Chain Id of the chain where the deposit will be made.
//      */
//     function deposit(
//         address userAccount,
//         address talosPositionAddress,
//         uint256 amount0Desired,
//         uint256 amount1Desired,
//         address localAddress0,
//         address localAddress1,
//         uint256 fromChainId
//     ) internal {
//         //Get local port address
//         address portAddress = localPortAddress;

//         // Get global address of deposited local hToken.
//         address globalAddress0 = IPort(portAddress).getGlobalTokenFromLocal(
//             localAddress0,
//             fromChainId
//         );

//         address globalAddress1 = IPort(portAddress).getGlobalTokenFromLocal(
//             localAddress1,
//             fromChainId
//         );

//         //Transfer assets to Virtual Account
//         if (globalAddress0 != address(0)) globalAddress0.safeTransfer(userAccount, amount0Desired);
//         if (globalAddress1 != address(0)) globalAddress1.safeTransfer(userAccount, amount1Desired);

//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: talosPositionAddress,
//                 callData: abi.encodeWithSignature(
//                     "deposit(uint256,uint256,address)",
//                     amount0Desired,
//                     amount1Desired,
//                     userAccount
//                 )
//             })
//         );
//     }

//     /**
//      *  @notice Function to deposit assets in an existing NFT position.
//      *  @param userAccount Virtual Account address.
//      *  @param talosPositionAddress TALOS Position address.
//      *  @param shares Amount of shares to deposit.
//      *  @param outputNative Boolean to indicate if output is native.
//      *  @param toChainId Chain Id of the destination chain.
//      */
//     function redeem(
//         address userAccount,
//         address talosPositionAddress,
//         uint256 shares,
//         bool outputNative,
//         uint256 toChainId
//     )
//         internal
//         returns (
//             address[] memory outputTokens,
//             uint256[] memory amountsOut,
//             uint256[] memory depositsOut
//         )
//     {
//         //Give Virtual Account call instructions
//         (, bytes memory returnData) = IVirtualAccount(userAccount).call(
//             Call({
//                 target: talosPositionAddress,
//                 callData: abi.encodeWithSignature(
//                     "redeem(uint256,address)",
//                     shares,
//                     userAccount,
//                     userAccount
//                 )
//             })
//         );

//         //Decode return data
//         (amountsOut[0], amountsOut[1]) = abi.decode(returnData, (uint256, uint256));

//         //Get token addresses
//         (outputTokens[0], outputTokens[1]) = (
//             address(ITalosBaseStrategy(talosPositionAddress).token0()),
//             address(ITalosBaseStrategy(talosPositionAddress).token1())
//         );

//         //If requested Withdraw assets from Virtual Account
//         if (toChainId != 0) {
//             if (amountsOut[0] > 0)
//                 IVirtualAccount(userAccount).withdrawERC20(outputTokens[0], amountsOut[0]);
//             if (amountsOut[1] > 0)
//                 IVirtualAccount(userAccount).withdrawERC20(outputTokens[1], amountsOut[1]);
//         }
//     }

//     /*///////////////////////////////////////////////////////////////
//                     BOOST AGGREGATOR REMOTE FUNCTIONS
//     ///////////////////////////////////////////////////////////////*/

//     /**
//      *  @notice Function to deposit assets in an existing NFT position.
//      *  @param userAccount Virtual Account address.
//      *  @param boostAggregator Boost Aggregator address.
//      *  @param tokenId Id of the NFT to deposit.
//      */
//     function depositAndStake(
//         address userAccount,
//         address boostAggregator,
//         uint256 tokenId
//     ) internal {
//         //Give Virtual Account call instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: boostAggregator,
//                 callData: abi.encodeWithSignature("depositAndStake(uint256)", tokenId)
//             })
//         );
//     }

//     /**
//      *  @notice Function to deposit assets in an NFT position adn stake in a boost aggregator.
//      *  @param userAccount Virtual Account address.
//      *  @param params Parameters to mint a new NFT position.
//      *  @param boostAggregator Boost Aggregator address.
//      */
//     function mintDepositAndStake(
//         address userAccount,
//         INonfungiblePositionManager.MintParams memory params,
//         address boostAggregator
//     ) internal {
//         // Get non fungible position manager address
//         address positionManager = nonFungiblePositionManagerAddress;

//         (uint256 tokenId, , , ) = INonfungiblePositionManager(positionManager).mint(params);

//         // deposit NFT into user account
//         INonfungiblePositionManager(positionManager).safeTransferFrom(
//             address(this),
//             userAccount,
//             tokenId
//         );

//         //Give Virtual Account deposit and stake instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: boostAggregator,
//                 callData: abi.encodeWithSignature("depositAndStake(uint256)", tokenId)
//             })
//         );
//     }

//     /**
//      *  @notice Function to unstake NFT from boost aggregator.
//      *  @param userAccount Virtual Account address.
//      *  @param boostAggregator Boost Aggregator address.
//      *  @param tokenId Id of the NFT to deposit.
//      */
//     function unstakeAndWithdraw(
//         address userAccount,
//         address boostAggregator,
//         uint256 tokenId
//     ) internal {
//         //Give Virtual Account unstakeAndWithdraw instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: boostAggregator,
//                 callData: abi.encodeWithSignature("unstakeAndWithdraw(uint256)", tokenId)
//             })
//         );
//     }

//     /**
//      *  @notice Function to unstake NFT from boost aggregator and withdraw assets.
//      *  @param userAccount Virtual Account address.
//      *  @param boostAggregator Boost Aggregator address.
//      *  @param tokenId Id of the NFT to deposit.
//      *  @param params Parameters to decrease liquidity of an NFT position.
//      *  @param outputNative Boolean to indicate if output is native.
//      *  @param toChainId Chain Id of the destination chain.
//      */
//     function unstakeWithdrawAndRemoveLiquidity(
//         address userAccount,
//         address boostAggregator,
//         uint256 tokenId,
//         INonfungiblePositionManager.DecreaseLiquidityParams memory params,
//         bool outputNative,
//         uint256 toChainId
//     )
//         internal
//         returns (
//             address[] memory outputTokens,
//             uint256[] memory amountsOut,
//             uint256[] memory depositsOut
//         )
//     {
//         // Get non fungible position manager address
//         address positionManager = nonFungiblePositionManagerAddress;

//         //Give Virtual Account unstakeAndWithdraw instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: boostAggregator,
//                 callData: abi.encodeWithSignature("unstakeAndWithdraw(uint256)", tokenId)
//             })
//         );

//         (, bytes memory returnData) = IVirtualAccount(userAccount).call(
//             Call({
//                 target: positionManager,
//                 callData: abi.encodeWithSignature(
//                     "decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams)",
//                     params
//                 )
//             })
//         );

//         if (toChainId != 0) {
//             //Decode return data
//             (amountsOut[0], amountsOut[1]) = abi.decode(returnData, (uint256, uint256));

//             //Get Token Address
//             (, , outputTokens[0], outputTokens[1], , , , , , , , ) = INonfungiblePositionManager(
//                 positionManager
//             ).positions(params.tokenId);

//             //Withdraw assets from Virtual Account
//             if (amountsOut[0] > 0)
//                 IVirtualAccount(userAccount).withdrawERC20(outputTokens[0], amountsOut[0]);
//             if (amountsOut[1] > 0)
//                 IVirtualAccount(userAccount).withdrawERC20(outputTokens[1], amountsOut[1]);
//         }
//     }

//     /**
//      *  @notice Function to unstake NFT from boost aggregator and restake in a new boost aggregator.
//      *  @param userAccount Virtual Account address.
//      *  @param originBoostAggregator Boost Aggregator address.
//      *  @param destinationBoostAggregator Boost Aggregator address.
//      *  @param tokenId Id of the NFT to deposit.
//      */
//     function unstakeAndRestakeToNewAggregator(
//         address userAccount,
//         address originBoostAggregator,
//         address destinationBoostAggregator,
//         uint256 tokenId
//     ) internal {
//         //Give Virtual Account unstakeAndWithdraw instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: originBoostAggregator,
//                 callData: abi.encodeWithSignature("unstakeAndWithdraw(uint256)", tokenId)
//             })
//         );

//         //Give Virtual Account stakeAndDeposit instructions
//         IVirtualAccount(userAccount).call(
//             Call({
//                 target: destinationBoostAggregator,
//                 callData: abi.encodeWithSignature("depositAndStake(uint256)", tokenId)
//             })
//         );
//     }

//     /*///////////////////////////////////////////////////////////////
//                         INTERNAL HOOKS
//     ////////////////////////////////////////////////////////////*/
//     /**
//      *  @notice Function to call 'clearToken' on the Root Port.
//      *  @param recipient Address to receive the output hTokens.
//      *  @param outputToken Address of the output hToken.
//      *  @param amountOut Amount of output hTokens to send.
//      *  @param depositOut Amount of output hTokens to deposit.
//      *  @param toChain Chain Id of the destination chain.
//      */
//     function _approveAndCallOut(
//         address recipient,
//         address outputToken,
//         uint256 amountOut,
//         uint256 depositOut,
//         uint256 toChain
//     ) internal virtual {
//         // Get local port address
//         address portAddress = localPortAddress;
//         //Approve Root Port to spend/send output hTokens.
//         ERC20hTokenRoot(outputToken).approve(localPortAddress, amountOut);

//         //Move output hTokens from Root to Branch and call 'clearToken'.
//         IBridgeAgent(bridgeAgentAddress).bridgeOutAndCall{ value: msg.value }(
//             recipient,
//             "",
//             outputToken,
//             amountOut,
//             depositOut,
//             toChain
//         );
//     }

//     /**
//         *  @notice Function to approve token spend Bridge Agent.
//         * 

//      */
//     function _approveMultipleAndCallOut(
//         address recipient,
//         address[] memory outputTokens,
//         uint256[] memory amountsOut,
//         uint256[] memory depositsOut,
//         uint256 toChain
//     ) internal virtual {
//         //Get local port address
//         address portAddress = localPortAddress;
//         //Approve Root Port to spend/send output hTokens.
//         ERC20hTokenRoot(outputTokens[0]).approve(portAddress, amountsOut[0]);
//         if (amountsOut[1] > 0) ERC20hTokenRoot(outputTokens[1]).approve(portAddress, amountsOut[1]);

//         //Move output hTokens from Root to Branch and call 'clearTokens'.
//         IBridgeAgent(bridgeAgentAddress).bridgeOutAndCallMultiple{ value: msg.value }(
//             recipient,
//             "",
//             outputTokens,
//             amountsOut,
//             depositsOut,
//             toChain
//         );
//     }

//     /*///////////////////////////////////////////////////////////////
//                         ANYCALL FUNCTIONS
//     ////////////////////////////////////////////////////////////*/
//     /**
//      *     @notice Function responsible of executing a branch router response.
//      *     @param funcId 1 byte called Router function identifier.
//      *     @param data data received from messaging layer.
//      *     @param fromChainId chain where the request originated from.
//      *
//      *   2            | addLocalToken
//      *   3            | setLocalToken
//      *
//      */
//     function anyExecuteResponse(
//         bytes1 funcId,
//         bytes calldata data,
//         uint256 fromChainId
//     ) external payable override requiresAgent returns (bool success, bytes memory result) {
//         revert();
//     }

//     /**
//      *     @notice Function responsible of executing a crosschain request without any deposit.
//      *     @param funcId 1 byte Router function identifier.
//      *     @param rlpEncodedData data received from messaging layer.
//      *     @param fromChainId chain where the request originated from.
//      *
//      *   1            | addGlobalToken
//      *
//      */
//     function anyExecute(
//         bytes1 funcId,
//         bytes calldata rlpEncodedData,
//         uint256 fromChainId
//     ) external payable override requiresAgent returns (bool success, bytes memory result) {
//         revert();
//     }

//     /**
//      *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information attached.
//      *   @param funcId 1 byte Router function identifier.
//      *   @param rlpEncodedData execution data received from messaging layer.
//      *   @param dParams cross-chain deposit information.
//      *   @param fromChainId chain where the request originated from.
//      *
//      *   4            | exactInputSingle
//      *   5            | exactInput
//      *   6            | exactOutputSingle
//      *   7            | exactOutput
//      *
//      *
//      */
//     function anyExecute(
//         bytes1 funcId,
//         bytes calldata rlpEncodedData,
//         DepositParams memory dParams,
//         uint256 fromChainId
//     ) external payable override requiresAgent returns (bool success, bytes memory result) {
//         /// FUNC ID: 4 (exactInputSingle)
//         if (funcId == 0x04) {
//             (ISwapRouter.ExactInputSingleParams memory params, bool outputNative) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (ISwapRouter.ExactInputSingleParams, bool)
//             ); // TODO max 16 bytes32 slots

//             (address outputToken, uint256 amountOut, uint256 depositOut) = exactInputSingle(
//                 params,
//                 outputNative,
//                 dParams
//             );

//             _approveAndCallOut(
//                 params.recipient,
//                 outputToken,
//                 amountOut,
//                 depositOut,
//                 dParams.toChain
//             );

//             emit LogCallin(funcId, rlpEncodedData, fromChainId);

//             /// FUNC ID: 5 (exactInput)
//         } else if (funcId == 0x05) {
//             (ISwapRouter.ExactInputParams memory params, bool outputNative) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (ISwapRouter.ExactInputParams, bool)
//             ); // TODO max 16 bytes32 slots

//             (address outputToken, uint256 amountOut, uint256 depositOut) = exactInput(
//                 params,
//                 outputNative,
//                 dParams
//             );

//             _approveAndCallOut(
//                 params.recipient,
//                 outputToken,
//                 amountOut,
//                 depositOut,
//                 dParams.toChain
//             );

//             emit LogCallin(funcId, rlpEncodedData, fromChainId);

//             ///  FUNC ID: 6 (exactOutputSingle)
//         } else if (funcId == 0x06) {
//             (ISwapRouter.ExactOutputSingleParams memory params, bool outputNative) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (ISwapRouter.ExactOutputSingleParams, bool)
//             ); // TODO max 16 bytes32 slots

//             (
//                 address[] memory outputTokens,
//                 uint256[] memory amountsOut,
//                 uint256[] memory depositsOut
//             ) = exactOutputSingle(params, outputNative, dParams);

//             _approveMultipleAndCallOut(
//                 params.recipient,
//                 outputTokens,
//                 amountsOut,
//                 depositsOut,
//                 dParams.toChain
//             );

//             emit LogCallin(funcId, rlpEncodedData, fromChainId);

//             ///  FUNC ID: 7 (exactOutput)
//         } else if (funcId == 0x07) {
//             (ISwapRouter.ExactOutputParams memory params, bool outputNative) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (ISwapRouter.ExactOutputParams, bool)
//             ); // TODO max 16 bytes32 slots

//             (
//                 address[] memory outputTokens,
//                 uint256[] memory amountsOut,
//                 uint256[] memory depositsOut
//             ) = exactOutput(params, outputNative, dParams);

//             _approveMultipleAndCallOut(
//                 params.recipient,
//                 outputTokens,
//                 amountsOut,
//                 depositsOut,
//                 dParams.toChain
//             );

//             emit LogCallin(funcId, rlpEncodedData, fromChainId);
//         } else {
//             return (false, "unknown selector");
//         }
//         return (true, "");
//     }

//     /**
//      *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information for multiple assets attached.
//      *   @param funcId 1 byte Router function identifier.
//      *   @param rlpEncodedData execution data received from messaging layer.
//      *   @param dParams cross-chain multiple deposit information.
//      *   @param fromChainId chain where the request originated from.
//      *
//      */
//     function anyExecute(
//         bytes1 funcId,
//         bytes calldata rlpEncodedData,
//         DepositMultipleParams memory dParams,
//         uint256 fromChainId
//     ) external payable requiresAgent returns (bool, bytes memory) {
//         revert();
//     }

//     /**
//      *     @notice Function responsible of executing a signed crosschain request without any deposit.
//      *     @param funcId 1 byte Router function identifier.
//      *     @param rlpEncodedData execution data received from messaging layer.
//      *     @param fromChainId chain where the request originated from.
//      *
//      *   10           | decreaseLiquidity
//      *   11           | collect
//      *   13           | redeeem
//      *   16           | unstakeAndWithdraw
//      *   17           | unstakeAndWithdrawAndRemoveLiquidity
//      *   18           | unstakeAndRestakeToNewAggregator
//      *
//      */
//     function anyExecute(
//         bytes1 funcId,
//         bytes memory rlpEncodedData,
//         address userAccount,
//         uint256 fromChainId
//     ) external payable override requiresAgent returns (bool success, bytes memory result) {
//         ///  FUNC ID: 10 (uniswapv3 position decreaseliquidity)
//         if (funcId == 0x0a) {
//             (
//                 INonfungiblePositionManager.DecreaseLiquidityParams memory params,
//                 bool outputNative,
//                 uint256 toChainId
//             ) = abi.decode(
//                     RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                     (INonfungiblePositionManager.DecreaseLiquidityParams, bool, uint256)
//                 ); // TODO max 16 bytes32 slots

//             (
//                 address[] memory outputTokens,
//                 uint256[] memory amountsOut,
//                 uint256[] memory depositsOut
//             ) = decreaseLiquidity(userAccount, params, outputNative, toChainId);

//             _approveMultipleAndCallOut(
//                 IVirtualAccount(userAccount).userAddress(),
//                 outputTokens,
//                 amountsOut,
//                 depositsOut,
//                 toChainId
//             );

//             ///  FUNC ID: 11 (uniswapv3 position collect)
//         } else if (funcId == 0x0b) {
//             (
//                 INonfungiblePositionManager.CollectParams memory params,
//                 bool outputNative,
//                 uint256 toChainId
//             ) = abi.decode(
//                     RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                     (INonfungiblePositionManager.CollectParams, bool, uint256)
//                 ); // TODO max 16 bytes32 slots

//             (
//                 address[] memory outputTokens,
//                 uint256[] memory amountsOut,
//                 uint256[] memory depositsOut
//             ) = collect(userAccount, params, outputNative, toChainId);

//             _approveMultipleAndCallOut(
//                 IVirtualAccount(userAccount).userAddress(),
//                 outputTokens,
//                 amountsOut,
//                 depositsOut,
//                 toChainId
//             );

//             ///  FUNC ID: 13 (talos position redeeem)
//         } else if (funcId == 0x0d) {
//             (
//                 address talosPositionAddress,
//                 uint256 shares,
//                 bool outputNative,
//                 uint256 toChainId
//             ) = abi.decode(
//                     RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                     (address, uint256, bool, uint256)
//                 ); // TODO max 16 bytes32 slots

//             (
//                 address[] memory outputTokens,
//                 uint256[] memory amountsOut,
//                 uint256[] memory depositsOut
//             ) = redeem(userAccount, talosPositionAddress, shares, outputNative, toChainId);

//             _approveMultipleAndCallOut(
//                 IVirtualAccount(userAccount).userAddress(),
//                 outputTokens,
//                 amountsOut,
//                 depositsOut,
//                 toChainId
//             );
//             ///  FUNC ID: 16 (boost aggregator unstakeAndWithdraw NFT)
//         } else if (funcId == 0x10) {
//             (address userAccount, address boostAggregator, uint256 tokenId) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address, address, uint256)
//             ); // TODO max 16 bytes32 slots

//             unstakeAndWithdraw(userAccount, boostAggregator, tokenId);
//             ///  FUNC ID: 17 (boost aggregator unstakeAndWithdrawAndRemoveLiquidity from NFT)
//         } else if (funcId == 0x11) {
//             (
//                 address boostAggregator,
//                 uint256 tokenId,
//                 INonfungiblePositionManager.DecreaseLiquidityParams memory params,
//                 bool outputNative,
//                 uint256 toChainId
//             ) = abi.decode(
//                     RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                     (
//                         address,
//                         uint256,
//                         INonfungiblePositionManager.DecreaseLiquidityParams,
//                         bool,
//                         uint256
//                     )
//                 ); // TODO max 16 bytes32 slots

//             (
//                 address[] memory outputTokens,
//                 uint256[] memory amountsOut,
//                 uint256[] memory depositsOut
//             ) = unstakeWithdrawAndRemoveLiquidity(
//                     userAccount,
//                     boostAggregator,
//                     tokenId,
//                     params,
//                     outputNative,
//                     toChainId
//                 );

//             _approveMultipleAndCallOut(
//                 IVirtualAccount(userAccount).userAddress(),
//                 outputTokens,
//                 amountsOut,
//                 depositsOut,
//                 toChainId
//             );

//             ///  FUNC ID: 18 (boost aggregator unstakeAndRestakeToNewAggregator)
//         } else if (funcId == 0x12) {
//             (
//                 address originBoostAggregator,
//                 address destinationBoostAggregator,
//                 uint256 tokenId
//             ) = abi.decode(
//                     RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                     (address, address, uint256)
//                 ); // TODO max 16 bytes32 slots

//             unstakeAndRestakeToNewAggregator(
//                 userAccount,
//                 originBoostAggregator,
//                 destinationBoostAggregator,
//                 tokenId
//             );
//         }

//         emit LogCallin(funcId, rlpEncodedData, fromChainId);
//     }

//     /**
//      *     @notice Function responsible of executing a signed crosschain request with single asset deposit.
//      *     @param funcId 1 byte Router function identifier.
//      *     @param rlpEncodedData execution data received from messaging layer.
//      *     @param fromChainId chain where the request originated from.
//      *
//      *    8           | mint
//      *    9           | increaseLiquidity
//      *   12           | deposit
//      *   14           | depositAndStake
//      *   15           | mintDepositAndStake
//      *   17           | unstakeAndWithdrawAndRemoveLiquidity
//      *   18           | unstakeAndRestakeToNewAggregator
//      *
//      */
//     function anyExecute(
//         bytes1 funcId,
//         bytes memory rlpEncodedData,
//         DepositParams memory dParams,
//         address userAccount,
//         uint256 fromChainId
//     ) external payable override requiresAgent returns (bool success, bytes memory result) {
//         ///  FUNC ID: 8 (uniswapv3 position mint)
//         if (funcId == 0x08) {
//             INonfungiblePositionManager.MintParams memory params = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (INonfungiblePositionManager.MintParams)
//             ); // TODO max 16 bytes32 slots
//             mint(userAccount, params);
//             ///  FUNC ID: 9 (uniswapv3 position increaseliquidity)
//         } else if (funcId == 0x09) {
//             INonfungiblePositionManager.IncreaseLiquidityParams memory params = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (INonfungiblePositionManager.IncreaseLiquidityParams)
//             ); // TODO max 16 bytes32 slots

//             increaseLiquidity(
//                 userAccount,
//                 params,
//                 dParams.hToken,
//                 address(0),
//                 dParams.amount,
//                 0,
//                 fromChainId
//             );
//             ///  FUNC ID: 12 (talos position deposit)
//         } else if (funcId == 0x0c) {
//             (address talosPositionAddress, uint256 amount0Desired, uint256 amount1Desired) = abi
//                 .decode(RLPDecoder.decodeCallData(rlpEncodedData, 16), (address, uint256, uint256)); // TODO max 16 bytes32 slots

//             deposit(
//                 userAccount,
//                 talosPositionAddress,
//                 amount0Desired,
//                 amount1Desired,
//                 amount0Desired > 0 ? dParams.hToken : address(0),
//                 amount1Desired > 0 ? dParams.hToken : address(0),
//                 fromChainId
//             );
//             ///  FUNC ID: 14 (boost aggregator NFT position depositAndStake)
//         } else if (funcId == 0x0e) {
//             (address userAccount, address boostAggregator, uint256 tokenId) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address, address, uint256)
//             ); // TODO max 16 bytes32 slots

//             depositAndStake(userAccount, boostAggregator, tokenId);

//             ///  FUNC ID: 15 (boost aggregator NFT position mintDepositAndStake)
//         } else if (funcId == 0x0f) {
//             (INonfungiblePositionManager.MintParams memory params, address boostAggregator) = abi
//                 .decode(
//                     RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                     (INonfungiblePositionManager.MintParams, address)
//                 ); // TODO max 16 bytes32 slots

//             mintDepositAndStake(userAccount, params, boostAggregator);
//         }
//         emit LogCallin(funcId, rlpEncodedData, fromChainId);
//     }

//     /**
//      *     @notice Function responsible of executing a signed crosschain request with multiple asset deposit.
//      *     @param funcId 1 byte Router function identifier.
//      *     @param rlpEncodedData execution data received from messaging layer.
//      *     @param fromChainId chain where the request originated from.
//      *
//      *    8           | mint
//      *    9           | increaseLiquidity
//      *   12           | deposit
//      *   14           | depositAndStake
//      *   15           | mintDepositAndStake
//      *   17           | unstakeAndWithdrawAndRemoveLiquidity
//      *   18           | unstakeAndRestakeToNewAggregator
//      *
//      */
//     function anyExecute(
//         bytes1 funcId,
//         bytes memory rlpEncodedData,
//         DepositMultipleParams memory dParams,
//         address userAccount,
//         uint256 fromChainId
//     ) external payable returns (bool success, bytes memory result) {
//         ///  FUNC ID: 8 (uniswapv3 position mint)
//         if (funcId == 0x08) {
//             INonfungiblePositionManager.MintParams memory params = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (INonfungiblePositionManager.MintParams)
//             ); // TODO max 16 bytes32 slots

//             mint(userAccount, params);

//             ///  FUNC ID: 9 (uniswapv3 position increaseliquidity)
//         } else if (funcId == 0x09) {
//             INonfungiblePositionManager.IncreaseLiquidityParams memory params = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (INonfungiblePositionManager.IncreaseLiquidityParams)
//             ); // TODO max 16 bytes32 slots

//             increaseLiquidity(
//                 userAccount,
//                 params,
//                 dParams.hTokens[0],
//                 dParams.hTokens[1],
//                 dParams.amounts[0],
//                 dParams.amounts[1],
//                 fromChainId
//             );

//             ///  FUNC ID: 12 (talos position deposit)
//         } else if (funcId == 0x0c) {
//             (address talosPositionAddress, uint256 amount0Desired, uint256 amount1Desired) = abi
//                 .decode(RLPDecoder.decodeCallData(rlpEncodedData, 16), (address, uint256, uint256)); // TODO max 16 bytes32 slots

//             deposit(
//                 userAccount,
//                 talosPositionAddress,
//                 amount0Desired,
//                 amount1Desired,
//                 dParams.hTokens[0],
//                 dParams.hTokens[1],
//                 fromChainId
//             );
//             ///  FUNC ID: 14 (boost aggregator NFT position depositAndStake)
//         } else if (funcId == 0x0e) {
//             (address userAccount, address boostAggregator, uint256 tokenId) = abi.decode(
//                 RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                 (address, address, uint256)
//             ); // TODO max 16 bytes32 slots

//             depositAndStake(userAccount, boostAggregator, tokenId);

//             ///  FUNC ID: 15 (boost aggregator NFT position mintDepositAndStake)
//         } else if (funcId == 0x0f) {
//             (INonfungiblePositionManager.MintParams memory params, address boostAggregator) = abi
//                 .decode(
//                     RLPDecoder.decodeCallData(rlpEncodedData, 16),
//                     (INonfungiblePositionManager.MintParams, address)
//                 ); // TODO max 16 bytes32 slots

//             mintDepositAndStake(userAccount, params, boostAggregator);
//         }
//         emit LogCallin(funcId, rlpEncodedData, fromChainId);
//     }

//     function anyFallback(bytes calldata data) external returns (bool success, bytes memory result) {
//         return (true, "");
//     }

//     /*///////////////////////////////////////////////////////////////
//                             MODIFIERS
//     ////////////////////////////////////////////////////////////*/

//     /// @notice Modifier for a simple re-entrancy check.
//     uint256 internal _unlocked = 1;

//     modifier lock() {
//         require(_unlocked == 1);
//         _unlocked = 2;
//         _;
//         _unlocked = 1;
//     }

//     /// @notice require msg sender == active branch interface
//     modifier requiresAgent() {
//         _requiresAgent();
//         _;
//     }

//     /// @notice reuse to reduce contract bytesize
//     function _requiresAgent() internal view {
//         require(msg.sender == bridgeAgentAddress, "Unauthorized Caller");
//     }
// }
