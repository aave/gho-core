import { expect } from 'chai';
import { DRE, impersonateAccountHardhat } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { aaveMarketAddresses } from '../helpers/config';

makeSuite('Gho AToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('Checks initial parameters', async function () {
    const { aToken, gho } = testEnv;
    expect(await aToken.ADDRESSES_PROVIDER()).to.be.equal(aaveMarketAddresses.addressesProvider);
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
    const treasuryAddress = await aToken.getTreasury();
    expect(treasuryAddress).to.be.equal(aaveMarketAddresses.treasury);
  });

  it('MintToTreasury - revert expected', async function () {
    const { aToken, pool } = testEnv;
    const poolSigner = await impersonateAccountHardhat(pool.address);
    await expect(aToken.connect(poolSigner).mintToTreasury(100, 10)).to.be.revertedWith(
      'OPERATION_NOT_PERMITTED'
    );
  });

  it('TransferOnLiquidation - revert expected', async function () {
    const { aToken, pool, users } = testEnv;
    const poolSigner = await impersonateAccountHardhat(pool.address);
    await expect(
      aToken.connect(poolSigner).transferOnLiquidation(users[0].address, users[1].address, 20)
    ).to.be.revertedWith('OPERATION_NOT_PERMITTED');
  });
});
