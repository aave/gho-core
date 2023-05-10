import {SafeCast} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/SafeCast.sol';
import {WadRayMath} from '@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';

library DebtUtils {
  using WadRayMath for uint256;
  using SafeCast for uint256;
  using PercentageMath for uint256;

  function computeDebt(
    uint256 userPreviousIndex,
    uint256 index,
    uint256 previousScaledBalance,
    uint256 accumulatedDebtInterest,
    uint256 discountPercent
  ) external pure returns (uint256, uint256, uint128) {
    uint256 balanceIncrease = previousScaledBalance.rayMul(index) -
      previousScaledBalance.rayMul(userPreviousIndex);

    uint256 discountScaled = 0;
    if (balanceIncrease != 0 && discountPercent != 0) {
      uint256 discount = balanceIncrease.percentMul(discountPercent);
      discountScaled = discount.rayDiv(index);
      balanceIncrease = balanceIncrease - discount;
    }

    uint128 accumulatedDebt = (balanceIncrease + accumulatedDebtInterest).toUint128();

    return (balanceIncrease, discountScaled, accumulatedDebt);
  }
}
