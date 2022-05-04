import { BigNumber } from 'ethers';
import './wadraymath';
import { TestEnv } from '../make-suite';
import { ONE_YEAR, RAY } from '../../../helpers/constants';
import { DataTypes } from '../../../../types/src/contracts/antei/poolUpgrade/LendingPool';
import { tEthereumAddress } from '../../../helpers/types';
import { forEachLeadingCommentRange } from 'typescript';

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

export const calcCompoundedInterestV2 = (
  rate: BigNumber,
  currentTimestamp: number,
  lastUpdateTimestamp: number
) => {
  const timeDifference = BigNumber.from(currentTimestamp).sub(BigNumber.from(lastUpdateTimestamp));
  const SECONDS_PER_YEAR = BigNumber.from(ONE_YEAR);

  if (timeDifference.eq(0)) {
    return BigNumber.from(RAY);
  }

  const expMinusOne = timeDifference.sub(1);
  const expMinusTwo = timeDifference.gt(2) ? timeDifference.sub(2) : 0;

  const ratePerSecond = rate.div(SECONDS_PER_YEAR);

  const basePowerTwo = ratePerSecond.rayMul(ratePerSecond);
  const basePowerThree = basePowerTwo.rayMul(ratePerSecond);

  const secondTerm = timeDifference.mul(expMinusOne).mul(basePowerTwo).div(2);
  const thirdTerm = timeDifference.mul(expMinusOne).mul(expMinusTwo).mul(basePowerThree).div(6);

  return BigNumber.from(RAY).add(ratePerSecond.mul(timeDifference)).add(secondTerm).add(thirdTerm);
};

export const getExpectedUserBalances = async (
  poolData: DataTypes.ReserveDataStructOutput,
  rate: BigNumber,
  nextTimestamp: number,
  users: tEthereumAddress[],
  testEnv: TestEnv
): Promise<BigNumber[]> => {
  const { variableDebtToken } = testEnv;

  const variableBorrowIndex = poolData.variableBorrowIndex;
  const startTime = poolData.lastUpdateTimestamp;

  const multiplier = calcCompoundedInterestV2(rate, nextTimestamp, startTime);
  const expIndex = variableBorrowIndex.rayMul(multiplier);

  const promises: Promise<BigNumber>[] = [];
  users.forEach((user) => {
    promises.push(variableDebtToken.scaledBalanceOf(user));
  });
  const scaledBalances = await Promise.all(promises);
  const balances = scaledBalances.map((scaledBalance) => scaledBalance.rayMul(expIndex));

  return balances;
};

export const getExpectedDiscounts = async (
  poolData: DataTypes.ReserveDataStructOutput,
  rate: BigNumber,
  discountRate: BigNumber,
  nextTimestamp: number,
  testEnv: TestEnv
): Promise<BigNumber> => {
  const { variableDebtToken } = testEnv;

  const variableBorrowIndex = poolData.variableBorrowIndex;
  const startTime = poolData.lastUpdateTimestamp;

  const multiplier = calcCompoundedInterestV2(rate, nextTimestamp, startTime);
  const expIndex = variableBorrowIndex.rayMul(multiplier);

  const scaledTotalSupply = await variableDebtToken.scaledTotalSupply();

  const balanceIncrease = scaledTotalSupply
    .rayMul(expIndex)
    .sub(scaledTotalSupply.rayMul(variableBorrowIndex));

  return balanceIncrease.percentMul(discountRate);
};
