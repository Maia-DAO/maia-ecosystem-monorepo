// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "solady/auth/Ownable.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { WETH9 } from "../interfaces/IWETH9.sol";

import { IAnycallProxy } from "./IAnycallProxy.sol";

import { IBranchPort as IPort } from "../interfaces/IBranchPort.sol";

import { CoreBranchRouter } from "../CoreBranchRouter.sol";

import { BranchBridgeAgent } from "../BranchBridgeAgent.sol";

/**
@title IBridgeAgentFactory.
@author MaiaDAO.
@notice This contract is used to interact with the Bridge Agent Factory which is in charge of deploying new Bridge Agents which are in charge of managing the deposit and withdrawal of assets between the branch chains and the omnichain environment.
*/
interface IBranchBridgeAgentFactory {
    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createBridgeAgent(address newRootRouterAddress, address rootBridgeAgentAddress)
        external
        returns (address newBridgeAgent);
}
