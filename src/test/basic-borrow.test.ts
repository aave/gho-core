import { expect } from 'chai';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { DRE, timeLatest, setBlocktime, mine } from '../helpers/misc-utils';
import { ONE_YEAR } from '../helpers/constants';
import { asdReserveConfig } from '../helpers/config';
import { calcCompoundedInterestV2 } from './helpers/math/calculations';

makeSuite('Antei VariableDebtToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

  let startTime;
  let oneYearLater;

  let user1Signer;
  let user1Address;
  let user2Signer;
  let user2Address;

  let user1Year1Debt;

  before(() => {
    ethers = DRE.ethers;

    collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    borrowAmount = ethers.utils.parseUnits('1000.0', 18);

    const { users } = testEnv;
    user1Signer = users[0].signer;
    user1Address = users[0].address;
    user2Signer = users[1].signer;
    user2Address = users[1].address;
  });

  it('User 1: Deposit WETH and Borrow ASD', async function () {
    const { pool, weth, asd, variableDebtToken } = testEnv;

    await weth.connect(user1Signer).approve(pool.address, collateralAmount);
    await pool.connect(user1Signer).deposit(weth.address, collateralAmount, user1Address, 0);
    await pool.connect(user1Signer).borrow(asd.address, borrowAmount, 2, 0, user1Address);

    expect(await asd.balanceOf(user1Address)).to.be.equal(borrowAmount);
    expect(await variableDebtToken.balanceOf(user1Address)).to.be.equal(borrowAmount);
  });

  it('User 1: Increase time by 1 year and check interest accrued', async function () {
    const { asd, variableDebtToken, pool } = testEnv;
    const poolData = await pool.getReserveData(asd.address);

    startTime = BigNumber.from(poolData.lastUpdateTimestamp);
    const variableBorrowIndex = poolData.variableBorrowIndex;

    oneYearLater = startTime.add(BigNumber.from(ONE_YEAR));
    await setBlocktime(oneYearLater.toNumber());
    await mine(); // Mine block to increment time in underlying chain as well

    const multiplier = calcCompoundedInterestV2(
      asdReserveConfig.INTEREST_RATE,
      oneYearLater,
      startTime
    );

    const expIndex = variableBorrowIndex.rayMul(multiplier);
    const user1ExpectedBalance = (await variableDebtToken.scaledBalanceOf(user1Address)).rayMul(
      expIndex
    );
    user1Year1Debt = await variableDebtToken.balanceOf(user1Address);

    expect(await asd.balanceOf(user1Address)).to.be.equal(borrowAmount);
    expect(user1Year1Debt).to.be.eq(user1ExpectedBalance);
  });

  it('User 2: After 1 year Deposit WETH and Borrow ASD', async function () {
    const { pool, weth, asd, variableDebtToken } = testEnv;
    startTime = await timeLatest();
    oneYearLater = startTime.add(BigNumber.from(ONE_YEAR));
    await setBlocktime(oneYearLater.toNumber());

    await weth.connect(user2Signer).approve(pool.address, collateralAmount);
    await pool.connect(user2Signer).deposit(weth.address, collateralAmount, user2Address, 0);
    await pool.connect(user2Signer).borrow(asd.address, borrowAmount, 2, 0, user2Address);

    expect(await asd.balanceOf(user2Address)).to.be.equal(borrowAmount);
    expect(await variableDebtToken.balanceOf(user2Address)).to.be.equal(borrowAmount);
  });

  it('User 1: Increase time by 1 more year and borrow more ASD', async function () {
    const { asd, variableDebtToken, pool } = testEnv;
    const poolData = await pool.getReserveData(asd.address);

    startTime = BigNumber.from(poolData.lastUpdateTimestamp);
    const variableBorrowIndex = poolData.variableBorrowIndex;

    oneYearLater = startTime.add(BigNumber.from(ONE_YEAR));
    const multiplier = calcCompoundedInterestV2(
      asdReserveConfig.INTEREST_RATE,
      oneYearLater,
      startTime
    );
    const expIndex = variableBorrowIndex.rayMul(multiplier);

    const user1Scaled = await variableDebtToken.scaledBalanceOf(user1Address);
    const user2Scaled = await variableDebtToken.scaledBalanceOf(user2Address);

    // Updating the timestamp for the borrow to be one year later
    await setBlocktime(oneYearLater.toNumber());

    await pool.connect(user1Signer).borrow(asd.address, borrowAmount, 2, 0, user1Address);

    const expectedIncrement = borrowAmount.rayDiv(expIndex);
    const user1ExpectedBalance = user1Scaled.add(expectedIncrement).rayMul(expIndex);
    const user2ExpectedBalance = user2Scaled.rayMul(expIndex);

    const user1Debt = await variableDebtToken.balanceOf(user1Address);
    const user2Debt = await variableDebtToken.balanceOf(user2Address);

    expect(await asd.balanceOf(user1Address)).to.be.equal(borrowAmount.add(borrowAmount));
    expect(await asd.balanceOf(user2Address)).to.be.equal(borrowAmount);
    expect(user1Debt).to.be.eq(user1ExpectedBalance);
    expect(user2Debt).to.be.eq(user2ExpectedBalance);
  });
});
