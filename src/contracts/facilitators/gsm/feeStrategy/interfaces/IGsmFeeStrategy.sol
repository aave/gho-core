// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IGsmFeeStrategy
 * @author Aave
 * @notice Defines the behaviour of Fee Strategies
 * @dev Functions' logic must be invertible, being possible to calculate the fee amount based on the gross amount, and
 * the other way round.
 */
interface IGsmFeeStrategy {
  /**
   * @notice Returns the fee to be applied when buying an underlying asset in exchange for GHO
   * @param grossAmount The amount of GHO being sold for the underlying asset
   * @return The fee amount of GHO
   */
  function getBuyFee(uint256 grossAmount) external view returns (uint256);

  /**
   * @notice Returns the fee to be applied when buying GHO in exchange for an underlying asset
   * @param grossAmount The amount of underlying, converted to GHO, being sold
   * @return The fee amount of GHO
   */
  function getSellFee(uint256 grossAmount) external view returns (uint256);

  /**
   * @notice Returns the gross amount of GHO being bought based on the total bought amount
   * @param totalAmount The total amount of GHO being bought (gross amount, GHO bought plus fee)
   * @return The gross amount of GHO being bought (total amount minus fee)
   */
  function getGrossAmountFromTotalBought(uint256 totalAmount) external view returns (uint256);

  /**
   * @notice Returns the amount of GHO being sold based on the total sold amount
   * @param totalAmount The total amount of GHO being sold (gross amount, GHO sold minus fee)
   * @return The gross amount of GHO being sold (total amount plus fee)
   */
  function getGrossAmountFromTotalSold(uint256 totalAmount) external view returns (uint256);
}
