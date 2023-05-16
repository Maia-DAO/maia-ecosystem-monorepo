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
        IBridgeAgent(localBridgeAgentAddress).performCallOut(msg.sender, packedData, 0, 0);
    }

    /*///////////////////////////////////////////////////////////////
                BRIDGE AGENT MANAGEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to deploy/add a token already active in the global environment in the Root Chain. Must be called from another chain.
     *  @param _newBranchRouter the address of the new branch router.
     *  @param _branchBridgeAgentFactory the address of the branch bridge agent factory.
     *  @param _rootBridgeAgent the address of the root bridge agent.
     *  @param _rootBridgeAgentFactory the address of the root bridge agent factory.
     *  @dev FUNC ID: 9
     *  @dev all hTokens have 18 decimals.
     *
     */
    function _receiveAddBridgeAgent(
        address _newBranchRouter,
        address _branchBridgeAgentFactory,
        address _rootBridgeAgent,
        address _rootBridgeAgentFactory,
        uint128
    ) internal override {
        //Check if msg.sender is a valid BridgeAgentFactory
        if (!IPort(localPortAddress).isBridgeAgentFactory(_branchBridgeAgentFactory)) {
            revert UnrecognizedBridgeAgentFactory();
        }

        //Create Token
        address newBridgeAgent = IBridgeAgentFactory(_branchBridgeAgentFactory).createBridgeAgent(
            _newBranchRouter, _rootBridgeAgent, _rootBridgeAgentFactory
        );

        //Check BridgeAgent Address
        if (!IPort(localPortAddress).isBridgeAgent(newBridgeAgent)) {
            revert UnrecognizedBridgeAgent();
        }

        //Encode Data
        bytes memory data = abi.encode(newBridgeAgent, _rootBridgeAgent);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x04), data);

        //Send Cross-Chain request
        IBridgeAgent(localBridgeAgentAddress).performSystemCallOut(address(this), packedData, 0, 0);
    }

    /*///////////////////////////////////////////////////////////////
                    ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Performs a cross-chain call to the root chain.
     * @param _data the data to be sent to the root chain.
     */
    function anyExecuteNoSettlement(bytes calldata _data)
        external
        override
        requiresBridgeAgent
        returns (bool success, bytes memory result)
    {
        if (_data[0] == 0x02) {
            (
                address newBranchRouter,
                address branchBridgeAgentFactory,
                address rootBridgeAgent,
                address rootBridgeAgentFactory,
            ) = abi.decode(_data[1:], (address, address, address, address, uint128));

            _receiveAddBridgeAgent(
                newBranchRouter, branchBridgeAgentFactory, rootBridgeAgent, rootBridgeAgentFactory, 0
            );

            /// _receiveAddBridgeAgentFactory
        } else if (_data[0] == 0x03) {
            (address newBridgeAgentFactoryAddress) = abi.decode(_data[1:], (address));

            _receiveAddBridgeAgentFactory(newBridgeAgentFactoryAddress);

            /// Unrecognized Function Selector
        } else {
            return (false, "unknown selector");
        }
        return (true, "");
    }
}
