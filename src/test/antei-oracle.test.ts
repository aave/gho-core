import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { aaveMarketAddresses } from '../helpers/config';
import { BigNumber } from 'ethers';
import './helpers/math/wadraymath';

const ETH_USD_ORACLE_DECIMALS = 8;
const ASD_ETH_ORACLE_DECIMALS = 18;

makeSuite('AaveOracle', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('Check initial config params of ASD oracle', async () => {
    const { asdOracle } = testEnv;

    expect(await asdOracle.ETH_USD_ORACLE()).to.equal(
      ethers.utils.getAddress(aaveMarketAddresses.ethUsdOracle)
    );
    expect(await asdOracle.ETH_USD_ORACLE_DECIMALS()).to.equal(ETH_USD_ORACLE_DECIMALS);
    expect(await asdOracle.ASD_ETH_ORACLE_DECIMALS()).to.equal(ASD_ETH_ORACLE_DECIMALS);
    expect(await asdOracle.NUMERATOR()).to.equal(
      BigNumber.from(10).pow(ETH_USD_ORACLE_DECIMALS + ASD_ETH_ORACLE_DECIMALS)
    );
  });

  it('Check price of ASD via ASD oracle', async () => {
    const { asdOracle, ethUsdOracle } = testEnv;

    const ethPrice = await ethUsdOracle.latestAnswer();
    const expectedAsdPrice = BigNumber.from(10)
      .pow(ETH_USD_ORACLE_DECIMALS + ASD_ETH_ORACLE_DECIMALS)
      .div(ethPrice);

    expect(await asdOracle.latestAnswer()).to.equal(expectedAsdPrice);
  });

  it('Check price of ASD via AaveOracle', async () => {
    const { aaveOracle, ethUsdOracle, asd } = testEnv;

    const ethPrice = await ethUsdOracle.latestAnswer();
    const expectedAsdPrice = BigNumber.from(10)
      .pow(ETH_USD_ORACLE_DECIMALS + ASD_ETH_ORACLE_DECIMALS)
      .div(ethPrice);

    expect(await aaveOracle.getAssetPrice(asd.address)).to.equal(expectedAsdPrice);
  });
});
