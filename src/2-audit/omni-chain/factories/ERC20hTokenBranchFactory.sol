// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20hTokenBranchFactory.sol";

/**
@title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
@author MaiaDAO
@dev
*/
contract ERC20hTokenBranchFactory is IERC20hTokenBranchFactory {
    /// @notice Local Network Identifier.
    uint256 public localChainId;

    /// @notice Local Port Address
    address localPortAddress;

    /// @notice Local Branch Core Router Address responsible for the addition of new tokens to the system.
    address localCoreRouterAddress;

    /// @notice Local hTokens deployed in current chain.
    ERC20hTokenBranch[] public hTokens;

    /// @notice Number of hTokens deployed in current chain.
    uint256 public hTokensLenght;

    constructor(address _localPortAddress) {
        localPortAddress = _localPortAddress;
    }

    /*///////////////////////////////////////////////////////////////
                            hTOKEN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Function to create a new hToken.
    /// @param _name Name of the Token.
    /// @param _symbol Symbol of the Token.
    function createToken(string memory _name, string memory _symbol)
        external
        requiresCoreRouter
        returns (ERC20hTokenBranch newToken)
    {
        newToken = new ERC20hTokenBranch(_name, _symbol, localPortAddress);
        hTokens.push(newToken);
        hTokensLenght++;
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresCoreRouter() {
        if (msg.sender != localCoreRouterAddress) revert UnrecognizedCoreRouter();
        _;
    }

    /// @notice Modifier that verifies msg sender is the Branch Port Contract from Local Chain.
    modifier requiresPort() {
        if (msg.sender != localPortAddress) revert UnrecognizedPort();
        _;
    }
}
