import { expect } from 'chai';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { DRE } from '../helpers/misc-utils';

import { MockFlashBorrower__factory } from '../../types';
import { oneRay, ZERO_ADDRESS } from '../helpers/constants';
import { aaveMarketAddresses, ghoEntityConfig } from '../helpers/config';

makeSuite('Gho FlashMinter', (testEnv: TestEnv) => {
  let ethers;

  let flashBorrower;

  let collateralAmount;
  let borrowAmount;

  let feeAmount;

  let tx;

  before(async () => {
    ethers = DRE.ethers;

    const { deployer, flashMinter } = testEnv;

    const flashBorrowerFactory = new MockFlashBorrower__factory(deployer.signer);
    flashBorrower = await flashBorrowerFactory.deploy(flashMinter.address);

    collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    borrowAmount = ethers.utils.parseUnits('1000.0', 18);

    feeAmount = ethers.utils.parseUnits('10.0', 18);
  });

  it('Check flashmint fee', async function () {
    const { flashMinter } = testEnv;

    expect(await flashMinter.getFee()).to.be.equal(100);
  });

  it('Fund FlashBorrower To Repay FlashMint Fees', async function () {
    const { users, pool, weth, gho, variableDebtToken } = testEnv;

    await weth.connect(users[0].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[0].signer)
      .deposit(weth.address, collateralAmount, users[0].address, 0);
    tx = await pool
      .connect(users[0].signer)
      .borrow(gho.address, borrowAmount, 2, 0, users[0].address);

    await gho.connect(users[0].signer).transfer(flashBorrower.address, feeAmount);

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(feeAmount);
  });

  it('Flashmint 1000 GHO', async function () {
    const { flashMinter, gho } = testEnv;

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(feeAmount);

    tx = await flashBorrower.flashBorrow(gho.address, borrowAmount);

    expect(tx)
      .to.emit(flashMinter, 'FlashMint')
      .withArgs(flashBorrower.address, flashBorrower.address, gho.address, borrowAmount, feeAmount);

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(0);
    expect(await gho.balanceOf(aaveMarketAddresses.treasury)).to.be.equal(feeAmount);
  });

  it('Flashmint 1 Billion GHO - expect revert', async function () {
    const { flashMinter, gho } = testEnv;

    const oneBillion = ethers.utils.parseUnits('1000000000', 18);

    await expect(flashBorrower.flashBorrow(gho.address, oneBillion)).to.be.revertedWith(
      'FACILITATOR_BUCKET_CAPACITY_EXCEEDED'
    );
  });

  it('Update Fee - not permissionned (expect revert)', async function () {
    const { flashMinter, users } = testEnv;

    await expect(flashMinter.connect(users[0].signer).updateFee(200)).to.be.revertedWith(
      'CALLER_NOT_POOL_ADMIN'
    );
  });

  it('Update Fee', async function () {
    const { flashMinter, poolAdmin } = testEnv;

    console.log(poolAdmin.address);

    tx = await flashMinter.connect(poolAdmin.signer).updateFee(200);
    expect(tx).to.emit(flashMinter, 'FeeUpdated').withArgs(100, 200);
  });

  it('MaxFlashLoan', async function () {
    const { flashMinter, gho } = testEnv;

    expect(await flashMinter.maxFlashLoan(gho.address)).to.be.equal(ghoEntityConfig.flashMinterMax);
  });
});
