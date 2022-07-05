import { expect } from 'chai';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { DRE, timeLatest, setBlocktime, mine } from '../helpers/misc-utils';
import { ONE_YEAR, MAX_UINT, WAD } from '../helpers/constants';
import { ghoReserveConfig, aaveMarketAddresses } from '../helpers/config';
import { calcCompoundedInterestV2 } from './helpers/math/calculations';

makeSuite('Gho StkAave Transfer', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

  let startTime;
  let oneYearLater;

  let user1Signer;
  let user1Address;
  let user2Signer;
  let user2Address;

  before(async () => {
    ethers = DRE.ethers;

    collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    borrowAmount = ethers.utils.parseUnits('1000.0', 18);

    const { users } = testEnv;
    user1Signer = users[0].signer;
    user1Address = users[0].address;
    user2Signer = users[1].signer;
    user2Address = users[1].address;
  });

  it('Transfer from user with stkAave and gho to user without gho', async function () {
    // setup
    const { pool, weth, gho, variableDebtToken } = testEnv;

    const { stakedAave, stkAaveWhale } = testEnv;
    const stkAaveAmount = ethers.utils.parseUnits('10.0', 18);
    await stakedAave.connect(stkAaveWhale.signer).transfer(user1Address, stkAaveAmount);

    await weth.connect(user1Signer).approve(pool.address, collateralAmount);
    await pool.connect(user1Signer).deposit(weth.address, collateralAmount, user1Address, 0);
    await pool.connect(user1Signer).borrow(gho.address, borrowAmount, 2, 0, user1Address);

    const poolData = await pool.getReserveData(gho.address);

    startTime = BigNumber.from(poolData.lastUpdateTimestamp);
    const variableBorrowIndex = poolData.variableBorrowIndex;

    oneYearLater = startTime.add(BigNumber.from(ONE_YEAR));
    await setBlocktime(oneYearLater.toNumber());
    await mine(); // Mine block to increment time in underlying chain as well

    // calculate expected results
    await expect(stakedAave.connect(user1Signer).transfer(user2Address, stkAaveAmount))
      .to.emit(variableDebtToken, 'Transfer')
      .to.emit(variableDebtToken, 'Burn');

    const multiplier = calcCompoundedInterestV2(
      ghoReserveConfig.INTEREST_RATE,
      oneYearLater.add(1),
      startTime
    );
    const expIndex = variableBorrowIndex.rayMul(multiplier);
    const user1Scaled = await variableDebtToken.scaledBalanceOf(user1Address);
    const user1ExpectedBalance = user1Scaled.rayMul(expIndex);
    const user1Debt = await variableDebtToken.balanceOf(user1Address);

    expect(user1Debt).to.be.eq(user1ExpectedBalance);
  });
});
