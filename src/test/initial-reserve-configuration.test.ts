import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { ZERO_ADDRESS } from '../helpers/constants';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { aaveMarketAddresses } from '../helpers/aave-v2-addresses';
import { asdConfiguration } from '../configs/asd-configuration';

makeSuite('Initial ASD Reserve Configuration', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('ASD listed as a reserve', async function () {
    const { pool, asd } = testEnv;

    const reserves = await pool.getReservesList();

    expect(reserves.includes(asd.address));
  });

  it('AToken proxy contract listed in Aave with correct implementation', async function () {
    const { aaveDataProvider, asd, aTokenImplementation } = testEnv;

    const reserveData = await aaveDataProvider.getReserveTokensAddresses(asd.address);
    const implementationAddressAsBytes = await ethers.provider.getStorageAt(
      reserveData.aTokenAddress,
      '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc'
    );
    const implementationAddress = ethers.utils.getAddress(
      ethers.utils.hexDataSlice(implementationAddressAsBytes, 12)
    );

    expect(implementationAddress).to.be.equal(aTokenImplementation.address);
  });

  it('StableDebtToken proxy contract listed in Aave with correct implementation', async function () {
    const { aaveDataProvider, asd, stableDebtTokenImplementation } = testEnv;

    const reserveData = await aaveDataProvider.getReserveTokensAddresses(asd.address);
    const implementationAddressAsBytes = await ethers.provider.getStorageAt(
      reserveData.stableDebtTokenAddress,
      '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc'
    );
    const implementationAddress = ethers.utils.getAddress(
      ethers.utils.hexDataSlice(implementationAddressAsBytes, 12)
    );

    expect(implementationAddress).to.be.equal(stableDebtTokenImplementation.address);
  });

  it('VariableDebtToken proxy contract listed in Aave with correct implementation', async function () {
    const { aaveDataProvider, asd, variableDebtTokenImplementation } = testEnv;

    const reserveData = await aaveDataProvider.getReserveTokensAddresses(asd.address);
    const implementationAddressAsBytes = await ethers.provider.getStorageAt(
      reserveData.variableDebtTokenAddress,
      '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc'
    );
    const implementationAddress = ethers.utils.getAddress(
      ethers.utils.hexDataSlice(implementationAddressAsBytes, 12)
    );

    expect(implementationAddress).to.be.equal(variableDebtTokenImplementation.address);
  });

  it('AToken configuration Check', async function () {
    const { aToken, asd } = testEnv;

    const { pool, treasury } = aaveMarketAddresses;

    const poolAddress = await aToken.POOL();
    const underlyingAddress = await aToken.UNDERLYING_ASSET_ADDRESS();
    const treasuryAddress = await aToken.RESERVE_TREASURY_ADDRESS();

    expect(poolAddress).to.be.equal(pool);
    expect(underlyingAddress).to.be.equal(asd.address);
    expect(treasuryAddress).to.be.equal(treasury);
  });

  it('StableDebtToken configuration check', async function () {
    const { stableDebtToken, asd } = testEnv;

    const { pool } = aaveMarketAddresses;

    const poolAddress = await stableDebtToken.POOL();
    const underlyingAddress = await stableDebtToken.UNDERLYING_ASSET_ADDRESS();

    expect(poolAddress).to.be.equal(pool);
    expect(underlyingAddress).to.be.equal(asd.address);
  });

  it('VariableDebtToken configuration check', async function () {
    const { variableDebtToken, asd } = testEnv;

    const { pool } = aaveMarketAddresses;

    const poolAddress = await variableDebtToken.POOL();
    const underlyingAddress = await variableDebtToken.UNDERLYING_ASSET_ADDRESS();

    expect(poolAddress).to.be.equal(pool);
    expect(underlyingAddress).to.be.equal(asd.address);
  });

  it('Interest Rate Strategy should be configured correctly', async function () {
    const { interestRateStrategy } = testEnv;

    const rates = await interestRateStrategy.calculateInterestRates(ZERO_ADDRESS, 0, 0, 0, 0, 0);

    expect(rates[0]).to.be.equal(0);
    expect(rates[1]).to.be.equal(0);
    expect(rates[2]).to.be.equal(asdConfiguration.marketConfig.INTEREST_RATE);
  });

  it('Reserve configuration data check', async function () {
    const { aaveDataProvider, asd } = testEnv;

    const reserverConfiguration = await aaveDataProvider.getReserveConfigurationData(asd.address);

    expect(reserverConfiguration.decimals).to.be.equal(18);
    expect(reserverConfiguration.ltv).to.be.equal(0);
    expect(reserverConfiguration.liquidationThreshold).to.be.equal(0);
    expect(reserverConfiguration.liquidationBonus).to.be.equal(0);
    expect(reserverConfiguration.reserveFactor).to.be.equal(0);
    expect(reserverConfiguration.usageAsCollateralEnabled).to.be.false;
    expect(reserverConfiguration.borrowingEnabled).to.be.true;
    expect(reserverConfiguration.stableBorrowRateEnabled).to.be.false;
    expect(reserverConfiguration.isActive).to.be.true;
    expect(reserverConfiguration.isFrozen).to.be.false;
  });

  it('Aave oracle - asd source address check', async function () {
    const { aaveOracle, asd, asdOracle } = testEnv;

    const asdSource = await aaveOracle.getSourceOfAsset(asd.address);

    expect(asdSource).to.be.equal(asdOracle.address);
  });
});
