// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPoolConfigurator} from '@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {ReserveConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {GhoInterestRateStrategy} from '../facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {IFixedRateStrategyFactory} from '../facilitators/aave/interestStrategy/interfaces/IFixedRateStrategyFactory.sol';
import {FixedFeeStrategy} from '../facilitators/gsm/feeStrategy/FixedFeeStrategy.sol';
import {IGsm} from '../facilitators/gsm/interfaces/IGsm.sol';
import {IGsmFeeStrategy} from '../facilitators/gsm/feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {IGhoToken} from '../gho/interfaces/IGhoToken.sol';
import {IArbGhoSteward} from './interfaces/IArbGhoSteward.sol';
import {IOwnable, RateLimiter, UpgradeableBurnMintTokenPool} from './deps/Dependencies.sol';

/**
 * @title ArbGhoSteward
 * @author Aave Labs
 * @notice Helper contract for managing parameters of the GHO reserve and GSM on the Arbitrum network
 * @dev Only the Risk Council is able to action contract's functions, based on specific conditions that have been agreed upon with the community.
 */
contract ArbGhoSteward is Ownable, IArbGhoSteward {
  using EnumerableSet for EnumerableSet.AddressSet;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  /// @inheritdoc IArbGhoSteward
  uint256 public constant GHO_BORROW_RATE_MAX = 0.2500e27; // 25.00%

  /// @inheritdoc IArbGhoSteward
  uint256 public constant GHO_BORROW_RATE_CHANGE_MAX = 0.0500e27; // 5.00%

  /// @inheritdoc IArbGhoSteward
  uint256 public constant MINIMUM_DELAY = 2 days;

  /// @inheritdoc IArbGhoSteward
  address public immutable POOL_ADDRESSES_PROVIDER;

  /// @inheritdoc IArbGhoSteward
  address public immutable GHO_TOKEN;

  /// @inheritdoc IArbGhoSteward
  address public immutable GHO_TOKEN_POOL;

  /// @inheritdoc IArbGhoSteward
  address public immutable FIXED_RATE_STRATEGY_FACTORY;

  /// @inheritdoc IArbGhoSteward
  address public immutable RISK_COUNCIL;

  GhoDebounce internal _ghoTimelocks;
  mapping(address => uint40) _facilitatorsBucketCapacityTimelocks;

  mapping(address => bool) internal _controlledFacilitatorsByAddress;
  EnumerableSet.AddressSet internal _controlledFacilitators;

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
  modifier notTimelocked(uint40 timelock) {
    require(block.timestamp - timelock > MINIMUM_DELAY, 'DEBOUNCE_NOT_RESPECTED');
    _;
  }

  /**
   * @dev Constructor
   * @param owner The address of the owner of the contract
   * @param addressesProvider The address of the PoolAddressesProvider of Aave V3 Arbitrum Pool
   * @param ghoToken The address of the GhoToken
   * @param fixedRateStrategyFactory The address of the FixedRateStrategyFactory
   * @param riskCouncil The address of the risk council
   */
  constructor(
    address owner,
    address addressesProvider,
    address ghoToken,
    address ghoTokenPool,
    address fixedRateStrategyFactory,
    address riskCouncil
  ) {
    require(owner != address(0), 'INVALID_OWNER');
    require(addressesProvider != address(0), 'INVALID_ADDRESSES_PROVIDER');
    require(ghoToken != address(0), 'INVALID_GHO_TOKEN');
    require(ghoTokenPool != address(0), 'INVALID_GHO_TOKEN_POOL');
    require(fixedRateStrategyFactory != address(0), 'INVALID_FIXED_RATE_STRATEGY_FACTORY');
    require(riskCouncil != address(0), 'INVALID_RISK_COUNCIL');

    POOL_ADDRESSES_PROVIDER = addressesProvider;
    GHO_TOKEN = ghoToken;
    GHO_TOKEN_POOL = ghoTokenPool;
    FIXED_RATE_STRATEGY_FACTORY = fixedRateStrategyFactory;
    RISK_COUNCIL = riskCouncil;

    _transferOwnership(owner);
  }

  /// @inheritdoc IArbGhoSteward
  function updateRateLimit(
    uint64 remoteChainSelector,
    bool outboundEnabled,
    uint128 outboundCapacity,
    uint128 outboundRate,
    bool inboundEnabled,
    uint128 inboundCapacity,
    uint128 inboundRate
  ) external onlyRiskCouncil {
    UpgradeableBurnMintTokenPool(GHO_TOKEN_POOL).setChainRateLimiterConfig(
      remoteChainSelector,
      RateLimiter.Config({
        isEnabled: outboundEnabled,
        capacity: outboundCapacity,
        rate: outboundRate
      }),
      RateLimiter.Config({isEnabled: inboundEnabled, capacity: inboundCapacity, rate: inboundRate})
    );
  }

  /// @inheritdoc IArbGhoSteward
  function updateFacilitatorBucketCapacity(
    address facilitator,
    uint128 newBucketCapacity
  ) external onlyRiskCouncil notTimelocked(_facilitatorsBucketCapacityTimelocks[facilitator]) {
    require(_controlledFacilitatorsByAddress[facilitator], 'FACILITATOR_NOT_CONTROLLED');
    (uint256 currentBucketCapacity, ) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(facilitator);
    require(
      _isIncreaseLowerThanMax(currentBucketCapacity, newBucketCapacity, currentBucketCapacity),
      'INVALID_BUCKET_CAPACITY_UPDATE'
    );

    _facilitatorsBucketCapacityTimelocks[facilitator] = uint40(block.timestamp);

    IGhoToken(GHO_TOKEN).setFacilitatorBucketCapacity(facilitator, newBucketCapacity);
  }

  /// @inheritdoc IArbGhoSteward
  function updateGhoBorrowRate(
    uint256 newBorrowRate
  ) external onlyRiskCouncil notTimelocked(_ghoTimelocks.ghoBorrowRateLastUpdate) {
    DataTypes.ReserveData memory ghoReserveData = IPool(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPool()
    ).getReserveData(GHO_TOKEN);
    require(
      ghoReserveData.interestRateStrategyAddress != address(0),
      'GHO_INTEREST_RATE_STRATEGY_NOT_FOUND'
    );

    uint256 currentBorrowRate = GhoInterestRateStrategy(ghoReserveData.interestRateStrategyAddress)
      .getBaseVariableBorrowRate();
    require(newBorrowRate <= GHO_BORROW_RATE_MAX, 'BORROW_RATE_HIGHER_THAN_MAX');
    require(
      _isDifferenceLowerThanMax(currentBorrowRate, newBorrowRate, GHO_BORROW_RATE_CHANGE_MAX),
      'INVALID_BORROW_RATE_UPDATE'
    );

    IFixedRateStrategyFactory strategyFactory = IFixedRateStrategyFactory(
      FIXED_RATE_STRATEGY_FACTORY
    );
    uint256[] memory borrowRateList = new uint256[](1);
    borrowRateList[0] = newBorrowRate;
    address strategy = strategyFactory.createStrategies(borrowRateList)[0];

    _ghoTimelocks.ghoBorrowRateLastUpdate = uint40(block.timestamp);

    IPoolConfigurator(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPoolConfigurator())
      .setReserveInterestRateStrategyAddress(GHO_TOKEN, strategy);
  }

  /// @inheritdoc IArbGhoSteward
  function setControlledFacilitator(
    address[] memory facilitatorList,
    bool approve
  ) external onlyOwner {
    for (uint256 i = 0; i < facilitatorList.length; i++) {
      _controlledFacilitatorsByAddress[facilitatorList[i]] = approve;
      if (approve) {
        _controlledFacilitators.add(facilitatorList[i]);
      } else {
        _controlledFacilitators.remove(facilitatorList[i]);
      }
    }
  }

  /// @inheritdoc IArbGhoSteward
  function getControlledFacilitators() external view returns (address[] memory) {
    return _controlledFacilitators.values();
  }

  /// @inheritdoc IArbGhoSteward
  function getGhoTimelocks() external view returns (GhoDebounce memory) {
    return _ghoTimelocks;
  }

  /// @inheritdoc IArbGhoSteward
  function getFacilitatorBucketCapacityTimelock(
    address facilitator
  ) external view returns (uint40) {
    return _facilitatorsBucketCapacityTimelocks[facilitator];
  }

  /**
   * @dev Ensures that the change is positive and the difference is lower than max.
   * @param from current value
   * @param to new value
   * @param max maximum difference between from and to
   * @return bool true if difference between values is positive and lower than max, false otherwise
   */
  function _isIncreaseLowerThanMax(
    uint256 from,
    uint256 to,
    uint256 max
  ) internal pure returns (bool) {
    return to >= from && to - from <= max;
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
}
