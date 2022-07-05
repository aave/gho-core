import hardhat, { ethers } from 'hardhat';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
  GhoOracle,
  GhoOracle__factory,
  MockAggregator,
  MockAggregator__factory,
} from '../../../types';
import { evmRevert, evmSnapshot, setCode, setStorageAt } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';

const INITIAL_ETH_USD_PRICE = ethers.utils.parseUnits('2000', 8);

const ETH_USD_ORACLE_DECIMALS = 8;
const GHO_ETH_ORACLE_DECIMALS = 18;

describe('Gho Oracle Unit Test', () => {
  let ghoOracle: GhoOracle;
  let mockEthUsdOracle: MockAggregator;
  let deployer: SignerWithAddress;
  let users: SignerWithAddress[];

  let snapId;

  before(async () => {
    await hardhat.run('set-DRE');
    [deployer, ...users] = await hardhat.ethers.getSigners();
    ghoOracle = await new GhoOracle__factory(deployer).deploy();

    // Mock ETH-USD price feed
    mockEthUsdOracle = await new MockAggregator__factory(deployer).deploy(INITIAL_ETH_USD_PRICE);
    const mockEthUsdOracleCode = await ethers.provider.getCode(mockEthUsdOracle.address);
    mockEthUsdOracle = MockAggregator__factory.connect(aaveMarketAddresses.ethUsdOracle, deployer);
    await setCode(aaveMarketAddresses.ethUsdOracle, mockEthUsdOracleCode);
    await setStorageAt(
      mockEthUsdOracle.address,
      '0x0',
      ethers.utils.defaultAbiCoder.encode(['uint256'], [INITIAL_ETH_USD_PRICE])
    );
  });

  beforeEach(async () => {
    snapId = await evmSnapshot();
  });

  afterEach(async () => {
    await evmRevert(snapId);
  });

  it('Check initial config params of GHO oracle', async () => {
    expect(await ghoOracle.ETH_USD_ORACLE()).to.equal(
      ethers.utils.getAddress(aaveMarketAddresses.ethUsdOracle)
    );
    expect(await ghoOracle.ETH_USD_ORACLE_DECIMALS()).to.equal(ETH_USD_ORACLE_DECIMALS);
    expect(await ghoOracle.GHO_ETH_ORACLE_DECIMALS()).to.equal(GHO_ETH_ORACLE_DECIMALS);
    expect(await ghoOracle.NUMERATOR()).to.equal(
      BigNumber.from(10).pow(ETH_USD_ORACLE_DECIMALS + GHO_ETH_ORACLE_DECIMALS)
    );
  });

  it('Check price of GHO', async () => {
    const ethPrice = await mockEthUsdOracle.latestAnswer();
    const expectedGhoPrice = BigNumber.from(10)
      .pow(ETH_USD_ORACLE_DECIMALS + GHO_ETH_ORACLE_DECIMALS)
      .div(ethPrice);

    expect(ethPrice).to.equal(INITIAL_ETH_USD_PRICE);
    expect(await ghoOracle.latestAnswer()).to.equal(expectedGhoPrice);
  });

  it('Check price of GHO when ETH price is 0', async () => {
    // Update price to 0 (answer is the first slot)
    const newPrice = 0;
    await setStorageAt(
      mockEthUsdOracle.address,
      '0x0',
      ethers.utils.defaultAbiCoder.encode(['uint256'], [newPrice])
    );

    const ethPrice = await mockEthUsdOracle.latestAnswer();
    expect(ethPrice).to.equal(newPrice);
    expect(await ghoOracle.latestAnswer()).to.equal(0);
  });
});
