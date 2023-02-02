import hre from 'hardhat';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { evmRevert, evmSnapshot, setBlocktime } from '../helpers/misc-utils';
import { ONE_YEAR, PERCENTAGE_FACTOR, ZERO_ADDRESS } from '../helpers/constants';
import { ghoReserveConfig } from '../helpers/config';
import { calcCompoundedInterest, calcDiscountRate } from './helpers/math/calculations';
import { getTxCostAndTimestamp } from './helpers/helpers';
import './helpers/math/wadraymath';

makeSuite('Gho StkAave Transfer', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

  let oneYearLater;

  let rcpt, tx;

  let discountRate, ghoDiscountedPerDiscountToken, minDiscountTokenBalance;

  before(async () => {
    ethers = hre.ethers;

    collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    borrowAmount = ethers.utils.parseUnits('1000.0', 18);

    const { users, discountRateStrategy } = testEnv;

    // Fetch discount rate strategy parameters
    [discountRate, ghoDiscountedPerDiscountToken, minDiscountTokenBalance] = await Promise.all([
      discountRateStrategy.DISCOUNT_RATE(),
      discountRateStrategy.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN(),
      discountRateStrategy.MIN_DISCOUNT_TOKEN_BALANCE(),
    ]);
  });

  it('Transfer stkAAVE to borrower of GHO', async function () {
    const snapId = await evmSnapshot();

    // setup
    const { users, pool, weth, gho, variableDebtToken } = testEnv;

    const { aaveToken, stakedAave, stkAaveWhale } = testEnv;
    const stkAaveAmount = ethers.utils.parseUnits('10.0', 18);
    await aaveToken.connect(users[2].signer).approve(stakedAave.address, stkAaveAmount);
    await stakedAave.connect(users[2].signer).stake(users[2].address, stkAaveAmount);

    await stakedAave.connect(users[2].signer).transfer(users[1].address, stkAaveAmount);

    await weth.connect(users[2].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[2].signer)
      .deposit(weth.address, collateralAmount, users[2].address, 0);
    await pool.connect(users[2].signer).borrow(gho.address, borrowAmount, 2, 0, users[2].address);

    const debtBalanceBefore = await variableDebtToken.balanceOf(users[2].address);

    await expect(stakedAave.connect(users[1].signer).transfer(users[2].address, stkAaveAmount)).to
      .not.be.reverted;

    const debtBalanceAfter = await variableDebtToken.balanceOf(users[2].address);
    expect(debtBalanceAfter).to.be.gte(debtBalanceBefore);

    await evmRevert(snapId);
  });

  it('Transfer from user with stkAave and GHO to user without GHO', async function () {
    // setup
    const { users, pool, weth, gho, variableDebtToken } = testEnv;

    const { aaveToken, stakedAave, stkAaveWhale } = testEnv;
    const stkAaveAmount = ethers.utils.parseUnits('10.0', 18);
    await aaveToken.connect(users[2].signer).approve(stakedAave.address, stkAaveAmount);
    await stakedAave.connect(users[2].signer).stake(users[2].address, stkAaveAmount);

    // await stakedAave.connect(stkAaveWhale.signer).transfer(users[2].address, stkAaveAmount);

    await weth.connect(users[2].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[2].signer)
      .deposit(weth.address, collateralAmount, users[2].address, 0);
    await pool.connect(users[2].signer).borrow(gho.address, borrowAmount, 2, 0, users[2].address);

    const { lastUpdateTimestamp, variableBorrowIndex } = await pool.getReserveData(gho.address);

    const user1ScaledBefore = await variableDebtToken.scaledBalanceOf(users[2].address);

    // Updating the timestamp for the borrow to be one year later
    oneYearLater = BigNumber.from(lastUpdateTimestamp).add(BigNumber.from(ONE_YEAR));
    await setBlocktime(oneYearLater.toNumber());

    const user1DiscountPercentBefore = await variableDebtToken.getDiscountPercent(users[2].address);

    expect(await variableDebtToken.getBalanceFromInterest(users[2].address)).to.be.eq(0);
    expect(await variableDebtToken.getBalanceFromInterest(users[1].address)).to.be.eq(0);

    // calculate expected results
    tx = await stakedAave.connect(users[2].signer).transfer(users[1].address, stkAaveAmount);
    rcpt = await tx.wait();
    const { txTimestamp } = await getTxCostAndTimestamp(rcpt);
    const multiplier = calcCompoundedInterest(
      ghoReserveConfig.INTEREST_RATE,
      txTimestamp,
      BigNumber.from(lastUpdateTimestamp)
    );
    const expIndex = variableBorrowIndex.rayMul(multiplier);

    const user1ExpectedBalanceNoDiscount = user1ScaledBefore.rayMul(expIndex);
    const user1BalanceIncrease = user1ExpectedBalanceNoDiscount.sub(borrowAmount);
    const user1ExpectedDiscount = user1BalanceIncrease
      .mul(user1DiscountPercentBefore)
      .div(PERCENTAGE_FACTOR);
    const user1ExpectedBalance = user1ExpectedBalanceNoDiscount.sub(user1ExpectedDiscount);
    const user1BalanceIncreaseWithDiscount = user1BalanceIncrease.sub(user1ExpectedDiscount);

    const user1DiscountTokenBalance = await stakedAave.balanceOf(users[2].address);
    const user1ExpectedDiscountPercent = calcDiscountRate(
      discountRate,
      ghoDiscountedPerDiscountToken,
      minDiscountTokenBalance,
      user1ExpectedBalance,
      user1DiscountTokenBalance
    );

    const user1Debt = await variableDebtToken.balanceOf(users[2].address);
    expect(user1Debt).to.be.closeTo(user1ExpectedBalance, 1);

    expect(await variableDebtToken.getBalanceFromInterest(users[2].address)).to.be.closeTo(
      user1BalanceIncreaseWithDiscount,
      1
    );
    expect(await variableDebtToken.getBalanceFromInterest(users[1].address)).to.be.eq(0);
  });
});
