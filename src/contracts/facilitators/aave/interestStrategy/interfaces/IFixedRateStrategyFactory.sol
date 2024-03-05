// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolAddressesProvider} from 'aave-address-book/AaveV3.sol';
import {IDefaultInterestRateStrategy} from 'aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategy.sol';

interface IFixedRateStrategyFactory {
  /**
   * @dev Emitted when a new strategy is created
   * @param strategy The new strategy address
   * @param rate The new strategy rate (expressed in ray) (e.g. 0.0150e27 results in 1.50%)
   */
  event RateStrategyCreated(address indexed strategy, uint256 indexed rate);

  /**
   * @notice Create new fixed rate strategies from a list of rates.
   * @dev If a strategy with exactly the same rate already exists, no creation happens but
   *  its address is returned
   * @param fixedRateList list of rates for multiple strategies (expressed in ray) (e.g. 0.0150e27 results in 1.50%)
   * @return The list of strategies
   */
  function createStrategies(uint256[] memory fixedRateList) external returns (address[] memory);

  /**
   * @notice Returns the address of the Pool Addresses Provider of the Aave V3 Ethereum Facilitator
   * @return The address of the PoolAddressesProvider of Aave V3 Ethereum Facilitator
   */
  function POOL_ADDRESSES_PROVIDER() external view returns (address);

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

  /**
   * @notice Returns the FixedRateStrategyFactory revision number
   * @return The revision number
   */
  function FIXED_RATE_STRATEGY_FACTORY_REVISION() external pure returns (uint256);
}
