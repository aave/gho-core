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
import {IGsmFeeStrategy} from '../facilitators/gsm/feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title GhoStewardV2
 * @author Aave Labs
 * @notice Helper contract for managing parameters of the GHO reserve and GSM
 * @dev This contract must be granted `PoolAdmin` in the Aave V3 Ethereum Pool, `BucketManager` in GHO Token and `Configurator` in every GSM asset that will be managed by the risk council.
 * @dev Only the Risk Council is able to action contract's functions.
 * @dev Only the Aave DAO is able add or remove approved GSMs.
 * @dev When updating GSM fee strategy the method asumes that the current strategy is FixedFeeStrategy for enforcing parameters
 * @dev FixedFeeStrategy is used when creating a new strategy for GSM
 * @dev GhoInterestRateStrategy is used when creating a new borrow rate strategy for GHO
 */
contract GhoStewardV2 is Ownable, IGhoStewardV2 {
  using PercentageMath for uint256;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @inheritdoc IGhoStewardV2
  uint256 public constant GHO_BORROW_RATE_CHANGE_MAX = 0.005e27;

  /// @inheritdoc IGhoStewardV2
  uint256 public constant GSM_FEE_RATE_CHANGE_MAX = 0.005e4;

  /// @inheritdoc IGhoStewardV2
  uint256 public constant GHO_BORROW_RATE_MAX = 9.5e27;

  /// @inheritdoc IGhoStewardV2
  uint256 public constant MINIMUM_DELAY = 7 days;

  /// @inheritdoc IGhoStewardV2
  address public immutable POOL_ADDRESSES_PROVIDER;

  /// @inheritdoc IGhoStewardV2
  address public immutable GHO_TOKEN;

  /// @inheritdoc IGhoStewardV2
  address public immutable RISK_COUNCIL;

  uint40 internal _ghoBorrowRateLastUpdated;
  mapping(address => uint40) _facilitatorsBucketCapacityTimelocks;
  mapping(address => GsmDebounce) internal _gsmTimelocksByAddress;

  mapping(address => bool) internal _controlledFacilitatorsByAddress;
  EnumerableSet.AddressSet internal _controlledFacilitators;

  mapping(uint256 => address) internal _ghoBorrowRateStrategiesByRate;
  EnumerableSet.AddressSet internal _ghoBorrowRateStrategies;
  mapping(uint256 => mapping(uint256 => address)) internal _gsmFeeStrategiesByRates;
  EnumerableSet.AddressSet internal _gsmFeeStrategies;

  /**
   * @dev Only Risk Council can call functions marked by this modifier.
   */
  modifier onlyRiskCouncil() {
    require(RISK_COUNCIL == msg.sender, 'INVALID_CALLER');
    _;
  }

  /**
   * @dev Only methods that are not timelocked can be called if marked by this modifier.
   */
  modifier notLocked(uint40 timelock) {
    require(block.timestamp - timelock > MINIMUM_DELAY, 'DEBOUNCE_NOT_RESPECTED');
    _;
  }

  /**
   * @dev Constructor
   * @param addressesProvider The address of the PoolAddressesProvider of Aave V3 Ethereum Pool
   * @param ghoToken The address of the GhoToken
   * @param riskCouncil The address of the risk council
   */
  constructor(address addressesProvider, address ghoToken, address riskCouncil, address executor) {
    require(addressesProvider != address(0), 'INVALID_ADDRESSES_PROVIDER');
    require(ghoToken != address(0), 'INVALID_GHO_TOKEN');
    require(riskCouncil != address(0), 'INVALID_RISK_COUNCIL');
    require(executor != address(0), 'INVALID_EXECUTOR');
    POOL_ADDRESSES_PROVIDER = addressesProvider;
    GHO_TOKEN = ghoToken;
    RISK_COUNCIL = riskCouncil;
    _transferOwnership(executor);
  }

  /// @inheritdoc IGhoStewardV2
  function updateFacilitatorBucketCapacity(
    address facilitator,
    uint128 newBucketCapacity
  ) external onlyRiskCouncil notLocked(_facilitatorsBucketCapacityTimelocks[facilitator]) {
    require(_controlledFacilitatorsByAddress[facilitator], 'FACILITATOR_NOT_APPROVED');
    (uint256 currentBucketCapacity, ) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(facilitator);
    require(
      _isChangePositiveAndIncreaseLowerThanMax(
        currentBucketCapacity,
        newBucketCapacity,
        currentBucketCapacity
      ),
      'INVALID_BUCKET_CAPACITY_UPDATE'
    );

    _facilitatorsBucketCapacityTimelocks[facilitator] = uint40(block.timestamp);

    IGhoToken(GHO_TOKEN).setFacilitatorBucketCapacity(facilitator, newBucketCapacity);
  }

  /// @inheritdoc IGhoStewardV2
  function updateGhoBorrowRate(
    uint256 newBorrowRate
  ) external onlyRiskCouncil notLocked(_ghoBorrowRateLastUpdated) {
    DataTypes.ReserveData memory ghoReserveData = IPool(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPool()
    ).getReserveData(GHO_TOKEN);
    require(
      ghoReserveData.interestRateStrategyAddress != address(0),
      'GHO_INTEREST_RATE_STRATEGY_NOT_FOUND'
    );

    uint256 currentBorrowRate = GhoInterestRateStrategy(ghoReserveData.interestRateStrategyAddress)
      .getBaseVariableBorrowRate();
    require(
      _isChangePositiveAndIncreaseLowerThanMax(
        currentBorrowRate,
        newBorrowRate,
        GHO_BORROW_RATE_CHANGE_MAX
      ) && newBorrowRate <= GHO_BORROW_RATE_MAX,
      'INVALID_BORROW_RATE_UPDATE'
    );
    address cachedStrategyAddress = _ghoBorrowRateStrategiesByRate[newBorrowRate];

    if (cachedStrategyAddress == address(0)) {
      GhoInterestRateStrategy newRateStrategy = new GhoInterestRateStrategy(
        POOL_ADDRESSES_PROVIDER,
        newBorrowRate
      );
      cachedStrategyAddress = address(newRateStrategy);

      _ghoBorrowRateStrategiesByRate[newBorrowRate] = cachedStrategyAddress;
      _ghoBorrowRateStrategies.add(cachedStrategyAddress);
    }

    _ghoBorrowRateLastUpdated = uint40(block.timestamp);

    IPoolConfigurator(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPoolConfigurator())
      .setReserveInterestRateStrategyAddress(GHO_TOKEN, cachedStrategyAddress);
  }

  /// @inheritdoc IGhoStewardV2
  function updateGsmExposureCap(
    address gsm,
    uint128 newExposureCap
  ) external onlyRiskCouncil notLocked(_gsmTimelocksByAddress[gsm].gsmExposureCapLastUpdated) {
    uint128 currentExposureCap = IGsm(gsm).getExposureCap();
    require(
      _isChangePositiveAndIncreaseLowerThanMax(
        currentExposureCap,
        newExposureCap,
        currentExposureCap
      ),
      'INVALID_EXPOSURE_CAP_UPDATE'
    );
    _gsmTimelocksByAddress[gsm].gsmExposureCapLastUpdated = uint40(block.timestamp);
    IGsm(gsm).updateExposureCap(newExposureCap);
  }

  /// @inheritdoc IGhoStewardV2
  function updateGsmFeeStrategy(
    address gsm,
    uint256 buyFee,
    uint256 sellFee
  ) external onlyRiskCouncil notLocked(_gsmTimelocksByAddress[gsm].gsmFeeStrategyLastUpdated) {
    address currentFeeStrategy = IGsm(gsm).getFeeStrategy();
    require(currentFeeStrategy != address(0), 'GSM_FEE_STRATEGY_NOT_FOUND');
    uint256 currentBuyFee = IGsmFeeStrategy(gsm).getBuyFee(10e5);
    uint256 currentSellFee = IGsmFeeStrategy(gsm).getSellFee(10e5);
    require(
      _isChangePositiveAndIncreaseLowerThanMax(currentBuyFee, buyFee, GSM_FEE_RATE_CHANGE_MAX) &&
        _isChangePositiveAndIncreaseLowerThanMax(currentSellFee, sellFee, GSM_FEE_RATE_CHANGE_MAX),
      'INVALID_FEE_STRATEGY_UPDATE'
    );
    address cachedStrategyAddress = _gsmFeeStrategiesByRates[buyFee][sellFee];
    if (cachedStrategyAddress == address(0)) {
      FixedFeeStrategy newRateStrategy = new FixedFeeStrategy(buyFee, sellFee);
      cachedStrategyAddress = address(newRateStrategy);
      _gsmFeeStrategiesByRates[buyFee][sellFee] = cachedStrategyAddress;
      _gsmFeeStrategies.add(cachedStrategyAddress);
    }
    _gsmTimelocksByAddress[gsm].gsmFeeStrategyLastUpdated = uint40(block.timestamp);
    IGsm(gsm).updateFeeStrategy(cachedStrategyAddress);
  }

  /// @inheritdoc IGhoStewardV2
  function controlFacilitators(address[] memory facilitatorList, bool approve) external onlyOwner {
    for (uint256 i = 0; i < facilitatorList.length; i++) {
      _controlledFacilitatorsByAddress[facilitatorList[i]] = approve;
      if (approve) {
        IGhoToken.Facilitator memory facilitator = IGhoToken(GHO_TOKEN).getFacilitator(
          facilitatorList[i]
        );
        require(bytes(facilitator.label).length > 0, 'FACILITATOR_DOES_NOT_EXIST');
        _controlledFacilitators.add(facilitatorList[i]);
      } else {
        _controlledFacilitators.remove(facilitatorList[i]);
      }
    }
  }

  /// @inheritdoc IGhoStewardV2
  function getControlledFacilitators() external view returns (address[] memory) {
    return _controlledFacilitators.values();
  }

  /// @inheritdoc IGhoStewardV2
  function getGhoBorrowRateTimelock() external view returns (uint40) {
    return _ghoBorrowRateLastUpdated;
  }

  /// @inheritdoc IGhoStewardV2
  function getGsmTimelocks(address gsm) external view returns (GsmDebounce memory) {
    return _gsmTimelocksByAddress[gsm];
  }

  /// @inheritdoc IGhoStewardV2
  function getFacilitatorBucketCapacityTimelock(
    address facilitator
  ) external view returns (uint40) {
    return _facilitatorsBucketCapacityTimelocks[facilitator];
  }

  /// @inheritdoc IGhoStewardV2
  function getGsmFeeStrategies() external view returns (address[] memory) {
    return _gsmFeeStrategies.values();
  }

  /// @inheritdoc IGhoStewardV2
  function getGhoBorrowRateStrategies() external view returns (address[] memory) {
    return _ghoBorrowRateStrategies.values();
  }

  /**
   * @notice Ensures the borrow rate change is within the allowed range and is smaller than the maximum allowed.
   * @param from current borrow rate (in ray)
   * @param to new borrow rate (in ray)
   * @return bool true, if difference is within the max 1% change window
   */
  function _isChangePositiveAndIncreaseLowerThanMax(
    uint256 from,
    uint256 to,
    uint256 max
  ) internal pure returns (bool) {
    return to >= from && to - from <= max;
  }
}
