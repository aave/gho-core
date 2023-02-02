import { expect } from 'chai';

import { makeSuite, TestEnv } from './helpers/make-suite';
import { impersonateAccountHardhat } from '../helpers/misc-utils';
import { ghoReserveConfig } from '../helpers/config';
import { ONE_ADDRESS } from '../helpers/constants';
import { GhoVariableDebtToken__factory } from '../../types';
import { ZERO_ADDRESS } from '@aave/deploy-v3';

makeSuite('Gho VariableDebtToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  let poolSigner;

  const testAddressOne = '0x2acAb3DEa77832C09420663b0E1cB386031bA17B';
  const testAddressTwo = '0x6fC355D4e0EE44b292E50878F49798ff755A5bbC';

  const CALLER_NOT_POOL_ADMIN = '1';
  const ZERO_ADDRESS_NOT_VALID = 'ZERO_ADDRESS_NOT_VALID';

  before(async () => {
    ethers = hre.ethers;

    const { pool } = testEnv;
    poolSigner = await impersonateAccountHardhat(pool.address);
  });

  it('Get AToken', async function () {
    const { variableDebtToken, aToken } = testEnv;
    const aTokenAddress = await variableDebtToken.getAToken();
    expect(aTokenAddress).to.be.equal(aToken.address);
  });

  it('Get Discount Rate Strategy', async function () {
    const { variableDebtToken, discountRateStrategy } = testEnv;
    const discountToken = await variableDebtToken.getDiscountRateStrategy();
    expect(discountToken).to.be.equal(discountRateStrategy.address);
  });

  it('Set ZERO address as AToken (expect revert)', async function () {
    const {
      users: [user1],
      pool,
      poolAdmin,
    } = testEnv;

    const newGhoAToken = await new GhoVariableDebtToken__factory(user1.signer).deploy(pool.address);

    await expect(newGhoAToken.connect(poolAdmin.signer).setAToken(ZERO_ADDRESS)).to.be.revertedWith(
      ZERO_ADDRESS_NOT_VALID
    );
  });

  it('Set AToken - already set (expect revert)', async function () {
    const { variableDebtToken, poolAdmin } = testEnv;

    await expect(
      variableDebtToken.connect(poolAdmin.signer).setAToken(testAddressTwo)
    ).to.be.revertedWith('ATOKEN_ALREADY_SET');
  });

  it('Set AToken - not permissioned (expect revert)', async function () {
    const { variableDebtToken, deployer } = testEnv;

    const randomSigner = await impersonateAccountHardhat(testAddressTwo);

    await expect(
      variableDebtToken.connect(randomSigner).setAToken(testAddressTwo)
    ).to.be.revertedWith(CALLER_NOT_POOL_ADMIN);
  });

  it('Set Discount Strategy', async function () {
    const { variableDebtToken, deployer, discountRateStrategy } = testEnv;

    await expect(variableDebtToken.connect(deployer.signer).updateDiscountRateStrategy(ONE_ADDRESS))
      .to.emit(variableDebtToken, 'DiscountRateStrategyUpdated')
      .withArgs(discountRateStrategy.address, ONE_ADDRESS);
  });

  it('Get Discount Strategy - after setting', async function () {
    const { variableDebtToken } = testEnv;

    expect(await variableDebtToken.getDiscountRateStrategy()).to.be.equal(ONE_ADDRESS);
  });

  it('Set ZERO address as Discount Strategy (expect revert)', async function () {
    const { variableDebtToken, deployer, discountRateStrategy } = testEnv;

    await expect(
      variableDebtToken.connect(deployer.signer).updateDiscountRateStrategy(ZERO_ADDRESS)
    ).to.be.revertedWith(ZERO_ADDRESS_NOT_VALID);
  });

  it('Set Discount Strategy - not permissioned (expect revert)', async function () {
    const { variableDebtToken } = testEnv;

    const randomSigner = await impersonateAccountHardhat(testAddressTwo);
    await expect(
      variableDebtToken.connect(randomSigner).updateDiscountRateStrategy(ONE_ADDRESS)
    ).to.be.revertedWith(CALLER_NOT_POOL_ADMIN);
  });

  it('Get Discount Token - before setting', async function () {
    const { variableDebtToken, stakedAave } = testEnv;

    expect(await variableDebtToken.getDiscountToken()).to.be.equal(stakedAave.address);
  });

  it('Set Discount Token', async function () {
    const { variableDebtToken, stakedAave, deployer } = testEnv;

    await expect(variableDebtToken.connect(deployer.signer).updateDiscountToken(testAddressOne))
      .to.emit(variableDebtToken, 'DiscountTokenUpdated')
      .withArgs(stakedAave.address, testAddressOne);
  });

  it('Get Discount Token - after setting', async function () {
    const { variableDebtToken } = testEnv;

    expect(await variableDebtToken.getDiscountToken()).to.be.equal(testAddressOne);
  });

  it('Set Discount Token - not permissioned (expect revert)', async function () {
    const { variableDebtToken } = testEnv;

    const randomSigner = await impersonateAccountHardhat(testAddressTwo);
    await expect(
      variableDebtToken.connect(randomSigner).updateDiscountToken(ONE_ADDRESS)
    ).to.be.revertedWith(CALLER_NOT_POOL_ADMIN);
  });

  it('Set Rebalance Lock Period', async function () {
    const { variableDebtToken, deployer } = testEnv;

    await expect(variableDebtToken.connect(deployer.signer).updateDiscountLockPeriod(2))
      .to.emit(variableDebtToken, 'DiscountLockPeriodUpdated')
      .withArgs(ghoReserveConfig.DISCOUNT_LOCK_PERIOD, 2);
  });

  it('Get Rebalance Lock Period', async function () {
    const { variableDebtToken, deployer } = testEnv;

    expect(await variableDebtToken.getDiscountLockPeriod()).to.be.equal(2);
  });

  it('Set Rebalance Lock Period - not permissioned (expect revert)', async function () {
    const { variableDebtToken } = testEnv;

    const randomSigner = await impersonateAccountHardhat(testAddressTwo);
    await expect(
      variableDebtToken.connect(randomSigner).updateDiscountLockPeriod(0)
    ).to.be.revertedWith(CALLER_NOT_POOL_ADMIN);
  });
});
