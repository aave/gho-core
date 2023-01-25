import { expect } from 'chai';
import { DRE, impersonateAccountHardhat } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { aaveMarketAddresses } from '../helpers/config';
import { ZERO_ADDRESS } from '../helpers/constants';

makeSuite('Gho AToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  const testAddressOne = '0x2acAb3DEa77832C09420663b0E1cB386031bA17B';
  const testAddressTwo = '0x6fC355D4e0EE44b292E50878F49798ff755A5bbC';

  let poolSigner;

  const CALLER_MUST_BE_POOL = '23';
  const CALLER_NOT_POOL_ADMIN = '1';
  const OPERATION_NOT_SUPPORTED = '80';

  before(async () => {
    ethers = DRE.ethers;

    const { pool } = testEnv;
    poolSigner = await impersonateAccountHardhat(pool.address);
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
      OPERATION_NOT_SUPPORTED
    );
  });

  it('TransferOnLiquidation - revert expected', async function () {
    const { aToken, users } = testEnv;
    await expect(
      aToken.connect(poolSigner).transferOnLiquidation(users[0].address, users[1].address, 20)
    ).to.be.revertedWith(OPERATION_NOT_SUPPORTED);
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
    ).to.be.revertedWith(OPERATION_NOT_SUPPORTED);
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
    ).to.be.revertedWith(OPERATION_NOT_SUPPORTED);
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
});
