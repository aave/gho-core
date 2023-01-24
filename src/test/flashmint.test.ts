import { expect } from 'chai';
import { ONE_ADDRESS } from '@aave/deploy-v3';
import { PANIC_CODES } from '@nomicfoundation/hardhat-chai-matchers/panic';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { DRE } from '../helpers/misc-utils';
import { MockFlashBorrower__factory, GhoFlashMinter__factory } from '../../types';
import { ZERO_ADDRESS } from '../helpers/constants';
import { ghoEntityConfig } from '../helpers/config';

import './helpers/math/wadraymath';
import { mintErc20 } from './helpers/user-setup';

makeSuite('Gho FlashMinter', (testEnv: TestEnv) => {
  let ethers;
  let flashBorrower;
  let flashFee;
  let tx;

  before(async () => {
    ethers = DRE.ethers;

    const { deployer, flashMinter } = testEnv;

    const flashBorrowerFactory = new MockFlashBorrower__factory(deployer.signer);
    flashBorrower = await flashBorrowerFactory.deploy(flashMinter.address);

    flashFee = ghoEntityConfig.flashMinterFee;
  });

  it('Check flashmint percentage fee', async function () {
    const { flashMinter } = testEnv;

    expect(await flashMinter.getFee()).to.be.equal(100);
  });

  it('Check flashmint fee', async function () {
    const { flashMinter, gho } = testEnv;

    const borrowAmount = ethers.utils.parseUnits('1000.0', 18);
    const expectedFeeAmount = borrowAmount.percentMul(flashFee);

    expect(await flashMinter.flashFee(gho.address, borrowAmount)).to.be.equal(expectedFeeAmount);
  });

  it('Check flashmint fee As Approved FlashBorrower', async function () {
    const { flashMinter, gho, aclAdmin, aclManager } = testEnv;

    const borrowAmount = ethers.utils.parseUnits('1000.0', 18);
    expect(await flashMinter.flashFee(gho.address, borrowAmount)).to.be.not.eq(0);

    expect(await aclManager.isFlashBorrower(flashMinter.address)).to.be.false;
    await aclManager.connect(aclAdmin.signer).addFlashBorrower(flashMinter.address);
    expect(await aclManager.isFlashBorrower(flashMinter.address)).to.be.true;

    expect(
      await flashMinter.connect(flashMinter.signer).flashFee(gho.address, borrowAmount)
    ).to.be.not.eq(0);
  });

  it('Fund FlashBorrower To Repay FlashMint Fees', async function () {
    const { users, pool, weth, gho } = testEnv;

    const collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    const borrowAmount = ethers.utils.parseUnits('1000.0', 18);
    const expectedFee = borrowAmount.percentMul(flashFee);

    await weth.connect(users[0].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[0].signer)
      .deposit(weth.address, collateralAmount, users[0].address, 0);
    tx = await pool
      .connect(users[0].signer)
      .borrow(gho.address, borrowAmount, 2, 0, users[0].address);

    await gho.connect(users[0].signer).transfer(flashBorrower.address, expectedFee);

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(expectedFee);
  });

  it('Flashmint 1000 GHO', async function () {
    const { flashMinter, gho } = testEnv;

    const borrowAmount = ethers.utils.parseUnits('1000.0', 18);
    const expectedFeeAmount = borrowAmount.percentMul(flashFee);

    tx = await flashBorrower.flashBorrow(gho.address, borrowAmount);

    expect(tx)
      .to.emit(flashMinter, 'FlashMint')
      .withArgs(
        flashBorrower.address,
        flashBorrower.address,
        gho.address,
        borrowAmount,
        expectedFeeAmount
      );

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(0);
    expect(await gho.balanceOf(flashMinter.address)).to.be.equal(expectedFeeAmount);
  });

  it('Flashmint 1000 GHO As Approved FlashBorrower', async function () {
    const { flashMinter, gho, aclAdmin, aclManager } = testEnv;

    expect(await aclManager.isFlashBorrower(flashBorrower.address)).to.be.false;
    await aclManager.connect(aclAdmin.signer).addFlashBorrower(flashBorrower.address);
    expect(await aclManager.isFlashBorrower(flashBorrower.address)).to.be.true;

    // fee should be zero since msg.sender will be an approved FlashBorrower
    const expectedFee = 0;

    const initialFlashMinterBalance = await gho.balanceOf(flashMinter.address);

    const borrowAmount = ethers.utils.parseUnits('1000.0', 18);
    tx = await flashBorrower.flashBorrow(gho.address, borrowAmount);

    expect(tx)
      .to.emit(flashMinter, 'FlashMint')
      .withArgs(
        flashBorrower.address,
        flashBorrower.address,
        gho.address,
        borrowAmount,
        expectedFee
      );

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(0);
    expect(await gho.balanceOf(flashMinter.address)).to.be.equal(initialFlashMinterBalance);

    // remove approved FlashBorrower role for the rest of the tests
    await aclManager.connect(aclAdmin.signer).removeFlashBorrower(flashBorrower.address);
    expect(await aclManager.isFlashBorrower(flashBorrower.address)).to.be.false;
  });

  it('Flashmint 1 Billion GHO - expect revert', async function () {
    const { gho } = testEnv;

    const oneBillion = ethers.utils.parseUnits('1000000000', 18);

    await expect(flashBorrower.flashBorrow(gho.address, oneBillion)).to.be.revertedWith(
      'FACILITATOR_BUCKET_CAPACITY_EXCEEDED'
    );
  });

  it('Fund FlashBorrower To Repay FlashMint Fees (Maximum Bucket Capacity Minus 1)', async function () {
    const { users, flashMinter, pool, weth, gho, faucetOwner, aaveOracle } = testEnv;

    const flashMinterFacilitator = await gho.getFacilitator(flashMinter.address);
    const capacityMinusOne = flashMinterFacilitator.bucketCapacity.sub(1);
    const expectedFee = capacityMinusOne.percentMul(flashFee);

    const ghoPrice = await aaveOracle.getAssetPrice(gho.address);
    const wethPrice = await aaveOracle.getAssetPrice(weth.address);
    const expectedRequiredCollateral = expectedFee.mul(ghoPrice).div(wethPrice).mul(2);
    await mintErc20(faucetOwner, weth.address, [users[0].address], expectedRequiredCollateral);

    await weth.connect(users[0].signer).approve(pool.address, expectedRequiredCollateral);
    await pool
      .connect(users[0].signer)
      .deposit(weth.address, expectedRequiredCollateral, users[0].address, 0);
    tx = await pool
      .connect(users[0].signer)
      .borrow(gho.address, expectedFee, 2, 0, users[0].address);

    await gho.connect(users[0].signer).transfer(flashBorrower.address, expectedFee);

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(expectedFee);
  });

  it('Flashmint Maximum Bucket Capacity Minus 1', async function () {
    const { flashMinter, gho } = testEnv;

    const flashMinterFacilitator = await gho.getFacilitator(flashMinter.address);
    const capacityMinusOne = flashMinterFacilitator.bucketCapacity.sub(1);
    const expectedFee = capacityMinusOne.percentMul(flashFee);

    const initialFlashMinterBalance = await gho.balanceOf(flashMinter.address);

    tx = await flashBorrower.flashBorrow(gho.address, capacityMinusOne);

    expect(tx)
      .to.emit(flashMinter, 'FlashMint')
      .withArgs(
        flashBorrower.address,
        flashBorrower.address,
        gho.address,
        capacityMinusOne,
        expectedFee
      );

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(0);
    expect(await gho.balanceOf(flashMinter.address)).to.be.equal(
      initialFlashMinterBalance.add(expectedFee)
    );
  });

  it('Fund FlashBorrower To Repay FlashMint Fees (Maximum Bucket Capacity)', async function () {
    const { users, flashMinter, pool, weth, gho, faucetOwner, aaveOracle } = testEnv;

    const flashMinterFacilitator = await gho.getFacilitator(flashMinter.address);
    const capacity = flashMinterFacilitator.bucketCapacity;
    const expectedFee = capacity.percentMul(flashFee);

    const ghoPrice = await aaveOracle.getAssetPrice(gho.address);
    const wethPrice = await aaveOracle.getAssetPrice(weth.address);
    const expectedRequiredCollateral = expectedFee.mul(ghoPrice).div(wethPrice).mul(2);
    await mintErc20(faucetOwner, weth.address, [users[0].address], expectedRequiredCollateral);

    await weth.connect(users[0].signer).approve(pool.address, expectedRequiredCollateral);
    await pool
      .connect(users[0].signer)
      .deposit(weth.address, expectedRequiredCollateral, users[0].address, 0);
    tx = await pool
      .connect(users[0].signer)
      .borrow(gho.address, expectedFee, 2, 0, users[0].address);

    await gho.connect(users[0].signer).transfer(flashBorrower.address, expectedFee);

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(expectedFee);
  });

  it('Flashmint Maximum Bucket Capacity', async function () {
    const { flashMinter, gho } = testEnv;

    const flashMinterFacilitator = await gho.getFacilitator(flashMinter.address);
    const capacity = flashMinterFacilitator.bucketCapacity;
    const expectedFee = capacity.percentMul(flashFee);

    const initialFlashMinterBalance = await gho.balanceOf(flashMinter.address);

    tx = await flashBorrower.flashBorrow(gho.address, capacity);

    expect(tx)
      .to.emit(flashMinter, 'FlashMint')
      .withArgs(flashBorrower.address, flashBorrower.address, gho.address, capacity, expectedFee);

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(0);
    expect(await gho.balanceOf(flashMinter.address)).to.be.equal(
      initialFlashMinterBalance.add(expectedFee)
    );
  });

  it('Flashmint maximum bucket capacity + 1 (expect revert)', async function () {
    const { flashMinter, gho } = testEnv;

    const flashMinterFacilitator = await gho.getFacilitator(flashMinter.address);

    await expect(
      flashBorrower.flashBorrow(gho.address, flashMinterFacilitator.bucketCapacity.add(1))
    ).to.be.revertedWith('FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
  });

  it('MaxFlashLoan', async function () {
    const { flashMinter, gho } = testEnv;

    expect(await flashMinter.maxFlashLoan(gho.address)).to.be.equal(
      ghoEntityConfig.flashMinterCapacity
    );
  });

  it('Change Flashmint Facilitator Max Capacity', async function () {
    const { flashMinter, gho, ghoOwner } = testEnv;

    const reducedCapacity = ghoEntityConfig.flashMinterCapacity.div(5);

    await expect(
      gho
        .connect(ghoOwner.signer)
        .setFacilitatorBucketCapacity(flashMinter.address, reducedCapacity)
    );
    const flashMinterFacilitator = await gho.getFacilitator(flashMinter.address);
    const updatedCapacity = flashMinterFacilitator.bucketCapacity;

    expect(updatedCapacity).to.be.equal(reducedCapacity);
  });

  it('Fund FlashBorrower To Repay FlashMint Fees (New Maximum Bucket Capacity)', async function () {
    const { users, flashMinter, pool, weth, gho, faucetOwner, aaveOracle } = testEnv;

    const flashMinterFacilitator = await gho.getFacilitator(flashMinter.address);
    const capacity = flashMinterFacilitator.bucketCapacity;
    expect(capacity).to.be.lt(ghoEntityConfig.flashMinterCapacity);

    const expectedFee = capacity.percentMul(flashFee);

    const ghoPrice = await aaveOracle.getAssetPrice(gho.address);
    const wethPrice = await aaveOracle.getAssetPrice(weth.address);
    const expectedRequiredCollateral = expectedFee.mul(ghoPrice).div(wethPrice).mul(2);
    await mintErc20(faucetOwner, weth.address, [users[0].address], expectedRequiredCollateral);

    await weth.connect(users[0].signer).approve(pool.address, expectedRequiredCollateral);
    await pool
      .connect(users[0].signer)
      .deposit(weth.address, expectedRequiredCollateral, users[0].address, 0);
    tx = await pool
      .connect(users[0].signer)
      .borrow(gho.address, expectedFee, 2, 0, users[0].address);

    await gho.connect(users[0].signer).transfer(flashBorrower.address, expectedFee);

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(expectedFee);
  });

  it('Flashmint New Maximum Bucket Capacity', async function () {
    const { flashMinter, gho } = testEnv;

    const flashMinterFacilitator = await gho.getFacilitator(flashMinter.address);
    const capacity = flashMinterFacilitator.bucketCapacity;
    const expectedFee = capacity.percentMul(flashFee);

    const initialFlashMinterBalance = await gho.balanceOf(flashMinter.address);

    tx = await flashBorrower.flashBorrow(gho.address, capacity);

    expect(tx)
      .to.emit(flashMinter, 'FlashMint')
      .withArgs(flashBorrower.address, flashBorrower.address, gho.address, capacity, expectedFee);

    expect(await gho.balanceOf(flashBorrower.address)).to.be.equal(0);
    expect(await gho.balanceOf(flashMinter.address)).to.be.equal(
      initialFlashMinterBalance.add(expectedFee)
    );
  });

  it('Flashmint maximum bucket capacity + 1 (expect revert)', async function () {
    const { flashMinter, gho } = testEnv;

    const flashMinterFacilitator = await gho.getFacilitator(flashMinter.address);

    await expect(
      flashBorrower.flashBorrow(gho.address, flashMinterFacilitator.bucketCapacity.add(1))
    ).to.be.revertedWith('FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
  });

  it('FlashMint from a borrower that does not approve the transfer for repayment', async function () {
    const { gho } = testEnv;

    const borrowAmount = ethers.utils.parseUnits('1000.0', 18);

    await flashBorrower.setAllowRepayment(false);

    // expect revert in transfer from `allowed - amount` will cause an error
    await expect(flashBorrower.flashBorrow(gho.address, borrowAmount)).to.be.revertedWithPanic(
      PANIC_CODES.ARITHMETIC_UNDER_OR_OVERFLOW
    );

    await flashBorrower.setAllowRepayment(true);
  });

  it('Update Fee - not permissionned (expect revert)', async function () {
    const { flashMinter, users } = testEnv;

    await expect(flashMinter.connect(users[0].signer).updateFee(200)).to.be.revertedWith(
      'CALLER_NOT_POOL_ADMIN'
    );
  });

  it('Distribute fees to treasury', async function () {
    const { flashMinter, gho, treasuryAddress } = testEnv;

    const flashMinterBalance = await gho.balanceOf(flashMinter.address);

    expect(flashMinterBalance).to.not.be.equal(0);
    expect(await gho.balanceOf(treasuryAddress)).to.be.equal(0);

    const tx = await flashMinter.distributeFeesToTreasury();

    expect(tx)
      .to.emit(flashMinter, 'FeesDistributedToTreasury')
      .withArgs(treasuryAddress, gho.address, flashMinterBalance);

    expect(await gho.balanceOf(treasuryAddress)).to.be.equal(flashMinterBalance);
    expect(await gho.balanceOf(flashMinter.address)).to.be.equal(0);
  });

  it('Update Fee', async function () {
    const { flashMinter, poolAdmin } = testEnv;

    const newFlashFee = 200;

    tx = await flashMinter.connect(poolAdmin.signer).updateFee(newFlashFee);
    expect(tx).to.emit(flashMinter, 'FeeUpdated').withArgs(flashFee, newFlashFee);
  });

  it('Check MaxFee amount', async function () {
    const { flashMinter } = testEnv;

    const expectedMaxFee = ghoEntityConfig.flashMinterMaxFee;
    expect(await flashMinter.MAX_FEE()).to.be.equal(expectedMaxFee);
  });

  it('Update Fee to an invalid amount', async function () {
    const { flashMinter, poolAdmin } = testEnv;

    const maxFee = await flashMinter.MAX_FEE();
    await expect(
      flashMinter.connect(poolAdmin.signer).updateFee(maxFee.add(1000))
    ).to.be.revertedWith('FlashMinter: Fee out of range');
  });

  it('Deploy GhoFlashMinter with an invalid amount', async function () {
    const { gho, poolAdmin, pool, treasuryAddress } = testEnv;

    const addressesProvider = await pool.ADDRESSES_PROVIDER();
    const largeFee = ghoEntityConfig.flashMinterMaxFee.add(100);

    const flashMinterFactory = new GhoFlashMinter__factory(poolAdmin.signer);
    await expect(
      flashMinterFactory.deploy(gho.address, treasuryAddress, largeFee, addressesProvider)
    ).to.be.revertedWith('FlashMinter: Fee out of range');
  });

  it('Get GhoTreasury', async function () {
    const { flashMinter, treasuryAddress } = testEnv;

    expect(await flashMinter.getGhoTreasury()).to.be.equal(treasuryAddress);
  });

  it('Update GhoTreasury - not permissionned (expect revert)', async function () {
    const { flashMinter, users } = testEnv;

    await expect(
      flashMinter.connect(users[0].signer).updateGhoTreasury(ZERO_ADDRESS)
    ).to.be.revertedWith('CALLER_NOT_POOL_ADMIN');
  });

  it('Update GhoTreasury', async function () {
    const { flashMinter, poolAdmin, treasuryAddress } = testEnv;

    expect(await flashMinter.getGhoTreasury()).to.be.not.eq(ZERO_ADDRESS);

    await expect(flashMinter.connect(poolAdmin.signer).updateGhoTreasury(ZERO_ADDRESS))
      .to.emit(flashMinter, 'GhoTreasuryUpdated')
      .withArgs(treasuryAddress, ZERO_ADDRESS);

    expect(await flashMinter.getGhoTreasury()).to.be.equal(ZERO_ADDRESS);
  });

  it('MaxFlashLoan - Address That Is Not GHO', async function () {
    const { flashMinter } = testEnv;

    expect(await flashMinter.maxFlashLoan(ONE_ADDRESS)).to.be.equal(0);
  });
});
