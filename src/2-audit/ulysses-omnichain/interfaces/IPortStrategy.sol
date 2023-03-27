// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

interface IPortStrategy {
    /*///////////////////////////////////////////////////////////////
                          TOKEN MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
      @notice Function to withdraw underlying / native token amount into Port in exchange for Local hToken.
      @param _recipient hToken receiver.
      @param _token native token address.
      @param _amount amount of tokens.
    **/
    function withdraw(address _recipient, address _token, uint256 _amount) external;

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedPort();
}
