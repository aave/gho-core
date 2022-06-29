// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {SafeMath} from '../../dependencies/aave-core/dependencies/openzeppelin/contracts/SafeMath.sol';
import {IChainlinkAggregator} from '../../dependencies/aave-core/interfaces/IChainlinkAggregator.sol';

/**
 * @title AnteiOracle
 * @notice Price feed for ASD (ETH denominated) (fixed to 1 USD)
 * @dev Converts the price of the feed ASD-ETH, Chainlink format with 18 decimals
 * @author Aave
 **/
contract AnteiOracle {
  using SafeMath for uint256;

  IChainlinkAggregator public constant ETH_USD_ORACLE =
    IChainlinkAggregator(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

  uint256 public constant ETH_USD_ORACLE_DECIMALS = 8;

  uint256 public constant ASD_ETH_ORACLE_DECIMALS = 18;

  /// @dev Precalculated numerator of the division needed for calculating the ASD price
  uint256 public constant NUMERATOR = 10**(ETH_USD_ORACLE_DECIMALS + ASD_ETH_ORACLE_DECIMALS);

  /**
   * @notice Returns the price of a unit of ASD (ETH denominated)
   * @dev ASD price is fixed to 1 USD
   * @dev A 1 unit of ASD is the multiplicative inverse of (ETH_USD_PRICE / ETH_USD_DECIMALS) times the decimals
   * of this oracle.
   *    price(ASD) = ( 1 / ( ETH_USD_PRICE / (10 ** ETH_USD_DECIMALS) ) ) * (10 ** ASD_ETH_DECIMALS)
   *    price(ASD) = 10 ** (ETH_USD_DECIMALS + ASD_ETH_DECIMALS) / ETH_USD_PRICE
   * @return The price of a unit of ASD (with 18 decimals)
   */
  function latestAnswer() external view returns (int256) {
    int256 ethPrice = ETH_USD_ORACLE.latestAnswer();
    if (ethPrice > 0) {
      return int256(NUMERATOR.div(uint256(ethPrice)));
    } else {
      return 0;
    }
  }
}
