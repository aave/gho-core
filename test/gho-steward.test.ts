import hre from 'hardhat';
import { expect } from 'chai';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { impersonateAccountHardhat } from '../helpers/misc-utils';
import { ONE_ADDRESS, RAY } from '../helpers/constants';
import { ProtocolErrors } from '@aave/core-v3';
import { evmRevert, evmSnapshot, getPoolConfiguratorProxy } from '@aave/deploy-v3';
import { BigNumber } from 'ethers';

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

  it('Updates gho interest rate strategy address', async function () {
    const { ghoSteward, poolAdmin, aaveDataProvider, gho } = testEnv;
    const randomAddress = ONE_ADDRESS;
    await expect(
      ghoSteward.connect(poolAdmin.signer).setReserveInterestRateStrategyAddress(randomAddress)
    ).to.emit(poolConfigurator, 'ReserveInterestRateStrategyChanged');

    expect(await aaveDataProvider.getInterestRateStrategyAddress(gho.address)).to.be.equal(
      randomAddress
    );
  });

  it('GhoSteward tries to update gho interest rate strategy address without PoolAdmin role (revert expected)', async function () {
    const { ghoSteward, poolAdmin, aclAdmin, aclManager } = testEnv;

    const snapId = await evmSnapshot();

    expect(await aclManager.connect(aclAdmin.signer).removePoolAdmin(ghoSteward.address));
    expect(await aclManager.isPoolAdmin(ghoSteward.address)).to.be.false;

    const randomAddress = ONE_ADDRESS;
    await expect(
      ghoSteward.connect(poolAdmin.signer).setReserveInterestRateStrategyAddress(randomAddress)
    ).to.be.revertedWith(ProtocolErrors.CALLER_NOT_RISK_OR_POOL_ADMIN);

    await evmRevert(snapId);
  });

  it('Updates gho variable borrow rate', async function () {
    const { ghoSteward, poolAdmin, aaveDataProvider, gho } = testEnv;
    const newVariableBorrowRate = BigNumber.from(RAY).mul(3);

    const oldInterestRateStrategyAddress = await aaveDataProvider.getInterestRateStrategyAddress(
      gho.address
    );
    await expect(
      ghoSteward.connect(poolAdmin.signer).setReserveVariableBorrowRate(newVariableBorrowRate)
    ).to.emit(poolConfigurator, 'ReserveInterestRateStrategyChanged');

    expect(await aaveDataProvider.getInterestRateStrategyAddress(gho.address)).not.to.be.equal(
      oldInterestRateStrategyAddress
    );
  });

  it('GhoSteward tries to update gho variable borrow rate without PoolAdmin role (revert expected)', async function () {
    const { ghoSteward, poolAdmin, aclAdmin, aclManager } = testEnv;

    const snapId = await evmSnapshot();

    expect(await aclManager.connect(aclAdmin.signer).removePoolAdmin(ghoSteward.address));
    expect(await aclManager.isPoolAdmin(ghoSteward.address)).to.be.false;

    await expect(
      ghoSteward.connect(poolAdmin.signer).setReserveVariableBorrowRate(123)
    ).to.be.revertedWith(ProtocolErrors.CALLER_NOT_RISK_OR_POOL_ADMIN);

    await evmRevert(snapId);
  });

  it('Updates facilitator bucket', async function () {
    const { ghoSteward, poolAdmin, gho, aToken } = testEnv;

    const [oldCapacity] = await gho.getFacilitatorBucket(aToken.address);
    await expect(ghoSteward.connect(poolAdmin.signer).setFacilitatorBucketCapacity(1000))
      .to.emit(gho, 'FacilitatorBucketCapacityUpdated')
      .withArgs(aToken.address, oldCapacity, 1000);
  });

  it('GhoSteward tries to update bucket capacity without BucketManager role (revert expected)', async function () {
    const { ghoSteward, poolAdmin, gho, deployer } = testEnv;

    const snapId = await evmSnapshot();

    expect(await gho.connect(deployer.signer).revokeRole(BUCKET_MANAGER_ROLE, ghoSteward.address));
    expect(await gho.hasRole(BUCKET_MANAGER_ROLE, ghoSteward.address)).to.be.false;

    await expect(
      ghoSteward.connect(poolAdmin.signer).setFacilitatorBucketCapacity(1000)
    ).to.be.revertedWith(
      `AccessControl: account ${ghoSteward.address.toLowerCase()} is missing role ${BUCKET_MANAGER_ROLE}`
    );

    await evmRevert(snapId);
  });

  it('Check permissions of owner modified functions (revert expected)', async () => {
    const { users, ghoSteward } = testEnv;
    const nonPoolAdmin = users[2];

    const randomAddress = ONE_ADDRESS;
    const calls = [
      {
        fn: 'setReserveInterestRateStrategyAddress',
        args: [randomAddress],
      },
      { fn: 'setReserveVariableBorrowRate', args: [0] },
      { fn: 'setFacilitatorBucketCapacity', args: [randomAddress] },
    ];
    for (const call of calls) {
      await expect(
        ghoSteward.connect(nonPoolAdmin.signer)[call.fn](...call.args)
      ).to.be.revertedWith(ProtocolErrors.OWNABLE_ONLY_OWNER);
    }
  });
});
