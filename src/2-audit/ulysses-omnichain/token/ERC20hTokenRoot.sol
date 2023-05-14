// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20hTokenRoot.sol";

/**
 * @title ERC20 hToken Contract for deployment in Root Chain of Hermes Omnichain Incentives System
 * @author MaiaDAO
 * @dev
 */
contract ERC20hTokenRoot is ERC20, IERC20hTokenRoot {
    using SafeTransferLib for address;

    /// @notice Local Network Identifier.
    uint256 public localChainId;

    /// @notice Root Port Address.
    address public rootPortAddress;

    /// @notice Root Port Address.
    address public localBranchPortAddress;

    /// @notice Factory Address.
    address public factoryAddress;

    /// @notice a mapping from a chain's id and the number of tokens.
    mapping(uint256 => uint256) public underlyingPerChain;

    /**
     * @notice Constructor for the ERC20hTokenRoot Contract.
     *     @param _localChainId Local Network Identifier.
     *     @param _factoryAddress Address of the Factory Contract.
     *     @param _rootPortAddress Address of the Root Port Contract.
     *     @param _name Name of the Token.
     *     @param _symbol Symbol of the Token.
     */
    constructor(
        uint256 _localChainId,
        address _factoryAddress,
        address _rootPortAddress,
        string memory _name,
        string memory _symbol
    ) ERC20(string(string.concat("Hermes ", _name)), string(string.concat("h-", _symbol)), 18) {
        require(_rootPortAddress != address(0), "Root Port Address cannot be 0");
        require(_factoryAddress != address(0), "Factory Address cannot be 0");
        localChainId = _localChainId;
        factoryAddress = _factoryAddress;
        rootPortAddress = _rootPortAddress;
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresPort() {
        if (msg.sender != rootPortAddress) revert UnrecognizedPort();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev View Function returns Token's Local Address.
    function getTokenBalance(uint256 chainId) public view returns (uint256) {
        return underlyingPerChain[chainId];
    }

    /*///////////////////////////////////////////////////////////////
                        ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints new tokens and updates the total supply for the given chain.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     * @param chainId Chain Id of the chain to mint tokens to.
     */
    function mint(address to, uint256 amount, uint256 chainId) external requiresPort returns (bool) {
        underlyingPerChain[chainId] += amount;
        _mint(to, amount);
        return true;
    }

    /**
     * @notice Burns new tokens and updates the total supply for the given chain.
     * @param from Address to burn tokens from.
     * @param value Amount of tokens to burn.
     * @param chainId Chain Id of the chain to burn tokens to.
     */
    function burn(address from, uint256 value, uint256 chainId) external requiresPort {
        underlyingPerChain[chainId] -= value;
        _burn(from, value);
    }
}
