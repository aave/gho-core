import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { ZERO_ADDRESS } from '../helpers/constants';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { asdEntityConfig } from '../helpers/config';

makeSuite('Initial ASD Aave Entity Configuration', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('Aave entity data check', async function () {
    const { asd, aToken } = testEnv;
    const { mintLimit } = asdEntityConfig;

    expect(await asd.isEntity(aToken.address)).to.be.true;
    expect(await asd.balanceOf(aToken.address)).to.be.equal(mintLimit);
  });
});
