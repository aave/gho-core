// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFixedFeeStrategyFactory {
  /**
   * @dev Emitted when a new strategy is created
   * @param strategy The address of the new Gsm fee strategy
   * @param buyFee The buy fee of the new strategy
   * @param sellFee The sell fee of the new strategy
   */
  event FeeStrategyCreated(
    address indexed strategy,
    uint256 indexed buyFee,
    uint256 indexed sellFee
  );

  /**
   * @notice Creates new Gsm Fee strategy contracts from lists of buy and sell fees
   * @dev Returns the address of a cached contract if a strategy with same fees already exists
   * @param buyFeeList The list of buy fees for Gsm fee strategies
   * @param sellFeeList The list of sell fees for Gsm fee strategies
   * @return The list of Gsm fee strategy contracts
   */
  function createStrategies(
    uint256[] memory buyFeeList,
    uint256[] memory sellFeeList
  ) external returns (address[] memory);

  /**
   * @notice Returns all the fee strategy contracts of the factory
   * @return The list of fee strategy contracts
   */
  function getGsmFeeStrategies() external view returns (address[] memory);

  /**
   * @notice Returns the fee strategy contract which corresponds to the given fees.
   * @dev Returns `address(0)` if there is no fee strategy for the given fees
   * @param buyFee The buy fee of the fee strategy contract
   * @param sellFee The sell fee of the fee strategy contract
   * @return The address of the fee strategy contract
   */
  function getStrategyByFees(uint256 buyFee, uint256 sellFee) external view returns (address);

  /**
   * @notice Returns the GsmFeeStrategyFactory revision number
   * @return The revision number
   */
  function REVISION() external pure returns (uint256);
}
