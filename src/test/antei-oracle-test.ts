import hre from 'hardhat';
import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { WAD } from '../helpers/constants';
import IChainlinkAggregatorV2Artifact from '@aave/protocol-v2/artifacts/contracts/interfaces/IChainlinkAggregator.sol/IChainlinkAggregator.json';

describe('Antei Oracle', function () {
  let anteiOracle;
  let ethers;

  before(async () => {
    await hre.run('set-DRE');
    ethers = DRE.ethers;

    const anteiOracle_factory = await ethers.getContractFactory('AnteiOracle');
    anteiOracle = await anteiOracle_factory.deploy();

    await anteiOracle.deployed();
  });

  it('Should return ETH per 1 usd', async function () {
    const ethPerUsd = await anteiOracle.latestAnswer();

    const ethUsdOracleAddress = '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419';
    const ethUsdOracle = new ethers.Contract(
      ethUsdOracleAddress,
      IChainlinkAggregatorV2Artifact.abi,
      ethers.provider
    );

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
    const ethPerUsd = await anteiOracle.ethUsdOracle();
    const ethUsdOracleAddress = '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419';

    expect(ethPerUsd).to.equal(ethUsdOracleAddress);
  });
});
