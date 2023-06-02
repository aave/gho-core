import hre from 'hardhat';
import { expect } from 'chai';
import { makeSuite, TestEnv } from './helpers/make-suite';
import {
  advanceTimeAndBlock,
  impersonateAccountHardhat,
  mine,
  setBlocktime,
  timeLatest,
} from '../helpers/misc-utils';
import { ONE_ADDRESS } from '../helpers/constants';
import { ProtocolErrors } from '@aave/core-v3';
import { evmRevert, evmSnapshot, getPoolConfiguratorProxy } from '@aave/deploy-v3';
import { BigNumber } from 'ethers';
import { GhoInterestRateStrategy__factory } from '../types';

export const TWO_ADDRESS = '0x0000000000000000000000000000000000000002';

makeSuite('Gho Steward End-To-End', (testEnv: TestEnv) => {
  let ethers;

  let poolSigner;
  let randomSigner;
  let poolConfigurator;

  const BUCKET_MANAGER_ROLE = hre.ethers.utils.id('BUCKET_MANAGER_ROLE');

  before(async () => {
    ethers = hre.ethers;

    const { pool } = testEnv;

    poolSigner = await impersonateAccountHardhat(pool.address);
    randomSigner = await impersonateAccountHardhat(ONE_ADDRESS);
    poolConfigurator = await getPoolConfiguratorProxy();
  });

  it('Check GhoSteward is PoolAdmin and BucketManager', async function () {
    const { gho, ghoSteward, aclManager } = testEnv;
    expect(await aclManager.isPoolAdmin(ghoSteward.address)).to.be.equal(true);
    expect(await gho.hasRole(BUCKET_MANAGER_ROLE, ghoSteward.address)).to.be.equal(true);
  });

  it('Extends steward expiration', async function () {
    const { ghoSteward } = testEnv;

    const expirationTimeBefore = await ghoSteward.getStewardExpiration();
    const newExpirationTime = BigNumber.from(expirationTimeBefore).add(
      await ghoSteward.STEWARD_LIFESPAN()
    );

    const shortExecutorAddress = await ghoSteward.AAVE_SHORT_EXECUTOR();
    const shortExecutor = await impersonateAccountHardhat(shortExecutorAddress);
    await expect(ghoSteward.connect(shortExecutor).extendStewardExpiration())
      .to.emit(ghoSteward, 'StewardExpirationUpdated')
      .withArgs(expirationTimeBefore, newExpirationTime);

    expect(await ghoSteward.getStewardExpiration()).to.be.eq(newExpirationTime.toNumber());
  });

  it('Tries to extend steward expiration with no authorization (revert expected)', async function () {
    const { ghoSteward, users } = testEnv;
    const nonPoolAdmin = users[2];

    await expect(
      ghoSteward.connect(nonPoolAdmin.signer).extendStewardExpiration()
    ).to.be.revertedWith('ONLY_SHORT_EXECUTOR');
  });

  it('Updates gho variable borrow rate', async function () {
    const { ghoSteward, poolAdmin, aaveDataProvider, gho, deployer } = testEnv;
    const oldInterestRateStrategyAddress = await aaveDataProvider.getInterestRateStrategyAddress(
      gho.address
    );
    const oldRate = await GhoInterestRateStrategy__factory.connect(
      oldInterestRateStrategyAddress,
      deployer.signer
    ).getBaseVariableBorrowRate();
    await advanceTimeAndBlock((await ghoSteward.MINIMUM_DELAY()).toNumber());
    await expect(ghoSteward.connect(poolAdmin.signer).updateBorrowRate(oldRate)).to.emit(
      poolConfigurator,
      'ReserveInterestRateStrategyChanged'
    );

    expect(await aaveDataProvider.getInterestRateStrategyAddress(gho.address)).not.to.be.equal(
      oldInterestRateStrategyAddress
    );
  });

  it('GhoSteward tries to update gho variable borrow rate without PoolAdmin role (revert expected)', async function () {
    const { ghoSteward, poolAdmin, aclAdmin, aclManager, aaveDataProvider, deployer, gho } =
      testEnv;

    const snapId = await evmSnapshot();

    const oldInterestRateStrategyAddress = await aaveDataProvider.getInterestRateStrategyAddress(
      gho.address
    );
    const oldRate = await GhoInterestRateStrategy__factory.connect(
      oldInterestRateStrategyAddress,
      deployer.signer
    ).getBaseVariableBorrowRate();
    await advanceTimeAndBlock((await ghoSteward.MINIMUM_DELAY()).toNumber());

    expect(await aclManager.connect(aclAdmin.signer).removePoolAdmin(ghoSteward.address));
    expect(await aclManager.isPoolAdmin(ghoSteward.address)).to.be.false;

    await expect(ghoSteward.connect(poolAdmin.signer).updateBorrowRate(oldRate)).to.be.revertedWith(
      ProtocolErrors.CALLER_NOT_RISK_OR_POOL_ADMIN
    );

    await evmRevert(snapId);
  });

  it('Updates facilitator bucket', async function () {
    const { ghoSteward, poolAdmin, gho, aToken } = testEnv;

    const [oldCapacity] = await gho.getFacilitatorBucket(aToken.address);
    await advanceTimeAndBlock((await ghoSteward.MINIMUM_DELAY()).toNumber());
    await expect(ghoSteward.connect(poolAdmin.signer).updateBucketCapacity(oldCapacity.add(1)))
      .to.emit(gho, 'FacilitatorBucketCapacityUpdated')
      .withArgs(aToken.address, oldCapacity, oldCapacity.add(1));
  });

  it('GhoSteward tries to update bucket capacity without BucketManager role (revert expected)', async function () {
    const { ghoSteward, poolAdmin, gho, deployer, aToken } = testEnv;

    const snapId = await evmSnapshot();

    const [oldCapacity] = await gho.getFacilitatorBucket(aToken.address);
    await advanceTimeAndBlock((await ghoSteward.MINIMUM_DELAY()).toNumber());
    expect(await gho.connect(deployer.signer).revokeRole(BUCKET_MANAGER_ROLE, ghoSteward.address));
    expect(await gho.hasRole(BUCKET_MANAGER_ROLE, ghoSteward.address)).to.be.false;

    await expect(
      ghoSteward.connect(poolAdmin.signer).updateBucketCapacity(oldCapacity)
    ).to.be.revertedWith(
      `AccessControl: account ${ghoSteward.address.toLowerCase()} is missing role ${BUCKET_MANAGER_ROLE}`
    );

    await evmRevert(snapId);
  });

  it('Check permissions of owner modified functions (revert expected)', async () => {
    const { users, ghoSteward } = testEnv;
    const nonPoolAdmin = users[2];

    const calls = [
      { fn: 'updateBorrowRate', args: [0] },
      { fn: 'updateBucketCapacity', args: [ONE_ADDRESS] },
    ];
    for (const call of calls) {
      await expect(
        ghoSteward.connect(nonPoolAdmin.signer)[call.fn](...call.args)
      ).to.be.revertedWith('INVALID_CALLER');
    }
  });

  it('RiskCouncil updates both parameters, steward expires, expiration time extends, more updates', async function () {
    const { ghoSteward, poolAdmin, gho, aToken, aaveDataProvider, deployer } = testEnv;

    const oldInterestRateStrategyAddress = await aaveDataProvider.getInterestRateStrategyAddress(
      gho.address
    );
    const oldRate = await GhoInterestRateStrategy__factory.connect(
      oldInterestRateStrategyAddress,
      deployer.signer
    ).getBaseVariableBorrowRate();
    const [oldCapacity] = await gho.getFacilitatorBucket(aToken.address);
    await advanceTimeAndBlock((await ghoSteward.MINIMUM_DELAY()).toNumber());

    // Update Bucket Capacity
    await expect(ghoSteward.connect(poolAdmin.signer).updateBucketCapacity(oldCapacity.add(1)));
    expect((await ghoSteward.getTimelock()).bucketCapacityLastUpdated).to.be.eq(await timeLatest());
    // Update Borrow Rate
    await expect(ghoSteward.connect(poolAdmin.signer).updateBorrowRate(oldRate));
    expect((await ghoSteward.getTimelock()).borrowRateLastUpdated).to.be.eq(await timeLatest());

    // Advance until expiration
    await setBlocktime(await ghoSteward.getStewardExpiration());
    await mine();

    // Tries to update bucket capacity or borrow rate
    await expect(
      ghoSteward.connect(poolAdmin.signer).updateBucketCapacity(oldCapacity)
    ).to.be.revertedWith('STEWARD_EXPIRED');
    await expect(ghoSteward.connect(poolAdmin.signer).updateBorrowRate(oldRate)).to.be.revertedWith(
      'STEWARD_EXPIRED'
    );

    // Extend
    const shortExecutorAddress = await ghoSteward.AAVE_SHORT_EXECUTOR();
    const shortExecutor = await impersonateAccountHardhat(shortExecutorAddress);
    await expect(ghoSteward.connect(shortExecutor).extendStewardExpiration()).to.emit(
      ghoSteward,
      'StewardExpirationUpdated'
    );

    // New updates are possible
    await expect(ghoSteward.connect(poolAdmin.signer).updateBucketCapacity(oldCapacity.add(1)));
    expect((await ghoSteward.getTimelock()).bucketCapacityLastUpdated).to.be.eq(await timeLatest());
    // Update Borrow Rate
    await expect(ghoSteward.connect(poolAdmin.signer).updateBorrowRate(oldRate));
    expect((await ghoSteward.getTimelock()).borrowRateLastUpdated).to.be.eq(await timeLatest());
  });

  it('Deactivate Steward', async function () {
    const { gho, ghoSteward, aclManager, deployer } = testEnv;
    expect(await aclManager.isPoolAdmin(ghoSteward.address)).to.be.equal(true);
    expect(await gho.hasRole(BUCKET_MANAGER_ROLE, ghoSteward.address)).to.be.equal(true);

    expect(await aclManager.connect(deployer.signer).removePoolAdmin(ghoSteward.address));
    expect(await gho.connect(deployer.signer).revokeRole(BUCKET_MANAGER_ROLE, ghoSteward.address));

    expect(await aclManager.isPoolAdmin(ghoSteward.address)).to.be.equal(false);
    expect(await gho.hasRole(BUCKET_MANAGER_ROLE, ghoSteward.address)).to.be.equal(false);
  });
});
