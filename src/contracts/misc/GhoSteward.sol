// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPoolConfigurator} from '@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {GhoInterestRateStrategy} from '../facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {IGhoToken} from '../gho/interfaces/IGhoToken.sol';
import {IGhoSteward} from './interfaces/IGhoSteward.sol';

/**
 * @title GhoSteward
 * @author Aave
 * @notice Helper contract for managing risk parameters of the GHO reserve within the Aave Facilitator
 * @dev This contract must be granted `PoolAdmin` in the Aave V3 Ethereum Pool and `BucketManager` in GHO Token
 * @dev Only the Risk Council is able to action contract's functions.
 * @dev Only the Aave DAO is able to extend the steward's lifespan.
 */
contract GhoSteward is Ownable, IGhoSteward {
  using PercentageMath for uint256;

  /// @inheritdoc IGhoSteward
  uint256 public constant MINIMUM_DELAY = 5 days;

  /// @inheritdoc IGhoSteward
  uint256 public constant BORROW_RATE_CHANGE_MAX = 0.01e4;

  /// @inheritdoc IGhoSteward
  uint40 public constant STEWARD_LIFESPAN = 90 days;

  /// @inheritdoc IGhoSteward
  address public immutable POOL_ADDRESSES_PROVIDER;

  /// @inheritdoc IGhoSteward
  address public immutable GHO_TOKEN;

  /// @inheritdoc IGhoSteward
  address public immutable RISK_COUNCIL;

  Debounce internal _timelocks;
  uint40 internal _stewardExpiration;
  mapping(uint256 => address) internal _strategiesByRate;
  address[] internal _strategies;

  /**
   * @dev Only Risk Council can call functions marked by this modifier.
   */
  modifier onlyRiskCouncil() {
    require(RISK_COUNCIL == msg.sender, 'INVALID_CALLER');
    _;
  }

  /**
   * @dev Constructor
   * @param addressesProvider The address of the PoolAddressesProvider of Aave V3 Ethereum Pool
   * @param ghoToken The address of the GhoToken
   * @param riskCouncil The address of the RiskCouncil
   * @param shortExecutor The address of the Aave Short Executor
   */
  constructor(
    address addressesProvider,
    address ghoToken,
    address riskCouncil,
    address shortExecutor
  ) {
    require(addressesProvider != address(0), 'INVALID_ADDRESSES_PROVIDER');
    require(ghoToken != address(0), 'INVALID_GHO_TOKEN');
    require(riskCouncil != address(0), 'INVALID_RISK_COUNCIL');
    require(shortExecutor != address(0), 'INVALID_SHORT_EXECUTOR');
    POOL_ADDRESSES_PROVIDER = addressesProvider;
    GHO_TOKEN = ghoToken;
    RISK_COUNCIL = riskCouncil;
    _stewardExpiration = uint40(block.timestamp + STEWARD_LIFESPAN);

    _transferOwnership(shortExecutor);
  }

  /// @inheritdoc IGhoSteward
  function updateBorrowRate(uint256 newBorrowRate) external onlyRiskCouncil {
    require(block.timestamp < _stewardExpiration, 'STEWARD_EXPIRED');
    require(
      block.timestamp - _timelocks.borrowRateLastUpdated > MINIMUM_DELAY,
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

    _timelocks.borrowRateLastUpdated = uint40(block.timestamp);

    address cachedStrategyAddress = _strategiesByRate[newBorrowRate];
    // Deploy a new one if does not exist
    if (cachedStrategyAddress == address(0)) {
      GhoInterestRateStrategy newRateStrategy = new GhoInterestRateStrategy(
        POOL_ADDRESSES_PROVIDER,
        newBorrowRate
      );
      cachedStrategyAddress = address(newRateStrategy);

      _strategiesByRate[newBorrowRate] = address(newRateStrategy);
      _strategies.push(address(newRateStrategy));
    }

    IPoolConfigurator(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPoolConfigurator())
      .setReserveInterestRateStrategyAddress(GHO_TOKEN, cachedStrategyAddress);
  }

  /// @inheritdoc IGhoSteward
  function updateBucketCapacity(uint128 newBucketCapacity) external onlyRiskCouncil {
    require(block.timestamp < _stewardExpiration, 'STEWARD_EXPIRED');
    require(
      block.timestamp - _timelocks.bucketCapacityLastUpdated > MINIMUM_DELAY,
      'DEBOUNCE_NOT_RESPECTED'
    );

    DataTypes.ReserveData memory ghoReserveData = IPool(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPool()
    ).getReserveData(GHO_TOKEN);
    require(ghoReserveData.aTokenAddress != address(0), 'GHO_ATOKEN_NOT_FOUND');

    (uint256 oldBucketCapacity, ) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(
      ghoReserveData.aTokenAddress
    );
    require(
      _bucketCapacityIncreaseAllowed(oldBucketCapacity, newBucketCapacity),
      'INVALID_BUCKET_CAPACITY_UPDATE'
    );

    _timelocks.bucketCapacityLastUpdated = uint40(block.timestamp);

    IGhoToken(GHO_TOKEN).setFacilitatorBucketCapacity(
      ghoReserveData.aTokenAddress,
      newBucketCapacity
    );
  }

  /// @inheritdoc IGhoSteward
  function extendStewardExpiration() external onlyOwner {
    uint40 oldStewardExpiration = _stewardExpiration;
    _stewardExpiration += uint40(STEWARD_LIFESPAN);
    emit StewardExpirationUpdated(oldStewardExpiration, _stewardExpiration);
  }

  /// @inheritdoc IGhoSteward
  function getTimelock() external view returns (Debounce memory) {
    return _timelocks;
  }

  /// @inheritdoc IGhoSteward
  function getStewardExpiration() external view returns (uint40) {
    return _stewardExpiration;
  }

  /// @inheritdoc IGhoSteward
  function getAllStrategies() external view returns (address[] memory) {
    return _strategies;
  }

  /**
   * @notice Ensures the borrow rate change is within the allowed range.
   * @param from current borrow rate (in ray)
   * @param to new borrow rate (in ray)
   * @return bool true, if difference is within the max 0.5% change window
   */
  function _borrowRateChangeAllowed(uint256 from, uint256 to) internal pure returns (bool) {
    return
      from < to
        ? to - from <= from.percentMul(BORROW_RATE_CHANGE_MAX)
        : from - to <= from.percentMul(BORROW_RATE_CHANGE_MAX);
  }

  /**
   * @notice Ensures the bucket capacity increase is within the allowed range.
   * @param from current bucket capacity
   * @param to new bucket capacity
   * @return bool true, if difference is within the max 100% increase window
   */
  function _bucketCapacityIncreaseAllowed(uint256 from, uint256 to) internal pure returns (bool) {
    return to >= from && to - from <= from;
  }
}
