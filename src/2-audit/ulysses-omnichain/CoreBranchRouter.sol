// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import "./BaseBranchRouter.sol";
import {IBranchPort as IPort} from "./interfaces/IBranchPort.sol";
import {IERC20hTokenBranchFactory as IFactory} from "./interfaces/IERC20hTokenBranchFactory.sol";
import {ERC20hTokenBranch as ERC20hToken} from "./token/ERC20hTokenBranch.sol";
import {ICoreBranchRouter} from "./interfaces/ICoreBranchRouter.sol";

/**
 * @title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
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

contract CoreBranchRouter is BaseBranchRouter {
    /// @notice hToken Factory Address.
    address public hTokenFactoryAddress;

    /// @notice Local Port Address.
    address public localPortAddress;

    constructor(address _hTokenFactoryAddress, address _localPortAddress) BaseBranchRouter() {
        localPortAddress = _localPortAddress;
        hTokenFactoryAddress = _hTokenFactoryAddress;
    }

    /*///////////////////////////////////////////////////////////////
                 TOKEN MANAGEMENT EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addGlobalToken(
        address _globalAddress,
        uint24 _toChain,
        uint128 _remoteExecutionGas,
        uint128 _rootExecutionGas
    ) external payable {
        //Encode Call Data
        bytes memory data = abi.encode(address(this), _globalAddress, _toChain, _rootExecutionGas);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        //Send Cross-Chain request (System Response/Request)
        IBridgeAgent(localBridgeAgentAddress).performSystemCallOut{value: msg.value}(
            msg.sender, packedData, _remoteExecutionGas
        );
    }

    function addLocalToken(address _underlyingAddress) external payable virtual {
        //Get Token Info
        string memory name = ERC20(_underlyingAddress).name();
        string memory symbol = ERC20(_underlyingAddress).symbol();

        //Create Token
        ERC20hToken newToken = IFactory(hTokenFactoryAddress).createToken(name, symbol);

        //Encode Data
        bytes memory data = abi.encode(_underlyingAddress, newToken, name, symbol);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        //Send Cross-Chain request (System Response/Request)
        IBridgeAgent(localBridgeAgentAddress).performSystemCallOut{value: msg.value}(msg.sender, packedData, 0);
    }

    function syncBridgeAgent(address _newBridgeAgentAddress, address _rootBridgeAgentAddress) external payable {
        //Check BridgeAgent Address
        if (!IPort(localPortAddress).isBridgeAgent(_newBridgeAgentAddress)) {
            revert UnrecognizedBridgeAgent();
        }

        //Encode Data
        bytes memory data = abi.encode(_newBridgeAgentAddress, _rootBridgeAgentAddress);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x04), data);

        //Send Cross-Chain request (System Response/Request)
        IBridgeAgent(localBridgeAgentAddress).performSystemCallOut{value: msg.value}(msg.sender, packedData, 0);
    }

    /*///////////////////////////////////////////////////////////////
                 TOKEN MANAGEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to deploy/add a token already active in the global environment in the Root Chain. Must be called from another chain.
     *  @param _globalAddress the address of the global virtualized token.
     *  @param _name token name.
     *  @param _symbol token symbol.
     *  @dev FUNC ID: 9
     *  @dev all hTokens have 18 decimals.
     *
     */
    function _receiveAddGlobalToken(
        address _globalAddress,
        string memory _name,
        string memory _symbol,
        uint128 _rootExecutionGas
    ) internal {
        //Create Token
        ERC20hToken newToken = IFactory(hTokenFactoryAddress).createToken(_name, _symbol);

        //Encode Data
        bytes memory data = abi.encode(_globalAddress, newToken);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x03), data);

        //Send Cross-Chain request
        IBridgeAgent(localBridgeAgentAddress).performSystemCallOut{value: _rootExecutionGas}(
            address(this), packedData, 0
        );
    }

    /**
     * @notice Function to deploy/add a token already active in the global enviornment in the Root Chain. Must be called from another chain.
     *  @param _newBridgeAgentFactoryAddress the address of the new local bridge agent factory.
     *
     */
    function _receiveAddBridgeAgentFactory(address _newBridgeAgentFactoryAddress) internal {
        IPort(localPortAddress).addBridgeAgentFactory(_newBridgeAgentFactoryAddress);
    }

    /*///////////////////////////////////////////////////////////////
                    ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Performs a cross-chain call to the root chain.
     * @param _data the data to be sent to the root chain.
     */
    function anyExecuteNoSettlement(bytes memory _data)
        external
        virtual
        override
        returns (bool success, bytes memory result)
    {
        if (_data[0] == 0x01) {
            (, address globalAddress, string memory name, string memory symbol, uint128 gasToBridgeOut) =
                abi.decode(_data, (bytes1, address, string, string, uint128));

            _receiveAddGlobalToken(globalAddress, name, symbol, gasToBridgeOut);

            /// Unrecognized Function Selector
        } else if (_data[0] == 0x01) {
            (, address newBridgeAgentFactoryAddress) = abi.decode(_data, (bytes1, address));

            _receiveAddBridgeAgentFactory(newBridgeAgentFactoryAddress);

            /// Unrecognized Function Selector
        } else {
            return (false, "unknown selector");
        }
        return (true, "");
    }

    error UnrecognizedBridgeAgent();
}
