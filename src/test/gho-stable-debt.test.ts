import hre from 'hardhat';
import { expect } from 'chai';
import { ProtocolErrors } from '@aave/core-v3';
import { impersonateAccountHardhat } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { ONE_ADDRESS, ZERO_ADDRESS } from '../helpers/constants';
import { GhoStableDebtToken__factory } from '../../types';
import { INITIALIZED } from './helpers/constants';

makeSuite('Gho StableDebtToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  let poolSigner;

  before(async () => {
    ethers = hre.ethers;

    const { pool } = testEnv;
    poolSigner = await impersonateAccountHardhat(pool.address);
  });

  it('Initialize when already initialized (revert expected)', async function () {
    const { stableDebtToken } = testEnv;
    await expect(
      stableDebtToken.initialize(ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, 0, 'test', 'test', [])
    ).to.be.revertedWith(INITIALIZED);
  });

  it('Initialize with incorrect pool (revert expected)', async function () {
    const { deployer, pool } = testEnv;
    const stableDebtToken = await new GhoStableDebtToken__factory(deployer.signer).deploy(
      pool.address
    );

    await expect(
      stableDebtToken.initialize(ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, 0, 'test', 'test', [])
    ).to.be.revertedWith(ProtocolErrors.POOL_ADDRESSES_DO_NOT_MATCH);
  });

  it('Checks initial parameters', async function () {
    const { stableDebtToken, gho } = testEnv;
    expect(await stableDebtToken.UNDERLYING_ASSET_ADDRESS()).to.be.equal(gho.address);
    expect(await stableDebtToken.DEBT_TOKEN_REVISION()).to.be.equal(1);
  });

  it('Check permission of onlyPool modified functions (revert expected)', async () => {
    const { stableDebtToken, users } = testEnv;
    const nonPoolAdmin = users[2];

    const randomAddress = ONE_ADDRESS;
    const randomNumber = '0';
    const calls = [
      { fn: 'mint', args: [randomAddress, randomAddress, randomNumber, randomNumber] },
      { fn: 'burn', args: [randomAddress, randomNumber] },
    ];
    for (const call of calls) {
      await expect(
        stableDebtToken.connect(nonPoolAdmin.signer)[call.fn](...call.args)
      ).to.be.revertedWith(ProtocolErrors.CALLER_MUST_BE_POOL);
    }
  });

  it('Check operations not permitted (revert expected)', async () => {
    const { stableDebtToken } = testEnv;

    const randomAddress = ONE_ADDRESS;
    const randomNumber = '0';
    const calls = [
      { fn: 'mint', args: [randomAddress, randomAddress, randomNumber, randomNumber] },
      { fn: 'burn', args: [randomAddress, randomNumber] },
      { fn: 'transfer', args: [randomAddress, randomNumber] },
      { fn: 'allowance', args: [randomAddress, randomAddress] },
      { fn: 'approve', args: [randomAddress, randomNumber] },
      { fn: 'transferFrom', args: [randomAddress, randomAddress, randomNumber] },
      { fn: 'increaseAllowance', args: [randomAddress, randomNumber] },
      { fn: 'decreaseAllowance', args: [randomAddress, randomNumber] },
    ];
    for (const call of calls) {
      await expect(stableDebtToken.connect(poolSigner)[call.fn](...call.args)).to.be.revertedWith(
        ProtocolErrors.OPERATION_NOT_SUPPORTED
      );
    }
  });

  // it('Mint or Burn GhoStableDebtToken by PoolAdmin - not permissioned (revert expected)', async function () {
  //   const { aToken, users } = testEnv;

  //   await expect(
  //     aToken.connect(users[5].signer).burn(testAddressOne, testAddressOne, 1000, 1)
  //   ).to.be.revertedWith(ProtocolErrors.CALLER_MUST_BE_POOL);
  // });

  it('User nonces - always zero', async function () {
    const { stableDebtToken, users } = testEnv;

    for (const user of users) {
      await expect(await stableDebtToken.nonces(user.address)).to.be.eq(0);
    }
  });
});
