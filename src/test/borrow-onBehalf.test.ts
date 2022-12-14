import { expect } from 'chai';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { DRE, timeLatest, setBlocktime, mine } from '../helpers/misc-utils';
import { ONE_YEAR, MAX_UINT, ZERO_ADDRESS, oneRay } from '../helpers/constants';
import { ghoReserveConfig, aaveMarketAddresses } from '../helpers/config';
import { calcCompoundedInterest } from './helpers/math/calculations';
import { getTxCostAndTimestamp } from './helpers/helpers';

makeSuite('Gho OnBehalf Borrow Flow', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

  let startTime;
  let oneYearLater;

  let rcpt, tx;

  before(() => {
    ethers = DRE.ethers;

    collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    borrowAmount = ethers.utils.parseUnits('1000.0', 18);
  });

  it('User 1: Deposit WETH and delegate borrowing power to User 2', async function () {
    const { users, pool, weth, gho, variableDebtToken } = testEnv;

    await weth.connect(users[0].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[0].signer)
      .deposit(weth.address, collateralAmount, users[0].address, 0);

    const tx = await variableDebtToken
      .connect(users[0].signer)
      .approveDelegation(users[1].address, borrowAmount);

    expect(tx)
      .to.emit(variableDebtToken, 'BorrowAllowanceDelegated')
      .withArgs(users[0].address, users[1].address, gho.address, borrowAmount);
  });

  it('User 2: Borrow GHO on behalf of User 1', async function () {
    const { users, pool, gho, variableDebtToken } = testEnv;

    tx = await pool
      .connect(users[1].signer)
      .borrow(gho.address, borrowAmount, 2, 0, users[0].address);

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, users[0].address, borrowAmount)
      .to.emit(variableDebtToken, 'Mint')
      .withArgs(users[1].address, users[0].address, borrowAmount, 0, oneRay)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    expect(await gho.balanceOf(users[1].address)).to.be.equal(borrowAmount);
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

    expect(await gho.balanceOf(users[1].address)).to.be.equal(borrowAmount);
    expect(user1Year1Debt).to.be.eq(user1ExpectedBalance);
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(0);
  });

  it('User 3: After 1 year Deposit WETH and Borrow GHO', async function () {
    const { users, pool, weth, gho, variableDebtToken } = testEnv;

    const { lastUpdateTimestamp: ghoLastUpdateTimestamp, variableBorrowIndex } =
      await pool.getReserveData(gho.address);

    await weth.connect(users[2].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[2].signer)
      .deposit(weth.address, collateralAmount, users[2].address, 0);
    tx = await pool
      .connect(users[2].signer)
      .borrow(gho.address, borrowAmount, 2, 0, users[2].address);
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
      .withArgs(ZERO_ADDRESS, users[2].address, borrowAmount)
      .to.emit(variableDebtToken, 'Mint')
      .withArgs(users[2].address, users[2].address, borrowAmount, 0, expIndex)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    expect(await gho.balanceOf(users[2].address)).to.be.equal(borrowAmount);

    expect(await variableDebtToken.getBalanceFromInterest(users[2].address)).to.be.equal(0);
    expect(await variableDebtToken.balanceOf(users[2].address)).to.be.equal(borrowAmount);
  });

  it('User 2: Receive GHO from User 3 and Repay Debt', async function () {
    const { users, gho, variableDebtToken, aToken, pool } = testEnv;

    await gho.connect(users[2].signer).transfer(users[1].address, borrowAmount);
    await gho.connect(users[1].signer).approve(pool.address, MAX_UINT);

    const { lastUpdateTimestamp, variableBorrowIndex } = await pool.getReserveData(gho.address);

    const user1ScaledBefore = await variableDebtToken.scaledBalanceOf(users[0].address);
    const user3ScaledBefore = await variableDebtToken.scaledBalanceOf(users[2].address);

    const currentTimestamp = await (
      await DRE.ethers.provider.getBlock(await DRE.ethers.provider.getBlockNumber())
    ).timestamp;
    const timestamp = currentTimestamp + 1;

    const multiplier = calcCompoundedInterest(
      ghoReserveConfig.INTEREST_RATE,
      DRE.ethers.BigNumber.from(timestamp),
      BigNumber.from(lastUpdateTimestamp)
    );
    const expIndex = variableBorrowIndex.rayMul(multiplier);

    const user1ExpectedBalance = user1ScaledBefore.rayMul(expIndex);
    const user3ExpectedBalance = user3ScaledBefore.rayMul(expIndex);
    const user1ExpectedInterest = user1ExpectedBalance.sub(borrowAmount);

    tx = await pool
      .connect(users[1].signer)
      .repay(gho.address, user1ExpectedBalance, 2, users[0].address);
    rcpt = await tx.wait();

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(users[0].address, ZERO_ADDRESS, borrowAmount)
      .to.emit(variableDebtToken, 'Burn')
      .withArgs(users[0].address, ZERO_ADDRESS, borrowAmount, user1ExpectedInterest, expIndex)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    const user1Debt = await variableDebtToken.balanceOf(users[0].address);
    const user2Debt = await variableDebtToken.balanceOf(users[1].address);
    const user3Debt = await variableDebtToken.balanceOf(users[2].address);

    expect(await gho.balanceOf(users[0].address)).to.be.equal(0);
    expect(await gho.balanceOf(users[1].address)).to.be.equal(
      borrowAmount.mul(2).sub(user1ExpectedBalance)
    );
    expect(await gho.balanceOf(users[2].address)).to.be.equal(0);

    expect(user1Debt).to.be.eq(0);
    expect(user2Debt).to.be.eq(0);
    expect(user3Debt).to.be.eq(user3ExpectedBalance);

    expect(await gho.balanceOf(aToken.address)).to.be.equal(user1ExpectedInterest);

    expect(await gho.balanceOf(aaveMarketAddresses.treasury)).to.be.eq(0, '8');
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(0);
  });
});
