// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IDefaultInterestRateStrategy} from '@aave/core-v3/contracts/interfaces/IDefaultInterestRateStrategy.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IFixedRateStrategyFactory} from './interfaces/IFixedRateStrategyFactory.sol';
import {GhoInterestRateStrategy} from './GhoInterestRateStrategy.sol';

/**
 * @title FixedRateStrategyFactory
 * @author Aave Labs
 * @notice Factory contract to create and keep record of Aave v3 fixed rate strategy contracts
 * @dev For creating the strategies `GhoInterestRateStrategy` is used.
 * @dev Associated to an specific Aave v3 Pool, via its addresses provider
 */
contract FixedRateStrategyFactory is VersionedInitializable, IFixedRateStrategyFactory {
  ///@inheritdoc IFixedRateStrategyFactory
  address public immutable POOL_ADDRESSES_PROVIDER;

  mapping(uint256 => address) internal _strategiesByRate;
  address[] internal _strategies;

  constructor(address addressesProvider) {
    require(addressesProvider != address(0), 'INVALID_ADDRESSES_PROVIDER');
    POOL_ADDRESSES_PROVIDER = addressesProvider;
  }

  /**
   * @notice FixedRateStrategyFactory initializer
   * @dev asumes that the addresses provided are fixed rate deployed strategies.
   * @param fixedRateStrategiesList List of fixed rate strategies
   */
  function initialize(address[] memory fixedRateStrategiesList) external initializer {
    for (uint256 i = 0; i < fixedRateStrategiesList.length; i++) {
      address fixedRateStrategy = fixedRateStrategiesList[i];
      uint256 rate = IDefaultInterestRateStrategy(fixedRateStrategy).getBaseVariableBorrowRate();

      _strategiesByRate[rate] = fixedRateStrategy;
      _strategies.push(fixedRateStrategy);

      emit RateStrategyCreated(fixedRateStrategy, rate);
    }
  }

  ///@inheritdoc IFixedRateStrategyFactory
  function createStrategies(uint256[] memory fixedRateList) public returns (address[] memory) {
    address[] memory strategies = new address[](fixedRateList.length);
    for (uint256 i = 0; i < fixedRateList.length; i++) {
      uint256 rate = fixedRateList[i];
      address cachedStrategy = _strategiesByRate[rate];

      if (cachedStrategy == address(0)) {
        cachedStrategy = address(new GhoInterestRateStrategy(POOL_ADDRESSES_PROVIDER, rate));
        _strategiesByRate[rate] = cachedStrategy;
        _strategies.push(cachedStrategy);

        emit RateStrategyCreated(cachedStrategy, rate);
      }

      strategies[i] = cachedStrategy;
    }

    return strategies;
  }

  ///@inheritdoc IFixedRateStrategyFactory
  function getAllStrategies() external view returns (address[] memory) {
    return _strategies;
  }

  ///@inheritdoc IFixedRateStrategyFactory
  function getStrategyByRate(uint256 borrowRate) external view returns (address) {
    return _strategiesByRate[borrowRate];
  }

  /// @inheritdoc IFixedRateStrategyFactory
  function FIXED_RATE_STRATEGY_FACTORY_REVISION() public pure virtual override returns (uint256) {
    return 1;
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return FIXED_RATE_STRATEGY_FACTORY_REVISION();
  }
}
