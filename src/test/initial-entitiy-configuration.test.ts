import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { ZERO_ADDRESS } from '../helpers/constants';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { ghoEntityConfig } from '../helpers/config';

makeSuite('Initial GHO Aave Entity Configuration', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('Aave entity data check', async function () {
    const { gho, aToken, variableDebtToken } = testEnv;
    const aaveFacilitator = await gho.getFacilitator(aToken.address);

    const { label, capacity, level } = aaveFacilitator;

    expect(label).to.be.equal(ghoEntityConfig.label);
    expect(capacity).to.be.equal(ghoEntityConfig.mintLimit);
  });
});
