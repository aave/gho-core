// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {GhoInterestRateStrategy} from '../facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {IFixedRateStrategyFactory} from './interfaces/IFixedRateStrategyFactory.sol';
/**
 * @title FixedRateStrategyFactory
 * @author Aave Labs
 * @notice Factory contract to create and keep record of Aave v3 rate strategy contracts
 * @dev Associated to an specific Aave v3 Pool, via its addresses provider
 */
contract FixedRateStrategyFactory is IFixedRateStrategyFactory {
  ///@inheritdoc IFixedRateStrategyFactory
  address public immutable POOL_ADDRESSES_PROVIDER;

  mapping(uint256 => address) internal _strategiesByRate;
  address[] internal _strategies;

  constructor(address addressesProvider) {
    POOL_ADDRESSES_PROVIDER = addressesProvider;
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
}
