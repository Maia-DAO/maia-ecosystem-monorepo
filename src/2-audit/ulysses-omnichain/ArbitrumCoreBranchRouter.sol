// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import "./CoreBranchRouter.sol";

import {ERC20hTokenBranch as ERC20hToken} from "./token/ERC20hTokenBranch.sol";

import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {IERC20hTokenBranchFactory as IFactory} from "./interfaces/IERC20hTokenBranchFactory.sol";

/**
 * @title Core Branch Router implementation for Arbitrum deployment.
 * @notice This contract is responsible for routing cross-chain messages to the Arbitrum Core Branch Router.
 * @author MaiaDAO
 * @dev
 *
 *   CROSS-CHAIN MESSAGING FUNCIDs
 *   -----------------------------
 *   FUNC ID      | FUNC NAME
 *   -------------+---------------
 *   1            | clearDeposit
 *   2            | finalizeDeposit
 *   3            | finalizeWithdraw
 *   4            | clearToken
 *   5            | clearTokens
 *   6            | addGlobalToken
 *
 */
contract ArbitrumCoreBranchRouter is CoreBranchRouter {
    constructor(address _hTokenFactoryAddress, address _localPortAddress)
        CoreBranchRouter(_hTokenFactoryAddress, _localPortAddress)
    {}

    /*///////////////////////////////////////////////////////////////
                    TOKEN MANAGEMENT EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addLocalToken(address _underlyingAddress) external payable override {
        //Get Token Info
        string memory name = ERC20(_underlyingAddress).name();
        string memory symbol = ERC20(_underlyingAddress).symbol();

        //Encode Data
        bytes memory data = abi.encode(_underlyingAddress, address(0), name, symbol);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        //Send Cross-Chain request (System Response/Request)
        IBridgeAgent(localBridgeAgentAddress).performSystemCallOut{value: msg.value}(msg.sender, packedData, 0);
    }

    /*///////////////////////////////////////////////////////////////
                    ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function anyExecuteNoSettlement(bytes memory) external pure override returns (bool, bytes memory) {
        /// Unrecognized Function Selector
        revert();
    }
}
