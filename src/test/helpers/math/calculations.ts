import { ethers, BigNumber } from 'ethers';
import './wadraymath';
import { ONE_YEAR, RAY, MAX_UINT_AMOUNT } from '../../../helpers/constants';
import { ReserveData, UserReserveData } from '../utils/interfaces';
import { asdReserveConfig } from '../../../helpers/config';

export const calcCompoundedInterestV2 = (
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

  const ratePerSecond = rate.div(SECONDS_PER_YEAR);

  const basePowerTwo = ratePerSecond.rayMul(ratePerSecond);
  const basePowerThree = basePowerTwo.rayMul(ratePerSecond);

  const secondTerm = timeDifference.mul(expMinusOne).mul(basePowerTwo).div(2);
  const thirdTerm = timeDifference.mul(expMinusOne).mul(expMinusTwo).mul(basePowerThree).div(6);

  return BigNumber.from(RAY).add(ratePerSecond.mul(timeDifference)).add(secondTerm).add(thirdTerm);
};

export const calcExpectedReserveDataAfterBorrow = (
  amountBorrowed: BigNumber,
  reserveDataBefore: ReserveData,
  txTimestamp: BigNumber,
  currentTimestamp: BigNumber
): ReserveData => {
  const expectedReserveData = <ReserveData>{};
  expectedReserveData.address = reserveDataBefore.address;
  expectedReserveData.lastUpdateTimestamp = txTimestamp;

  expectedReserveData.liquidityIndex = calcExpectedLiquidityIndex(reserveDataBefore, txTimestamp);
  expectedReserveData.availableLiquidity = reserveDataBefore.availableLiquidity.sub(amountBorrowed);
  expectedReserveData.liquidityRate = ethers.utils.parseUnits('1.0', 25);

  expectedReserveData.principalStableDebt = reserveDataBefore.principalStableDebt;
  expectedReserveData.totalStableDebt = BigNumber.from(0);
  expectedReserveData.averageStableBorrowRate = reserveDataBefore.averageStableBorrowRate;
  expectedReserveData.stableBorrowRate = ethers.utils.parseUnits('1.0', 25);

  expectedReserveData.variableBorrowIndex = calcExpectedVariableBorrowIndex(
    reserveDataBefore,
    txTimestamp
  );
  expectedReserveData.scaledVariableDebt = reserveDataBefore.scaledVariableDebt.add(
    amountBorrowed.rayDiv(expectedReserveData.variableBorrowIndex)
  );
  expectedReserveData.variableBorrowRate = asdReserveConfig.INTEREST_RATE;
  expectedReserveData.totalVariableDebt = expectedReserveData.scaledVariableDebt.rayMul(
    calcExpectedReserveNormalizedDebt(
      expectedReserveData.variableBorrowRate,
      expectedReserveData.variableBorrowIndex,
      txTimestamp,
      currentTimestamp
    )
  );

  expectedReserveData.totalLiquidity = expectedReserveData.availableLiquidity
    .add(expectedReserveData.totalStableDebt)
    .add(expectedReserveData.totalVariableDebt);

  expectedReserveData.utilizationRate = calcExpectedUtilizationRate(
    expectedReserveData.totalStableDebt,
    expectedReserveData.totalVariableDebt,
    expectedReserveData.totalLiquidity
  );

  return expectedReserveData;
};

export const calcExpectedUserDataAfterBorrow = (
  amountBorrowed: BigNumber,
  reserveDataBeforeAction: ReserveData,
  expectedDataAfterAction: ReserveData,
  userDataBeforeAction: UserReserveData,
  currentTimestamp: BigNumber
): UserReserveData => {
  const expectedUserData = <UserReserveData>{};

  expectedUserData.scaledVariableDebt = userDataBeforeAction.scaledVariableDebt.add(
    amountBorrowed.rayDiv(expectedDataAfterAction.variableBorrowIndex)
  );

  expectedUserData.principalStableDebt = userDataBeforeAction.principalStableDebt;
  expectedUserData.stableBorrowRate = userDataBeforeAction.stableBorrowRate;
  expectedUserData.stableRateLastUpdated = userDataBeforeAction.stableRateLastUpdated;
  expectedUserData.currentStableDebt = calcExpectedStableDebtTokenBalance(
    userDataBeforeAction.principalStableDebt,
    userDataBeforeAction.stableBorrowRate,
    userDataBeforeAction.stableRateLastUpdated,
    currentTimestamp
  );

  expectedUserData.currentVariableDebt = calcExpectedVariableDebtTokenBalance(
    expectedDataAfterAction,
    expectedUserData,
    currentTimestamp
  );

  expectedUserData.liquidityRate = expectedDataAfterAction.liquidityRate;
  expectedUserData.usageAsCollateralEnabled = userDataBeforeAction.usageAsCollateralEnabled;
  expectedUserData.currentATokenBalance = calcExpectedATokenBalance(
    expectedDataAfterAction,
    userDataBeforeAction,
    currentTimestamp
  );
  expectedUserData.scaledATokenBalance = userDataBeforeAction.scaledATokenBalance;
  expectedUserData.walletBalance = userDataBeforeAction.walletBalance.add(amountBorrowed);

  return expectedUserData;
};

export const calcExpectedReserveDataAfterRepay = (
  amountRepaid: BigNumber,
  reserveDataBeforeAction: ReserveData,
  userDataBeforeAction: UserReserveData,
  txTimestamp: BigNumber
): ReserveData => {
  const expectedReserveData: ReserveData = <ReserveData>{};

  expectedReserveData.address = reserveDataBeforeAction.address;

  const userVariableDebt = calcExpectedVariableDebtTokenBalance(
    reserveDataBeforeAction,
    userDataBeforeAction,
    txTimestamp
  );

  //if amount repaid == MAX_UINT_AMOUNT, user is repaying everything
  if (amountRepaid.eq(MAX_UINT_AMOUNT)) {
    amountRepaid = userVariableDebt;
  }

  expectedReserveData.liquidityIndex = calcExpectedLiquidityIndex(
    reserveDataBeforeAction,
    txTimestamp
  );
  expectedReserveData.variableBorrowIndex = calcExpectedVariableBorrowIndex(
    reserveDataBeforeAction,
    txTimestamp
  );
  expectedReserveData.scaledVariableDebt = reserveDataBeforeAction.scaledVariableDebt.sub(
    amountRepaid.rayDiv(expectedReserveData.variableBorrowIndex)
  );
  expectedReserveData.totalVariableDebt = expectedReserveData.scaledVariableDebt.rayMul(
    expectedReserveData.variableBorrowIndex
  );

  expectedReserveData.principalStableDebt = reserveDataBeforeAction.principalStableDebt;
  expectedReserveData.totalStableDebt = reserveDataBeforeAction.totalStableDebt;
  expectedReserveData.averageStableBorrowRate = reserveDataBeforeAction.averageStableBorrowRate;

  expectedReserveData.availableLiquidity =
    reserveDataBeforeAction.availableLiquidity.add(amountRepaid);

  expectedReserveData.totalLiquidity = expectedReserveData.availableLiquidity
    .add(expectedReserveData.totalStableDebt)
    .add(expectedReserveData.totalVariableDebt);

  expectedReserveData.utilizationRate = calcExpectedUtilizationRate(
    expectedReserveData.totalStableDebt,
    expectedReserveData.totalVariableDebt,
    expectedReserveData.totalLiquidity
  );

  expectedReserveData.liquidityRate = ethers.utils.parseUnits('1.0', 25);

  expectedReserveData.stableBorrowRate = ethers.utils.parseUnits('1.0', 25);

  expectedReserveData.variableBorrowRate = asdReserveConfig.INTEREST_RATE;

  expectedReserveData.lastUpdateTimestamp = txTimestamp;

  return expectedReserveData;
};

export const calcExpectedUserDataAfterRepay = (
  totalRepaid: BigNumber,
  reserveDataBeforeAction: ReserveData,
  expectedDataAfterAction: ReserveData,
  userDataBeforeAction: UserReserveData,
  user: string,
  onBehalfOf: string,
  txTimestamp: BigNumber,
  currentTimestamp: BigNumber
): [BigNumber, UserReserveData] => {
  const expectedUserData = <UserReserveData>{};

  const variableDebt = calcExpectedVariableDebtTokenBalance(
    reserveDataBeforeAction,
    userDataBeforeAction,
    currentTimestamp
  );

  const stableDebt = calcExpectedStableDebtTokenBalance(
    userDataBeforeAction.principalStableDebt,
    userDataBeforeAction.stableBorrowRate,
    userDataBeforeAction.stableRateLastUpdated,
    currentTimestamp
  );

  if (totalRepaid.eq(MAX_UINT_AMOUNT)) {
    totalRepaid = variableDebt;
  }

  expectedUserData.currentStableDebt = userDataBeforeAction.principalStableDebt;
  expectedUserData.principalStableDebt = stableDebt;
  expectedUserData.stableBorrowRate = userDataBeforeAction.stableBorrowRate;
  expectedUserData.stableRateLastUpdated = userDataBeforeAction.stableRateLastUpdated;

  expectedUserData.scaledVariableDebt = userDataBeforeAction.scaledVariableDebt.sub(
    totalRepaid.rayDiv(expectedDataAfterAction.variableBorrowIndex)
  );
  expectedUserData.currentVariableDebt = expectedUserData.scaledVariableDebt.rayMul(
    expectedDataAfterAction.variableBorrowIndex
  );

  expectedUserData.liquidityRate = expectedDataAfterAction.liquidityRate;
  expectedUserData.usageAsCollateralEnabled = userDataBeforeAction.usageAsCollateralEnabled;
  expectedUserData.currentATokenBalance = calcExpectedATokenBalance(
    reserveDataBeforeAction,
    userDataBeforeAction,
    txTimestamp
  );
  expectedUserData.scaledATokenBalance = userDataBeforeAction.scaledATokenBalance;

  if (user === onBehalfOf) {
    expectedUserData.walletBalance = userDataBeforeAction.walletBalance.sub(totalRepaid);
  } else {
    //wallet balance didn't change
    expectedUserData.walletBalance = userDataBeforeAction.walletBalance;
  }

  return [totalRepaid, expectedUserData];
};

const calcExpectedLiquidityIndex = (reserveData: ReserveData, timestamp: BigNumber) => {
  //if utilization rate is 0, nothing to compound
  if (reserveData.utilizationRate.eq('0')) {
    return reserveData.liquidityIndex;
  }

  const cumulatedInterest = calcLinearInterest(
    reserveData.liquidityRate,
    timestamp,
    reserveData.lastUpdateTimestamp
  );

  return cumulatedInterest.rayMul(reserveData.liquidityIndex);
};

const calcExpectedVariableBorrowIndex = (reserveData: ReserveData, timestamp: BigNumber) => {
  //if totalVariableDebt is 0, nothing to compound
  if (reserveData.totalVariableDebt.eq('0')) {
    return reserveData.variableBorrowIndex;
  }

  const cumulatedInterest = calcCompoundedInterestV2(
    reserveData.variableBorrowRate,
    timestamp,
    reserveData.lastUpdateTimestamp
  );

  return cumulatedInterest.rayMul(reserveData.variableBorrowIndex);
};

const calcExpectedReserveNormalizedDebt = (
  variableBorrowRate: BigNumber,
  variableBorrowIndex: BigNumber,
  lastUpdateTimestamp: BigNumber,
  currentTimestamp: BigNumber
) => {
  //if utilization rate is 0, nothing to compound
  if (variableBorrowRate.eq('0')) {
    return variableBorrowIndex;
  }

  const cumulatedInterest = calcCompoundedInterestV2(
    variableBorrowRate,
    currentTimestamp,
    lastUpdateTimestamp
  );

  const debt = cumulatedInterest.rayMul(variableBorrowIndex);

  return debt;
};

export const calcExpectedUtilizationRate = (
  totalStableDebt: BigNumber,
  totalVariableDebt: BigNumber,
  totalLiquidity: BigNumber
): BigNumber => {
  if (totalStableDebt.eq(BigNumber.from(0)) && totalVariableDebt.eq(BigNumber.from(0))) {
    return BigNumber.from(0);
  }

  const utilization = totalStableDebt.add(totalVariableDebt).rayDiv(totalLiquidity);

  return utilization;
};

const calcLinearInterest = (
  rate: BigNumber,
  currentTimestamp: BigNumber,
  lastUpdateTimestamp: BigNumber
) => {
  const timeDifference = currentTimestamp.sub(lastUpdateTimestamp);

  const cumulatedInterest = rate.mul(timeDifference).div(ONE_YEAR).add(RAY);

  return cumulatedInterest;
};

// Calculate Reserve Token Balances
export const calcExpectedVariableDebtTokenBalance = (
  reserveData: ReserveData,
  userData: UserReserveData,
  currentTimestamp: BigNumber
) => {
  const normalizedDebt = calcExpectedReserveNormalizedDebt(
    reserveData.variableBorrowRate,
    reserveData.variableBorrowIndex,
    reserveData.lastUpdateTimestamp,
    currentTimestamp
  );

  const { scaledVariableDebt } = userData;

  return scaledVariableDebt.rayMul(normalizedDebt);
};

export const calcExpectedStableDebtTokenBalance = (
  principalStableDebt: BigNumber,
  stableBorrowRate: BigNumber,
  stableRateLastUpdated: BigNumber,
  currentTimestamp: BigNumber
) => {
  if (
    stableBorrowRate.eq(0) ||
    currentTimestamp.eq(stableRateLastUpdated) ||
    stableRateLastUpdated.eq(0)
  ) {
    return principalStableDebt;
  }

  const cumulatedInterest = calcCompoundedInterestV2(
    stableBorrowRate,
    currentTimestamp,
    stableRateLastUpdated
  );

  return principalStableDebt.rayMul(cumulatedInterest);
};

export const calcExpectedATokenBalance = (
  reserveData: ReserveData,
  userData: UserReserveData,
  currentTimestamp: BigNumber
) => {
  const index = calcExpectedReserveNormalizedIncome(reserveData, currentTimestamp);

  const { scaledATokenBalance: scaledBalanceBeforeAction } = userData;

  return scaledBalanceBeforeAction.rayMul(index);
};

const calcExpectedReserveNormalizedIncome = (
  reserveData: ReserveData,
  currentTimestamp: BigNumber
) => {
  const { liquidityRate, liquidityIndex, lastUpdateTimestamp } = reserveData;

  //if utilization rate is 0, nothing to compound
  if (liquidityRate.eq('0')) {
    return liquidityIndex;
  }

  const cumulatedInterest = calcLinearInterest(
    liquidityRate,
    currentTimestamp,
    lastUpdateTimestamp
  );

  const income = cumulatedInterest.rayMul(liquidityIndex);

  return income;
};
