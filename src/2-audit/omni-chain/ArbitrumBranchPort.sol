// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IArbBranchPort.sol";

contract ArbitrumBranchPort is Ownable, IArbBranchPort {
    using SafeTransferLib for address;

    /// @notice Local Network Identifier.
    uint256 public localChainId;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    address public rootPortAddress;

    /// @notice Mapping from Underlying Address to isUnderlying (bool).
    mapping(address => bool) public isBridgeAgent;

    /// @notice Bridge Agents deployed in root chain.
    address[] public bridgeAgents;

    /// @notice Number of hTokens deployed in current chain.
    uint256 public bridgeAgentsLenght;

    constructor(
        uint256 _localChainId,
        address _rootPortAddress,
        address _owner
    ) {
        localChainId = _localChainId;
        rootPortAddress = _rootPortAddress;
        _initializeOwner(_owner);
    }

    /*///////////////////////////////////////////////////////////////
                        PORT STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositToPort(
        address _depositor,
        address _recipient,
        address _underlyingAddress,
        uint256 _amount
    ) external requiresRouter {
        address globalToken = IRootPort(rootPortAddress).getLocalTokenFromUnder(
            _underlyingAddress,
            localChainId
        );
        if (globalToken == address(0)) revert UnknownUnderlyingToken();

        _underlyingAddress.safeTransferFrom(_depositor, address(this), _amount);

        IRootPort(rootPortAddress).mintToLocalBranch(
            _recipient,
            globalToken,
            _amount        );
    }

    function withdrawFromPort(
        address _depositor,
        address _recipient,
        address _globalAddress,
        uint256 _amount
    ) external requiresRouter {
        if (!IRootPort(rootPortAddress).isGlobalToken(_globalAddress, localChainId))
            revert UnknownToken();

        address underlyingAddress = IRootPort(rootPortAddress).getUnderlyingTokenFromLocal(
            _globalAddress,
            localChainId
        );

        if (underlyingAddress == address(0)) revert UnknownUnderlyingToken();

        IRootPort(rootPortAddress).burnFromLocalBranch(
            _depositor,
            _globalAddress,
            _amount
        );

        _withdraw(_recipient, underlyingAddress, _amount);
    }

    /**
      @notice Function to withdraw underlying / native token amount into Port in exchange for Local hToken.
      @param _recipient hToken receiver.
      @param _underlyingAddress underlying / native token address.
      @param _amount amount of tokens.
    **/
    function withdraw(
        address _recipient,
        address _underlyingAddress,
        uint256 _amount
    ) external requiresRouter {
        _withdraw(_recipient, _underlyingAddress, _amount);
    }

    /**
      @notice Internal function to withdraw underlying / native token amount into Port in exchange for Local hToken.
      @param _recipient hToken receiver.
      @param _underlyingAddress underlying / native token address.
      @param _amount amount of tokens.
    **/
    function _withdraw(
        address _recipient,
        address _underlyingAddress,
        uint256 _amount
    ) internal {
        _underlyingAddress.safeTransfer(_recipient, _amount);
    }

    /**
      @notice Setter function to increase local hToken supply.
      @param _recipient hToken receiver.
      @param _localAddress token address.
      @param _amount amount of tokens.
    **/
    function bridgeIn(
        address _recipient,
        address _localAddress,
        uint256 _amount
    ) external requiresRouter {
        IRootPort(rootPortAddress).mintToLocalBranch(_recipient, _localAddress, _amount);
    }

    /**
      @notice Setter function to increase local hToken supply.
      @param _localAddresses token addresses.
      @param _amounts amount of tokens.
    **/
    function bridgeInMultiple(
        address _recipient,
        address[] memory _localAddresses,
        uint256[] memory _amounts
    ) external requiresRouter {
        for (uint256 i = 0; i < _localAddresses.length; ) {
            IRootPort(rootPortAddress).mintToLocalBranch(
                _recipient,
                _localAddresses[i],
                _amounts[i]
            );

            unchecked {
                ++i;
            }
        }
    }

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
    ) external requiresRouter {
        if (_amount - _deposit > 0) {
            IRootPort(rootPortAddress).bridgeToRootFromLocalBranch(
                _depositor,
                _localAddress,
                _amount - _deposit
            );
        }
        if (_deposit > 0) {
            _underlyingAddress.safeTransferFrom(_depositor, address(this), _deposit);
        }
    }

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
    ) external requiresRouter {
        for (uint256 i = 0; i < _localAddresses.length; ) {
            if (_amounts[i] - _deposits[i] > 0) {
                IRootPort(rootPortAddress).bridgeToRootFromLocalBranch(
                    _depositor,
                    _localAddresses[i],
                    _amounts[i] - _deposits[i]
                );
            }
            if (_deposits[i] > 0) {
                _underlyingAddresses[i].safeTransferFrom(_depositor, address(this), _deposits[i]);
            }
            unchecked {
                ++i;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addBridgeAgent(address _bridgeAgent) external onlyOwner {
        //TODO modifier
        bridgeAgents.push(_bridgeAgent);
    }

    function toggleBridgeAgent(address _bridgeAgent) external onlyOwner {
        //TODO modifier
        isBridgeAgent[_bridgeAgent] = !isBridgeAgent[_bridgeAgent];
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresRouter() {
        if (!isBridgeAgent[msg.sender]) revert UnrecognizedBridgeAgent();
        _;
    }
}
