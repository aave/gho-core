import hre from 'hardhat';
import { expect } from 'chai';
import { DRE } from '../../helpers/misc-utils';
import { aaveMarketAddresses, ghoReserveConfig } from '../../helpers/config';
import { impersonateAccountHardhat } from '../../helpers/misc-utils';
import { ZERO_ADDRESS } from '../../helpers/constants';

describe('Gho VariableDebtToken Unit Test', () => {
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

    const ghoVariableDebtToken_factory = await ethers.getContractFactory('GhoVariableDebtToken');

    tempVariableDebtToken = await ghoVariableDebtToken_factory.deploy(
      aaveMarketAddresses.pool,
      testTokenAddress,
      'Dummy Token',
      'DT',
      aaveMarketAddresses.incentivesController
    );

    const discountRateStrategy_factory = await ethers.getContractFactory('GhoDiscountRateStrategy');

    discountRateStrategy = await discountRateStrategy_factory.deploy();

    const adminSigner = await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor);
    tempVariableDebtTokenAdmin = tempVariableDebtToken.connect(adminSigner);
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

  it('Get Discount Token - before setting', async function () {
    expect(await tempVariableDebtToken.getDiscountToken()).to.be.equal(ZERO_ADDRESS);
  });

  it('Set Discount Token', async function () {
    await expect(tempVariableDebtTokenAdmin.updateDiscountToken(testAddressOne))
      .to.emit(tempVariableDebtToken, 'DiscountTokenUpdated')
      .withArgs(ZERO_ADDRESS, testAddressOne);
  });

  it('Get Discount Token - after setting', async function () {
    expect(await tempVariableDebtToken.getDiscountToken()).to.be.equal(testAddressOne);
  });

  it('Set Discount Token - not permissioned (expect revert)', async function () {
    await expect(tempVariableDebtToken.updateDiscountToken(ZERO_ADDRESS)).to.be.revertedWith(
      CALLER_NOT_POOL_ADMIN
    );
  });

  it('Set Rebalance Lock Period', async function () {
    await expect(
      tempVariableDebtTokenAdmin.updateDiscountLockPeriod(ghoReserveConfig.DISCOUNT_LOCK_PERIOD)
    )
      .to.emit(tempVariableDebtToken, 'DiscountLockPeriodUpdated')
      .withArgs(0, ghoReserveConfig.DISCOUNT_LOCK_PERIOD);
  });

  it('Get Rebalance Lock Period', async function () {
    expect(await tempVariableDebtToken.getDiscountLockPeriod()).to.be.equal(
      ghoReserveConfig.DISCOUNT_LOCK_PERIOD
    );
  });

  it('Set Rebalance Lock Period - not permissioned (expect revert)', async function () {
    await expect(tempVariableDebtToken.updateDiscountLockPeriod(0)).to.be.revertedWith(
      CALLER_NOT_POOL_ADMIN
    );
  });
});
