import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { tEthereumAddress } from '../../../helpers/types';
import { ReserveData, UserReserveData } from './interfaces';
import { TestEnv } from '../make-suite';
import '../math/wadraymath';

export const expectEqual = (
  actual: ReserveData | UserReserveData,
  expected: ReserveData | UserReserveData
) => {
  const keys = Object.keys(actual);

  keys.forEach((key) => {
    if (
      key === 'lastUpdateTimestamp' ||
      key === 'marketStableRate' ||
      key === 'symbol' ||
      key === 'aTokenAddress' ||
      key === 'decimals' ||
      key === 'totalStableDebtLastUpdated'
    ) {
      // skipping consistency check on accessory data
      return;
    }
    if (actual[key] === null || actual[key] === 'undefined') {
      console.log(`Error in Actual ${key} value`);
    }
    if (expected[key] === null || expected[key] === 'undefined') {
      console.log(`Error in Actual ${key} value`);
    }
    // console.log(`${key} (actual):      ${actual[key]}`);
    // console.log(`${key} (expected):    ${expected[key]}`);
    // console.log();
    expect(actual[key]).to.be.equal(expected[key]);
  });
};

export const getReserveData = async (
  reserve: tEthereumAddress,
  testEnv: TestEnv
): Promise<ReserveData> => {
  const [reserveData, tokenAddresses] = await Promise.all([
    testEnv.aaveDataProvider.getReserveData(reserve),
    testEnv.aaveDataProvider.getReserveTokensAddresses(reserve),
  ]);

  const rateOracle = testEnv.rateOracle;
  const token = testEnv.asd;

  const { 0: principalStableDebt } = await testEnv.stableDebtToken.getSupplyData();
  const totalStableDebtLastUpdated = await testEnv.stableDebtToken.getTotalSupplyLastUpdated();

  const scaledVariableDebt = await testEnv.variableDebtToken.scaledTotalSupply();

  const rate = await rateOracle.getMarketBorrowRate(reserve);
  const symbol = await token.symbol();
  const decimals = BigNumber.from(await token.decimals());

  const totalLiquidity = reserveData.availableLiquidity
    .add(reserveData.totalStableDebt)
    .add(reserveData.totalVariableDebt);

  const utilizationRate = totalLiquidity.eq(0)
    ? BigNumber.from(0)
    : reserveData.totalStableDebt.add(reserveData.totalVariableDebt).rayDiv(totalLiquidity);

  return {
    totalLiquidity,
    utilizationRate,
    availableLiquidity: reserveData.availableLiquidity,
    totalStableDebt: reserveData.totalStableDebt,
    totalVariableDebt: reserveData.totalVariableDebt,
    liquidityRate: reserveData.liquidityRate,
    variableBorrowRate: reserveData.variableBorrowRate,
    stableBorrowRate: reserveData.stableBorrowRate,
    averageStableBorrowRate: reserveData.averageStableBorrowRate,
    liquidityIndex: reserveData.liquidityIndex,
    variableBorrowIndex: reserveData.variableBorrowIndex,
    lastUpdateTimestamp: BigNumber.from(reserveData.lastUpdateTimestamp),
    totalStableDebtLastUpdated: BigNumber.from(totalStableDebtLastUpdated),
    principalStableDebt: principalStableDebt,
    scaledVariableDebt: scaledVariableDebt,
    address: reserve,
    aTokenAddress: tokenAddresses.aTokenAddress,
    symbol,
    decimals,
    marketStableRate: rate,
  };
};

export const getUserData = async (
  user: tEthereumAddress,
  testEnv: TestEnv
): Promise<UserReserveData> => {
  const userData = await testEnv.aaveDataProvider.getUserReserveData(testEnv.asd.address, user);

  const walletBalance = await testEnv.asd.balanceOf(user);

  return {
    scaledATokenBalance: await testEnv.aToken.scaledBalanceOf(user),
    currentATokenBalance: userData.currentATokenBalance,
    currentStableDebt: userData.currentStableDebt,
    currentVariableDebt: userData.currentVariableDebt,
    principalStableDebt: userData.principalStableDebt,
    scaledVariableDebt: userData.scaledVariableDebt,
    stableBorrowRate: userData.stableBorrowRate,
    liquidityRate: userData.liquidityRate,
    usageAsCollateralEnabled: userData.usageAsCollateralEnabled,
    stableRateLastUpdated: BigNumber.from(userData.stableRateLastUpdated),
    walletBalance,
  };
};
