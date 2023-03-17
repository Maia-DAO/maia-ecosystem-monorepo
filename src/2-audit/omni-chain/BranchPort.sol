// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IBranchPort.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract BranchPort is Ownable, IBranchPort {
    using SafeTransferLib for address;

    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from Underlying Address to isUnderlying (bool).
    mapping(address => bool) public isBridgeAgent;

    /// @notice Branch Routers deployed in branc chain.
    address[] public bridgeAgents;

    /// @notice Number of Branch Routers deployed in current chain.
    uint256 public bridgeAgentsLenght;

    /*///////////////////////////////////////////////////////////////
                        PORT STRATEGY STATE
    //////////////////////////////////////////////////////////////*/
    /// Strategy Tokens

    /// @notice Mapping returns true if Strategy Token Address is active for usage in Port Strategies.
    mapping(address => bool) public isStrategyToken;

    /// @notice List of Tokens whitelisted for usage in Port Strategies.
    address[] public strategyTokens;

    /// @notice Number of Port Strategies deployed in current branch chain.
    uint256 public strategyTokensLenght;

    /// @notice Mapping returns a given token's total debt incurred by Port Strategies.
    mapping(address => uint256) public getStrategyTokenDebt;

    /// @notice Mapping returns the minimum ratio of a given Strategy Token the Port should hold.
    mapping(address => uint256) public getMinimumTokenReserveRatio;

    /// Port Strategies

    /// @notice Mapping returns true if Port Startegy is allowed to manage a given Strategy Token. Strategy => Token => bool.
    mapping(address => mapping(address => bool)) public isPortStrategy;

    /// @notice Port Strategy Addresses deployed in current branch chain.
    address[] public portStrategies;

    /// @notice Number of Port Strategies deployed in current branch chain.
    uint256 public portStrategiesLenght;

    /// @notice Mapping returns the amount of Strategy Token debt a given Port Startegy has.  Strategy => Token => uint256.
    mapping(address => mapping(address => uint256)) public getPortStrategyTokenDebt;

    /// @notice Mapping returns the last time a given Port Strategy managed a given Strategy Token. Strategy => Token => uint256.
    mapping(address => mapping(address => uint256)) public lastManaged;

    /// @notice Mapping returns the time limit a given Port Strategy must wait before managing a Strategy Token. Strategy => Token => uint256.
    mapping(address => mapping(address => uint256)) public strategyDailyLimitAmount;

    /// @notice Mapping returns the amount of a Strategy Token a given Port Strategy can manage.
    mapping(address => mapping(address => uint256)) public strategyDailyLimitRemaining;

    uint256 internal constant DIVISIONER = 1e4;
    uint256 internal constant MIN_RESERVE_RATIO = 3e3;

    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    /*///////////////////////////////////////////////////////////////
                        PORT STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Allows active Port Strategy addresses to withdraw assets.
        @param _token token address.
        @param _amount amount of tokens.
     */
    function manage(address _token, uint256 _amount) external requiresPortStrategy(_token) {
        if (_amount > _excessReserves(_token)) revert InsufficientReserves();

        _checkTimeLimit(_token, _amount);

        getStrategyTokenDebt[_token] += _amount;
        getPortStrategyTokenDebt[msg.sender][_token] += _amount;

        _token.safeTransfer(msg.sender, _amount);

        emit DebtCreated(msg.sender, _token, _amount);
    }

    /**
        @notice allow approved address to repay borrowed reserves with reserves
        @param _amount uint
        @param _token address
     */
    function replenishReserves(address _strategy, address _token, uint256 _amount) external {
        if (!isStrategyToken[_token]) revert UnrecognizedStrategyToken();
        if (!isPortStrategy[_strategy][_token]) revert UnrecognizedPortStrategy();

        uint256 reservesLacking = _reservesLacking(_token);

        IPortStrategy(_strategy).withdraw(
            address(this),
            _token,
            _amount < reservesLacking ? _amount : reservesLacking
        );

        getPortStrategyTokenDebt[msg.sender][_token] -= _amount;
        getStrategyTokenDebt[_token] -= _amount;

        emit DebtRepaid(_strategy, _token, _amount);
    }

    /**
        @notice Returns amount of Strategy Tokens 
        @return uint256 excess reserves
     */
    function _excessReserves(address _token) internal view returns (uint256) {
        uint256 currBalance = ERC20(_token).balanceOf(address(this));
        uint256 minReserves = _minimumReserves(currBalance, _token);
        return currBalance > minReserves ? currBalance - minReserves : 0;
    }

    /**
        @notice Returns amount of Strategy Tokens needed to reach minimum reserves
        @return uint256 excess reserves
     */
    function _reservesLacking(address _token) internal view returns (uint256) {
        uint256 currBalance = ERC20(_token).balanceOf(address(this));
        uint256 minReserves = _minimumReserves(currBalance, _token);
        return currBalance < minReserves ? minReserves - currBalance : 0;
    }

    /**
        @notice returns excess reserves not backing tokens
        @return uint
     */
    function _minimumReserves(
        uint256 _currBalance,
        address _token
    ) internal view returns (uint256) {
        return
            _currBalance +
            (getStrategyTokenDebt[_token] * getMinimumTokenReserveRatio[_token]) /
            DIVISIONER;
    }

    /**
        @notice checks LimitRequirements
        @param _token address being managed.
        @param _amount token amount being managed.
     */
    function _checkTimeLimit(address _token, uint256 _amount) internal {
        if (block.timestamp - lastManaged[msg.sender][_token] >= 1 days) {
            strategyDailyLimitRemaining[msg.sender][_token] = strategyDailyLimitAmount[msg.sender][
                _token
            ];
        }
        strategyDailyLimitRemaining[msg.sender][_token] -= _amount;
        lastManaged[msg.sender][_token] = block.timestamp;
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
    ) external requiresBridgeAgent {
        _withdraw(_recipient, _underlyingAddress, _amount);
    }

    /**
      @notice Internal function to withdraw underlying / native token amount into Port in exchange for Local hToken.
      @param _recipient hToken receiver.
      @param _underlyingAddress underlying / native token address.
      @param _amount amount of tokens.
    **/
    function _withdraw(address _recipient, address _underlyingAddress, uint256 _amount) internal {
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
    ) external requiresBridgeAgent {
        ERC20hTokenBranch(_localAddress).mint(_recipient, _amount);
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
    ) external requiresBridgeAgent {
        for (uint256 i = 0; i < _localAddresses.length; ) {
            ERC20hTokenBranch(_localAddresses[i]).mint(_recipient, _amounts[i]);

            unchecked {
                i++;
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
    ) external requiresBridgeAgent {
        if (_amount - _deposit > 0) {
            _localAddress.safeTransferFrom(_depositor, address(this), _amount - _deposit);
            ERC20hTokenBranch(_localAddress).burn(_amount - _deposit);
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
    ) external requiresBridgeAgent {
        for (uint256 i = 0; i < _localAddresses.length; ) {
            if (_amounts[i] - _deposits[i] > 0) {
                _localAddresses[i].safeTransferFrom(
                    _depositor,
                    address(this),
                    _amounts[i] - _deposits[i]
                );
                ERC20hTokenBranch(_localAddresses[i]).burn(_amounts[i] - _deposits[i]);
            }
            if (_deposits[i] > 0) {
                _underlyingAddresses[i].safeTransferFrom(_depositor, address(this), _deposits[i]);
            }
            unchecked {
                i++;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addBridgeAgent(address _bridgeAgent) external onlyOwner {
        bridgeAgents.push(_bridgeAgent);
        bridgeAgentsLenght++;
    }

    function toggleBridgeAgent(address _bridgeAgent) external onlyOwner {
        isBridgeAgent[_bridgeAgent] = !isBridgeAgent[_bridgeAgent];
    }

    function addPortStrategy(
        address _portStrategy,
        address _token,
        uint256 _dailyManagementLimit
    ) external onlyOwner {
        portStrategies.push(_portStrategy);
        portStrategiesLenght++;
        strategyDailyLimitAmount[_portStrategy][_token] = _dailyManagementLimit;
    }

    function togglePortStrategy(address _portStrategy, address _token) external onlyOwner {
        isPortStrategy[_portStrategy][_token] = !isPortStrategy[_portStrategy][_token];
    }

    function updatePortStrategy(
        address _portStrategy,
        address _token,
        uint256 _dailyManagementLimit
    ) external onlyOwner {
        strategyDailyLimitAmount[_portStrategy][_token] = _dailyManagementLimit;
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier that verifies msg sender is an active bridgeAgent.
    modifier requiresBridgeAgent() {
        if (!isBridgeAgent[msg.sender]) revert UnrecognizedBridgeAgent();
        _;
    }

    /// @notice require msg sender == active port strategy
    modifier requiresPortStrategy(address _token) {
        if (!isPortStrategy[msg.sender][_token]) revert UnrecognizedPortStrategy();
        _;
    }

    /// @notice Modifier for a simple re-entrancy check.
    uint256 internal _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }
}
