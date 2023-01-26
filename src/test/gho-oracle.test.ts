import hre from 'hardhat';
import { expect } from 'chai';
import { makeSuite, TestEnv } from './helpers/make-suite';
import './helpers/math/wadraymath';

makeSuite('AaveOracle', (testEnv: TestEnv) => {
  let ethers;

  const GHO_ORACLE_DECIMALS = 8;

  let ghoPrice;

  before(async () => {
    ethers = hre.ethers;

    ghoPrice = ethers.utils.parseUnits('1', 8);
  });

  it('Check initial config params of GHO oracle', async () => {
    const { ghoOracle } = testEnv;

    expect(await ghoOracle.decimals()).to.equal(GHO_ORACLE_DECIMALS);
  });

  it('Check price of GHO via GHO oracle', async () => {
    const { ghoOracle } = testEnv;

    expect(await ghoOracle.latestAnswer()).to.equal(ghoPrice);
  });

  it('Check price of GHO via AaveOracle', async () => {
    const { aaveOracle, gho } = testEnv;

    expect(await aaveOracle.getAssetPrice(gho.address)).to.equal(ghoPrice);
  });
});
