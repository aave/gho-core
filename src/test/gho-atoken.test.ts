import { expect } from 'chai';
import { DRE, impersonateAccountHardhat } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { aaveMarketAddresses } from '../helpers/config';
import { ZERO_ADDRESS, oneRay } from '../helpers/constants';

makeSuite('Gho AToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  const testAddressOne = '0x2acAb3DEa77832C09420663b0E1cB386031bA17B';
  const testAddressTwo = '0x6fC355D4e0EE44b292E50878F49798ff755A5bbC';

  let poolSigner;

  const CALLER_MUST_BE_POOL = '23';
  const CALLER_NOT_POOL_ADMIN = '1';

  let collateralAmount;
  let borrowAmount;

  before(async () => {
    ethers = DRE.ethers;

    const { pool } = testEnv;
    poolSigner = await impersonateAccountHardhat(pool.address);

    collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    borrowAmount = ethers.utils.parseUnits('1000.0', 18);
  });

  it('Checks initial parameters', async function () {
    const { aToken, gho } = testEnv;
    expect(await aToken.UNDERLYING_ASSET_ADDRESS()).to.be.equal(gho.address);
    expect(await aToken.ATOKEN_REVISION()).to.be.equal(1);
  });

  it('Get VariableDebtToken', async function () {
    const { aToken, variableDebtToken } = testEnv;
    const variableDebtTokenAddress = await aToken.getVariableDebtToken();
    expect(variableDebtTokenAddress).to.be.equal(variableDebtToken.address);
  });

  it('Get Treasury', async function () {
    const { aToken } = testEnv;
    const treasuryAddress = await aToken.getGhoTreasury();
    expect(treasuryAddress).to.be.equal(aaveMarketAddresses.treasury);
  });

  it('MintToTreasury - revert expected', async function () {
    const { aToken } = testEnv;

    await expect(aToken.connect(poolSigner).mintToTreasury(100, 10)).to.be.revertedWith(
      'OPERATION_NOT_PERMITTED'
    );
  });

  it('TransferOnLiquidation - revert expected', async function () {
    const { aToken, users } = testEnv;
    await expect(
      aToken.connect(poolSigner).transferOnLiquidation(users[0].address, users[1].address, 20)
    ).to.be.revertedWith('OPERATION_NOT_PERMITTED');
  });

  it('Mint AToken - not permissioned (revert expected)', async function () {
    const { aToken, users } = testEnv;

    await expect(
      aToken.connect(users[5].signer).mint(testAddressOne, testAddressOne, 1000, 1)
    ).to.be.revertedWith(CALLER_MUST_BE_POOL);
  });

  it('Mint AToken - no minting allowed (revert expected)', async function () {
    const { aToken } = testEnv;

    await expect(
      aToken.connect(poolSigner).mint(testAddressOne, testAddressOne, 1000, 1)
    ).to.be.revertedWith('OPERATION_NOT_PERMITTED');
  });

  it('Burn AToken - not permissioned (revert expected)', async function () {
    const { aToken, users } = testEnv;

    await expect(
      aToken.connect(users[5].signer).burn(testAddressOne, testAddressOne, 1000, 1)
    ).to.be.revertedWith(CALLER_MUST_BE_POOL);
  });

  it('Burn AToken - no burning allowed (revert expected)', async function () {
    const { aToken } = testEnv;

    await expect(
      aToken.connect(poolSigner).burn(testAddressOne, testAddressOne, 1000, 1)
    ).to.be.revertedWith('OPERATION_NOT_PERMITTED');
  });

  it('Get VariableDebtToken', async function () {
    const { aToken, variableDebtToken } = testEnv;

    const variableDebtTokenAddress = await aToken.getVariableDebtToken();
    expect(variableDebtTokenAddress).to.be.equal(variableDebtToken.address);
  });

  it('Set Treasury', async function () {
    const { aToken, deployer } = testEnv;

    await expect(aToken.connect(deployer.signer).updateGhoTreasury(testAddressTwo))
      .to.emit(aToken, 'GhoTreasuryUpdated')
      .withArgs(aaveMarketAddresses.treasury, testAddressTwo);
  });

  it('Get Treasury', async function () {
    const { aToken } = testEnv;

    const ghoTreasury = await aToken.getGhoTreasury();
    expect(ghoTreasury).to.be.equal(testAddressTwo);
  });

  it('Set VariableDebtToken - already set (expect revert)', async function () {
    const { aToken } = testEnv;

    await expect(aToken.setVariableDebtToken(testAddressTwo)).to.be.revertedWith(
      'VARIABLE_DEBT_TOKEN_ALREADY_SET'
    );
  });

  it('Set Treasury - not permissioned (expect revert)', async function () {
    const { aToken } = testEnv;

    await expect(
      aToken.connect(poolSigner).updateGhoTreasury(aaveMarketAddresses.treasury)
    ).to.be.revertedWith(CALLER_NOT_POOL_ADMIN);
  });

  it('Total Supply - expect to be max int', async function () {
    const { aToken } = testEnv;

    await expect(await aToken.totalSupply()).to.be.equal(0);
  });

  it('User 1: Deposit WETH and Borrow GHO', async function () {
    const { users, pool, weth, gho, variableDebtToken } = testEnv;

    await weth.connect(users[0].signer).approve(pool.address, collateralAmount);
    await pool
      .connect(users[0].signer)
      .deposit(weth.address, collateralAmount, users[0].address, 0);

    const tx = await pool
      .connect(users[0].signer)
      .borrow(gho.address, borrowAmount, 2, 0, users[0].address);

    expect(tx)
      .to.emit(variableDebtToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, users[0].address, borrowAmount)
      .to.emit(variableDebtToken, 'Mint')
      .withArgs(users[0].address, users[0].address, borrowAmount, 0, oneRay)
      .to.not.emit(variableDebtToken, 'DiscountPercentLocked');

    expect(await gho.balanceOf(users[0].address)).to.be.equal(borrowAmount);
    expect(await variableDebtToken.getBalanceFromInterest(users[0].address)).to.be.equal(0);
    expect(await variableDebtToken.balanceOf(users[0].address)).to.be.equal(borrowAmount);
  });

  it('User 1: Accidentally transfer GHO to AToken', async function () {
    const { users, gho, aToken } = testEnv;

    await gho.connect(users[0].signer).transfer(aToken.address, borrowAmount);
  });

  it('Governance: Rescue too much GHO - (expect revert)', async function () {
    const { users, gho, poolAdmin, aToken } = testEnv;

    await expect(
      aToken.connect(poolAdmin.signer).rescueGho(users[0].address, borrowAmount.add(1))
    ).to.be.revertedWith('RESCUING_TOO_MUCH_GHO');

    await expect(await gho.balanceOf(users[0].address)).to.be.equal(0);
    await expect(await gho.balanceOf(aToken.address)).to.be.equal(borrowAmount);
  });

  it('Governance: Rescue GHO', async function () {
    const { users, poolAdmin, gho, aToken } = testEnv;

    const tx = await aToken.connect(poolAdmin.signer).rescueGho(users[0].address, borrowAmount);

    await expect(tx)
      .to.emit(gho, 'Transfer')
      .withArgs(aToken.address, users[0].address, borrowAmount);

    await expect(await gho.balanceOf(users[0].address)).to.be.equal(borrowAmount);
    await expect(await gho.balanceOf(aToken.address)).to.be.equal(0);
  });
});
