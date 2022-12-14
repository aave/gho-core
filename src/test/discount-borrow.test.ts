import { expect } from 'chai';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { DRE, timeLatest, setBlocktime, mine } from '../helpers/misc-utils';
import { ONE_YEAR, MAX_UINT, ZERO_ADDRESS, oneRay, PERCENTAGE_FACTOR } from '../helpers/constants';
import { ghoReserveConfig, aaveMarketAddresses } from '../helpers/config';
import { calcCompoundedInterest, calcDiscountRate } from './helpers/math/calculations';
import { getTxCostAndTimestamp } from './helpers/helpers';
import { gho } from '../../types/src/contracts';

makeSuite('Gho Discount Borrow Flow', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

  let startTime;
  let oneYearLater;

  let rcpt, tx;

  let discountRate, ghoDiscountedPerDiscountToken, minDiscountTokenBalance;

  before(async () => {
    ethers = DRE.ethers;

    collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    borrowAmount = ethers.utils.parseUnits('1000.0', 18);

    const { users, stakedAave, stkAaveWhale, discountRateStrategy } = testEnv;

    // Fetch discount rate strategy parameters
    [discountRate, ghoDiscountedPerDiscountToken, minDiscountTokenBalance] = await Promise.all([
      discountRateStrategy.DISCOUNT_RATE(),
      discountRateStrategy.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN(),
      discountRateStrategy.MIN_DISCOUNT_TOKEN_BALANCE(),
    ]);

    // Transfers 10 stkAave (discountToken) to User 2
    const stkAaveAmount = ethers.utils.parseUnits('10.0', 18);
    await stakedAave.connect(stkAaveWhale.signer).transfer(users[1].address, stkAaveAmount);
  });

  it('User 1: Deposit WETH and Borrow GHO', async function () {
    const { users, pool, weth, gho, variableDebtToken } = testEnv;

    await weth.connect(users[0].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[0].signer)
      .deposit(weth.address, collateralAmount, users[0].address, 0);
    tx = await pool
      .connect(users[0].signer)
      .borrow(gho.address, borrowAmount, 2, 0, users[0].address);

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, users[0].address, borrowAmount)
      .to.emit(variableDebtToken, 'Mint')
      .withArgs(users[0].address, users[0].address, borrowAmount, 0, oneRay);

    expect(await variableDebtToken.getDiscountPercent(users[0].address)).to.be.eq(0);

    expect(await gho.balanceOf(users[0].address)).to.be.equal(borrowAmount);
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(0);
    expect(await variableDebtToken.balanceOf(users[0].address)).to.be.equal(borrowAmount);
  });

  it('User 1: Increase time by 1 year and check interest accrued', async function () {
    const { users, gho, variableDebtToken, pool } = testEnv;
    const poolData = await pool.getReserveData(gho.address);

    startTime = BigNumber.from(poolData.lastUpdateTimestamp);
    const variableBorrowIndex = poolData.variableBorrowIndex;

    oneYearLater = startTime.add(BigNumber.from(ONE_YEAR));
    await setBlocktime(oneYearLater.toNumber());
    await mine(); // Mine block to increment time in underlying chain as well

    const multiplier = calcCompoundedInterest(
      ghoReserveConfig.INTEREST_RATE,
      await timeLatest(),
      startTime
    );

    const expIndex = variableBorrowIndex.rayMul(multiplier);
    const user1ExpectedBalance = (await variableDebtToken.scaledBalanceOf(users[0].address)).rayMul(
      expIndex
    );
    const user1Year1Debt = await variableDebtToken.balanceOf(users[0].address);

    expect(await gho.balanceOf(users[0].address)).to.be.equal(borrowAmount);
    expect(user1Year1Debt).to.be.eq(user1ExpectedBalance);
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(0);
  });

  it('User 2: After 1 year Deposit WETH and Borrow GHO', async function () {
    const { users, pool, weth, gho, variableDebtToken, stakedAave } = testEnv;

    const { lastUpdateTimestamp: ghoLastUpdateTimestamp, variableBorrowIndex } =
      await pool.getReserveData(gho.address);

    await weth.connect(users[1].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[1].signer)
      .deposit(weth.address, collateralAmount, users[1].address, 0);
    tx = await pool
      .connect(users[1].signer)
      .borrow(gho.address, borrowAmount, 2, 0, users[1].address);
    rcpt = await tx.wait();
    const { txTimestamp } = await getTxCostAndTimestamp(rcpt);

    const multiplier = calcCompoundedInterest(
      ghoReserveConfig.INTEREST_RATE,
      txTimestamp,
      BigNumber.from(ghoLastUpdateTimestamp)
    );
    const expIndex = variableBorrowIndex.rayMul(multiplier);

    const discountTokenBalance = await stakedAave.balanceOf(users[1].address);
    const discountPercent = calcDiscountRate(
      discountRate,
      ghoDiscountedPerDiscountToken,
      minDiscountTokenBalance,
      borrowAmount,
      discountTokenBalance
    );

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, users[1].address, borrowAmount)
      .to.emit(variableDebtToken, 'Mint')
      .withArgs(users[1].address, users[1].address, borrowAmount, 0, expIndex)
      .to.emit(variableDebtToken, 'DiscountPercentLocked')
      .withArgs(
        users[1].address,
        discountPercent,
        txTimestamp.add(ghoReserveConfig.DISCOUNT_LOCK_PERIOD)
      );

    expect(await variableDebtToken.getDiscountPercent(users[1].address)).to.be.eq(discountPercent);

    expect(await gho.balanceOf(users[1].address)).to.be.equal(borrowAmount);
    expect(await variableDebtToken.getBalanceFromInterest(users[1].address)).to.be.equal(0);
    expect(await variableDebtToken.balanceOf(users[1].address)).to.be.equal(borrowAmount);
  });

  it('User 1: Increase time by 1 more year and borrow more GHO', async function () {
    const { users, gho, variableDebtToken, pool, stakedAave } = testEnv;

    const user1BeforeDebt = await variableDebtToken.scaledBalanceOf(users[0].address);

    const { lastUpdateTimestamp, variableBorrowIndex } = await pool.getReserveData(gho.address);

    const user1ScaledBefore = await variableDebtToken.scaledBalanceOf(users[0].address);
    const user2ScaledBefore = await variableDebtToken.scaledBalanceOf(users[1].address);

    // Updating the timestamp for the borrow to be one year later
    oneYearLater = BigNumber.from(lastUpdateTimestamp).add(BigNumber.from(ONE_YEAR));
    await setBlocktime(oneYearLater.toNumber());

    tx = await pool
      .connect(users[0].signer)
      .borrow(gho.address, borrowAmount, 2, 0, users[0].address);
    rcpt = await tx.wait();
    const { txTimestamp } = await getTxCostAndTimestamp(rcpt);
    const multiplier = calcCompoundedInterest(
      ghoReserveConfig.INTEREST_RATE,
      txTimestamp,
      BigNumber.from(lastUpdateTimestamp)
    );
    const expIndex = variableBorrowIndex.rayMul(multiplier);

    const borrowedAmountScaled = borrowAmount.rayDiv(expIndex);
    const user1ExpectedBalance = user1ScaledBefore.add(borrowedAmountScaled).rayMul(expIndex);
    const amount = user1ExpectedBalance.sub(borrowAmount);
    const user1BalanceIncrease = amount.sub(borrowAmount);

    const user2ExpectedBalanceNoDiscount = user2ScaledBefore.rayMul(expIndex);
    const user2BalanceIncrease = user2ExpectedBalanceNoDiscount.sub(borrowAmount);
    const user2DiscountTokenBalance = await stakedAave.balanceOf(users[1].address);
    const user2DiscountPercent = calcDiscountRate(
      discountRate,
      ghoDiscountedPerDiscountToken,
      minDiscountTokenBalance,
      borrowAmount,
      user2DiscountTokenBalance
    );
    const user2ExpectedDiscount = user2BalanceIncrease
      .mul(user2DiscountPercent)
      .div(PERCENTAGE_FACTOR);
    const user2ExpectedBalance = user2ExpectedBalanceNoDiscount.sub(user2ExpectedDiscount);

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, users[0].address, amount)
      .to.emit(variableDebtToken, 'Mint')
      .withArgs(users[0].address, users[0].address, amount, user1BalanceIncrease, expIndex)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    const user1Debt = await variableDebtToken.balanceOf(users[0].address);
    const user2Debt = await variableDebtToken.balanceOf(users[1].address);

    expect(await variableDebtToken.getDiscountPercent(users[0].address)).to.be.eq(0);
    expect(await variableDebtToken.getDiscountPercent(users[1].address)).to.be.eq(
      user2DiscountPercent
    );

    expect(await gho.balanceOf(users[0].address)).to.be.equal(borrowAmount.add(borrowAmount));
    expect(await gho.balanceOf(users[1].address)).to.be.equal(borrowAmount);
    expect(user1Debt).to.be.eq(user1ExpectedBalance);
    expect(user2Debt).to.be.closeTo(user2ExpectedBalance, 1);

    const balanceIncrease = user1Debt.sub(borrowAmount).sub(user1BeforeDebt);
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(
      balanceIncrease
    );
  });

  it('User 2: Receive GHO from User 1 and Repay Debt', async function () {
    const { users, gho, variableDebtToken, aToken, pool, stakedAave } = testEnv;

    await gho.connect(users[0].signer).transfer(users[1].address, borrowAmount);
    await gho.connect(users[1].signer).approve(pool.address, MAX_UINT);

    const { lastUpdateTimestamp, variableBorrowIndex } = await pool.getReserveData(gho.address);

    const user1ScaledBefore = await variableDebtToken.scaledBalanceOf(users[0].address);
    const user2ScaledBefore = await variableDebtToken.scaledBalanceOf(users[1].address);
    const user2DiscountPercentBefore = await variableDebtToken.getDiscountPercent(users[1].address);

    expect(await variableDebtToken.getBalanceFromInterest(users[1].address)).to.be.equal(0);

    tx = await pool.connect(users[1].signer).repay(gho.address, MAX_UINT, 2, users[1].address);
    rcpt = await tx.wait();
    const { txTimestamp } = await getTxCostAndTimestamp(rcpt);

    const multiplier = calcCompoundedInterest(
      ghoReserveConfig.INTEREST_RATE,
      txTimestamp,
      BigNumber.from(lastUpdateTimestamp)
    );
    const expIndex = variableBorrowIndex.rayMul(multiplier);
    const user1ExpectedBalance = user1ScaledBefore.rayMul(expIndex);

    const user2ExpectedBalanceNoDiscount = user2ScaledBefore.rayMul(expIndex);
    const user2BalanceIncrease = user2ExpectedBalanceNoDiscount.sub(borrowAmount);
    const user2DiscountTokenBalance = await stakedAave.balanceOf(users[1].address);
    const user2ExpectedDiscount = user2BalanceIncrease
      .mul(user2DiscountPercentBefore)
      .div(PERCENTAGE_FACTOR);
    const user2ExpectedBalance = user2ExpectedBalanceNoDiscount.sub(user2ExpectedDiscount);
    const user2ExpectedInterest = user2BalanceIncrease.sub(user2ExpectedDiscount);
    expect(await variableDebtToken.getBalanceFromInterest(users[1].address)).to.be.equal(0);

    const user2DiscountPercent = calcDiscountRate(
      discountRate,
      ghoDiscountedPerDiscountToken,
      minDiscountTokenBalance,
      BigNumber.from(0),
      user2DiscountTokenBalance
    );

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(users[1].address, ZERO_ADDRESS, borrowAmount)
      .to.emit(variableDebtToken, 'Burn')
      .withArgs(users[1].address, ZERO_ADDRESS, borrowAmount, user2ExpectedInterest, expIndex)
      .to.emit(variableDebtToken, 'DiscountPercentLocked')
      .withArgs(users[1].address, user2DiscountPercent, 0);

    const user1Debt = await variableDebtToken.balanceOf(users[0].address);
    const user2Debt = await variableDebtToken.balanceOf(users[1].address);

    expect(await variableDebtToken.getDiscountPercent(users[1].address)).to.be.eq(
      user2DiscountPercent
    );

    expect(await gho.balanceOf(users[0].address)).to.be.equal(borrowAmount);
    expect(await gho.balanceOf(users[1].address)).to.be.equal(
      borrowAmount.mul(2).sub(user2ExpectedBalance)
    );

    expect(user1Debt).to.be.eq(user1ExpectedBalance);

    // TODO: update to zero
    expect(user2Debt).to.be.eq(1);

    expect(await gho.balanceOf(aToken.address)).to.be.eq(user2ExpectedInterest);
    expect(await variableDebtToken.getBalanceFromInterest(users[1].address)).to.be.equal(0);
  });

  it('User 3: Deposit some ETH and borrow GHO', async function () {
    const { users, pool, weth, gho, variableDebtToken } = testEnv;

    const { lastUpdateTimestamp: ghoLastUpdateTimestamp, variableBorrowIndex } =
      await pool.getReserveData(gho.address);

    await weth.connect(users[2].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[2].signer)
      .deposit(weth.address, collateralAmount, users[2].address, 0);
    tx = await pool
      .connect(users[2].signer)
      .borrow(gho.address, borrowAmount.mul(3), 2, 0, users[2].address);
    rcpt = await tx.wait();
    const { txTimestamp } = await getTxCostAndTimestamp(rcpt);

    const multiplier = calcCompoundedInterest(
      ghoReserveConfig.INTEREST_RATE,
      txTimestamp,
      BigNumber.from(ghoLastUpdateTimestamp)
    );
    const expIndex = variableBorrowIndex.rayMul(multiplier);

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, users[2].address, borrowAmount.mul(3))
      .to.emit(variableDebtToken, 'Mint')
      .withArgs(users[2].address, users[2].address, borrowAmount.mul(3), 0, expIndex)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    expect(await variableDebtToken.getDiscountPercent(users[2].address)).to.be.eq(0);

    expect(await gho.balanceOf(users[2].address)).to.be.equal(borrowAmount.mul(3));
    expect(await variableDebtToken.getBalanceFromInterest(users[2].address)).to.be.equal(0);
    expect(await variableDebtToken.balanceOf(users[2].address)).to.be.equal(borrowAmount.mul(3));
  });

  it('User 1: Repay 100 wei of GHO Debt', async function () {
    const { users, gho, variableDebtToken, aToken, pool } = testEnv;

    const repayAmount = BigNumber.from('100'); // 100 wei

    await gho.connect(users[0].signer).approve(pool.address, MAX_UINT);

    const { lastUpdateTimestamp, variableBorrowIndex } = await pool.getReserveData(gho.address);

    const user1ScaledBefore = await variableDebtToken.scaledBalanceOf(users[0].address);
    const aTokenGhoBalanceBefore = await gho.balanceOf(aToken.address);
    const user1AccruedInterestBefore = await variableDebtToken.getBalanceFromInterest(
      users[0].address
    );

    tx = await pool.connect(users[0].signer).repay(gho.address, repayAmount, 2, users[0].address);
    rcpt = await tx.wait();
    const { txTimestamp } = await getTxCostAndTimestamp(rcpt);

    const multiplier = calcCompoundedInterest(
      ghoReserveConfig.INTEREST_RATE,
      txTimestamp,
      BigNumber.from(lastUpdateTimestamp)
    );
    const expIndex = variableBorrowIndex.rayMul(multiplier);

    const user1ExpectedBalance = user1ScaledBefore.rayMul(expIndex);
    const user1ExpectedInterest = user1ExpectedBalance.sub(borrowAmount.mul(2));
    const user1ExpectedBalanceIncrease = user1ExpectedInterest.sub(user1AccruedInterestBefore);
    const expectedATokenGhoBalance = aTokenGhoBalanceBefore.add(repayAmount);

    const amount = user1ExpectedBalanceIncrease.sub(repayAmount);
    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, users[0].address, amount)
      .to.emit(variableDebtToken, 'Mint')
      .withArgs(users[0].address, users[0].address, amount, user1ExpectedBalanceIncrease, expIndex)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    expect(await variableDebtToken.getDiscountPercent(users[0].address)).to.be.eq(0);

    expect(await variableDebtToken.balanceOf(users[0].address)).to.be.eq(
      user1ExpectedBalance.sub(repayAmount)
    );
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(
      user1AccruedInterestBefore.add(user1ExpectedBalanceIncrease).sub(repayAmount)
    );

    expect(await gho.balanceOf(aToken.address)).to.be.eq(expectedATokenGhoBalance);
  });

  it('User 1: Receive some GHO from User 3 and Repay Debt', async function () {
    const { users, gho, variableDebtToken, aToken, pool } = testEnv;

    await gho.connect(users[2].signer).transfer(users[0].address, borrowAmount.mul(3));

    await gho.connect(users[0].signer).approve(pool.address, MAX_UINT);

    const { lastUpdateTimestamp, variableBorrowIndex } = await pool.getReserveData(gho.address);

    const user1ScaledBefore = await variableDebtToken.scaledBalanceOf(users[0].address);
    const aTokenGhoBalanceBefore = await gho.balanceOf(aToken.address);
    const user1AccruedInterestBefore = await variableDebtToken.getBalanceFromInterest(
      users[0].address
    );

    tx = await pool.connect(users[0].signer).repay(gho.address, MAX_UINT, 2, users[0].address);
    rcpt = await tx.wait();
    const { txTimestamp } = await getTxCostAndTimestamp(rcpt);

    const multiplier = calcCompoundedInterest(
      ghoReserveConfig.INTEREST_RATE,
      txTimestamp,
      BigNumber.from(lastUpdateTimestamp)
    );
    const expIndex = variableBorrowIndex.rayMul(multiplier);

    const user1ExpectedBalance = user1ScaledBefore.rayMul(expIndex);
    const user1ExpectedInterest = user1ExpectedBalance.sub(borrowAmount.mul(2));
    const user1ExpectedBalanceIncrease = user1ExpectedInterest.sub(user1AccruedInterestBefore);
    const expectedATokenGhoBalance = aTokenGhoBalanceBefore.add(user1ExpectedInterest);

    const amount = user1ExpectedBalance.sub(user1ExpectedBalanceIncrease);
    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(users[0].address, ZERO_ADDRESS, amount)
      .to.emit(variableDebtToken, 'Burn')
      .withArgs(users[0].address, ZERO_ADDRESS, amount, user1ExpectedBalanceIncrease, expIndex)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    expect(await variableDebtToken.getDiscountPercent(users[0].address)).to.be.eq(0);

    expect(await variableDebtToken.balanceOf(users[0].address)).to.be.eq(0);
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(0);

    expect(await gho.balanceOf(aToken.address)).to.be.eq(expectedATokenGhoBalance);
  });

  it('Distribute fees to treasury', async function () {
    const { aToken, gho } = testEnv;

    const aTokenBalance = await gho.balanceOf(aToken.address);

    expect(aTokenBalance).to.not.be.equal(0);
    expect(await gho.balanceOf(aaveMarketAddresses.treasury)).to.be.equal(0);

    const tx = await aToken.distributeFeesToTreasury();

    expect(tx)
      .to.emit(aToken, 'FeesDistributedToTreasury')
      .withArgs(aaveMarketAddresses.treasury, gho.address, aTokenBalance);

    expect(await gho.balanceOf(aToken.address)).to.be.equal(0);
    expect(await gho.balanceOf(aaveMarketAddresses.treasury)).to.be.equal(aTokenBalance);
  });
});
