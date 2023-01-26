import hre from 'hardhat';
import { expect } from 'chai';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { ghoEntityConfig } from '../helpers/config';

makeSuite('Initial GHO Aave Entity Configuration', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = hre.ethers;
  });

  it('Aave entity data check', async function () {
    const { gho, aToken } = testEnv;
    const aaveFacilitator = await gho.getFacilitator(aToken.address);

    const { label, bucketCapacity, bucketLevel } = aaveFacilitator;

    expect(label).to.be.equal(ghoEntityConfig.label);
    expect(bucketCapacity).to.be.equal(ghoEntityConfig.mintLimit);
    expect(bucketLevel).to.be.equal(0);
  });
});
