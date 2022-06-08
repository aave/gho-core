import hre from 'hardhat';
import { expect } from 'chai';
import { DRE } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { impersonateAccountHardhat } from '../../helpers/misc-utils';
import { ZERO_ADDRESS } from '../../helpers/constants';

describe('Antei VariableDebtToken Unit Test', () => {
  let ethers;
  let discountRateStrategy;
  let tempVariableDebtToken;
  let tempVariableDebtTokenAdmin;

  const testAddressOne = '0x2acAb3DEa77832C09420663b0E1cB386031bA17B';
  const testAddressTwo = '0x6fC355D4e0EE44b292E50878F49798ff755A5bbC';
  const testTokenAddress = '0x492E71Fa9f56d558f30388c20779e13e7A13e0dA';

  const addressesProvider = aaveMarketAddresses.addressesProvider;

  const CALLER_NOT_POOL_ADMIN = '33';

  before(async () => {
    await hre.run('set-DRE');
    ethers = DRE.ethers;

    const anteiVariableDebtToken_factory = await ethers.getContractFactory(
      'AnteiVariableDebtToken'
    );

    tempVariableDebtToken = await anteiVariableDebtToken_factory.deploy(
      aaveMarketAddresses.pool,
      testTokenAddress,
      'Dummy Token',
      'DT',
      aaveMarketAddresses.incentivesController,
      aaveMarketAddresses.addressesProvider
    );

    const getDiscountRateStrategy_factory = await ethers.getContractFactory(
      'AnteiDiscountRateStrategy'
    );

    discountRateStrategy = await getDiscountRateStrategy_factory.deploy();

    const adminSigner = await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor);
    tempVariableDebtTokenAdmin = tempVariableDebtToken.connect(adminSigner);
  });

  it('Get Addresses Provider', async function () {
    const currentAddressProvider = await tempVariableDebtToken.ADDRESSES_PROVIDER();
    expect(currentAddressProvider).to.be.equal(addressesProvider);
  });

  it('Set AToken', async function () {
    await expect(tempVariableDebtTokenAdmin.setAToken(testAddressOne))
      .to.emit(tempVariableDebtTokenAdmin, 'ATokenSet')
      .withArgs(testAddressOne);
  });

  it('Get AToken', async function () {
    const aToken = await tempVariableDebtToken.getAToken();
    expect(aToken).to.be.equal(testAddressOne);
  });

  it('Set AToken - already set (expect revert)', async function () {
    await expect(tempVariableDebtTokenAdmin.setAToken(testAddressTwo)).to.be.revertedWith(
      'ATOKEN_ALREADY_SET'
    );
  });

  it('Set AToken - not permissioned (expect revert)', async function () {
    await expect(tempVariableDebtToken.setAToken(testAddressTwo)).to.be.revertedWith(
      CALLER_NOT_POOL_ADMIN
    );
  });

  it('Get Discount Strategy - before setting', async function () {
    expect(await tempVariableDebtToken.getDiscountRateStrategy()).to.be.equal(ZERO_ADDRESS);
  });

  it('Set Discount Strategy', async function () {
    await expect(
      tempVariableDebtTokenAdmin.updateDiscountRateStrategy(discountRateStrategy.address)
    )
      .to.emit(tempVariableDebtToken, 'DiscountRateStrategyUpdated')
      .withArgs(ZERO_ADDRESS, discountRateStrategy.address);
  });

  it('Get Discount Strategy - after setting', async function () {
    expect(await tempVariableDebtToken.getDiscountRateStrategy()).to.be.equal(
      discountRateStrategy.address
    );
  });

  it('Set Discount Strategy - not permissioned (expect revert)', async function () {
    await expect(tempVariableDebtToken.updateDiscountRateStrategy(ZERO_ADDRESS)).to.be.revertedWith(
      CALLER_NOT_POOL_ADMIN
    );
  });

  it('Get Staked Token - before setting', async function () {
    expect(await tempVariableDebtToken.getStakedToken()).to.be.equal(ZERO_ADDRESS);
  });

  it('Set Staked Token', async function () {
    await expect(tempVariableDebtTokenAdmin.updateStakedToken(testAddressOne))
      .to.emit(tempVariableDebtToken, 'StakedTokenUpdated')
      .withArgs(ZERO_ADDRESS, testAddressOne);
  });

  it('Get Staked Token - after setting', async function () {
    expect(await tempVariableDebtToken.getStakedToken()).to.be.equal(testAddressOne);
  });

  it('Set Staked Token - not permissioned (expect revert)', async function () {
    await expect(tempVariableDebtToken.updateStakedToken(ZERO_ADDRESS)).to.be.revertedWith(
      CALLER_NOT_POOL_ADMIN
    );
  });
});
