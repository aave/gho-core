import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { WAD } from '../helpers/constants';
import { makeSuite, TestEnv } from './helpers/make-suite';

makeSuite('AaveOracle', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('Should return ETH per 1 usd', async function () {
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

  it('Should return ETH/USD Oracle', async function () {
    const { asdOracle } = testEnv;
    const ethPerUsd = await asdOracle.ethUsdOracle();
    const ethUsdOracleAddress = '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419';

    expect(ethPerUsd).to.equal(ethUsdOracleAddress);
  });
});
