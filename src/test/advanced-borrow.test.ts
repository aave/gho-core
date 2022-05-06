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
  getWorkingBalance,
  getNextIndex,
} from './helpers/math/calculations';
import { getERC20 } from '../helpers/contract-getters';

makeSuite('Antei Advanced Borrow Flow', (testEnv: TestEnv) => {
  let ethers;

  let user1;
  let user2;
  let user3;
  let user4;

  let ASD_CONSTANT;
  let ONE;

  let totalSupply;
  let totalStk;
  let integrateDiscount;
  let totalWorkingSupply;

  let user1RepayAmount;
  let user3RepayAmount;

  /***********************************/
  /*   Step 1: User 1 - borrow 1000 ASD with 10 stkAave
  /*   
  /*   Step 2: year 1 passes & check debt balances
  /*   
  /*   Step 3: User 2 - borrow 2000 ASD, 0 stkAave
  /*
  /*   Step 4: 1 year & check debt balances
  /*
  /*   Step 5: User 3 - borrow 4000 ASD, 50 stkAave
  /*   
  /*   Step 6: 1 year & check debt balances
  /*
  /*   Step 7: User 4 - borrow 6000 ASD, 30 stkAave
  /* 
  /*   Step 8: 1 year & check debt balances
  /*
  /*   Step 9: User 1 - repay full ASD, 10 stkAave
  /*
  /*   Step 10: 1 Yr - check balances
  /*
  /*   Step 11: User 3 repay 1000 balance, 50 stkAave
  /*
  /*   Step 12: 1 Yr - Check all balances
  /***********************************/

  before(() => {
    ethers = DRE.ethers;

    ASD_CONSTANT = ethers.utils.parseUnits('4.0', 17);
    ONE = ethers.utils.parseUnits('1.0', 18);

    totalSupply = BigNumber.from(0);
    totalStk = BigNumber.from(0);
    integrateDiscount = ethers.utils.parseUnits('1.0', 30);
    totalWorkingSupply = BigNumber.from(0);

    user3RepayAmount = ethers.utils.parseUnits('1000.0', 18);

    const { users } = testEnv;
    users[0].collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    users[0].borrowAmount = ethers.utils.parseUnits('1000.0', 18);
    users[0].stkAmount = ethers.utils.parseUnits('10.0', 18);
    user1 = users[0];

    users[1].collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    users[1].borrowAmount = ethers.utils.parseUnits('2000.0', 18);
    users[1].stkAmount = ethers.utils.parseUnits('0.0', 18);
    user2 = users[1];

    users[2].collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    users[2].borrowAmount = ethers.utils.parseUnits('4000.0', 18);
    users[2].stkAmount = ethers.utils.parseUnits('50.0', 18);
    user3 = users[2];

    users[3].collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    users[3].borrowAmount = ethers.utils.parseUnits('6000.0', 18);
    users[3].stkAmount = ethers.utils.parseUnits('30.0', 18);
    user4 = users[3];
  });

  it('Setup: Deposit WETH as collateral', async function () {
    const { pool, weth, aaveDataProvider, users } = testEnv;

    // get weth AToken
    const { aTokenAddress: wethATokenAddress } = await aaveDataProvider.getReserveTokensAddresses(
      weth.address
    );
    const wethAToken = await getERC20(wethATokenAddress);

    // deposit weth for user
    for (let i = 0; i < 4; i++) {
      const user = users[i];
      if (!user.collateralAmount.eq(BigNumber.from(0))) {
        await weth.connect(user.signer).approve(pool.address, user.collateralAmount);
        await pool
          .connect(user.signer)
          .deposit(weth.address, user.collateralAmount, user.address, 0);

        expect(
          await wethAToken.balanceOf(user.address),
          `ERROR: Collateral Setup - User${i + 1}`
        ).to.be.equal(user.collateralAmount);
      }
    }
  });

  it('Setup: acquire stkAave', async function () {
    const { stkAave, stkAaveWhale, users } = testEnv;

    // stk Aave
    for (let i = 0; i < 4; i++) {
      const user = users[i];
      if (!user.stkAmount.eq(BigNumber.from(0))) {
        await stkAave.connect(stkAaveWhale.signer).transfer(user.address, user.stkAmount);
        expect(await stkAave.balanceOf(user.address), `ERROR: StkAave Setup - User${i + 1}`);
      }
    }
  });

  it('Step 1: User 1 - borrow 1000 ASD with 10 stkAave', async function () {
    const { pool, asd, variableDebtToken } = testEnv;

    await pool.connect(user1.signer).borrow(asd.address, user1.borrowAmount, 2, 0, user1.address);

    totalSupply = totalSupply.add(user1.borrowAmount);
    totalStk = user1.stkAmount;

    // no time passed, so no update
    integrateDiscount = integrateDiscount;
    user1.integrateDiscountOf = integrateDiscount;

    user1.workingBalance = await getWorkingBalance(
      user1.borrowAmount,
      user1.stkAmount,
      totalSupply,
      totalStk,
      ASD_CONSTANT
    );
    totalWorkingSupply = user1.workingBalance;

    expect(await asd.balanceOf(user1.address)).to.be.equal(user1.borrowAmount);
    expect(await variableDebtToken.balanceOf(user1.address)).to.be.equal(user1.borrowAmount);
  });

  it('Step 2: year 1 passes & check debt balances', async function () {
    const { asd, variableDebtToken, pool } = testEnv;

    const poolData = await pool.getReserveData(asd.address);
    const nextTimestamp = poolData.lastUpdateTimestamp + ONE_YEAR;

    const nextIndex = await getNextIndex(poolData, asdReserveConfig.INTEREST_RATE, nextTimestamp);

    const [user1BalanceNoDiscount] = await getExpectedUserBalances(
      [user1.address],
      nextIndex,
      variableDebtToken
    );

    const totalDiscounts = await getExpectedDiscounts(
      poolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    const nextIntegrateDiscount = integrateDiscount.add(
      totalDiscounts.mul(ONE).div(totalWorkingSupply)
    );

    const discount = user1.workingBalance
      .mul(nextIntegrateDiscount.sub(user1.integrateDiscountOf))
      .div(ONE);

    const expectedBalance = user1BalanceNoDiscount.sub(discount);

    await setBlocktime(nextTimestamp);
    await mine(); // Mine block to increment time in underlying chain as well

    const user1Year1Debt = await variableDebtToken.balanceOf(user1.address);

    expect(await asd.balanceOf(user1.address)).to.be.equal(user1.borrowAmount);
    expect(user1Year1Debt).to.be.eq(expectedBalance);
  });

  it('Step 3: User 2 - borrow 2000 ASD, 0 stkAave', async function () {
    const { pool, asd, variableDebtToken } = testEnv;

    const beforePoolData = await pool.getReserveData(asd.address);

    const nextIndex = await getNextIndex(
      beforePoolData,
      asdReserveConfig.INTEREST_RATE,
      (await timeLatest()) + 1
    );

    const totalDiscounts = await getExpectedDiscounts(
      beforePoolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    integrateDiscount = integrateDiscount.add(totalDiscounts.mul(ONE).div(totalWorkingSupply));
    user2.integrateDiscountOf = integrateDiscount;

    await pool.connect(user2.signer).borrow(asd.address, user2.borrowAmount, 2, 0, user2.address);

    totalSupply = await variableDebtToken.totalSupply();
    totalStk = totalStk.add(user2.stkAmount);

    user2.workingBalance = await getWorkingBalance(
      user2.borrowAmount,
      user2.stkAmount,
      totalSupply,
      totalStk,
      ASD_CONSTANT
    );

    totalWorkingSupply = totalWorkingSupply.add(user2.workingBalance);

    expect(user2.workingBalance).to.be.equal(ASD_CONSTANT.wadMul(user2.borrowAmount));
    expect(await asd.balanceOf(user2.address)).to.be.equal(user2.borrowAmount);
    expect(await variableDebtToken.balanceOf(user2.address)).to.be.equal(user2.borrowAmount);
  });

  it('Step 4: year 2 passes & check debt balances', async function () {
    const { asd, variableDebtToken, pool } = testEnv;

    const poolData = await pool.getReserveData(asd.address);
    const nextTimestamp = poolData.lastUpdateTimestamp + ONE_YEAR;

    const nextIndex = await getNextIndex(poolData, asdReserveConfig.INTEREST_RATE, nextTimestamp);

    const [user1BalanceNoDiscount, user2BalanceNoDiscount] = await getExpectedUserBalances(
      [user1.address, user2.address],
      nextIndex,
      variableDebtToken
    );

    const totalDiscounts = await getExpectedDiscounts(
      poolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    const nextIntegrateDiscount = integrateDiscount.add(
      totalDiscounts.mul(ONE).div(totalWorkingSupply)
    );

    const user1Discount = user1.workingBalance
      .mul(nextIntegrateDiscount.sub(user1.integrateDiscountOf))
      .div(ONE);

    const user2Discount = user2.workingBalance
      .mul(nextIntegrateDiscount.sub(user2.integrateDiscountOf))
      .div(ONE);

    const user1ExpectedBalance = user1BalanceNoDiscount.sub(user1Discount);
    const user2ExpectedBalance = user2BalanceNoDiscount.sub(user2Discount);

    await setBlocktime(nextTimestamp);
    await mine(); // Mine block to increment time in underlying chain as well

    const user1Year1Debt = await variableDebtToken.balanceOf(user1.address);
    const user2Year1Debt = await variableDebtToken.balanceOf(user2.address);

    expect(await asd.balanceOf(user1.address)).to.be.equal(user1.borrowAmount);
    expect(user1Year1Debt).to.be.eq(user1ExpectedBalance);

    expect(await asd.balanceOf(user2.address)).to.be.equal(user2.borrowAmount);
    expect(user2Year1Debt).to.be.eq(user2ExpectedBalance);
  });

  it('Step 5: User 3 - borrow 4000 ASD, 50 stkAave', async function () {
    const { pool, asd, variableDebtToken } = testEnv;

    const beforePoolData = await pool.getReserveData(asd.address);

    const nextIndex = await getNextIndex(
      beforePoolData,
      asdReserveConfig.INTEREST_RATE,
      (await timeLatest()) + 1
    );

    const totalDiscounts = await getExpectedDiscounts(
      beforePoolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    integrateDiscount = integrateDiscount.add(totalDiscounts.mul(ONE).div(totalWorkingSupply));
    user3.integrateDiscountOf = integrateDiscount;

    await pool.connect(user3.signer).borrow(asd.address, user3.borrowAmount, 2, 0, user3.address);

    totalSupply = await variableDebtToken.totalSupply();
    totalStk = totalStk.add(user3.stkAmount);

    user3.workingBalance = await getWorkingBalance(
      user3.borrowAmount,
      user3.stkAmount,
      totalSupply,
      totalStk,
      ASD_CONSTANT
    );

    totalWorkingSupply = totalWorkingSupply.add(user3.workingBalance);

    expect(await asd.balanceOf(user3.address)).to.be.equal(user3.borrowAmount);
    expect(await variableDebtToken.balanceOf(user3.address)).to.be.equal(user3.borrowAmount);
  });

  it('Step 6: Year 3 passes & check debt balances', async function () {
    const { asd, variableDebtToken, pool } = testEnv;

    const poolData = await pool.getReserveData(asd.address);
    const nextTimestamp = poolData.lastUpdateTimestamp + ONE_YEAR;

    const nextIndex = await getNextIndex(poolData, asdReserveConfig.INTEREST_RATE, nextTimestamp);

    const [user1BalanceNoDiscount, user2BalanceNoDiscount, user3BalanceNoDiscount] =
      await getExpectedUserBalances(
        [user1.address, user2.address, user3.address],
        nextIndex,
        variableDebtToken
      );

    const totalDiscounts = await getExpectedDiscounts(
      poolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    const nextIntegrateDiscount = integrateDiscount.add(
      totalDiscounts.mul(ONE).div(totalWorkingSupply)
    );

    const user1Discount = user1.workingBalance
      .mul(nextIntegrateDiscount.sub(user1.integrateDiscountOf))
      .div(ONE);

    const user2Discount = user2.workingBalance
      .mul(nextIntegrateDiscount.sub(user2.integrateDiscountOf))
      .div(ONE);

    const user3Discount = user3.workingBalance
      .mul(nextIntegrateDiscount.sub(user3.integrateDiscountOf))
      .div(ONE);

    const user1ExpectedBalance = user1BalanceNoDiscount.sub(user1Discount);
    const user2ExpectedBalance = user2BalanceNoDiscount.sub(user2Discount);
    const user3ExpectedBalance = user3BalanceNoDiscount.sub(user3Discount);

    await setBlocktime(nextTimestamp);
    await mine(); // Mine block to increment time in underlying chain as well

    const user1Year1Debt = await variableDebtToken.balanceOf(user1.address);
    const user2Year1Debt = await variableDebtToken.balanceOf(user2.address);
    const user3Year1Debt = await variableDebtToken.balanceOf(user3.address);

    expect(await asd.balanceOf(user1.address)).to.be.equal(user1.borrowAmount);
    expect(user1Year1Debt).to.be.eq(user1ExpectedBalance);

    expect(await asd.balanceOf(user2.address)).to.be.equal(user2.borrowAmount);
    expect(user2Year1Debt).to.be.eq(user2ExpectedBalance);

    expect(await asd.balanceOf(user3.address)).to.be.equal(user3.borrowAmount);
    expect(user3Year1Debt).to.be.eq(user3ExpectedBalance);
  });

  it('Step 7: User 4 - borrow 6000 ASD, 30 stkAave', async function () {
    const { pool, asd, variableDebtToken } = testEnv;

    const beforePoolData = await pool.getReserveData(asd.address);

    const nextIndex = await getNextIndex(
      beforePoolData,
      asdReserveConfig.INTEREST_RATE,
      (await timeLatest()) + 1
    );

    const totalDiscounts = await getExpectedDiscounts(
      beforePoolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    integrateDiscount = integrateDiscount.add(totalDiscounts.mul(ONE).div(totalWorkingSupply));
    user4.integrateDiscountOf = integrateDiscount;

    await pool.connect(user4.signer).borrow(asd.address, user4.borrowAmount, 2, 0, user4.address);

    totalSupply = await variableDebtToken.totalSupply();
    totalStk = totalStk.add(user4.stkAmount);

    user4.workingBalance = await getWorkingBalance(
      user4.borrowAmount,
      user4.stkAmount,
      totalSupply,
      totalStk,
      ASD_CONSTANT
    );

    totalWorkingSupply = totalWorkingSupply.add(user4.workingBalance);

    expect(await asd.balanceOf(user4.address)).to.be.equal(user4.borrowAmount);
    expect(await variableDebtToken.balanceOf(user4.address)).to.be.equal(user4.borrowAmount);
  });

  it('Step 8: 1 year & check debt balances', async function () {
    const { asd, variableDebtToken, pool } = testEnv;

    const poolData = await pool.getReserveData(asd.address);
    const nextTimestamp = poolData.lastUpdateTimestamp + ONE_YEAR;

    const nextIndex = await getNextIndex(poolData, asdReserveConfig.INTEREST_RATE, nextTimestamp);

    const [
      user1BalanceNoDiscount,
      user2BalanceNoDiscount,
      user3BalanceNoDiscount,
      user4BalanceNoDiscount,
    ] = await getExpectedUserBalances(
      [user1.address, user2.address, user3.address, user4.address],
      nextIndex,
      variableDebtToken
    );

    const totalDiscounts = await getExpectedDiscounts(
      poolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    const nextIntegrateDiscount = integrateDiscount.add(
      totalDiscounts.mul(ONE).div(totalWorkingSupply)
    );

    const user1Discount = user1.workingBalance
      .mul(nextIntegrateDiscount.sub(user1.integrateDiscountOf))
      .div(ONE);

    const user2Discount = user2.workingBalance
      .mul(nextIntegrateDiscount.sub(user2.integrateDiscountOf))
      .div(ONE);

    const user3Discount = user3.workingBalance
      .mul(nextIntegrateDiscount.sub(user3.integrateDiscountOf))
      .div(ONE);

    const user4Discount = user4.workingBalance
      .mul(nextIntegrateDiscount.sub(user4.integrateDiscountOf))
      .div(ONE);

    const user1ExpectedBalance = user1BalanceNoDiscount.sub(user1Discount);
    const user2ExpectedBalance = user2BalanceNoDiscount.sub(user2Discount);
    const user3ExpectedBalance = user3BalanceNoDiscount.sub(user3Discount);
    const user4ExpectedBalance = user4BalanceNoDiscount.sub(user4Discount);

    await setBlocktime(nextTimestamp);
    await mine(); // Mine block to increment time in underlying chain as well

    const user1Year1Debt = await variableDebtToken.balanceOf(user1.address);
    const user2Year1Debt = await variableDebtToken.balanceOf(user2.address);
    const user3Year1Debt = await variableDebtToken.balanceOf(user3.address);
    const user4Year1Debt = await variableDebtToken.balanceOf(user4.address);

    expect(await asd.balanceOf(user1.address)).to.be.equal(user1.borrowAmount);
    expect(user1Year1Debt).to.be.eq(user1ExpectedBalance);

    expect(await asd.balanceOf(user2.address)).to.be.equal(user2.borrowAmount);
    expect(user2Year1Debt).to.be.eq(user2ExpectedBalance);

    expect(await asd.balanceOf(user3.address)).to.be.equal(user3.borrowAmount);
    expect(user3Year1Debt).to.be.eq(user3ExpectedBalance);

    expect(await asd.balanceOf(user4.address)).to.be.equal(user4.borrowAmount);
    expect(user4Year1Debt).to.be.eq(user4ExpectedBalance);
  });

  it('Step 9: User 1 - repay full ASD, 10 stkAave', async function () {
    const { pool, asd, variableDebtToken } = testEnv;

    const beforePoolData = await pool.getReserveData(asd.address);

    const nextIndex = await getNextIndex(
      beforePoolData,
      asdReserveConfig.INTEREST_RATE,
      (await timeLatest()) + 3
    );

    const totalDiscounts = await getExpectedDiscounts(
      beforePoolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    const [user1BalanceNoDiscount] = await getExpectedUserBalances(
      [user1.address],
      nextIndex,
      variableDebtToken
    );

    integrateDiscount = integrateDiscount.add(totalDiscounts.mul(ONE).div(totalWorkingSupply));
    const user1Discount = user1.workingBalance
      .mul(integrateDiscount.sub(user1.integrateDiscountOf))
      .div(ONE);

    user1.integrateDiscountOf = integrateDiscount;

    const user1ExpectedBalance = user1BalanceNoDiscount.sub(user1Discount);
    user1RepayAmount = user1ExpectedBalance;

    await asd.connect(user4.signer).transfer(user1.address, user4.borrowAmount);
    await asd.connect(user1.signer).approve(pool.address, MAX_UINT);
    await pool.connect(user1.signer).repay(asd.address, user1RepayAmount, 2, user1.address);

    totalSupply = totalSupply.sub(user1ExpectedBalance);
    totalStk = totalStk.sub(user1.stkAmount);

    const previousWorkingBalance = user1.workingBalance;
    user1.workingBalance = await getWorkingBalance(
      await variableDebtToken.balanceOf(user1.address),
      user1.stkAmount,
      totalSupply,
      totalStk,
      ASD_CONSTANT
    );

    totalWorkingSupply = totalWorkingSupply.sub(previousWorkingBalance);

    expect(user1.workingBalance).to.be.eq(0);
    expect(await asd.balanceOf(user1.address), 'asdBalance').to.be.equal(
      user4.borrowAmount.add(user1.borrowAmount).sub(user1ExpectedBalance)
    );
    expect(await variableDebtToken.balanceOf(user1.address)).to.be.equal(0);
  });

  it('Step 10: 1 year & check debt balances', async function () {
    const { asd, variableDebtToken, pool } = testEnv;

    const poolData = await pool.getReserveData(asd.address);
    const nextTimestamp = poolData.lastUpdateTimestamp + ONE_YEAR;

    const nextIndex = await getNextIndex(poolData, asdReserveConfig.INTEREST_RATE, nextTimestamp);

    const [, user2BalanceNoDiscount, user3BalanceNoDiscount, user4BalanceNoDiscount] =
      await getExpectedUserBalances(
        [user1.address, user2.address, user3.address, user4.address],
        nextIndex,
        variableDebtToken
      );

    const totalDiscounts = await getExpectedDiscounts(
      poolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    const nextIntegrateDiscount = integrateDiscount.add(
      totalDiscounts.mul(ONE).div(totalWorkingSupply)
    );

    const user2Discount = user2.workingBalance
      .mul(nextIntegrateDiscount.sub(user2.integrateDiscountOf))
      .div(ONE);

    const user3Discount = user3.workingBalance
      .mul(nextIntegrateDiscount.sub(user3.integrateDiscountOf))
      .div(ONE);

    const user4Discount = user4.workingBalance
      .mul(nextIntegrateDiscount.sub(user4.integrateDiscountOf))
      .div(ONE);

    const user2ExpectedBalance = user2BalanceNoDiscount.sub(user2Discount);
    const user3ExpectedBalance = user3BalanceNoDiscount.sub(user3Discount);
    const user4ExpectedBalance = user4BalanceNoDiscount.sub(user4Discount);

    await setBlocktime(nextTimestamp);
    await mine(); // Mine block to increment time in underlying chain as well

    const user1Year1Debt = await variableDebtToken.balanceOf(user1.address);
    const user2Year1Debt = await variableDebtToken.balanceOf(user2.address);
    const user3Year1Debt = await variableDebtToken.balanceOf(user3.address);
    const user4Year1Debt = await variableDebtToken.balanceOf(user4.address);

    expect(await asd.balanceOf(user1.address)).to.be.equal(
      user1.borrowAmount.add(user4.borrowAmount).sub(user1RepayAmount)
    );
    expect(user1Year1Debt).to.be.eq(0);

    expect(await asd.balanceOf(user2.address), '1').to.be.equal(user2.borrowAmount);
    expect(user2Year1Debt, '2').to.be.eq(user2ExpectedBalance);

    expect(await asd.balanceOf(user3.address)).to.be.equal(user3.borrowAmount);
    expect(user3Year1Debt, '3').to.be.eq(user3ExpectedBalance);

    // zero since transferred to user 1 last step
    expect(await asd.balanceOf(user4.address), '4').to.be.equal(0);
    expect(user4Year1Debt, '5').to.be.eq(user4ExpectedBalance);
  });

  it('Step 11: User 3 - repay 1000 ASD, 10 stkAave', async function () {
    const { pool, asd, variableDebtToken } = testEnv;

    const beforePoolData = await pool.getReserveData(asd.address);

    const nextIndex = await getNextIndex(
      beforePoolData,
      asdReserveConfig.INTEREST_RATE,
      (await timeLatest()) + 2
    );

    const totalDiscounts = await getExpectedDiscounts(
      beforePoolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    const [user3BalanceNoDiscount] = await getExpectedUserBalances(
      [user3.address],
      nextIndex,
      variableDebtToken
    );

    integrateDiscount = integrateDiscount.add(totalDiscounts.mul(ONE).div(totalWorkingSupply));
    const user3Discount = user3.workingBalance
      .mul(integrateDiscount.sub(user3.integrateDiscountOf))
      .div(ONE);
    user3.integrateDiscountOf = integrateDiscount;

    const user3ExpectedBalance = user3BalanceNoDiscount.sub(user3Discount);

    await asd.connect(user3.signer).approve(pool.address, MAX_UINT);
    await pool.connect(user3.signer).repay(asd.address, user3RepayAmount, 2, user3.address);

    totalSupply = totalSupply.sub(user3RepayAmount);

    // do not adjust total stk

    const previousWorkingBalance = user3.workingBalance;
    user3.workingBalance = await getWorkingBalance(
      await variableDebtToken.balanceOf(user3.address),
      user3.stkAmount,
      totalSupply,
      totalStk,
      ASD_CONSTANT
    );
    totalWorkingSupply = totalWorkingSupply.sub(previousWorkingBalance).add(user3.workingBalance);

    expect(await asd.balanceOf(user3.address)).to.be.equal(
      user3.borrowAmount.sub(user3RepayAmount)
    );
    expect(await variableDebtToken.balanceOf(user3.address)).to.be.closeTo(
      user3ExpectedBalance.sub(user3RepayAmount),
      1
    );
  });

  it('Step 12: 1 year & check debt balances', async function () {
    const { asd, variableDebtToken, pool } = testEnv;

    const poolData = await pool.getReserveData(asd.address);
    const nextTimestamp = poolData.lastUpdateTimestamp + ONE_YEAR;

    const nextIndex = await getNextIndex(poolData, asdReserveConfig.INTEREST_RATE, nextTimestamp);

    const [, user2BalanceNoDiscount, user3BalanceNoDiscount, user4BalanceNoDiscount] =
      await getExpectedUserBalances(
        [user1.address, user2.address, user3.address, user4.address],
        nextIndex,
        variableDebtToken
      );

    const totalDiscounts = await getExpectedDiscounts(
      poolData,
      asdReserveConfig.discountRate,
      nextIndex,
      variableDebtToken
    );

    const nextIntegrateDiscount = integrateDiscount.add(
      totalDiscounts.mul(ONE).div(totalWorkingSupply)
    );

    const user2Discount = user2.workingBalance
      .mul(nextIntegrateDiscount.sub(user2.integrateDiscountOf))
      .div(ONE);

    const user3Discount = user3.workingBalance
      .mul(nextIntegrateDiscount.sub(user3.integrateDiscountOf))
      .div(ONE);

    const user4Discount = user4.workingBalance
      .mul(nextIntegrateDiscount.sub(user4.integrateDiscountOf))
      .div(ONE);

    const user2ExpectedBalance = user2BalanceNoDiscount.sub(user2Discount);
    const user3ExpectedBalance = user3BalanceNoDiscount.sub(user3Discount);
    const user4ExpectedBalance = user4BalanceNoDiscount.sub(user4Discount);

    await setBlocktime(nextTimestamp);
    await mine(); // Mine block to increment time in underlying chain as well

    const user1Year1Debt = await variableDebtToken.balanceOf(user1.address);
    const user2Year1Debt = await variableDebtToken.balanceOf(user2.address);
    const user3Year1Debt = await variableDebtToken.balanceOf(user3.address);
    const user4Year1Debt = await variableDebtToken.balanceOf(user4.address);

    expect(await asd.balanceOf(user1.address)).to.be.equal(
      user1.borrowAmount.add(user4.borrowAmount).sub(user1RepayAmount)
    );
    expect(user1Year1Debt).to.be.eq(0);

    expect(await asd.balanceOf(user2.address), '1').to.be.equal(user2.borrowAmount);
    expect(user2Year1Debt, '2').to.be.eq(user2ExpectedBalance);

    expect(await asd.balanceOf(user3.address)).to.be.equal(
      user3.borrowAmount.sub(user3RepayAmount)
    );
    expect(user3Year1Debt, '3').to.be.eq(user3ExpectedBalance);

    // zero since transferred to user 1 last step
    expect(await asd.balanceOf(user4.address), '4').to.be.equal(0);
    expect(user4Year1Debt, '5').to.be.eq(user4ExpectedBalance);
  });
});
