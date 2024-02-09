// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPoolConfigurator} from '@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {ReserveConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {GhoInterestRateStrategy} from '../facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {FixedFeeStrategy} from '../facilitators/gsm/feeStrategy/FixedFeeStrategy.sol';
import {IGhoToken} from '../gho/interfaces/IGhoToken.sol';
import {IGhoStewardV2} from './interfaces/IGhoStewardV2.sol';
import {IGsm} from '../facilitators/gsm/interfaces/IGsm.sol';

/**
 * @title GhoStewardV2
 * @author Aave
 * @notice Helper contract for managing parameters of the GHO reserve and GSM
 * @dev This contract must be granted `PoolAdmin` in the Aave V3 Ethereum Pool and `BucketManager` in GHO Token
 * @dev Only the Service Provider is able to action contract's functions.
 */
contract GhoStewardV2 is IGhoStewardV2 {
  using PercentageMath for uint256;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  /// @inheritdoc IGhoStewardV2
  uint256 public constant GHO_BORROW_CAP_MAX = 50e6 ether;

  /// @inheritdoc IGhoStewardV2
  uint256 public constant GHO_BORROW_RATE_CHANGE_MAX = 0.01e4;

  /// @inheritdoc IGhoStewardV2
  uint256 public constant GHO_BORROW_RATE_MAX = 9.5e4;

  /// @inheritdoc IGhoStewardV2
  uint256 public constant GHO_BORROW_RATE_CHANGE_DELAY = 7 days;

  /// @inheritdoc IGhoStewardV2
  address public immutable POOL_ADDRESSES_PROVIDER;

  /// @inheritdoc IGhoStewardV2
  address public immutable GHO_TOKEN;

  /// @inheritdoc IGhoStewardV2
  address public immutable SERVICE_PROVIDER;

  Debounce internal _timelocks;
  mapping(uint256 => address) internal _ghoBorrowRateStrategies;
  mapping(uint256 => mapping(uint256 => address)) internal _gsmFeeStrategies;

  /**
   * @dev Only SERVICE_PROVIDER can call functions marked by this modifier.
   */
  modifier onlyApprovedServiceProvider() {
    require(SERVICE_PROVIDER == msg.sender, 'INVALID_CALLER');
    _;
  }

  /**
   * @dev Constructor
   * @param addressesProvider The address of the PoolAddressesProvider of Aave V3 Ethereum Pool
   * @param ghoToken The address of the GhoToken
   * @param serviceProvider The address of the service provider
   */
  constructor(address addressesProvider, address ghoToken, address serviceProvider) {
    require(addressesProvider != address(0), 'INVALID_ADDRESSES_PROVIDER');
    require(ghoToken != address(0), 'INVALID_GHO_TOKEN');
    require(serviceProvider != address(0), 'INVALID_SERVICE_PROVIDER');
    POOL_ADDRESSES_PROVIDER = addressesProvider;
    GHO_TOKEN = ghoToken;
    SERVICE_PROVIDER = serviceProvider;
  }

  /// @inheritdoc IGhoStewardV2
  function updateGhoBorrowCap(uint256 newBorrowCap) external onlyApprovedServiceProvider {
    require(newBorrowCap < GHO_BORROW_CAP_MAX, 'INVALID_BORROW_CAP');
    DataTypes.ReserveConfigurationMap memory configurationData = IPool(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPool()
    ).getConfiguration(GHO_TOKEN);
    (, uint256 oldBorrowCap) = configurationData.getCaps();
    require(newBorrowCap > oldBorrowCap, 'INVALID_BORROW_CAP');
    IPoolConfigurator(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPoolConfigurator())
      .setBorrowCap(GHO_TOKEN, newBorrowCap);
  }

  /// @inheritdoc IGhoStewardV2
  function updateGhoBorrowRate(uint256 newBorrowRate) external onlyApprovedServiceProvider {
    require(
      block.timestamp - _timelocks.ghoBorrowRateLastUpdated > GHO_BORROW_RATE_CHANGE_DELAY,
      'DEBOUNCE_NOT_RESPECTED'
    );

    DataTypes.ReserveData memory ghoReserveData = IPool(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPool()
    ).getReserveData(GHO_TOKEN);
    require(
      ghoReserveData.interestRateStrategyAddress != address(0),
      'GHO_INTEREST_RATE_STRATEGY_NOT_FOUND'
    );

    uint256 oldBorrowRate = GhoInterestRateStrategy(ghoReserveData.interestRateStrategyAddress)
      .getBaseVariableBorrowRate();
    require(_borrowRateChangeAllowed(oldBorrowRate, newBorrowRate), 'INVALID_BORROW_RATE_UPDATE');

    _timelocks.ghoBorrowRateLastUpdated = uint40(block.timestamp);

    address cachedStrategyAddress = _ghoBorrowRateStrategies[newBorrowRate];

    if (cachedStrategyAddress == address(0)) {
      GhoInterestRateStrategy newRateStrategy = new GhoInterestRateStrategy(
        POOL_ADDRESSES_PROVIDER,
        newBorrowRate
      );
      cachedStrategyAddress = address(newRateStrategy);

      _ghoBorrowRateStrategies[newBorrowRate] = address(newRateStrategy);
    }

    IPoolConfigurator(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPoolConfigurator())
      .setReserveInterestRateStrategyAddress(GHO_TOKEN, cachedStrategyAddress);
  }

  /// @inheritdoc IGhoStewardV2
  function updateGsmExposureCap(
    IGsm gsm,
    uint128 newExposureCap
  ) external onlyApprovedServiceProvider {
    gsm.updateExposureCap(newExposureCap);
  }

  /// @inheritdoc IGhoStewardV2
  function updateGsmBucketCapacity(
    address gsm,
    uint128 newBucketCapacity
  ) external onlyApprovedServiceProvider {
    IGhoToken(GHO_TOKEN).setFacilitatorBucketCapacity(gsm, newBucketCapacity);
  }

  /// @inheritdoc IGhoStewardV2
  function updateGsmFeeStrategy(
    IGsm gsm,
    uint256 buyFee,
    uint256 sellFee
  ) external onlyApprovedServiceProvider {
    address cachedStrategyAddress = _gsmFeeStrategies[buyFee][sellFee];
    if (cachedStrategyAddress == address(0)) {
      FixedFeeStrategy newRateStrategy = new FixedFeeStrategy(buyFee, sellFee);
      cachedStrategyAddress = address(newRateStrategy);
      _gsmFeeStrategies[buyFee][sellFee] = address(newRateStrategy);
    }
    gsm.updateFeeStrategy(address(cachedStrategyAddress));
  }

  /**
   * @notice Ensures the borrow rate change is within the allowed range and is smaller than the maximum allowed.
   * @param from current borrow rate (in ray)
   * @param to new borrow rate (in ray)
   * @return bool true, if difference is within the max 0.5% change window
   */
  function _borrowRateChangeAllowed(uint256 from, uint256 to) internal pure returns (bool) {
    return
      (
        from < to
          ? to - from <= from.percentMul(GHO_BORROW_RATE_CHANGE_MAX)
          : from - to <= from.percentMul(GHO_BORROW_RATE_CHANGE_MAX)
      ) && (to < GHO_BORROW_RATE_MAX);
  }
}
