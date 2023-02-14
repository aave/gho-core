import hre from 'hardhat';
import { expect } from 'chai';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { impersonateAccountHardhat } from '../helpers/misc-utils';
import { ghoReserveConfig } from '../helpers/config';
import { ONE_ADDRESS, ZERO_ADDRESS } from '../helpers/constants';
import { ProtocolErrors } from '@aave/core-v3';
import { getPoolConfiguratorProxy } from '@aave/deploy-v3';

export const TWO_ADDRESS = '0x0000000000000000000000000000000000000002';

makeSuite('Gho Manager End-To-End', (testEnv: TestEnv) => {
  let ethers;

  let poolSigner;
  let randomSigner;
  let poolConfigurator;

  before(async () => {
    ethers = hre.ethers;

    const { pool } = testEnv;

    poolSigner = await impersonateAccountHardhat(pool.address);
    randomSigner = await impersonateAccountHardhat(ONE_ADDRESS);
    poolConfigurator = await getPoolConfiguratorProxy();
  });

  it('Update discount rate strategy from gho manager', async function () {
    const { variableDebtToken, deployer, discountRateStrategy, ghoManager } = testEnv;

    await expect(
      ghoManager
        .connect(deployer.signer)
        .updateDiscountRateStrategy(variableDebtToken.address, TWO_ADDRESS)
    ).to.emit(variableDebtToken, 'DiscountRateStrategyUpdated');
  });

  it('Get Discount Strategy - after setting', async function () {
    const { variableDebtToken } = testEnv;

    expect(await variableDebtToken.getDiscountRateStrategy()).to.be.equal(TWO_ADDRESS);
  });

  it('Update discount rate strategy from gho manager without admin role (revert expected)', async function () {
    const { variableDebtToken, deployer, discountRateStrategy, ghoManager } = testEnv;

    await expect(
      ghoManager
        .connect(randomSigner)
        .updateDiscountRateStrategy(variableDebtToken.address, ONE_ADDRESS)
    ).to.be.revertedWith(ProtocolErrors.CALLER_NOT_RISK_OR_POOL_ADMIN);
  });

  it('Set Rebalance Lock Period', async function () {
    const { ghoManager, deployer, variableDebtToken } = testEnv;

    await expect(
      ghoManager.connect(deployer.signer).updateDiscountLockPeriod(variableDebtToken.address, 3)
    )
      .to.emit(variableDebtToken, 'DiscountLockPeriodUpdated')
      .withArgs(ghoReserveConfig.DISCOUNT_LOCK_PERIOD, 3);
  });

  it('Get Rebalance Lock Period', async function () {
    const { variableDebtToken } = testEnv;
    expect(await variableDebtToken.getDiscountLockPeriod()).to.be.equal(3);
  });

  it('Updates gho interest rate strategy', async function () {
    const { variableDebtToken, gho, poolAdmin } = testEnv;
    const randomAddress = ONE_ADDRESS;
    await expect(
      poolConfigurator
        .connect(poolAdmin.signer)
        .setReserveInterestRateStrategyAddress(gho.address, randomAddress)
    ).to.emit(poolConfigurator, 'ReserveInterestRateStrategyChanged');
  });

  it('Check gho interest rate strategy is set correctly', async function () {
    const { variableDebtToken, gho, poolAdmin, aaveDataProvider } = testEnv;
    const randomAddress = ONE_ADDRESS;
    await expect(await aaveDataProvider.getInterestRateStrategyAddress(gho.address)).to.be.equal(
      randomAddress
    );
  });

  it('Check permissions of onlyGhoManager modified functions (revert expected)', async () => {
    const { variableDebtToken, users, ghoManager } = testEnv;
    const nonPoolAdmin = users[2];

    const randomAddress = ONE_ADDRESS;
    const randomNumber = '0';
    const calls = [
      { fn: 'updateDiscountRateStrategy', args: [variableDebtToken.address, randomAddress] },
      { fn: 'updateDiscountLockPeriod', args: [variableDebtToken.address, randomNumber] },
    ];
    for (const call of calls) {
      await expect(
        ghoManager.connect(nonPoolAdmin.signer)[call.fn](...call.args)
      ).to.be.revertedWith(ProtocolErrors.CALLER_NOT_RISK_OR_POOL_ADMIN);
    }
  });
});
