// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import { IBranchRouter, SafeTransferLib, Ownable, ERC20, WETH9, Deposit, DepositStatus, DepositInput, DepositParams, DepositMultipleInput, DepositMultipleParams } from "./interfaces/IBranchRouter.sol";
import "./BranchBridgeAgent.sol";
import {IArbBranchPort as IArbPort} from "./interfaces/IArbBranchPort.sol";
import {IRootBridgeAgent} from "./interfaces/IRootBridgeAgent.sol";

/**
 * @title Base Bridge Agent implementation for the Arbitrum deployment.
 * @author MaiaDAO
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
     * @notice Function to deposit a single asset to the local Port.
     *   @param underlyingAddress address of the underlying asset to be deposited.
     *   @param amount amount to be deposited.
     *
     */
    function depositToPort(address underlyingAddress, uint256 amount) external payable lock {
        IArbPort(localPortAddress).depositToPort(msg.sender, msg.sender, underlyingAddress, amount);
    }

    /**
     * @notice Function to withdraw a single asset to the local Port.
     *   @param localAddress local hToken to be withdrawn.
     *   @param amount amount to be withdrawn.
     *
     */
    function withdrawFromPort(address localAddress, uint256 amount) external payable lock {
        IArbPort(localPortAddress).withdrawFromPort(msg.sender, msg.sender, localAddress, amount);
    }

    /*///////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
    /// @param _callData bytes of the call to be sent to the AnycallProxy.
    function _performCall(bytes memory _callData) internal override {
        IRootBridgeAgent(rootBridgeAgentAddress).anyExecute(_callData);
    }

    /// @notice Internal function to pay for execution gas.
    /// @param _recipient address to take gas from.
    /// @param _feesOwed amount of fees owed.
    function _payExecutionGas(address _recipient, uint256, uint256 _feesOwed) internal override {}

    /// @notice Internal function to deposit gas to the AnycallProxy.
    /// @notice Runs after every remote initiated call.
    /// @param _executionGasSpent amount of gas spent on execution.
    function _replenishGas(uint256 _executionGasSpent) internal override {
        //Deposit Gas
        IAnycallConfig(IAnycallProxy(localAnyCallAddress).config()).deposit{value: _executionGasSpent}(
            rootBridgeAgentAddress
        );
    }

    /**
     * @notice Internal function to calculate cost for cross-chain message.
     *
     */
    function _computeAnyCallFees(uint256) internal view override returns (uint256 fees) {
        //Get initial gas
        uint256 initialGas = IRootBridgeAgent(rootBridgeAgentAddress).initialGas();
        if (initialGas == 0) return 0;
        (,, fees) = IRootBridgeAgent(rootBridgeAgentAddress).userFeeInfo();
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresExecutor() internal view override {
        if (msg.sender != rootBridgeAgentAddress) revert AnycallUnauthorizedCaller();
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresFallbackGas() internal view override {
        if (IRootBridgeAgent(rootBridgeAgentAddress).initialGas() == 0) return;
        if (msg.value <= MIN_FALLBACK_OVERHEAD) revert InsufficientGas();
    }

    /// @notice reuse to reduce contract bytesize
    function _requiresFallbackGas(uint256 _depositedGas) internal view override {
        if (IRootBridgeAgent(rootBridgeAgentAddress).initialGas() == 0) return;
        if (_depositedGas <= MIN_FALLBACK_OVERHEAD) revert InsufficientGas();
    }
}
