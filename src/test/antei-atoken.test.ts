import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { aaveMarketAddresses } from '../helpers/config';

makeSuite('Antei AToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('Checks initial parameters', async function () {
    const { aToken, asd } = testEnv;
    expect(await aToken.ADDRESSES_PROVIDER()).to.be.equal(aaveMarketAddresses.addressesProvider);
    expect(await aToken.UNDERLYING_ASSET_ADDRESS()).to.be.equal(asd.address);
    expect(await aToken.ATOKEN_REVISION()).to.be.equal(2);
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
});
