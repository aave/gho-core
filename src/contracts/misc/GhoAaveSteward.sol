// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Address} from 'solidity-utils/contracts/oz-common/Address.sol';
import {IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPoolConfigurator} from '@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {ReserveConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {GhoInterestRateStrategy} from '../facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {IFixedRateStrategyFactory} from '../facilitators/aave/interestStrategy/interfaces/IFixedRateStrategyFactory.sol';
import {IDefaultInterestRateStrategyV2} from './deps/Dependencies.sol';
import {IGhoAaveSteward} from './interfaces/IGhoAaveSteward.sol';
import {RiskCouncilControlled} from './RiskCouncilControlled.sol';
import {IAaveV3ConfigEngine as IEngine} from './deps/Dependencies.sol';

/**
 * @title GhoAaveSteward
 * @author Aave Labs
 * @notice Helper contract for managing parameters of the GHO reserve
 * @dev Only the Risk Council is able to action contract's functions, based on specific conditions that have been agreed upon with the community.
 * @dev Requires role RiskAdmin on the Aave V3 Ethereum Pool
 */
contract GhoAaveSteward is RiskCouncilControlled, IGhoAaveSteward {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using Address for address;

  /// @inheritdoc IGhoAaveSteward
  uint256 public constant GHO_BORROW_RATE_CHANGE_MAX = 0.0500e27; // 5.00%

  /// @inheritdoc IGhoAaveSteward
  uint256 public constant GHO_BORROW_RATE_MAX = 0.2500e27; // 25.00%

  /// @inheritdoc IGhoAaveSteward
  address public immutable CONFIG_ENGINE;

  /// @inheritdoc IGhoAaveSteward
  address public immutable POOL_DATA_PROVIDER;

  /// @inheritdoc IGhoAaveSteward
  uint256 public constant MINIMUM_DELAY = 2 days;

  /// @inheritdoc IGhoAaveSteward
  address public immutable POOL_ADDRESSES_PROVIDER;

  /// @inheritdoc IGhoAaveSteward
  address public immutable GHO_TOKEN;

  /// @inheritdoc IGhoAaveSteward
  address public immutable FIXED_RATE_STRATEGY_FACTORY;

  uint256 internal constant BPS_MAX = 100_00;

  Config internal _riskConfig;

  GhoDebounce internal _ghoTimelocks;

  /**
   * @dev Only methods that are not timelocked can be called if marked by this modifier.
   */
  modifier notTimelocked(uint40 timelock) {
    require(block.timestamp - timelock > MINIMUM_DELAY, 'DEBOUNCE_NOT_RESPECTED');
    _;
  }

  /**
   * @dev Constructor
   * @param addressesProvider The address of the PoolAddressesProvider of Aave V3 Ethereum Pool
   * @param poolDataProvider The pool data provider of the pool to be controlled by the steward
   * @param engine the address of the config engine to be used by the steward
   * @param ghoToken The address of the GhoToken
   * @param fixedRateStrategyFactory The address of the FixedRateStrategyFactory
   * @param riskCouncil The address of the risk council
   * @param riskConfig The initial risk configuration for the Gho reserve
   */
  constructor(
    address addressesProvider,
    address poolDataProvider,
    address engine,
    address ghoToken,
    address fixedRateStrategyFactory,
    address riskCouncil,
    Config memory riskConfig
  ) RiskCouncilControlled(riskCouncil) {
    require(addressesProvider != address(0), 'INVALID_ADDRESSES_PROVIDER');
    require(poolDataProvider != address(0), 'INVALID_DATA_PROVIDER');
    require(engine != address(0), 'INVALID_CONFIG_ENGINE');
    require(ghoToken != address(0), 'INVALID_GHO_TOKEN');
    require(fixedRateStrategyFactory != address(0), 'INVALID_FIXED_RATE_STRATEGY_FACTORY');

    POOL_ADDRESSES_PROVIDER = addressesProvider;
    POOL_DATA_PROVIDER = poolDataProvider;
    CONFIG_ENGINE = engine;
    GHO_TOKEN = ghoToken;
    FIXED_RATE_STRATEGY_FACTORY = fixedRateStrategyFactory;
    _riskConfig = riskConfig;
  }

  /// @inheritdoc IGhoAaveSteward
  function updateGhoBorrowRate(
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  ) external onlyRiskCouncil notTimelocked(_ghoTimelocks.ghoBorrowRateLastUpdate) {
    _validateRatesUpdate(
      optimalUsageRatio,
      baseVariableBorrowRate,
      variableRateSlope1,
      variableRateSlope2
    );
    _updateRates(optimalUsageRatio, baseVariableBorrowRate, variableRateSlope1, variableRateSlope2);

    _ghoTimelocks.ghoBorrowRateLastUpdate = uint40(block.timestamp);
  }

  /// @inheritdoc IGhoAaveSteward
  function updateGhoBorrowCap(
    uint256 newBorrowCap
  ) external onlyRiskCouncil notTimelocked(_ghoTimelocks.ghoBorrowCapLastUpdate) {
    DataTypes.ReserveConfigurationMap memory configuration = IPool(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPool()
    ).getConfiguration(GHO_TOKEN);
    uint256 currentBorrowCap = configuration.getBorrowCap();
    require(
      _isDifferenceLowerThanMax(currentBorrowCap, newBorrowCap, currentBorrowCap),
      'INVALID_BORROW_CAP_UPDATE'
    );

    _ghoTimelocks.ghoBorrowCapLastUpdate = uint40(block.timestamp);

    IPoolConfigurator(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPoolConfigurator())
      .setBorrowCap(GHO_TOKEN, newBorrowCap);
  }

  /// @inheritdoc IGhoAaveSteward
  function updateGhoSupplyCap(
    uint256 newSupplyCap
  ) external onlyRiskCouncil notTimelocked(_ghoTimelocks.ghoSupplyCapLastUpdate) {
    DataTypes.ReserveConfigurationMap memory configuration = IPool(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPool()
    ).getConfiguration(GHO_TOKEN);
    uint256 currentSupplyCap = configuration.getSupplyCap();
    require(
      _isDifferenceLowerThanMax(currentSupplyCap, newSupplyCap, currentSupplyCap),
      'INVALID_SUPPLY_CAP_UPDATE'
    );

    _ghoTimelocks.ghoSupplyCapLastUpdate = uint40(block.timestamp);

    IPoolConfigurator(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPoolConfigurator())
      .setSupplyCap(GHO_TOKEN, newSupplyCap);
  }

  /// @inheritdoc IGhoAaveSteward
  function setRiskConfig(Config calldata riskConfig) external onlyRiskCouncil {
    _riskConfig = riskConfig;
    emit RiskConfigSet(riskConfig);
  }

  /// @inheritdoc IGhoAaveSteward
  function getRiskConfig() external view returns (Config memory) {
    return _riskConfig;
  }

  /// @inheritdoc IGhoAaveSteward
  function getGhoTimelocks() external view returns (GhoDebounce memory) {
    return _ghoTimelocks;
  }

  /// @inheritdoc IGhoAaveSteward
  function RISK_COUNCIL() public view override returns (address) {
    return COUNCIL;
  }

  function _updateRates(
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  ) internal {
    IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](1);
    ratesUpdate[0] = IEngine.RateStrategyUpdate({
      asset: GHO_TOKEN,
      params: IEngine.InterestRateInputData({
        optimalUsageRatio: optimalUsageRatio,
        baseVariableBorrowRate: baseVariableBorrowRate,
        variableRateSlope1: variableRateSlope1,
        variableRateSlope2: variableRateSlope2
      })
    });

    address(CONFIG_ENGINE).functionDelegateCall(
      abi.encodeWithSelector(IEngine(CONFIG_ENGINE).updateRateStrategies.selector, ratesUpdate)
    );
  }

  function _validateRatesUpdate(
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  ) internal view {
    DataTypes.ReserveData memory ghoReserveData = IPool(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPool()
    ).getReserveData(GHO_TOKEN);
    require(
      ghoReserveData.interestRateStrategyAddress != address(0),
      'GHO_INTEREST_RATE_STRATEGY_NOT_FOUND'
    );

    (
      uint256 currentOptimalUsageRatio,
      uint256 currentBaseVariableBorrowRate,
      uint256 currentVariableRateSlope1,
      uint256 currentVariableRateSlope2
    ) = _getInterestRatesForAsset(GHO_TOKEN);

    require(
      _updateWithinAllowedRange(
        currentOptimalUsageRatio,
        optimalUsageRatio,
        _riskConfig.optimalUsageRatio.maxPercentChange,
        false
      ),
      'INVALID_OPTIMAL_USAGE_RATIO'
    );
    require(
      _updateWithinAllowedRange(
        currentBaseVariableBorrowRate,
        baseVariableBorrowRate,
        _riskConfig.baseVariableBorrowRate.maxPercentChange,
        false
      ),
      'INVALID_BORROW_RATE_UPDATE'
    );
    require(
      _updateWithinAllowedRange(
        currentVariableRateSlope1,
        variableRateSlope1,
        _riskConfig.variableRateSlope1.maxPercentChange,
        false
      ),
      'INVALID_VARIABLE_RATE_SLOPE1'
    );
    require(
      _updateWithinAllowedRange(
        currentVariableRateSlope2,
        variableRateSlope2,
        _riskConfig.variableRateSlope2.maxPercentChange,
        false
      ),
      'INVALID_VARIABLE_RATE_SLOPE2'
    );

    uint256 maxBorrowRate = IDefaultInterestRateStrategyV2(
      ghoReserveData.interestRateStrategyAddress
    ).MAX_BORROW_RATE();
    require(
      uint256(baseVariableBorrowRate) + uint256(variableRateSlope1) + uint256(variableRateSlope2) <=
        maxBorrowRate,
      'BORROW_RATE_HIGHER_THAN_MAX'
    );
  }

  /**
   * @notice method to fetch the current interest rate params of the asset
   * @param asset the address of the underlying asset
   * @return optimalUsageRatio the current optimal usage ratio of the asset
   * @return baseVariableBorrowRate the current base variable borrow rate of the asset
   * @return variableRateSlope1 the current variable rate slope 1 of the asset
   * @return variableRateSlope2 the current variable rate slope 2 of the asset
   */
  function _getInterestRatesForAsset(
    address asset
  )
    internal
    view
    returns (
      uint256 optimalUsageRatio,
      uint256 baseVariableBorrowRate,
      uint256 variableRateSlope1,
      uint256 variableRateSlope2
    )
  {
    address rateStrategyAddress = IPoolDataProvider(POOL_DATA_PROVIDER)
      .getInterestRateStrategyAddress(asset);
    IDefaultInterestRateStrategyV2.InterestRateData
      memory interestRateData = IDefaultInterestRateStrategyV2(rateStrategyAddress)
        .getInterestRateDataBps(asset);
    return (
      interestRateData.optimalUsageRatio,
      interestRateData.baseVariableBorrowRate,
      interestRateData.variableRateSlope1,
      interestRateData.variableRateSlope2
    );
  }

  /**
   * @dev Ensures that the change difference is lower than max.
   * @param from current value
   * @param to new value
   * @param max maximum difference between from and to
   * @return bool true if difference between values lower than max, false otherwise
   */
  function _isDifferenceLowerThanMax(
    uint256 from,
    uint256 to,
    uint256 max
  ) internal pure returns (bool) {
    return from < to ? to - from <= max : from - to <= max;
  }

  /**
   * @notice Ensures the risk param update is within the allowed range
   * @param from current risk param value
   * @param to new updated risk param value
   * @param maxPercentChange the max percent change allowed
   * @param isChangeRelative true, if maxPercentChange is relative in value, false if maxPercentChange
   *        is absolute in value.
   * @return bool true, if difference is within the maxPercentChange
   */
  function _updateWithinAllowedRange(
    uint256 from,
    uint256 to,
    uint256 maxPercentChange,
    bool isChangeRelative
  ) internal pure returns (bool) {
    // diff denotes the difference between the from and to values, ensuring it is a positive value always
    uint256 diff = from > to ? from - to : to - from;

    // maxDiff denotes the max permitted difference on both the upper and lower bounds, if the maxPercentChange is relative in value
    // we calculate the max permitted difference using the maxPercentChange and the from value, otherwise if the maxPercentChange is absolute in value
    // the max permitted difference is the maxPercentChange itself
    uint256 maxDiff = isChangeRelative ? (maxPercentChange * from) / BPS_MAX : maxPercentChange;

    if (diff > maxDiff) return false;
    return true;
  }
}
