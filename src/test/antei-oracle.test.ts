import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { WAD } from '../helpers/constants';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { aaveMarketAddresses } from '../helpers/aave-v2-addresses';

makeSuite('AaveOracle', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('ASD Oracle - ETH per 1 usd check', async function () {
    const { asdOracle, ethUsdOracle } = testEnv;

    const ethPerUsd = await asdOracle.latestAnswer();
    const ethPrice = await ethUsdOracle.latestAnswer();

    const decimalMultiplier = ethers.utils.parseUnits('1.0', 10);
    const ethPriceMoreDecimals = ethPrice.mul(decimalMultiplier);
    const oneDollar = ethers.utils.parseUnits('1.0', 18);
    const estimatedEthPerUsd = oneDollar
      .mul(WAD)
      .add(ethPriceMoreDecimals.div(2))
      .div(ethPriceMoreDecimals);

    expect(estimatedEthPerUsd).to.equal(ethPerUsd);
  });

  it('Aave Oracle - ETH per 1 usd check', async function () {
    const { aaveOracle, ethUsdOracle, asd } = testEnv;

    const ethPerUsd = await aaveOracle.getAssetPrice(asd.address);
    const ethPrice = await ethUsdOracle.latestAnswer();

    const decimalMultiplier = ethers.utils.parseUnits('1.0', 10);
    const ethPriceMoreDecimals = ethPrice.mul(decimalMultiplier);
    const oneDollar = ethers.utils.parseUnits('1.0', 18);
    const estimatedEthPerUsd = oneDollar
      .mul(WAD)
      .add(ethPriceMoreDecimals.div(2))
      .div(ethPriceMoreDecimals);

    expect(estimatedEthPerUsd).to.equal(ethPerUsd);
  });

  it('ETH/USD Oracle address check', async function () {
    const { asdOracle } = testEnv;
    const ethPerUsd = await asdOracle.ethUsdOracle();
    const ethUsdOracleAddress = aaveMarketAddresses.ethUsdOracle;

    expect(ethPerUsd).to.equal(ethers.utils.getAddress(ethUsdOracleAddress));
  });
});
