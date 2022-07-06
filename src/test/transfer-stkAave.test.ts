import { expect } from 'chai';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { DRE, setBlocktime } from '../helpers/misc-utils';
import { ONE_YEAR, PERCENTAGE_FACTOR, ZERO_ADDRESS } from '../helpers/constants';
import { asdReserveConfig } from '../helpers/config';
import { calcCompoundedInterestV2, calcDiscountRate } from './helpers/math/calculations';
import { getTxCostAndTimestamp } from './helpers/helpers';

makeSuite('Antei StkAave Transfer', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

  let oneYearLater;

  let rcpt, tx;

  let discountRate, asdDiscountedPerDiscountToken, minDiscountTokenBalance;

  before(async () => {
    ethers = DRE.ethers;

    collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    borrowAmount = ethers.utils.parseUnits('1000.0', 18);

    const { users, discountRateStrategy } = testEnv;
    users[0].signer = users[0].signer;
    users[0].address = users[0].address;
    users[1].signer = users[1].signer;
    users[1].address = users[1].address;

    // Fetch discount rate strategy parameters
    [discountRate, asdDiscountedPerDiscountToken, minDiscountTokenBalance] = await Promise.all([
      discountRateStrategy.DISCOUNT_RATE(),
      discountRateStrategy.ASD_DISCOUNTED_PER_DISCOUNT_TOKEN(),
      discountRateStrategy.MIN_DISCOUNT_TOKEN_BALANCE(),
    ]);
  });

  it('Transfer from user with stkAave and asd to user without asd', async function () {
    // setup
    const { users, pool, weth, asd, variableDebtToken } = testEnv;

    const { stakedAave, stkAaveWhale } = testEnv;
    const stkAaveAmount = ethers.utils.parseUnits('10.0', 18);
    await stakedAave.connect(stkAaveWhale.signer).transfer(users[0].address, stkAaveAmount);

    await weth.connect(users[0].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[0].signer)
      .deposit(weth.address, collateralAmount, users[0].address, 0);
    await pool.connect(users[0].signer).borrow(asd.address, borrowAmount, 2, 0, users[0].address);

    const { lastUpdateTimestamp, variableBorrowIndex } = await pool.getReserveData(asd.address);

    const user1ScaledBefore = await variableDebtToken.scaledBalanceOf(users[0].address);

    // Updating the timestamp for the borrow to be one year later
    oneYearLater = BigNumber.from(lastUpdateTimestamp).add(BigNumber.from(ONE_YEAR));
    await setBlocktime(oneYearLater.toNumber());

    const user1DiscountPercentBefore = await variableDebtToken.getDiscountPercent(users[0].address);

    // calculate expected results
    tx = await stakedAave.connect(users[0].signer).transfer(users[1].address, stkAaveAmount);
    rcpt = await tx.wait();
    const { txTimestamp } = await getTxCostAndTimestamp(rcpt);
    const multiplier = calcCompoundedInterestV2(
      asdReserveConfig.INTEREST_RATE,
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

    const user1DiscountTokenBalance = await stakedAave.balanceOf(users[0].address);
    const user1ExpectedDiscountPercent = calcDiscountRate(
      discountRate,
      asdDiscountedPerDiscountToken,
      minDiscountTokenBalance,
      user1ExpectedBalance,
      user1DiscountTokenBalance
    );

    await expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(users[0].address, ZERO_ADDRESS, user1BalanceIncreaseWithDiscount)
      .to.emit(variableDebtToken, 'Burn')
      .withArgs(
        users[0].address,
        ZERO_ADDRESS,
        user1BalanceIncreaseWithDiscount,
        user1BalanceIncreaseWithDiscount,
        expIndex
      )
      .to.emit(variableDebtToken, 'DiscountAppliedToDebt')
      .withArgs(users[0].address, user1ExpectedDiscount)
      .to.emit(variableDebtToken, 'DiscountPercentUpdated')
      .withArgs(users[0].address, user1DiscountPercentBefore, user1ExpectedDiscountPercent);

    const user1Debt = await variableDebtToken.balanceOf(users[0].address);
    expect(user1Debt).to.be.closeTo(user1ExpectedBalance, 1);
  });
});