// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IPoolDataProvider} from '@aave/core-v3/contracts/interfaces/IPoolDataProvider.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {ReserveConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {IPoolConfigurator, IDefaultInterestRateStrategyV2, DefaultReserveInterestRateStrategyV2} from './dependencies/AaveV3-1.sol';
import {IGhoAaveSteward} from './interfaces/IGhoAaveSteward.sol';
import {RiskCouncilControlled} from './RiskCouncilControlled.sol';

/**
 * @title GhoAaveSteward
 * @author Aave Labs
 * @notice Helper contract for managing parameters of the GHO reserve
 * @dev Only the Risk Council is able to action contract's functions, based on specific conditions that have been agreed upon with the community.
 * @dev Requires role RiskAdmin on the Aave V3 Ethereum Pool
 */
contract GhoAaveSteward is Ownable, RiskCouncilControlled, IGhoAaveSteward {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  /// @inheritdoc IGhoAaveSteward
  uint32 public constant GHO_BORROW_RATE_MAX = 0.25e4; // 25.00%

  uint256 internal constant BPS_MAX = 100_00;

  /// @inheritdoc IGhoAaveSteward
  address public immutable POOL_DATA_PROVIDER;

  /// @inheritdoc IGhoAaveSteward
  uint256 public constant MINIMUM_DELAY = 2 days;

  /// @inheritdoc IGhoAaveSteward
  address public immutable POOL_ADDRESSES_PROVIDER;

  /// @inheritdoc IGhoAaveSteward
  address public immutable GHO_TOKEN;

  BorrowRateConfig internal _borrowRateConfig;

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
   * @param owner The address of the contract's owner
   * @param addressesProvider The address of the PoolAddressesProvider of Aave V3 Ethereum Pool
   * @param poolDataProvider The pool data provider of the pool to be controlled by the steward
   * @param ghoToken The address of the GhoToken
   * @param riskCouncil The address of the risk council
   * @param borrowRateConfig The configuration conditions for GHO borrow rate changes
   */
  constructor(
    address owner,
    address addressesProvider,
    address poolDataProvider,
    address ghoToken,
    address riskCouncil,
    BorrowRateConfig memory borrowRateConfig
  ) RiskCouncilControlled(riskCouncil) {
    require(owner != address(0), 'INVALID_OWNER');
    require(addressesProvider != address(0), 'INVALID_ADDRESSES_PROVIDER');
    require(poolDataProvider != address(0), 'INVALID_DATA_PROVIDER');
    require(ghoToken != address(0), 'INVALID_GHO_TOKEN');

    POOL_ADDRESSES_PROVIDER = addressesProvider;
    POOL_DATA_PROVIDER = poolDataProvider;
    GHO_TOKEN = ghoToken;
    _borrowRateConfig = borrowRateConfig;

    _transferOwnership(owner);
  }

  /// @inheritdoc IGhoAaveSteward
  function updateGhoBorrowRate(
    uint16 optimalUsageRatio,
    uint32 baseVariableBorrowRate,
    uint32 variableRateSlope1,
    uint32 variableRateSlope2
  ) external onlyRiskCouncil notTimelocked(_ghoTimelocks.ghoBorrowRateLastUpdate) {
    IDefaultInterestRateStrategyV2.InterestRateData
      memory rateParams = IDefaultInterestRateStrategyV2.InterestRateData({
        optimalUsageRatio: optimalUsageRatio,
        baseVariableBorrowRate: baseVariableBorrowRate,
        variableRateSlope1: variableRateSlope1,
        variableRateSlope2: variableRateSlope2
      });
    _validateRatesUpdate(rateParams);

    _ghoTimelocks.ghoBorrowRateLastUpdate = uint40(block.timestamp);

    IPoolConfigurator(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPoolConfigurator())
      .setReserveInterestRateData(GHO_TOKEN, abi.encode(rateParams));
  }

  /// @inheritdoc IGhoAaveSteward
  function updateGhoBorrowCap(
    uint256 newBorrowCap
  ) external onlyRiskCouncil notTimelocked(_ghoTimelocks.ghoBorrowCapLastUpdate) {
    DataTypes.ReserveConfigurationMap memory configuration = IPool(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPool()
    ).getConfiguration(GHO_TOKEN);
    uint256 currentBorrowCap = configuration.getBorrowCap();
    require(newBorrowCap != currentBorrowCap, 'NO_CHANGE_IN_BORROW_CAP');
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
    require(newSupplyCap != currentSupplyCap, 'NO_CHANGE_IN_SUPPLY_CAP');
    require(
      _isDifferenceLowerThanMax(currentSupplyCap, newSupplyCap, currentSupplyCap),
      'INVALID_SUPPLY_CAP_UPDATE'
    );

    _ghoTimelocks.ghoSupplyCapLastUpdate = uint40(block.timestamp);

    IPoolConfigurator(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPoolConfigurator())
      .setSupplyCap(GHO_TOKEN, newSupplyCap);
  }

  /// @inheritdoc IGhoAaveSteward
  function setBorrowRateConfig(
    uint16 optimalUsageRatioMaxChange,
    uint32 baseVariableBorrowRateMaxChange,
    uint32 variableRateSlope1MaxChange,
    uint32 variableRateSlope2MaxChange
  ) external onlyOwner {
    _borrowRateConfig.optimalUsageRatioMaxChange = optimalUsageRatioMaxChange;
    _borrowRateConfig.baseVariableBorrowRateMaxChange = baseVariableBorrowRateMaxChange;
    _borrowRateConfig.variableRateSlope1MaxChange = variableRateSlope1MaxChange;
    _borrowRateConfig.variableRateSlope2MaxChange = variableRateSlope2MaxChange;
  }

  /// @inheritdoc IGhoAaveSteward
  function getBorrowRateConfig() external view returns (BorrowRateConfig memory) {
    return _borrowRateConfig;
  }

  /// @inheritdoc IGhoAaveSteward
  function getGhoTimelocks() external view returns (GhoDebounce memory) {
    return _ghoTimelocks;
  }

  /// @inheritdoc IGhoAaveSteward
  function RISK_COUNCIL() public view override returns (address) {
    return _riskCouncil;
  }

  /**
   * @dev Validates the interest rates update
   * @param newRates The new interest rate data
   */
  function _validateRatesUpdate(
    IDefaultInterestRateStrategyV2.InterestRateData memory newRates
  ) internal view {
    address rateStrategyAddress = IPoolDataProvider(POOL_DATA_PROVIDER)
      .getInterestRateStrategyAddress(GHO_TOKEN);
    IDefaultInterestRateStrategyV2.InterestRateData
      memory currentRates = IDefaultInterestRateStrategyV2(rateStrategyAddress)
        .getInterestRateDataBps(GHO_TOKEN);

    require(
      newRates.optimalUsageRatio != currentRates.optimalUsageRatio ||
        newRates.baseVariableBorrowRate != currentRates.baseVariableBorrowRate ||
        newRates.variableRateSlope1 != currentRates.variableRateSlope1 ||
        newRates.variableRateSlope2 != currentRates.variableRateSlope2,
      'NO_CHANGE_IN_RATES'
    );

    require(
      _updateWithinAllowedRange(
        currentRates.optimalUsageRatio,
        newRates.optimalUsageRatio,
        _borrowRateConfig.optimalUsageRatioMaxChange,
        false
      ),
      'INVALID_OPTIMAL_USAGE_RATIO'
    );
    require(
      _updateWithinAllowedRange(
        currentRates.baseVariableBorrowRate,
        newRates.baseVariableBorrowRate,
        _borrowRateConfig.baseVariableBorrowRateMaxChange,
        false
      ),
      'INVALID_BORROW_RATE_UPDATE'
    );
    require(
      _updateWithinAllowedRange(
        currentRates.variableRateSlope1,
        newRates.variableRateSlope1,
        _borrowRateConfig.variableRateSlope1MaxChange,
        false
      ),
      'INVALID_VARIABLE_RATE_SLOPE1'
    );
    require(
      _updateWithinAllowedRange(
        currentRates.variableRateSlope2,
        newRates.variableRateSlope2,
        _borrowRateConfig.variableRateSlope2MaxChange,
        false
      ),
      'INVALID_VARIABLE_RATE_SLOPE2'
    );

    require(
      uint256(newRates.baseVariableBorrowRate) +
        uint256(newRates.variableRateSlope1) +
        uint256(newRates.variableRateSlope2) <=
        GHO_BORROW_RATE_MAX,
      'BORROW_RATE_HIGHER_THAN_MAX'
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
