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
    const aaveEntity = await gho.getEntityById(1);

    const { label, entityAddress, mintLimit, mintBalance, minters, burners, active } = aaveEntity;

    expect(label).to.be.equal(ghoEntityConfig.label);
    expect(entityAddress).to.be.equal(ZERO_ADDRESS);
    expect(mintLimit).to.be.equal(ghoEntityConfig.mintLimit);
    expect(mintBalance).to.be.equal(0);
    expect(minters.length).to.be.equal(1);
    expect(minters[0]).to.be.equal(aToken.address);
    expect(burners.length).to.be.equal(1);
    expect(burners[0]).to.be.equal(aToken.address);
    expect(active).to.be.true;
  });
});
