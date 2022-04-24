import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { aaveMarketAddresses } from '../helpers/config';

makeSuite('Antei VariableDebtToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('Get AddressesProvider', async function () {
    const { variableDebtToken } = testEnv;
    const addressProviderAddress = await variableDebtToken.ADDRESSES_PROVIDER();
    expect(addressProviderAddress).to.be.equal(aaveMarketAddresses.addressesProvider);
  });

  it('Get AToken', async function () {
    const { variableDebtToken, aToken } = testEnv;
    const aTokenAddress = await variableDebtToken.getAToken();
    expect(aTokenAddress).to.be.equal(aToken.address);
  });
});
