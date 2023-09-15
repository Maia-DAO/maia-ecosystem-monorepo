// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20hTokenBranch} from "../token/ERC20hTokenBranch.sol";

/**
 * @title  ERC20hTokenBranchFactory Interface
 * @author MaiaDAO
 * @notice Factory contract allowing for permissionless deployment of new Branch hTokens in Branch
 *  	   Chains of Ulysses Omnichain Liquidity Protocol.
 * @dev    This contract is called by the chain's Core Branch Router.
 */
interface IERC20hTokenBranchFactory {
    /*///////////////////////////////////////////////////////////////
                            hTOKEN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Function to create a new Branch hToken.
     * @param _name Name of the Token.
     * @param _symbol Symbol of the Token.
     * @param _decimals Decimals of the Token.
     * @param _addPrefix Boolean to add or not the chain prefix to the token name and symbol.
     */
    function createToken(string memory _name, string memory _symbol, uint8 _decimals, bool _addPrefix)
        external
        returns (ERC20hTokenBranch newToken);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedCoreRouter();

    error UnrecognizedPort();
}
