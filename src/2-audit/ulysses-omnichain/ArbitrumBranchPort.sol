// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IArbBranchPort.sol";

/**
 * @title Base Port implementation for the Arbitrum deployment.
 *   @author MaiaDAO
 */
contract ArbitrumBranchPort is BranchPort, IArbBranchPort {
    using SafeTransferLib for address;

    /// @notice Local Network Identifier.
    uint24 public localChainId;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    address public rootPortAddress;

    /**
     * @notice Constructor for Arbitrum Branch Port.
     * @param _owner owner of the contract.
     * @param _localChainId local chain id.
     * @param _rootPortAddress address of the Root Port.
     */
    constructor(uint24 _localChainId, address _rootPortAddress, address _owner) BranchPort(_owner) {
        require(_rootPortAddress != address(0), "Root Port Address cannot be 0");

        localChainId = _localChainId;
        rootPortAddress = _rootPortAddress;
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    ///@inheritdoc IArbBranchPort
    function depositToPort(address _depositor, address _recipient, address _underlyingAddress, uint256 _amount)
        external
        requiresBridgeAgent
    {
        address globalToken = IRootPort(rootPortAddress).getLocalTokenFromUnder(_underlyingAddress, localChainId);
        if (globalToken == address(0)) revert UnknownUnderlyingToken();

        _underlyingAddress.safeTransferFrom(_depositor, address(this), _amount);

        IRootPort(rootPortAddress).mintToLocalBranch(_recipient, globalToken, _amount);
    }

    ///@inheritdoc IArbBranchPort
    function withdrawFromPort(address _depositor, address _recipient, address _globalAddress, uint256 _amount)
        external
        requiresBridgeAgent
    {
        if (!IRootPort(rootPortAddress).isGlobalToken(_globalAddress, localChainId)) {
            revert UnknownToken();
        }

        address underlyingAddress = IRootPort(rootPortAddress).getUnderlyingTokenFromLocal(_globalAddress, localChainId);

        if (underlyingAddress == address(0)) revert UnknownUnderlyingToken();

        IRootPort(rootPortAddress).burnFromLocalBranch(_depositor, _globalAddress, _amount);

        _withdraw(_recipient, underlyingAddress, _amount);
    }

    /// @inheritdoc IBranchPort
    function withdraw(address _recipient, address _underlyingAddress, uint256 _amount)
        external
        override(IBranchPort, BranchPort)
        requiresBridgeAgent
    {
        _withdraw(_recipient, _underlyingAddress, _amount);
    }

    /**
     * @notice Internal function to withdraw underlying / native token amount into Port in exchange for Local hToken.
     *   @param _recipient hToken receiver.
     *   @param _underlyingAddress underlying / native token address.
     *   @param _amount amount of tokens.
     *
     */
    function _withdraw(address _recipient, address _underlyingAddress, uint256 _amount) internal override(BranchPort) {
        _underlyingAddress.safeTransfer(_recipient, _amount);
    }

    /// @inheritdoc IBranchPort
    function bridgeIn(address _recipient, address _localAddress, uint256 _amount)
        external
        override(IBranchPort, BranchPort)
        requiresBridgeAgent
    {
        IRootPort(rootPortAddress).mintToLocalBranch(_recipient, _localAddress, _amount);
    }

    /// @inheritdoc IBranchPort
    function bridgeInMultiple(address _recipient, address[] memory _localAddresses, uint256[] memory _amounts)
        external
        override(IBranchPort, BranchPort)
        requiresBridgeAgent
    {
        for (uint256 i = 0; i < _localAddresses.length;) {
            IRootPort(rootPortAddress).mintToLocalBranch(_recipient, _localAddresses[i], _amounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IBranchPort
    function bridgeOut(
        address _depositor,
        address _localAddress,
        address _underlyingAddress,
        uint256 _amount,
        uint256 _deposit
    ) external override(IBranchPort, BranchPort) requiresBridgeAgent {
        if (_deposit > 0) {
            _underlyingAddress.safeTransferFrom(_depositor, address(this), _deposit);
        }
        if (_amount - _deposit > 0) {
            IRootPort(rootPortAddress).bridgeToRootFromLocalBranch(_depositor, _localAddress, _amount - _deposit);
        }
    }

    /// @inheritdoc IBranchPort
    function bridgeOutMultiple(
        address _depositor,
        address[] memory _localAddresses,
        address[] memory _underlyingAddresses,
        uint256[] memory _amounts,
        uint256[] memory _deposits
    ) external override(IBranchPort, BranchPort) requiresBridgeAgent {
        for (uint256 i = 0; i < _localAddresses.length;) {
            if (_deposits[i] > 0) {
                _underlyingAddresses[i].safeTransferFrom(_depositor, address(this), _deposits[i]);
            }
            if (_amounts[i] - _deposits[i] > 0) {
                IRootPort(rootPortAddress).bridgeToRootFromLocalBranch(
                    _depositor, _localAddresses[i], _amounts[i] - _deposits[i]
                );
            }

            unchecked {
                ++i;
            }
        }
    }
}
