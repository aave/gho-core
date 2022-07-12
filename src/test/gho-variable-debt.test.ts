import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';

makeSuite('Gho VariableDebtToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('Get AToken', async function () {
    const { variableDebtToken, aToken } = testEnv;
    const aTokenAddress = await variableDebtToken.getAToken();
    expect(aTokenAddress).to.be.equal(aToken.address);
  });

  it('Get Discount Rate Strategy', async function () {
    const { variableDebtToken, discountRateStrategy } = testEnv;
    const discountToken = await variableDebtToken.getDiscountRateStrategy();
    expect(discountToken).to.be.equal(discountRateStrategy.address);
  });
});
