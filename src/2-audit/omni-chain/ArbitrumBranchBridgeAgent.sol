// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import { IBranchRouter, SafeTransferLib, Ownable, ERC20, WETH9, Deposit, DepositStatus, DepositInput, DepositParams, DepositMultipleInput, DepositMultipleParams } from "./interfaces/IBranchRouter.sol";
import "./BranchBridgeAgent.sol";
import { IArbBranchPort as IArbPort } from "./interfaces/IArbBranchPort.sol";
import { IRootBridgeAgent } from "./interfaces/IRootBridgeAgent.sol";

import { console2 } from "forge-std/console2.sol";

/**
@title BaseBranchRouter contract for deployment in Branch Chains of Omnichain System.
@author MaiaDAO
@dev Base Branch Interface for Anycall cross-chain messaging.
*/
contract ArbitrumBranchBridgeAgent is BranchBridgeAgent {
    using SafeTransferLib for ERC20;

    constructor(
        WETH9 _wrappedNativeToken,
        uint256 _localChainId,
        address _rootBridgeAgentAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localRouterAddress,
        address _localPortAddress
    )
        BranchBridgeAgent(
            _wrappedNativeToken,
            _localChainId,
            _localChainId,
            _rootBridgeAgentAddress,
            _localAnyCallAddress,
            _localAnyCallExecutorAddress,
            _localRouterAddress,
            _localPortAddress
        )
    {}

    /*///////////////////////////////////////////////////////////////
                    LOCAL USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
      @notice Function to deposit a single asset to the local Port.
      @param underlyingAddress underlying asset to be deposited.
      @param amount amount to be deposited.
    **/
    function depositToPort(address underlyingAddress, uint256 amount) external payable lock {
        IArbPort(localPortAddress).depositToPort(msg.sender, msg.sender, underlyingAddress, amount);
    }

    /**
      @notice Function to deposit a single asset to the local Port.
      @param localAddress local hToken to be withdrawn.
      @param amount amount to be withdrawn.
    **/
    function withdrawFromPort(address localAddress, uint256 amount) external payable lock {
        IArbPort(localPortAddress).withdrawFromPort(msg.sender, msg.sender, localAddress, amount);
    }

    /*///////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
    function _performCall(bytes memory _callData) internal override {
        IRootBridgeAgent(rootBridgeAgentAddress).anyExecute(_callData);
    }

    function _payExecutionGas(
        address _recipient,
        uint256 _initialGas,
        uint256 _depositedGasTokens,
        uint256 _feesOwed
    ) internal override returns (uint256) {
        //Get initial gas
        uint256 initialGas = IRootBridgeAgent(rootBridgeAgentAddress).initialGas();

        //Check if remote initiated call
        if (initialGas == 0) return 0;

        //Get Branch Environment Execution Cost
        uint256 minExecCost = tx.gasprice *
            (MIN_EXECUTION_OVERHEAD + initialGas - _feesOwed - gasleft());

        //Unwrap Gas
        wrappedNativeToken.withdraw(_depositedGasTokens);

        //Replenish Gas
        _replenishGas(minExecCost);

        //Transfer gas remaining to recipient
        if (minExecCost < _depositedGasTokens)
            SafeTransferLib.safeTransferETH(_recipient, _depositedGasTokens - minExecCost);
    }

    function _replenishGas(uint256 _executionGasSpent) internal override {
        //Deposit Gas
        IAnycallConfig(IAnycallProxy(localAnyCallAddress).config()).deposit{
            value: _executionGasSpent
        }(address(this));
    }

    /**
      @notice Internal function to calculate cost for cross-chain message.
    **/
    function _computeAnyCallFees(uint256) internal override returns (uint256 fees) {
        fees = 0;
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresExecutor() internal view override {
        if (msg.sender != rootBridgeAgentAddress) revert AnycallUnauthorizedCaller();
    }
}
