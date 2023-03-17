// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ERC20hTokenBranch } from "../token/ERC20hTokenBranch.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IPortStrategy } from "./IPortStrategy.sol";

interface IBranchPort {
    /*///////////////////////////////////////////////////////////////
                          hTOKEN MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
      @notice Function to withdraw underlying / native token amount into Port in exchange for Local hToken.
      @param _recipient hToken receiver.
      @param _underlyingAddress underlying / native token address.
      @param _amount amount of tokens.
    **/
    function withdraw(address _recipient, address _underlyingAddress, uint256 _amount) external;

    /**
      @notice Setter function to increase local hToken supply.
      @param _recipient hToken receiver.
      @param _localAddress token address.
      @param _amount amount of tokens.
    **/
    function bridgeIn(address _recipient, address _localAddress, uint256 _amount) external;

    /**
      @notice Setter function to increase local hToken supply.
      @param _recipient hToken receiver.
      @param _localAddresses token addresses.
      @param _amounts amount of tokens.
    **/
    function bridgeInMultiple(
        address _recipient,
        address[] memory _localAddresses,
        uint256[] memory _amounts
    ) external;

    /**
      @notice Setter function to decrease local hToken supply.
      @param _localAddress token address.
      @param _amount amount of tokens.
    **/
    function bridgeOut(
        address _depositor,
        address _localAddress,
        address _underlyingAddress,
        uint256 _amount,
        uint256 _deposit
    ) external;

    /**
      @notice Setter function to decrease local hToken supply.
      @param _depositor user to deduct balance from.
      @param _localAddresses local token addresses.
      @param _underlyingAddresses local token address.
      @param _amounts amount of local tokens.
      @param _deposits amount of underlying tokens.
    **/
    function bridgeOutMultiple(
        address _depositor,
        address[] memory _localAddresses,
        address[] memory _underlyingAddresses,
        uint256[] memory _amounts,
        uint256[] memory _deposits
    ) external;

    /*///////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addBridgeAgent(address _bridgeAgent) external;

    function toggleBridgeAgent(address _bridgeAgent) external;

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event DebtCreated(address indexed _strategy, address indexed _token, uint256 _amount);
    event DebtRepaid(address indexed _strategy, address indexed _token, uint256 _amount);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    
    error InsufficientReserves();
    error UnrecognizedBridgeAgent();
    error UnrecognizedPortStrategy();
    error UnrecognizedStrategyToken();
}
