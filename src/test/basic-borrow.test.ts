import { expect } from 'chai';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { DRE, timeLatest, setBlocktime, mine } from '../helpers/misc-utils';
import { ONE_YEAR, MAX_UINT_AMOUNT, MAX_UINT } from '../helpers/constants';
import { asdReserveConfig, aaveMarketAddresses } from '../helpers/config';
import {
  getExpectedUserBalances,
  getExpectedDiscounts,
  getNextIndex,
} from './helpers/math/calculations';

makeSuite('Antei Basic Borrow Flow', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

  let user1Signer;
  let user1Address;
  let user2Signer;
  let user2Address;

  let ASD_CONSTANT;
  let ONE;
  let integrateDiscount;

  let user1IntegrateDiscount;
  let user2IntegrateDiscount;

  before(() => {
    ethers = DRE.ethers;

    ASD_CONSTANT = ethers.utils.parseUnits('4.0', 17);
    ONE = ethers.utils.parseUnits('1.0', 18);
    integrateDiscount = ethers.utils.parseUnits('1.0', 30);

    collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    borrowAmount = ethers.utils.parseUnits('1000.0', 18);

    const { users } = testEnv;
    user1Signer = users[0].signer;
    user1Address = users[0].address;
    user2Signer = users[1].signer;
    user2Address = users[1].address;
  });

  it('User 1: Deposit WETH and Borrow ASD', async function () {
    const { pool, weth, asd, stkAave, variableDebtToken } = testEnv;

    await weth.connect(user1Signer).approve(pool.address, collateralAmount);
    await pool.connect(user1Signer).deposit(weth.address, collateralAmount, user1Address, 0);
    await pool.connect(user1Signer).borrow(asd.address, borrowAmount, 2, 0, user1Address);

    expect(await asd.balanceOf(user1Address)).to.be.equal(borrowAmount);
    expect(await variableDebtToken.balanceOf(user1Address)).to.be.equal(borrowAmount);
  });

  it('User 1: Increase time by 1 year and check interest accrued', async function () {
    const { asd, variableDebtToken, pool } = testEnv;

    const poolData = await pool.getReserveData(asd.address);
    const nextTimestamp = poolData.lastUpdateTimestamp + ONE_YEAR;

    const nextIndex = await getNextIndex(poolData, asdReserveConfig.INTEREST_RATE, nextTimestamp);

    const [balanceNoDiscount] = await getExpectedUserBalances(
      [user1Address],
      nextIndex,
      variableDebtToken
    );

    const workingBalance = ASD_CONSTANT.wadMul(borrowAmount);
    const workingSupply = workingBalance;

    const totalInterest = balanceNoDiscount.sub(borrowAmount);
    const totalDiscounts = totalInterest.percentMul(asdReserveConfig.discountRate);

    user1IntegrateDiscount = integrateDiscount;
    const nextIntegrateDiscount = integrateDiscount.add(totalDiscounts.mul(ONE).div(workingSupply));

    const discount = workingBalance.mul(nextIntegrateDiscount.sub(user1IntegrateDiscount)).div(ONE);
    const expectedBalance = balanceNoDiscount.sub(discount);

    await setBlocktime(nextTimestamp);
    await mine(); // Mine block to increment time in underlying chain as well

    const user1Year1Debt = await variableDebtToken.balanceOf(user1Address);

    expect(await asd.balanceOf(user1Address)).to.be.equal(borrowAmount);
    expect(user1Year1Debt).to.be.eq(expectedBalance);
  });

  it('User 2: After 1 year Deposit WETH and Borrow ASD', async function () {
    const { pool, weth, asd, variableDebtToken } = testEnv;

    const poolData = await pool.getReserveData(asd.address);

    const nextIndex = await getNextIndex(
      poolData,
      asdReserveConfig.INTEREST_RATE,
      (await timeLatest()) + 3
    );

    await weth.connect(user2Signer).approve(pool.address, collateralAmount);
    await pool.connect(user2Signer).deposit(weth.address, collateralAmount, user2Address, 0);
    await pool.connect(user2Signer).borrow(asd.address, borrowAmount, 2, 0, user2Address);

    const [balanceNoDiscount] = await getExpectedUserBalances(
      [user1Address],
      nextIndex,
      variableDebtToken
    );
    const workingBalance = ASD_CONSTANT.wadMul(borrowAmount);
    const workingSupply = workingBalance;

    const totalInterest = balanceNoDiscount.sub(borrowAmount);
    const totalDiscounts = totalInterest.percentMul(asdReserveConfig.discountRate);

    integrateDiscount = integrateDiscount.add(totalDiscounts.mul(ONE).div(workingSupply));
    user2IntegrateDiscount = integrateDiscount;

    const discount = workingBalance.mul(integrateDiscount.sub(user1IntegrateDiscount)).div(ONE);
    const expectedBalance = balanceNoDiscount.sub(discount);

    const user1Debt = await variableDebtToken.balanceOf(user1Address);

    expect(await asd.balanceOf(user1Address)).to.be.equal(borrowAmount);
    expect(user1Debt).to.be.eq(expectedBalance);

    expect(await asd.balanceOf(user2Address)).to.be.equal(borrowAmount);
    expect(await variableDebtToken.balanceOf(user2Address)).to.be.equal(borrowAmount);
  });

  it('User 1: Increase time by 1 more year and borrow more ASD', async function () {
    const { asd, variableDebtToken, pool } = testEnv;

    const poolData = await pool.getReserveData(asd.address);
    const nextTimestamp = poolData.lastUpdateTimestamp + ONE_YEAR;
    const nextIndex = await getNextIndex(poolData, asdReserveConfig.INTEREST_RATE, nextTimestamp);

    const [user1BalanceNoDiscount, user2BalanceNoDiscount] = await getExpectedUserBalances(
      [user1Address, user2Address],
      nextIndex,
      variableDebtToken
    );

    const totalDiscounts = await getExpectedDiscounts(
      poolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    const user1WorkingBalance = ASD_CONSTANT.wadMul(borrowAmount);
    const user2WorkingBalance = ASD_CONSTANT.wadMul(borrowAmount);
    const workingSupply = user1WorkingBalance.add(user2WorkingBalance);

    integrateDiscount = integrateDiscount.add(totalDiscounts.mul(ONE).div(workingSupply));

    const user1Discount = user1WorkingBalance
      .mul(integrateDiscount.sub(user1IntegrateDiscount))
      .div(ONE);

    const user2Discount = user2WorkingBalance
      .mul(integrateDiscount.sub(user2IntegrateDiscount))
      .div(ONE);

    const user1ExpectedBalancePreborrow = user1BalanceNoDiscount.sub(user1Discount);
    const user1ExpectedBalance = user1ExpectedBalancePreborrow.add(borrowAmount);
    user1IntegrateDiscount = integrateDiscount;

    const user2ExpectedBalance = user2BalanceNoDiscount.sub(user2Discount);

    // Updating the timestamp for the borrow to be one year later
    await setBlocktime(nextTimestamp);
    await pool.connect(user1Signer).borrow(asd.address, borrowAmount, 2, 0, user1Address);

    const user1Debt = await variableDebtToken.balanceOf(user1Address);
    expect(user1Debt).to.be.closeTo(user1ExpectedBalance, 1);

    const user2Debt = await variableDebtToken.balanceOf(user2Address);
    expect(user2Debt).to.be.closeTo(user2ExpectedBalance, 1);

    expect(await asd.balanceOf(user1Address)).to.be.equal(borrowAmount.add(borrowAmount));
    expect(await asd.balanceOf(user2Address)).to.be.equal(borrowAmount);
  });

  it('User 2: Receive ASD from User 1 and Repay Debt', async function () {
    const { asd, variableDebtToken, aToken, pool } = testEnv;

    const user1Debt = await variableDebtToken.balanceOf(user1Address);
    const user2Debt = await variableDebtToken.balanceOf(user2Address);

    await asd.connect(user1Signer).transfer(user2Address, borrowAmount);
    await asd.connect(user2Signer).approve(pool.address, MAX_UINT);

    const poolData = await pool.getReserveData(asd.address);
    const nextTimestamp = (await timeLatest()) + 1;
    const nextIndex = await getNextIndex(poolData, asdReserveConfig.INTEREST_RATE, nextTimestamp);

    const [user1BalanceNoDiscount, user2BalanceNoDiscount] = await getExpectedUserBalances(
      [user1Address, user2Address],
      nextIndex,
      variableDebtToken
    );

    const totalDiscounts = await getExpectedDiscounts(
      poolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    const user1WorkingBalance = ASD_CONSTANT.wadMul(user1Debt);
    const user2WorkingBalance = ASD_CONSTANT.wadMul(borrowAmount);
    const workingSupply = user1WorkingBalance.add(user2WorkingBalance);

    integrateDiscount = integrateDiscount.add(totalDiscounts.mul(ONE).div(workingSupply));

    const user1Discount = user1WorkingBalance
      .mul(integrateDiscount.sub(user1IntegrateDiscount))
      .div(ONE);

    const user2Discount = user2WorkingBalance
      .mul(integrateDiscount.sub(user2IntegrateDiscount))
      .div(ONE);

    const user1ExpectedBalance = user1BalanceNoDiscount.sub(user1Discount);
    const user2ExpectedBalance = user2BalanceNoDiscount.sub(user2Discount);

    const repayAmount = borrowAmount.div(2);
    const tx = await pool.connect(user2Signer).repay(asd.address, repayAmount, 2, user2Address);
    await tx.wait();

    expect(await asd.balanceOf(user1Address)).to.be.equal(borrowAmount);
    expect(await variableDebtToken.balanceOf(user1Address)).to.be.equal(user1ExpectedBalance);

    expect(await asd.balanceOf(user2Address)).to.be.eq(borrowAmount.mul(2).sub(repayAmount));
    expect(await variableDebtToken.balanceOf(user2Address)).to.be.closeTo(
      user2ExpectedBalance.sub(repayAmount),
      1
    );
    expect(await asd.balanceOf(aToken.address)).to.be.equal(0);
    expect(await asd.balanceOf(aaveMarketAddresses.treasury)).to.be.eq(
      user2ExpectedBalance.sub(borrowAmount)
    );
  });
});
