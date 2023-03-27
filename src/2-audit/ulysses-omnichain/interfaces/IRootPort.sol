// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Ownable } from "solady/auth/Ownable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { ERC20hTokenRoot } from "../token/ERC20hTokenRoot.sol";

import { VirtualAccount } from "../VirtualAccount.sol";

import { IRootBridgeAgent as IBridgeAgent } from "./IRootBridgeAgent.sol";

import { IRootBridgeAgentFactory } from "./IRootBridgeAgentFactory.sol";

import { ISwapRouter } from "../interfaces/ISwapRouter.sol";

import { IERC20hTokenRootFactory } from "../interfaces/IERC20hTokenRootFactory.sol";

import { INonfungiblePositionManager } from "../interfaces/INonfungiblePositionManager.sol";

interface ICoreRootRouter {
    function hTokenFactoryAddress() external view returns (address);
}

struct GasPoolInfo {
    //zeroForOne when swapping gas from branch chain into root chain gas
    bool zeroForOneOnInflow;
    uint24 priceImpactPercentage;
    address gasTokenGlobalAddress;
    address poolAddress;
}

interface IRootPort {
    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getBridgeAgentManager(address _rootBridgeAgent) external view returns (address);

    /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isGlobalAddress(address _globalAddress) external view returns (bool);

    /// @notice Mapping from Underlying Address to isUnderlying (bool).
    function isRouterApproved(VirtualAccount _userAccount, address _router) external returns (bool);

    /**
     * @notice View Function returns Token's Global Address from it's local address.
     *  @param _localAddress The address of the token in the local chain.
     *  @param _fromChain The chainId of the chain where the token is deployed.
     */
    function getGlobalTokenFromLocal(
        address _localAddress,
        uint24 _fromChain
    ) external view returns (address);

    /**
     * @notice View Function returns Token's Local Address from it's global address.
     * @param _globalAddress The address of the token in the global chain.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function getLocalTokenFromGlobal(
        address _globalAddress,
        uint24 _fromChain
    ) external view returns (address);

    /**
     * @notice View Function that returns the local token address from the underlying token address.
     *  @param _underlyingAddress The address of the underlying token.
     *  @param _fromChain The chainId of the chain where the token is deployed.
     */
    function getLocalTokenFromUnder(
        address _underlyingAddress,
        uint24 _fromChain
    ) external view returns (address);

    /**
     * @notice Function that returns Local Token's Local Address on another chain.
     * @param _localAddress The address of the token in the local chain.
     * @param _fromChain The chainId of the chain where the token is deployed.
     * @param _toChain The chainId of the chain where the token is deployed.
     */
    function getLocalToken(
        address _localAddress,
        uint24 _fromChain,
        uint24 _toChain
    ) external view returns (address);

    /**
     * @notice View Function returns a underlying token address from it's local address.
     * @param _localAddress The address of the token in the local chain.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function getUnderlyingTokenFromLocal(
        address _localAddress,
        uint24 _fromChain
    ) external view returns (address);

    /**
     * @notice Returns the underlying token address given it's global address.
     * @param _globalAddress The address of the token in the global chain.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function getUnderlyingTokenFromGlobal(
        address _globalAddress,
        uint24 _fromChain
    ) external view returns (address);

    /**
     * @notice View Function returns True if Global Token is already added in current chain, false otherwise.
     * @param _globalAddress The address of the token in the global chain.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function isGlobalToken(address _globalAddress, uint24 _fromChain) external view returns (bool);

    /**
     * @notice View Function returns True if Local Token is already added in current chain, false otherwise.
     *  @param _localAddress The address of the token in the local chain.
     *  @param _fromChain The chainId of the chain where the token is deployed.
     */
    function isLocalToken(address _localAddress, uint24 _fromChain) external view returns (bool);

    /// @notice View Function returns True if Local Token and is also already added in another branch chain, false otherwise.
    function isLocalToken(
        address _localAddress,
        uint24 _fromChain,
        uint24 _toChain
    ) external view returns (bool);

    /**
     * @notice View Function returns True if the underlying Token is already added in current chain, false otherwise.
     * @param _underlyingToken The address of the underlying token.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function isUnderlyingToken(
        address _underlyingToken,
        uint24 _fromChain
    ) external view returns (bool);

    /// @notice View Function returns wrapped native token address for a given chain.
    function getWrappedNativeToken(uint256 _chainId) external view returns (address);

    /// @notice View Function returns the gasPoolAddress for a given chain.
    function getGasPoolInfo(
        uint256 _chainId
    )
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

    /**
     * @notice Burns hTokens from the sender address.
     * @param _from sender of the hTokens to burn.
     * @param _hToken address of the hToken to burn.
     * @param _amount amount of hTokens to burn.
     * @param _fromChain The chainId of the chain where the token is deployed.
     */
    function burn(address _from, address _hToken, uint256 _amount, uint24 _fromChain) external;

    /**
     * @notice Updates root port state to match a new deposit.
     * @param _recipient recipient of bridged tokens.
     * @param _hToken address of the hToken to bridge.
     * @param _amount amount of hTokens to bridge.
     * @param _deposit amount of underlying tokens to deposit.
     * @param _fromChainId The chainId of the chain where the token is deployed.
     */
    function bridgeToRoot(
        address _recipient,
        address _hToken,
        uint256 _amount,
        uint256 _deposit,
        uint24 _fromChainId
    ) external;

    /**
     * @notice Bridges hTokens from the local branch to the root port.
     * @param _from sender of the hTokens to bridge.
     * @param _hToken address of the hToken to bridge.
     * @param _amount amount of hTokens to bridge.
     */
    function bridgeToRootFromLocalBranch(address _from, address _hToken, uint256 _amount) external;

    /**
     * @notice Bridges tokens from the root port to the local branch.
     * @param _recipient recipient of bridged tokens.
     * @param _hToken address of the hToken to bridge.
     * @param _amount amount of hTokens to bridge.
     * @param _deposit amount of underlying tokens to deposit.
     */
    function bridgeToLocalBranch(
        address _recipient,
        address _hToken,
        uint256 _amount,
        uint256 _deposit
    ) external;

    /**
     * @notice Mints new tokens to the recipient address
     * @param _recipient recipient of the newly minted tokens.
     * @param _hToken address of the hToken to mint.
     * @param _amount amount of tokens to mint.
     */
    function mintToLocalBranch(address _recipient, address _hToken, uint256 _amount) external;

    /**
     * @notice Burns tokens from the sender address
     * @param _from sender of the tokens to burn.
     * @param _hToken address of the hToken to burn.
     * @param _amount amount of tokens to burn.
     */
    function burnFromLocalBranch(address _from, address _hToken, uint256 _amount) external;

    /*///////////////////////////////////////////////////////////////
                        hTOKEN MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Setter function to a local hTokens's Underlying Address.
     *   @param _localAddress new hToken address to update.
     *   @param _underlyingAddress new underlying/native token address to set.
     *
     */
    function setUnderlyingAddress(
        address _localAddress,
        address _underlyingAddress,
        uint24 _fromChain
    ) external;

    /**
     * @notice Setter function to update a Global hToken's Local hToken Address.
     *   @param _globalAddress new hToken address to update.
     *   @param _localAddress new underlying/native token address to set.
     *
     */
    function setAddresses(
        address _globalAddress,
        address _localAddress,
        address _underlyingAddress,
        uint24 _fromChain
    ) external;

    /**
     * @notice Setter function to update a Global hToken's Local hToken Address.
     *   @param _globalAddress new hToken address to update.
     *   @param _localAddress new underlying/native token address to set.
     *
     */
    function setLocalAddress(
        address _globalAddress,
        address _localAddress,
        uint24 _fromChain
    ) external;

    /*///////////////////////////////////////////////////////////////
                    VIRTUAL ACCOUNT MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the virtual account given a user address.
     * @param _user address of the user to get the virtual account for.
     */
    function fetchVirtualAccount(address _user) external returns (VirtualAccount account);

    /**
     * @notice Toggles the approval of a router for a virtual account. Allows for a router to spend a user's virtual account.
     * @param _userAccount virtual account to toggle the approval for.
     * @param _router router to toggle the approval for.
     */
    function toggleVirtualAccountApproved(VirtualAccount _userAccount, address _router) external;

    /*///////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the address of the bridge agent for a given chain.
     * @param _newBranchBridgeAgent address of the new branch bridge agent.
     * @param _rootBridgeAgent address of the root bridge agent.
     * @param _fromChain chainId of the chain to set the bridge agent for.
     */
    function syncBranchBridgeAgentWithRoot(
        address _newBranchBridgeAgent,
        address _rootBridgeAgent,
        uint24 _fromChain
    ) external;

    /**
     * @notice Adds a new bridge agent to the list of bridge agents.
     * @param _manager address of the manager of the bridge agent.
     * @param _bridgeAgent address of the bridge agent to add.
     */
    function addBridgeAgent(address _manager, address _bridgeAgent) external;

    /**
     * @notice Toggles the status of a bridge agent.
     * @param _bridgeAgent address of the bridge agent to toggle.
     */
    function toggleBridgeAgent(address _bridgeAgent) external;

    /**
     * @notice Adds a new bridge agent factory to the list of bridge agent factories.
     * @param _bridgeAgentFactory address of the bridge agent factory to add.
     */
    function addBridgeAgentFactory(address _bridgeAgentFactory) external;

    /**
     * @notice Toggles the status of a bridge agent factory.
     * @param _bridgeAgentFactory address of the bridge agent factory to toggle.
     */
    function toggleBridgeAgentFactory(address _bridgeAgentFactory) external;

    /**
     * @notice Setter for the local branch port address.
     * @param _branchPort address of the local branch port.
     */
    function setLocalBranchPort(address _branchPort) external;

    /**
     * @notice Adds a new chain to the root port lists of chains
     * @param _chainId chainId of the new chain
     * @param _gasTokenName gas token name of the chain to add
     * @param _gasTokenSymbol gas token symbol of the chain to add
     * @param _fee fee of the chain to add
     * @param _priceImpactPercentage price impact percentage of the chain to add
     * @param _sqrtPriceX96 sqrt price of the chain to add
     * @param _hTokenFactoryAddress address of the hToken factory
     * @param _nonFungiblePositionManagerAddress address of the NFT position manager
     * @param _newLocalBranchWrappedNativeTokenAddress address of the wrapped native token of the new branch
     * @param _newUnderlyingBranchWrappedNativeTokenAddress address of the underlying wrapped native token of the new branch
     * @param _hTokenFactoryAddress address of the hToken factory
     */
    function addNewChain(
        uint24 _chainId,
        string memory _gasTokenName,
        string memory _gasTokenSymbol,
        uint24 _fee,
        uint24 _priceImpactPercentage,
        uint160 _sqrtPriceX96,
        address _nonFungiblePositionManagerAddress,
        address _newLocalBranchWrappedNativeTokenAddress,
        address _newUnderlyingBranchWrappedNativeTokenAddress,
        address _hTokenFactoryAddress
    ) external;

    /**
     * @notice Sets the gas pool info for a chain
     * @param _chainId chainId of the chain to set the gas pool info for
     * @param _gasPoolInfo gas pool info to set
     */
    function setGasPoolInfo(uint24 _chainId, GasPoolInfo calldata _gasPoolInfo) external;

    /**
     *    @notice Sets the gas pool info for a chain
     * @param _branchBridgeAgent branch bridge agent address
     * @param _chainId chainId of the chain to set the gas pool info for
     */
    function addChainToCore(address _branchBridgeAgent, uint24 _chainId) external;

    /**
     * @notice
     * @param hermesGlobalAddress hermes global address
     * @param maiaGlobalAddress maia global address
     */
    function initializeEcosystemTokenAddresses(
        address hermesGlobalAddress,
        address maiaGlobalAddress
    ) external;

    /**
     * @notice Adds an ecosystem hToken to a branch chain
     * @param ecoTokenGlobalAddress ecosystem token global address
     * @param ecoTokenLocalAddress ecosystem token local address
     * @param toChainId chainId of the branch chain to add the ecosystem token to
     */
    function addEcosystemTokenToChain(
        address ecoTokenGlobalAddress,
        address ecoTokenLocalAddress,
        uint256 toChainId
    ) external;

    /*///////////////////////////////////////////////////////////////
                            ERRORS  
        //////////////////////////////////////////////////////////////*/

    error UnrecognizedBridgeAgentFactory();
    error UnrecognizedBridgeAgent();

    error AlreadyAddedBridgeAgent();
    error BridgeAgentNotAllowed();
    error UnrecognizedCoreBridgeAgent();
    error UnrecognizedLocalBranchPort();
    error UnknowHTokenFactory();
}
