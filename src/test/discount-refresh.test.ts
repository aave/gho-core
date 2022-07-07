import { expect } from 'chai';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { DRE, advanceTimeAndBlock, impersonateAccountHardhat } from '../helpers/misc-utils';
import { ZERO_ADDRESS, oneRay } from '../helpers/constants';
import { ghoReserveConfig, aaveMarketAddresses } from '../helpers/config';
import { calcCompoundedInterestV2, calcDiscountRate } from './helpers/math/calculations';
import { getTxCostAndTimestamp } from './helpers/helpers';
import { printVariableDebtTokenEvents } from './helpers/tokenization-events';
import { EmptyDiscountRateStrategy__factory } from '../../types';

makeSuite('Gho Discount Refresh Flow', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

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

    // Transfers 10 stkAave (discountToken) to User 1
    const stkAaveAmount = ethers.utils.parseUnits('10.0', 18);
    await stakedAave.connect(stkAaveWhale.signer).transfer(users[0].address, stkAaveAmount);
  });

  it('User 1: Deposit WETH and Borrow GHO', async function () {
    const { users, pool, weth, gho, variableDebtToken, stakedAave } = testEnv;

    await weth.connect(users[0].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[0].signer)
      .deposit(weth.address, collateralAmount, users[0].address, 0);
    tx = await pool
      .connect(users[0].signer)
      .borrow(gho.address, borrowAmount, 2, 0, users[0].address);
    rcpt = await tx.wait();
    printVariableDebtTokenEvents(variableDebtToken, rcpt);

    const discountTokenBalance = await stakedAave.balanceOf(users[0].address);
    const discountPercent = calcDiscountRate(
      discountRate,
      ghoDiscountedPerDiscountToken,
      minDiscountTokenBalance,
      borrowAmount,
      discountTokenBalance
    );

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, users[0].address, borrowAmount)
      .to.emit(variableDebtToken, 'Mint')
      .withArgs(users[0].address, users[0].address, borrowAmount, 0, oneRay)
      .to.emit(variableDebtToken, 'DiscountPercentUpdated')
      .withArgs(users[0].address, 0, discountPercent);

    expect(await variableDebtToken.getDiscountPercent(users[0].address)).to.be.eq(discountPercent);

    expect(await gho.balanceOf(users[0].address)).to.be.equal(borrowAmount);
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(0);
    expect(await variableDebtToken.balanceOf(users[0].address)).to.be.equal(borrowAmount);
  });

  it('User 3 tries to refresh User 1 discount percent (revert expected)', async function () {
    const { users, variableDebtToken } = testEnv;

    await expect(
      variableDebtToken.connect(users[2].signer).refreshUserDiscountPercent(users[0].address)
    ).to.be.revertedWith('DISCOUNT_PERCENT_REFRESH_CONDITION_NOT_MET');
  });

  it('User 2: Deposit WETH and Borrow GHO', async function () {
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
    printVariableDebtTokenEvents(variableDebtToken, rcpt);

    const multiplier = calcCompoundedInterestV2(
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
      .to.not.emit(variableDebtToken, 'DiscountPercentUpdated');

    expect(await variableDebtToken.getDiscountPercent(users[1].address)).to.be.eq(discountPercent);

    expect(await gho.balanceOf(users[1].address)).to.be.equal(borrowAmount);
    expect(await variableDebtToken.getBalanceFromInterest(users[1].address)).to.be.equal(0);
    expect(await variableDebtToken.balanceOf(users[1].address)).to.be.equal(borrowAmount);
  });

  it('Time flies - variable debt index increases', async function () {
    await advanceTimeAndBlock(10000000000);
  });

  it('User 3 refreshes User 1 discount percent - discount percent is adjusted to current debt', async function () {
    const { users, variableDebtToken, stakedAave, gho } = testEnv;

    const discountPercentBefore = await variableDebtToken.getDiscountPercent(users[0].address);
    const expectedDiscountPercent = calcDiscountRate(
      discountRate,
      ghoDiscountedPerDiscountToken,
      minDiscountTokenBalance,
      await gho.balanceOf(users[0].address),
      await stakedAave.balanceOf(users[0].address)
    );

    tx = await variableDebtToken
      .connect(users[2].signer)
      .refreshUserDiscountPercent(users[0].address);
    rcpt = await tx.wait();
    expect(tx)
      .to.emit(variableDebtToken, 'DiscountPercentUpdated')
      .withArgs(users[0].address, discountPercentBefore, expectedDiscountPercent);
    printVariableDebtTokenEvents(variableDebtToken, rcpt);

    console.log((await variableDebtToken.getDiscountPercent(users[0].address)).toString());
    console.log(expectedDiscountPercent.toString());
    expect(await variableDebtToken.getDiscountPercent(users[0].address)).to.be.eq(
      expectedDiscountPercent
    );
  });

  it('Time flies - variable debt index increases', async function () {
    await advanceTimeAndBlock(10000000);
  });

});
