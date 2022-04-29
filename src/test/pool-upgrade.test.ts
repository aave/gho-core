import { expect } from 'chai';
import { aaveMarketAddresses } from '../helpers/config';
import { DRE } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';

makeSuite('Check upgraded pool', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('Revision number check', async function () {
    const { pool } = testEnv;

    const revision = await pool.LENDINGPOOL_REVISION();

    expect(revision).to.be.equal(3);
  });

  it('AddressesProvider check', async function () {
    const { pool } = testEnv;

    const addressesProvider = await pool.getAddressesProvider();

    expect(addressesProvider).to.be.equal(aaveMarketAddresses.addressesProvider);
  });
});
