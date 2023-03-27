// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20hTokenBranch.sol";

/**
@title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
@author MaiaDAO
@dev
*/
contract ERC20hTokenBranch is ERC20, Ownable, IERC20hTokenBranch {
    constructor(
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC20(string(string.concat("Hermes - ", _name)), string(string.concat("h-", _symbol)), 18) {
        _initializeOwner(_owner);
    }

    /*///////////////////////////////////////////////////////////////
                        ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function mint(address account, uint256 amount) external override onlyOwner returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(uint256 value) public override onlyOwner {
        _burn(msg.sender, value);
    }
}
