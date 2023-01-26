// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title GhoOracle
 * @notice Price feed for GHO (USD denominated)
 * @dev Price fixed at 1 USD, Chainlink format with 8 decimals
 * @author Aave
 */
contract GhoOracle {
  int256 public constant GHO_PRICE = 1e8;

  /**
   * @notice Returns the price of a unit of GHO (USD denominated)
   * @dev GHO price is fixed at 1 USD
   * @return The price of a unit of GHO (with 8 decimals)
   */
  function latestAnswer() external pure returns (int256) {
    return GHO_PRICE;
  }

  /**
   * @notice Returns the number of decimals the price is formatted with
   * @return The number of decimals
   */
  function decimals() external pure returns (uint8) {
    return 8;
  }
}
