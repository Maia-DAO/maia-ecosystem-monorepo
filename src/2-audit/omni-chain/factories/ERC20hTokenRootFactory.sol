// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20hTokenRootFactory.sol";

/**
@title ERC20 hToken Contract for deployment in Root Chain of Hermes Omnichain Incentives System
@author MaiaDAO
@dev
*/
contract ERC20hTokenRootFactory is Ownable, IERC20hTokenRootFactory {
    using SafeTransferLib for address;

    /// @notice Local Network Identifier.
    uint256 public localChainId;

    /// @notice Root Port Address.
    address public rootPortAddress;

    /// @notice Root Port Address.
    address public localBranchPortAddress;

    /// @notice Root Core Router Address, in charge of the addition of new tokens to the system.
    address public rootCoreRouterAddress;

    ERC20hTokenRoot[] public hTokens;

    uint256 public hTokensLenght;

    /**
        @notice Constructor for ERC20 hToken Contract
        @param _localChainId Local Network Identifier.
        @param _rootCoreRouterAddress Address of the Root Core Router Contract.   
        @param _rootPortAddress Root Port Address
        @param _localBranchPortAddress Local Branch Port Address
        @param _owner Owner of the Contract
     */
    constructor(
        uint256 _localChainId,
        address _rootCoreRouterAddress,
        address _rootPortAddress,
        address _localBranchPortAddress,
        address _owner
    ) {
        localChainId = _localChainId;
        rootCoreRouterAddress = _rootCoreRouterAddress;
        rootPortAddress = _rootPortAddress;
        localBranchPortAddress = _localBranchPortAddress;
        hTokensLenght = 0;
        _initializeOwner(_owner);
    }

    /*///////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    function isPort(address _port) external view returns (bool) {
        return (_port == rootPortAddress || _port == localBranchPortAddress);
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
        returns (ERC20hTokenRoot newToken)
    {
        newToken = new ERC20hTokenRoot(
            localChainId,
            address(this),
            rootPortAddress,
            localBranchPortAddress,
            _name,
            _symbol
        );
        hTokens.push(newToken);
        hTokensLenght++;
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresCoreRouter() {
        if (msg.sender != rootCoreRouterAddress && msg.sender != rootPortAddress)
            revert UnrecognizedCoreRouter();
        _;
    }
}
