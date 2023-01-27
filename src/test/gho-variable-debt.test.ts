import hre from 'hardhat';
import { expect } from 'chai';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { impersonateAccountHardhat } from '../helpers/misc-utils';
import { ghoReserveConfig } from '../helpers/config';
import { ONE_ADDRESS, ZERO_ADDRESS } from '../helpers/constants';
import { GhoVariableDebtToken__factory } from '../../types';

makeSuite('Gho VariableDebtToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  let poolSigner;

  const CALLER_MUST_BE_POOL = '23';
  const CALLER_NOT_POOL_ADMIN = '1';
  const OPERATION_NOT_SUPPORTED = '80';
  const POOL_ADDRESSES_DO_NOT_MATCH = '87';
  const CALLER_NOT_DISCOUNT_TOKEN = 'CALLER_NOT_DISCOUNT_TOKEN';
  const CALLER_NOT_A_TOKEN = 'CALLER_NOT_A_TOKEN';
  const INITIALIZED = 'Contract instance has already been initialized';

  before(async () => {
    ethers = hre.ethers;

    const { pool } = testEnv;
    poolSigner = await impersonateAccountHardhat(pool.address);
  });

  it('Initialize when already initialized (revert expected)', async function () {
    const { variableDebtToken } = testEnv;
    await expect(
      variableDebtToken.initialize(ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, 0, 'test', 'test', [])
    ).to.be.revertedWith(INITIALIZED);
  });

  it('Initialize with incorrect pool (revert expected)', async function () {
    const { deployer, pool } = testEnv;
    const variableDebtToken = await new GhoVariableDebtToken__factory(deployer.signer).deploy(
      pool.address
    );

    await expect(
      variableDebtToken.initialize(ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, 0, 'test', 'test', [])
    ).to.be.revertedWith(POOL_ADDRESSES_DO_NOT_MATCH);
  });

  it('Update discount distribution - not permissioned (revert expected)', async function () {
    const { variableDebtToken } = testEnv;

    const randomSigner = await impersonateAccountHardhat(ONE_ADDRESS);
    const randomAddress = ONE_ADDRESS;
    const randomNumber = '0';
    await expect(
      variableDebtToken
        .connect(randomSigner)
        .updateDiscountDistribution(
          randomAddress,
          randomAddress,
          randomNumber,
          randomNumber,
          randomNumber
        )
    ).to.be.revertedWith(CALLER_NOT_DISCOUNT_TOKEN);
  });

  it('Decrease Balance from Interest - not permissioned (revert expected)', async function () {
    const { variableDebtToken } = testEnv;

    const randomSigner = await impersonateAccountHardhat(ONE_ADDRESS);
    const randomAddress = ONE_ADDRESS;
    const randomNumber = '0';
    await expect(
      variableDebtToken
        .connect(randomSigner)
        .decreaseBalanceFromInterest(randomAddress, randomNumber)
    ).to.be.revertedWith(CALLER_NOT_A_TOKEN);
  });

  it('Check operations not permitted (revert expected)', async () => {
    const { variableDebtToken } = testEnv;

    const randomAddress = ONE_ADDRESS;
    const randomNumber = '0';
    const calls = [
      { fn: 'transfer', args: [randomAddress, randomNumber] },
      { fn: 'allowance', args: [randomAddress, randomAddress] },
      { fn: 'approve', args: [randomAddress, randomNumber] },
      { fn: 'transferFrom', args: [randomAddress, randomAddress, randomNumber] },
      { fn: 'increaseAllowance', args: [randomAddress, randomNumber] },
      { fn: 'decreaseAllowance', args: [randomAddress, randomNumber] },
    ];
    for (const call of calls) {
      await expect(variableDebtToken.connect(poolSigner)[call.fn](...call.args)).to.be.revertedWith(
        OPERATION_NOT_SUPPORTED
      );
    }
  });

  it('Check permission of onlyPool modified functions (revert expected)', async () => {
    const { variableDebtToken, users } = testEnv;
    const nonPoolAdmin = users[2];

    const randomAddress = ONE_ADDRESS;
    const randomNumber = '0';
    const calls = [
      { fn: 'mint', args: [randomAddress, randomAddress, randomNumber, randomNumber] },
      { fn: 'burn', args: [randomAddress, randomNumber, randomNumber] },
    ];
    for (const call of calls) {
      await expect(
        variableDebtToken.connect(nonPoolAdmin.signer)[call.fn](...call.args)
      ).to.be.revertedWith(CALLER_MUST_BE_POOL);
    }
  });

  it('Check permission of onlyPoolAdmin modified functions (revert expected)', async () => {
    const { variableDebtToken, users } = testEnv;
    const nonPoolAdmin = users[2];

    const randomAddress = ONE_ADDRESS;
    const randomNumber = '0';
    const calls = [
      { fn: 'setAToken', args: [randomAddress] },
      { fn: 'updateDiscountRateStrategy', args: [randomAddress] },
      { fn: 'updateDiscountToken', args: [randomAddress] },
      { fn: 'updateDiscountLockPeriod', args: [randomNumber] },
    ];
    for (const call of calls) {
      await expect(
        variableDebtToken.connect(nonPoolAdmin.signer)[call.fn](...call.args)
      ).to.be.revertedWith(CALLER_NOT_POOL_ADMIN);
    }
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

  it('Set AToken - already set (revert expected)', async function () {
    const { variableDebtToken, poolAdmin } = testEnv;

    await expect(
      variableDebtToken.connect(poolAdmin.signer).setAToken(ONE_ADDRESS)
    ).to.be.revertedWith('ATOKEN_ALREADY_SET');
  });

  it('Set Discount Strategy', async function () {
    const { variableDebtToken, deployer, discountRateStrategy } = testEnv;

    await expect(
      variableDebtToken.connect(deployer.signer).updateDiscountRateStrategy(ZERO_ADDRESS)
    )
      .to.emit(variableDebtToken, 'DiscountRateStrategyUpdated')
      .withArgs(discountRateStrategy.address, ZERO_ADDRESS);
  });

  it('Get Discount Strategy - after setting', async function () {
    const { variableDebtToken } = testEnv;

    expect(await variableDebtToken.getDiscountRateStrategy()).to.be.equal(ZERO_ADDRESS);
  });

  it('Get Discount Token - before setting', async function () {
    const { variableDebtToken, stakedAave } = testEnv;

    expect(await variableDebtToken.getDiscountToken()).to.be.equal(stakedAave.address);
  });

  it('Set Discount Token', async function () {
    const { variableDebtToken, stakedAave, deployer } = testEnv;

    await expect(variableDebtToken.connect(deployer.signer).updateDiscountToken(ONE_ADDRESS))
      .to.emit(variableDebtToken, 'DiscountTokenUpdated')
      .withArgs(stakedAave.address, ONE_ADDRESS);
  });

  it('Get Discount Token - after setting', async function () {
    const { variableDebtToken } = testEnv;

    expect(await variableDebtToken.getDiscountToken()).to.be.equal(ONE_ADDRESS);
  });

  it('Set Rebalance Lock Period', async function () {
    const { variableDebtToken, deployer } = testEnv;

    await expect(variableDebtToken.connect(deployer.signer).updateDiscountLockPeriod(2))
      .to.emit(variableDebtToken, 'DiscountLockPeriodUpdated')
      .withArgs(ghoReserveConfig.DISCOUNT_LOCK_PERIOD, 2);
  });

  it('Get Rebalance Lock Period', async function () {
    const { variableDebtToken } = testEnv;

    expect(await variableDebtToken.getDiscountLockPeriod()).to.be.equal(2);
  });
});
