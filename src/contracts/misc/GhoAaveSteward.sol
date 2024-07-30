// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPoolConfigurator} from '@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {ReserveConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {GhoInterestRateStrategy} from '../facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {IFixedRateStrategyFactory} from '../facilitators/aave/interestStrategy/interfaces/IFixedRateStrategyFactory.sol';
import {IGhoAaveSteward} from './interfaces/IGhoAaveSteward.sol';
import {RiskCouncilControlled} from './RiskCouncilControlled.sol';

/**
 * @title GhoAaveSteward
 * @author Aave Labs
 * @notice Helper contract for managing parameters of the GHO reserve
 * @dev Only the Risk Council is able to action contract's functions, based on specific conditions that have been agreed upon with the community.
 * @dev Requires role RiskAdmin on the Aave V3 Ethereum Pool
 */
contract GhoAaveSteward is RiskCouncilControlled, IGhoAaveSteward {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  /// @inheritdoc IGhoAaveSteward
  uint256 public constant MINIMUM_DELAY = 2 days;

  /// @inheritdoc IGhoAaveSteward
  address public immutable POOL_ADDRESSES_PROVIDER;

  /// @inheritdoc IGhoAaveSteward
  address public immutable GHO_TOKEN;

  /// @inheritdoc IGhoAaveSteward
  address public immutable FIXED_RATE_STRATEGY_FACTORY;

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
   * @param ghoToken The address of the GhoToken
   * @param fixedRateStrategyFactory The address of the FixedRateStrategyFactory
   * @param riskCouncil The address of the risk council
   */
  constructor(
    address addressesProvider,
    address ghoToken,
    address fixedRateStrategyFactory,
    address riskCouncil
  ) RiskCouncilControlled(riskCouncil) {
    require(addressesProvider != address(0), 'INVALID_ADDRESSES_PROVIDER');
    require(ghoToken != address(0), 'INVALID_GHO_TOKEN');
    require(fixedRateStrategyFactory != address(0), 'INVALID_FIXED_RATE_STRATEGY_FACTORY');

    POOL_ADDRESSES_PROVIDER = addressesProvider;
    GHO_TOKEN = ghoToken;
    FIXED_RATE_STRATEGY_FACTORY = fixedRateStrategyFactory;
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
  function getGhoTimelocks() external view returns (GhoDebounce memory) {
    return _ghoTimelocks;
  }

  /// @inheritdoc IGhoAaveSteward
  function RISK_COUNCIL() public view override returns (address) {
    return COUNCIL;
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
