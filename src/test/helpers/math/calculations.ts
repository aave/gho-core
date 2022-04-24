import { BigNumber } from 'ethers';
import './wadraymath';
import { ONE_YEAR, RAY } from '../../../helpers/constants';

export const calcCompoundedInterest = (
  rate: BigNumber,
  currentTimestamp: BigNumber,
  lastUpdateTimestamp: BigNumber
) => {
  const timeDifference = currentTimestamp.sub(lastUpdateTimestamp);
  const SECONDS_PER_YEAR = BigNumber.from(ONE_YEAR);

  if (timeDifference.eq(0)) {
    return BigNumber.from(RAY);
  }

  const expMinusOne = timeDifference.sub(1);
  const expMinusTwo = timeDifference.gt(2) ? timeDifference.sub(2) : 0;

  const basePowerTwo = rate.rayMul(rate).div(SECONDS_PER_YEAR.mul(SECONDS_PER_YEAR));
  const basePowerThree = basePowerTwo.rayMul(rate).div(SECONDS_PER_YEAR);

  const secondTerm = timeDifference.mul(expMinusOne).mul(basePowerTwo).div(2);
  const thirdTerm = timeDifference.mul(expMinusOne).mul(expMinusTwo).mul(basePowerThree).div(6);

  return BigNumber.from(RAY)
    .add(rate.mul(timeDifference).div(SECONDS_PER_YEAR))
    .add(secondTerm)
    .add(thirdTerm);
};
