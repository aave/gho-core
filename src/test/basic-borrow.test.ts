import hre from 'hardhat';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { timeLatest, setBlocktime, mine } from '../helpers/misc-utils';
import { ONE_YEAR, MAX_UINT, ZERO_ADDRESS, oneRay } from '../helpers/constants';
import { ghoReserveConfig } from '../helpers/config';
import { calcCompoundedInterest } from './helpers/math/calculations';
import { getTxCostAndTimestamp } from './helpers/helpers';

makeSuite('Gho Basic Borrow Flow', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

  let startTime;
  let oneYearLater;

  let rcpt, tx;

  before(() => {
    ethers = hre.ethers;

    collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    borrowAmount = ethers.utils.parseUnits('1000.0', 18);
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
      .withArgs(users[0].address, users[0].address, borrowAmount, 0, oneRay)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    expect(await gho.balanceOf(users[0].address)).to.be.equal(borrowAmount);
    expect(await variableDebtToken.totalSupply()).to.be.equal(borrowAmount);
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
    expect(await variableDebtToken.totalSupply()).to.be.equal(user1ExpectedBalance);
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(0);
  });

  it('User 2: After 1 year Deposit WETH and Borrow GHO', async function () {
    const { users, pool, weth, gho, variableDebtToken } = testEnv;

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

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, users[1].address, borrowAmount)
      .to.emit(variableDebtToken, 'Mint')
      .withArgs(users[1].address, users[1].address, borrowAmount, 0, expIndex)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    expect(await gho.balanceOf(users[1].address)).to.be.equal(borrowAmount);

    expect(await variableDebtToken.getBalanceFromInterest(users[1].address)).to.be.equal(0);
    expect(await variableDebtToken.balanceOf(users[1].address)).to.be.equal(borrowAmount);
  });

  it('User 1: Increase time by 1 more year and borrow more GHO', async function () {
    const { users, gho, variableDebtToken, pool } = testEnv;

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
    const user2ExpectedBalance = user2ScaledBefore.rayMul(expIndex);
    const amount = user1ExpectedBalance.sub(borrowAmount);
    const user1ExpectedBalanceIncrease = amount.sub(borrowAmount);

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, users[0].address, amount)
      .to.emit(variableDebtToken, 'Mint')
      .withArgs(users[0].address, users[0].address, amount, user1ExpectedBalanceIncrease, expIndex)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    const user1Debt = await variableDebtToken.balanceOf(users[0].address);
    const user2Debt = await variableDebtToken.balanceOf(users[1].address);

    expect(await gho.balanceOf(users[0].address)).to.be.equal(borrowAmount.add(borrowAmount));
    expect(await gho.balanceOf(users[1].address)).to.be.equal(borrowAmount);
    expect(user1Debt).to.be.eq(user1ExpectedBalance);
    expect(user2Debt).to.be.eq(user2ExpectedBalance);

    const interestsSinceLastAction = user1Debt.sub(borrowAmount).sub(borrowAmount);
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(
      interestsSinceLastAction
    );
  });

  it('User 2: Receive GHO from User 1 and Repay Debt', async function () {
    const { users, gho, variableDebtToken, aToken, pool } = testEnv;

    await gho.connect(users[0].signer).transfer(users[1].address, borrowAmount);
    await gho.connect(users[1].signer).approve(pool.address, MAX_UINT);

    const { lastUpdateTimestamp, variableBorrowIndex } = await pool.getReserveData(gho.address);

    const user1ScaledBefore = await variableDebtToken.scaledBalanceOf(users[0].address);
    const user2ScaledBefore = await variableDebtToken.scaledBalanceOf(users[1].address);

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
    const user2ExpectedBalance = user2ScaledBefore.rayMul(expIndex);
    const user2ExpectedInterest = user2ExpectedBalance.sub(borrowAmount);

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(users[1].address, ZERO_ADDRESS, borrowAmount)
      .to.emit(variableDebtToken, 'Burn')
      .withArgs(users[1].address, ZERO_ADDRESS, borrowAmount, user2ExpectedInterest, expIndex)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    const user1Debt = await variableDebtToken.balanceOf(users[0].address);
    const user2Debt = await variableDebtToken.balanceOf(users[1].address);

    expect(await gho.balanceOf(users[0].address)).to.be.equal(borrowAmount);
    expect(await gho.balanceOf(users[1].address)).to.be.equal(
      borrowAmount.mul(2).sub(user2ExpectedBalance)
    );

    expect(user1Debt).to.be.eq(user1ExpectedBalance);
    expect(user2Debt).to.be.eq(0);

    expect(await gho.balanceOf(aToken.address)).to.be.equal(user2ExpectedInterest);
    expect(await variableDebtToken.getBalanceFromInterest(users[1].address)).to.be.equal(0);
  });

  it('User 3: Deposit some ETH and borrow GHO', async function () {
    const { users, pool, weth, gho, variableDebtToken, treasuryAddress } = testEnv;

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

    expect(await gho.balanceOf(users[2].address)).to.be.equal(borrowAmount.mul(3));
    expect(await variableDebtToken.getBalanceFromInterest(users[2].address)).to.be.equal(0);
    expect(await variableDebtToken.balanceOf(users[2].address)).to.be.equal(borrowAmount.mul(3));
  });

  it('User 1: Repay 100 wei of GHO Debt', async function () {
    const { users, gho, variableDebtToken, aToken, pool, treasuryAddress } = testEnv;

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

    expect(await variableDebtToken.balanceOf(users[0].address)).to.be.eq(
      user1ExpectedBalance.sub(repayAmount)
    );
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(
      user1AccruedInterestBefore.add(user1ExpectedBalanceIncrease).sub(repayAmount)
    );

    expect(await gho.balanceOf(aToken.address)).to.be.eq(expectedATokenGhoBalance);
  });

  it('User 1: Receive some GHO from User 3 and Repay Debt', async function () {
    const { users, gho, variableDebtToken, aToken, pool, treasuryAddress } = testEnv;

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

    expect(await variableDebtToken.balanceOf(users[0].address)).to.be.eq(0);
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(0);

    expect(await gho.balanceOf(aToken.address)).to.be.eq(expectedATokenGhoBalance);
  });

  it('Distribute fees to treasury', async function () {
    const { aToken, gho, treasuryAddress } = testEnv;

    const aTokenBalance = await gho.balanceOf(aToken.address);

    expect(aTokenBalance).to.not.be.equal(0);
    expect(await gho.balanceOf(treasuryAddress)).to.be.equal(0);

    const tx = await aToken.distributeFeesToTreasury();

    expect(tx)
      .to.emit(aToken, 'FeesDistributedToTreasury')
      .withArgs(treasuryAddress, gho.address, aTokenBalance);

    expect(await gho.balanceOf(aToken.address)).to.be.equal(0);
    expect(await gho.balanceOf(treasuryAddress)).to.be.equal(aTokenBalance);
  });
});
