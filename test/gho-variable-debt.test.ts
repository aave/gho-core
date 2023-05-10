import hre from 'hardhat';
import { expect } from 'chai';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { impersonateAccountHardhat } from '../helpers/misc-utils';
import { ONE_ADDRESS, ZERO_ADDRESS } from '../helpers/constants';
import { GhoVariableDebtToken__factory } from '../types';
import { ProtocolErrors } from '@aave/core-v3';
import {
  INITIALIZED,
  CALLER_NOT_DISCOUNT_TOKEN,
  CALLER_NOT_A_TOKEN,
  ZERO_ADDRESS_NOT_VALID,
} from './helpers/constants';

makeSuite('Gho VariableDebtToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  let poolSigner;

  const testAddressOne = '0x2acAb3DEa77832C09420663b0E1cB386031bA17B';
  const testAddressTwo = '0x6fC355D4e0EE44b292E50878F49798ff755A5bbC';

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
    ).to.be.revertedWith(ProtocolErrors.POOL_ADDRESSES_DO_NOT_MATCH);
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
        ProtocolErrors.OPERATION_NOT_SUPPORTED
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
      ).to.be.revertedWith(ProtocolErrors.CALLER_MUST_BE_POOL);
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
    ];
    for (const call of calls) {
      await expect(
        variableDebtToken.connect(nonPoolAdmin.signer)[call.fn](...call.args)
      ).to.be.revertedWith(ProtocolErrors.CALLER_NOT_POOL_ADMIN);
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

  it('Set ZERO address as AToken (revert expected)', async function () {
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

  it('Set AToken - already set (revert expected)', async function () {
    const { variableDebtToken, poolAdmin } = testEnv;

    await expect(
      variableDebtToken.connect(poolAdmin.signer).setAToken(ONE_ADDRESS)
    ).to.be.revertedWith('ATOKEN_ALREADY_SET');
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

  it('Set ZERO address as Discount Strategy (revert expected)', async function () {
    const { variableDebtToken, deployer } = testEnv;

    await expect(
      variableDebtToken.connect(deployer.signer).updateDiscountRateStrategy(ZERO_ADDRESS)
    ).to.be.revertedWith(ZERO_ADDRESS_NOT_VALID);
  });

  it('Set Discount Strategy - not permissioned (revert expected)', async function () {
    const { variableDebtToken } = testEnv;

    const randomSigner = await impersonateAccountHardhat(testAddressTwo);
    await expect(
      variableDebtToken.connect(randomSigner).updateDiscountRateStrategy(ONE_ADDRESS)
    ).to.be.revertedWith(ProtocolErrors.CALLER_NOT_POOL_ADMIN);
  });

  it('Set ZERO address as Discount Token (revert expected)', async function () {
    const { variableDebtToken, deployer } = testEnv;

    await expect(
      variableDebtToken.connect(deployer.signer).updateDiscountToken(ZERO_ADDRESS)
    ).to.be.revertedWith(ZERO_ADDRESS_NOT_VALID);
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

  it('Set Discount Token - not permissioned (revert expected)', async function () {
    const { variableDebtToken } = testEnv;

    const randomSigner = await impersonateAccountHardhat(testAddressTwo);
    await expect(
      variableDebtToken.connect(randomSigner).updateDiscountToken(ONE_ADDRESS)
    ).to.be.revertedWith(ProtocolErrors.CALLER_NOT_POOL_ADMIN);
  });
});
