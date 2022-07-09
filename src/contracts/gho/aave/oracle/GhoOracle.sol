// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import {IChainlinkAggregator} from '../../dependencies/aave-core/interfaces/IChainlinkAggregator.sol';

/**
 * @title GhoOracle
 * @notice Price feed for GHO (ETH denominated) (fixed to 1 USD)
 * @dev Converts the price of the feed GHO-ETH, Chainlink format with 18 decimals
 * @author Aave
 **/
contract GhoOracle {
  IChainlinkAggregator public constant ETH_USD_ORACLE =
    IChainlinkAggregator(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

  uint256 public constant ETH_USD_ORACLE_DECIMALS = 8;

  uint256 public constant GHO_ETH_ORACLE_DECIMALS = 18;

  /// @dev Precalculated numerator of the division needed for calculating the GHO price
  uint256 public constant NUMERATOR = 10**(ETH_USD_ORACLE_DECIMALS + GHO_ETH_ORACLE_DECIMALS);

  /**
   * @notice Returns the price of a unit of GHO (ETH denominated)
   * @dev GHO price is fixed to 1 USD
   * @dev A 1 unit of GHO is the multiplicative inverse of (ETH_USD_PRICE / ETH_USD_DECIMALS) times the decimals
   * of this oracle.
   *    price(GHO) = ( 1 / ( ETH_USD_PRICE / (10 ** ETH_USD_DECIMALS) ) ) * (10 ** GHO_ETH_DECIMALS)
   *    price(GHO) = 10 ** (ETH_USD_DECIMALS + GHO_ETH_DECIMALS) / ETH_USD_PRICE
   * @return The price of a unit of GHO (with 18 decimals)
   */
  function latestAnswer() external view returns (int256) {
    int256 ethPrice = ETH_USD_ORACLE.latestAnswer();
    if (ethPrice > 0) {
      return int256(NUMERATOR / uint256(ethPrice));
    } else {
      return 0;
    }
  }
}
