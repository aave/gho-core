// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolAddressesProvider} from 'aave-address-book/AaveV3.sol';
import {IDefaultInterestRateStrategy} from 'aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategy.sol';

interface IFixedRateStrategyFactory {
  event RateStrategyCreated(address indexed strategy, uint256 indexed rate);

  /**
   * @notice Create new fixed rate strategies from a list of rates.
   * @dev If a strategy with exactly the same rate already exists, no creation happens but
   *  its address is returned
   * @param fixedRateList list of parameters for multiple strategies
   * @return The list of strategies
   */
  function createStrategies(uint256[] memory fixedRateList) external returns (address[] memory);

  /**
   * @notice Returns all the strategies registered in the factory
   * @return The list of strategies
   */
  function getAllStrategies() external view returns (address[] memory);

  /**
   * @notice Returns the strategy given its rate.
   * @dev Only if the strategy is registered in the factory.
   * @param rate the rate of the strategy
   * @return The address of the strategy
   */
  function getStrategyByRate(uint256 rate) external view returns (address);

  function POOL_ADDRESSES_PROVIDER() external view returns (address);
}
