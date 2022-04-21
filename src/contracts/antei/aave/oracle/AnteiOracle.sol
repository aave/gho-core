// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {SafeMath} from '@aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from '@aave/protocol-v2/contracts/protocol/libraries/math/WadRayMath.sol';
import {IChainlinkAggregator} from '@aave/protocol-v2/contracts/interfaces/IChainlinkAggregator.sol';

/**
 * @title DefaultReserveInterestRateStrategy contract
 * @notice Implements the calculation of the interest rates depending on the reserve state
 * @dev The model of interest rate is based on 2 slopes, one before the `OPTIMAL_UTILIZATION_RATE`
 * point of utilization and another from that one to 100%
 * - An instance of this same contract, can't be used across different Aave markets, due to the caching
 *   of the LendingPoolAddressesProvider
 * @author Aave
 **/
contract AnteiOracle {
  using WadRayMath for uint256;
  using SafeMath for uint256;

  IChainlinkAggregator public constant ethUsdOracle = IChainlinkAggregator(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

  function latestAnswer() external view returns (int256) {
    int256 ethPrice = ethUsdOracle.latestAnswer();
    if (ethPrice > 0) { 
      // TODO: rounding check
      uint256 ethPriceMoreDecimals = uint256(ethPrice)*1e10;
      uint256 ethPerUsd = WadRayMath.wad().wadDiv(ethPriceMoreDecimals);

      // TODO: casting check
      return int(ethPerUsd);
    } else {
      return 0;
    }
  }
}