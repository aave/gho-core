import { expect } from 'chai';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { MAX_UINT_AMOUNT, ONE_YEAR, YEAR } from '../helpers/constants';
import { aaveMarketAddresses, asdEntityConfig, asdReserveConfig } from '../helpers/config';
import {
  DRE,
  setBlocktime,
  mine,
  timeLatest,
  impersonateAccountHardhat,
} from '../helpers/misc-utils';
import { calcCompoundedInterestV2 } from './helpers/math/calculations';
import { getReserveData } from './helpers/utils/helpers';
import { borrowASD, repayASD } from './helpers/utils/actions';

makeSuite('Antei VariableDebtToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

  let user1Signer;
  let user1Address;
  let user2Signer;
  let user2Address;

  let protocolInterest;

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
    const { pool, weth, asd } = testEnv;

    await weth.connect(user1Signer).approve(pool.address, collateralAmount);
    await pool.connect(user1Signer).deposit(weth.address, collateralAmount, user1Address, 0);

    await borrowASD(user1Address, borrowAmount, 0, testEnv);
  });

  it('User 1: Borrow ASD again and increase time', async function () {
    await borrowASD(user1Address, borrowAmount, YEAR, testEnv);
  });

  it('User 2: After 1 year Deposit WETH and Borrow ASD', async function () {
    const { pool, weth } = testEnv;

    await weth.connect(user2Signer).approve(pool.address, collateralAmount);
    await pool.connect(user2Signer).deposit(weth.address, collateralAmount, user2Address, 0);

    await borrowASD(user2Address, borrowAmount, 0, testEnv);
  });

  it('User 1: Increase time by 1 more year and borrow more ASD', async function () {
    await borrowASD(user2Address, borrowAmount, YEAR, testEnv);
  });

  it('User 2: Receive ASD from User 1 and Repay Debt', async function () {
    const { asd, pool, variableDebtToken } = testEnv;

    await asd.connect(user1Signer).transfer(user2Address, borrowAmount);
    await asd.connect(user2Signer).approve(pool.address, MAX_UINT_AMOUNT);

    expect(await variableDebtToken.getProtocolInterest()).to.be.equal(0);

    const amountRepaid = await repayASD(
      BigNumber.from(MAX_UINT_AMOUNT),
      user2Address,
      user2Address,
      testEnv
    );

    const user2Principal = borrowAmount.mul(2);
    protocolInterest = amountRepaid.sub(user2Principal);

    expect(await variableDebtToken.getProtocolInterest()).to.be.equal(protocolInterest);
  });

  it('Claim protocol interest', async function () {
    const { asd, variableDebtToken, aToken, pool } = testEnv;

    const treasuryAddress = await aaveMarketAddresses.treasury;
    const treasurySigner = await impersonateAccountHardhat(treasuryAddress);

    await aToken.connect(treasurySigner).claimInterest();

    const expectedATokenBalance = asdEntityConfig.mintLimit.sub(borrowAmount).sub(borrowAmount);

    expect(await variableDebtToken.getProtocolInterest()).to.be.eq(0);
    expect(await asd.balanceOf(treasuryAddress)).to.be.eq(protocolInterest);
    expect(await asd.balanceOf(aToken.address)).to.be.eq(expectedATokenBalance);
  });
});
