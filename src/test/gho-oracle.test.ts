import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { aaveMarketAddresses } from '../helpers/config';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';

const ETH_USD_ORACLE_DECIMALS = 8;
const GHO_ETH_ORACLE_DECIMALS = 18;

makeSuite('AaveOracle', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('Check initial config params of GHO oracle', async () => {
    const { ghoOracle } = testEnv;

    expect(await ghoOracle.ETH_USD_ORACLE()).to.equal(
      ethers.utils.getAddress(aaveMarketAddresses.ethUsdOracle)
    );
    expect(await ghoOracle.ETH_USD_ORACLE_DECIMALS()).to.equal(ETH_USD_ORACLE_DECIMALS);
    expect(await ghoOracle.GHO_ETH_ORACLE_DECIMALS()).to.equal(GHO_ETH_ORACLE_DECIMALS);
    expect(await ghoOracle.NUMERATOR()).to.equal(
      BigNumber.from(10).pow(ETH_USD_ORACLE_DECIMALS + GHO_ETH_ORACLE_DECIMALS)
    );
  });

  it('Check price of GHO via GHO oracle', async () => {
    const { ghoOracle, ethUsdOracle } = testEnv;

    const ethPrice = await ethUsdOracle.latestAnswer();
    const expectedGhoPrice = BigNumber.from(10)
      .pow(ETH_USD_ORACLE_DECIMALS + GHO_ETH_ORACLE_DECIMALS)
      .div(ethPrice);

    expect(await ghoOracle.latestAnswer()).to.equal(expectedGhoPrice);
  });

  it('Check price of GHO via AaveOracle', async () => {
    const { aaveOracle, ethUsdOracle, gho } = testEnv;

    const ethPrice = await ethUsdOracle.latestAnswer();
    const expectedGhoPrice = BigNumber.from(10)
      .pow(ETH_USD_ORACLE_DECIMALS + GHO_ETH_ORACLE_DECIMALS)
      .div(ethPrice);

    expect(await aaveOracle.getAssetPrice(gho.address)).to.equal(expectedGhoPrice);
  });
});
