// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFixedRateStrategyFactory {
  /**
   * @dev Emitted when a new strategy is created
   * @param strategy The address of the new fixed rate strategy
   * @param rate The rate of the new strategy, expressed in ray (e.g. 0.0150e27 results in 1.50%)
   */
  event RateStrategyCreated(address indexed strategy, uint256 indexed rate);

  /**
   * @notice Creates new fixed rate strategy contracts from a list of rates.
   * @dev Returns the address of a cached contract if a strategy with same rate already exists
   * @param fixedRateList The list of rates for interest rates strategies, expressed in ray (e.g. 0.0150e27 results in 1.50%)
   * @return The list of fixed interest rate strategy contracts
   */
  function createStrategies(uint256[] memory fixedRateList) external returns (address[] memory);

  /**
   * @notice Returns the address of the Pool Addresses Provider of Aave
   * @return The address of the PoolAddressesProvider of Aave
   */
  function POOL_ADDRESSES_PROVIDER() external view returns (address);

  /**
   * @notice Returns all the fixed interest rate strategy contracts of the factory
   * @return The list of fixed interest rate strategy contracts
   */
  function getAllStrategies() external view returns (address[] memory);

  /**
   * @notice Returns the fixed interest rate strategy contract which corresponds to the given rate.
   * @dev Returns `address(0)` if there is no interest rate strategy for the given rate
   * @param rate The rate of the fixed interest rate strategy contract
   * @return The address of the fixed interest rate strategy contract
   */
  function getStrategyByRate(uint256 rate) external view returns (address);

  /**
   * @notice Returns the FixedRateStrategyFactory revision number
   * @return The revision number
   */
  function REVISION() external pure returns (uint256);
}
