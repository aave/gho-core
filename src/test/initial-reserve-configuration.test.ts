import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';

makeSuite('Initial GHO Reserve Configuration', (testEnv: TestEnv) => {
  let ethers;

  before(async () => {
    ethers = DRE.ethers;
  });

  it('GHO listed as a reserve', async function () {
    const { pool, gho } = testEnv;

    const reserves = await pool.getReservesList();

    expect(reserves.includes(gho.address));
  });

  it('AToken proxy contract listed in Aave with correct implementation', async function () {
    const { aaveDataProvider, gho, aTokenImplementation } = testEnv;

    const reserveData = await aaveDataProvider.getReserveTokensAddresses(gho.address);
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
    const { aaveDataProvider, gho, stableDebtTokenImplementation } = testEnv;

    const reserveData = await aaveDataProvider.getReserveTokensAddresses(gho.address);
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
    const { aaveDataProvider, gho, variableDebtTokenImplementation } = testEnv;

    const reserveData = await aaveDataProvider.getReserveTokensAddresses(gho.address);
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
    const { aToken, gho, pool, treasuryAddress } = testEnv;

    const poolAddress = await aToken.POOL();
    const underlyingAddress = await aToken.UNDERLYING_ASSET_ADDRESS();
    const aTokenTreasuryAddress = await aToken.RESERVE_TREASURY_ADDRESS();

    expect(poolAddress).to.be.equal(pool.address);
    expect(underlyingAddress).to.be.equal(gho.address);
    expect(aTokenTreasuryAddress).to.be.equal(treasuryAddress);
  });

  it('StableDebtToken configuration check', async function () {
    const { stableDebtToken, gho, pool } = testEnv;

    const poolAddress = await stableDebtToken.POOL();
    const underlyingAddress = await stableDebtToken.UNDERLYING_ASSET_ADDRESS();

    expect(poolAddress).to.be.equal(pool.address);
    expect(underlyingAddress).to.be.equal(gho.address);
  });

  it('VariableDebtToken configuration check', async function () {
    const { variableDebtToken, gho, pool } = testEnv;

    const poolAddress = await variableDebtToken.POOL();
    const underlyingAddress = await variableDebtToken.UNDERLYING_ASSET_ADDRESS();

    expect(poolAddress).to.be.equal(pool.address);
    expect(underlyingAddress).to.be.equal(gho.address);
  });

  // it('Interest Rate Strategy should be configured correctly', async function () {
  //   const { interestRateStrategy } = testEnv;

  //   const rates = await interestRateStrategy.calculateInterestRates(ZERO_ADDRESS, 0, 0, 0, 0, 0);

  //   expect(rates[0]).to.be.equal(ethers.utils.parseUnits('1.0', 25));
  //   expect(rates[1]).to.be.equal(ethers.utils.parseUnits('1.0', 25));
  //   expect(rates[2]).to.be.equal(ghoReserveConfig.INTEREST_RATE);
  // });

  it('Reserve configuration data check', async function () {
    const { aaveDataProvider, gho } = testEnv;

    const reserverConfiguration = await aaveDataProvider.getReserveConfigurationData(gho.address);

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

  it('Aave oracle - gho source address check', async function () {
    const { aaveOracle, gho, ghoOracle } = testEnv;

    const ghoSource = await aaveOracle.getSourceOfAsset(gho.address);

    expect(ghoSource).to.be.equal(ghoOracle.address);
  });
});
