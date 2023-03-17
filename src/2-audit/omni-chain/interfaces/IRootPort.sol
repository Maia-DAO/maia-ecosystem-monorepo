// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Ownable } from "solady/auth/Ownable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { ERC20hTokenRoot } from "../token/ERC20hTokenRoot.sol";

import { VirtualAccount } from "../VirtualAccount.sol";

import { IRootBridgeAgentFactory } from "./IRootBridgeAgentFactory.sol";

import { ISwapRouter } from "../interfaces/ISwapRouter.sol";

import { IERC20hTokenRootFactory } from "../interfaces/IERC20hTokenRootFactory.sol";

import { INonfungiblePositionManager } from "../interfaces/INonfungiblePositionManager.sol";

struct GasPoolInfo {
    //zeroForOne when swapping gas from branch chain into root chain gas
    bool zeroForOneOnInflow;
    uint24 priceImpactPercentage;
    address gasTokenGlobalAddress;
    address poolAddress;
}

interface IRootPort {
    /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from Underlying Address to isUnderlying (bool).
    function isRouterApproved(VirtualAccount _userAccount, address _router) external returns (bool);

    /// @notice View Function returns Token's Local Address.
    function getGlobalTokenFromLocal(address _localAddress, uint256 _fromChain)
        external
        view
        returns (address);

    /// @notice View Function returns Token's Local Address.
    function getLocalTokenFromGlobal(address _globalAddress, uint256 _fromChain)
        external
        view
        returns (address);

    /// @notice View Function returns Token's Local Address.
    function getLocalTokenFromUnder(address _underlyingAddress, uint256 _fromChain)
        external
        view
        returns (address);

    /// @notice View Function returns Local Token's Local Address on another chain.
    function getLocalToken(
        address _localAddress,
        uint256 _fromChain,
        uint256 _toChain
    ) external view returns (address);

    /// @notice View Function returns a Local Token's Native Underlying Token Address.
    function getUnderlyingTokenFromLocal(address _localAddress, uint256 _fromChain)
        external
        view
        returns (address);

    /// @notice View Function returns a Global Token's Native Underlying Token Address.
    function getUnderlyingTokenFromGlobal(address _globalAddress, uint256 _fromChain)
        external
        view
        returns (address);

    /// @notice View Function returns True if Global Token is already added in current chain, false otherwise.
    function isGlobalToken(address _globalAddress, uint256 _fromChain) external view returns (bool);

    /// @notice View Function returns True if Global Token is already added in current chain, false otherwise.
    function isLocalToken(address _localAddress, uint256 _fromChain) external view returns (bool);

    /// @notice View Function returns True if Local Token and is also already added in another branch chain, false otherwise.
    function isLocalToken(
        address _localAddress,
        uint256 _fromChain,
        uint256 _toChain
    ) external view returns (bool);

    /// @notice View Function returns True if Local Token is already added in current chain, false otherwise.
    function isUnderlyingToken(address _underlyingToken, uint256 _fromChain)
        external
        view
        returns (bool);

    /// @notice View Function returns wrapped native token address for a given chain.
    function getWrappedNativeToken(uint256 _chainId) external view returns (address);

    /// @notice View Function returns the gasPoolAddress for a given chain.
    function getGasPoolInfo(uint256 _chainId)
        external
        view
        returns (
            bool zeroForOneOnInflow,
            uint24 priceImpactPercentage,
            address gasTokenGlobalAddress,
            address poolAddress
        );

    /*///////////////////////////////////////////////////////////////
                        hTOKEN ACCOUTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function burn(
        address _from,
        address _hToken,
        uint256 _amount,
        uint256 _fromChain
    ) external;

    function bridgeToRoot(
        address _recipient,
        address _hToken,
        uint256 _amount,
        uint256 _deposit,
        uint256 fromChainId
    ) external;

    function bridgeToRootFromLocalBranch(
        address _from,
        address _hToken,
        uint256 _amount
    ) external;

    function bridgeToLocalBranch(
        address _recipient,
        address _hToken,
        uint256 _amount,
        uint256 _deposit
    ) external;

    function mintToLocalBranch(
        address _recipient,
        address _hToken,
        uint256 _amount
    ) external;

    function burnFromLocalBranch(
        address _from,
        address _hToken,
        uint256 _amount
    ) external;

    /*///////////////////////////////////////////////////////////////
                        hTOKEN MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
      @notice Setter function to a local hTokens's Underlying Address.
      @param _localAddress new hToken address to update.
      @param _underlyingAddress new underlying/native token address to set.
    **/
    function setUnderlyingAddress(
        address _localAddress,
        address _underlyingAddress,
        uint256 _fromChain
    ) external;

    /**
      @notice Setter function to update a Global hToken's Local hToken Address.
      @param _globalAddress new hToken address to update.
      @param _localAddress new underlying/native token address to set.
    **/
    function setAddresses(
        address _globalAddress,
        address _localAddress,
        address _underlyingAddress,
        uint256 _fromChain
    ) external;

    /**
      @notice Setter function to update a Global hToken's Local hToken Address.
      @param _globalAddress new hToken address to update.
      @param _localAddress new underlying/native token address to set.
    **/
    function setLocalAddress(
        address _globalAddress,
        address _localAddress,
        uint256 _fromChain
    ) external;

    /*///////////////////////////////////////////////////////////////
                    VIRTUAL ACCOUNT MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function fetchVirtualAccount(address _user) external returns (VirtualAccount account);

    function toggleVirtualAccountApproved(VirtualAccount _userAccount, address _router) external;

    /*///////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addBridgeAgent(address _bridgeAgent) external;

    function toggleBridgeAgent(address _bridgeAgent) external;

    function addBridgeAgentFactory(address _bridgeAgentFactory) external;

    function toggleBridgeAgentFactory(address _bridgeAgentFactory) external;

    function setLocalBranchPort(address _branchPort) external;

    /*///////////////////////////////////////////////////////////////
                            ERRORS  
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedBridgeAgentFactory();
    error UnrecognizedBridgeAgent();
    error UnrecognizedCoreBridgeAgent();
    error UnrecognizedLocalBranchPort();
}
