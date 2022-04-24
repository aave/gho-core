import { expect } from 'chai';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { DRE, timeLatest, setBlocktime } from '../helpers/misc-utils';
import { ONE_YEAR } from '../helpers/constants';
import { calcCompoundedInterest } from './helpers/math/calculations';
import { asdConfiguration } from '../configs/asd-configuration';

makeSuite('Antei VariableDebtToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

  let startTime;
  let oneYearLater;
  let twoYearsLater;

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

  it('User 1: Check 1 year interest accrued', async function () {
    const { asd, variableDebtToken } = testEnv;
    const interest = await calcCompoundedInterest(
      asdConfiguration.marketConfig.INTEREST_RATE,
      oneYearLater,
      startTime
    );

    const user1ExpectedBalance = borrowAmount.rayMul(interest);
    user1Year1Debt = await variableDebtToken.balanceOf(user1Address);

    expect(await asd.balanceOf(user1Address)).to.be.equal(borrowAmount);
    expect(user1Year1Debt).to.be.closeTo(user1ExpectedBalance, ethers.utils.parseUnits('1.0', 14));
  });

  it('User 1: After 1 more year borrow ASD', async function () {
    const { pool, asd, variableDebtToken } = testEnv;

    twoYearsLater = oneYearLater.add(BigNumber.from(ONE_YEAR));
    await setBlocktime(twoYearsLater.toNumber());
    await pool.connect(user1Signer).borrow(asd.address, borrowAmount, 2, 0, user1Address);
    const interest = await calcCompoundedInterest(
      asdConfiguration.marketConfig.INTEREST_RATE,
      twoYearsLater,
      oneYearLater
    );

    const user1ExpectedDebt = user1Year1Debt.rayMul(interest).add(borrowAmount);
    const user2ExpectedDebt = borrowAmount.rayMul(interest);

    const user1Debt = await variableDebtToken.balanceOf(user1Address);
    const user2Debt = await variableDebtToken.balanceOf(user2Address);

    expect(await asd.balanceOf(user1Address)).to.be.equal(borrowAmount.add(borrowAmount));
    expect(user1Debt).to.be.closeTo(user1ExpectedDebt, ethers.utils.parseUnits('1.0', 14));

    expect(await asd.balanceOf(user2Address)).to.be.equal(borrowAmount);
    expect(user2Debt).to.be.closeTo(user2ExpectedDebt, ethers.utils.parseUnits('1.0', 14));
  });
});
