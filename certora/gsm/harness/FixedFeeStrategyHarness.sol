pragma solidity ^0.8.0;

import {FixedFeeStrategy} from '../../../src/contracts/facilitators/gsm/feeStrategy/FixedFeeStrategy.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';

contract FixedFeeStrategyHarness is FixedFeeStrategy {
  constructor(uint256 buyFee, uint256 sellFee) FixedFeeStrategy(buyFee, sellFee) {}

  function getBuyFeeBP() external view returns (uint256) {
    return _buyFee;
  }

  function getSellFeeBP() external view returns (uint256) {
    return _sellFee;
  }

  function getPercMathPercentageFactor() external view returns (uint256) {
    return PercentageMath.PERCENTAGE_FACTOR;
  }
}
