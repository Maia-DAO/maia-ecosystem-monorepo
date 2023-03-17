// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";

import "./BaseBranchRouter.sol";
import { ISwapRouter } from "./interfaces/ISwapRouter.sol";
import { IERC20hTokenBranchFactory as IFactory } from "./interfaces/IERC20hTokenBranchFactory.sol";
import { ERC20hTokenBranch as ERC20hToken } from "./token/ERC20hTokenBranch.sol";

/**
@title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
@author MaiaDAO
@dev
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
    /// @notice hToken Factory Address. TODO maybe add setter
    address public hTokenFactoryAddress;

    constructor(address _hTokenFactoryAddress) BaseBranchRouter() {
        hTokenFactoryAddress = _hTokenFactoryAddress;
    }

    /*///////////////////////////////////////////////////////////////
                 TOKEN MANAGEMENT EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addGlobalToken(
        address _globalAddress,
        uint256 _toChain,
        uint128 rootExecutionGas
    ) external payable {
        //Check Gas + Fees
        bytes memory data = abi.encode(0x01, _globalAddress, _toChain);

        //Send Cross-Chain request (System Response/Request)
        IBridgeAgent(localBridgeAgentAddress).performCall{ value: msg.value }(
            data,
            address(this),
            rootExecutionGas
        );
    }

    function addLocalToken(address _underlyingAddress, uint128 rootExecutionGas) external payable {
        //Create Token
        ERC20hToken newToken = IFactory(hTokenFactoryAddress).createToken(
            ERC20(_underlyingAddress).name(),
            ERC20(_underlyingAddress).symbol()
        );

        //Encode Data
        bytes memory data = abi.encode(0x02, _underlyingAddress, newToken);

        //Send Cross-Chain request (System Response/Request)
        IBridgeAgent(localBridgeAgentAddress).performCall{ value: msg.value }(
            data,
            address(this),
            rootExecutionGas
        );
    }

    /*///////////////////////////////////////////////////////////////
                 TOKEN MANAGEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     @notice Function to deploy/add a token already active in the global enviornment in the Root Chain. Must be called from another chain. 
     @param _globalAddress the address of the global virtualized token.
     @param _name token name.
     @param _symbol token symbol.
     @dev FUNC ID: 9
     @dev all hTokens have 18 decimals.
   **/
    function _receiveAddGlobalToken(
        address _globalAddress,
        string memory _name,
        string memory _symbol
    ) internal {
        //Create Token
        ERC20hToken newToken = IFactory(hTokenFactoryAddress).createToken(_name, _symbol);

        //Encode Data
        bytes memory data = abi.encode(0x01, _globalAddress, newToken);

        //Send Cross-Chain request   TODO add remianing gas
        IBridgeAgent(localBridgeAgentAddress).performCall{ value: msg.value }(
            data,
            address(this),
            0
        );
    }

    /*///////////////////////////////////////////////////////////////
                    ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function anyExecuteNoSettlement(bytes memory _data)
        external
        virtual
        override
        returns (bool success, bytes memory result)
    {
        if (_data[0] == 0x01) {
            (, address globalAddress, string memory name, string memory symbol) = abi.decode(
                _data,
                (bytes1, address, string, string)
            );

            _receiveAddGlobalToken(globalAddress, name, symbol);

            /// Unrecognized Function Selector
        } else {
            return (false, "unknown selector");
        }
        return (true, "");
    }
}
