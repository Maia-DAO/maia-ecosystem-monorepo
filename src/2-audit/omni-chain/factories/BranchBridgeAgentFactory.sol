// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IBranchBridgeAgentFactory.sol";

/**
@title BridgeAgentFactory.
@author MaiaDAO.
@notice This contract is used to deploy new Bridge Agents which are in charge of managing the deposit and withdrawal of assets between the branch chains and the omnichain environment.
*/
contract BranchBridgeAgentFactory is Ownable, IBranchBridgeAgentFactory {
    /// @notice Local Chain Id
    uint256 public immutable localChainId;

    /// @notice Root Chain Id
    uint256 public immutable rootChainId;

    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Root Port Address
    address public immutable localPortAddress;

    /// @notice Local Anycall Address
    address public immutable localAnyCallAddress;

    /// @notice Local Anyexec Address
    address public immutable localAnyCallExecutorAddress;

    /**
        @notice Constructor for Bridge Agent.
        @param _localChainId Local Chain Id.
        @param _wrappedNativeToken Local Wrapped Native Token.
        @param _localAnyCallAddress Local Anycall Address.
        @param _localPortAddress Local Port Address.
        @param _owner Owner of the contract.
     */
    constructor(
        uint256 _localChainId,
        uint256 _rootChainId,
        WETH9 _wrappedNativeToken,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localPortAddress,
        address _owner
    ) {
        localChainId = _localChainId;
        rootChainId = _rootChainId;
        wrappedNativeToken = _wrappedNativeToken;
        localAnyCallAddress = _localAnyCallAddress;
        localAnyCallExecutorAddress = IAnycallProxy(localAnyCallAddress).executor();
        localPortAddress = _localPortAddress;
        _initializeOwner(_owner);
    }

    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createBridgeAgent(address _newBranchRouterAddress, address _rootBridgeAgentAddress)
        external
        onlyOwner
        returns (address newBridgeAgent)
    {
        newBridgeAgent = address(
            new BranchBridgeAgent(
                wrappedNativeToken,
                rootChainId,
                localChainId,
                _rootBridgeAgentAddress,
                localAnyCallAddress,
                localAnyCallExecutorAddress,
                _newBranchRouterAddress,
                localPortAddress
            )
        );

        IRootPort(localPortAddress).addBridgeAgent(newBridgeAgent);
        // IRootPort(localPortAddress).toggleBridgeAgent(newBridgeAgent);
    }

    function toggleBridgeAgent(address _bridgeAgentAddress) external onlyOwner {
        IRootPort(localPortAddress).toggleBridgeAgent(_bridgeAgentAddress);
    }
}
