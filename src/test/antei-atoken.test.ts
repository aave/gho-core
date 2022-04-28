import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { aaveMarketAddresses } from '../helpers/aave-v2-addresses';

makeSuite('Antei AToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('Get AddressesProvider', async function () {
    const { aToken } = testEnv;
    const addressProviderAddress = await aToken.ADDRESSES_PROVIDER();
    expect(addressProviderAddress).to.be.equal(aaveMarketAddresses.addressesProvider);
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
