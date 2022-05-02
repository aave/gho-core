import hre from 'hardhat';
import { expect } from 'chai';
import { DRE } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { impersonateAccountHardhat } from '../../helpers/misc-utils';
import { ZERO_ADDRESS } from '../../helpers/constants';

describe('Antei VariableDebtToken Unit Test', () => {
  let ethers;
  let tempVariableDebtToken;
  let tempVariableDebtTokenAdmin;

  const testAddressOne = '0x2acAb3DEa77832C09420663b0E1cB386031bA17B';
  const testAddressTwo = '0x6fC355D4e0EE44b292E50878F49798ff755A5bbC';
  const testTokenAddress = '0x492E71Fa9f56d558f30388c20779e13e7A13e0dA';

  const discountRate = 2000;
  const maxDiscountRate = 6500;

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

  it('Set Discount Token', async function () {
    await expect(tempVariableDebtTokenAdmin.setDiscountToken(testAddressOne))
      .to.emit(tempVariableDebtTokenAdmin, 'DiscountTokenSet')
      .withArgs(ZERO_ADDRESS, testAddressOne);
  });

  it('Get Discount Token', async function () {
    const currentDiscountToken = await tempVariableDebtToken.getDiscountToken();
    expect(currentDiscountToken).to.be.equal(testAddressOne);
  });

  it('Set Discount Token - not permissioned (expect revert)', async function () {
    await expect(tempVariableDebtToken.setDiscountToken(testAddressTwo)).to.be.revertedWith(
      CALLER_NOT_POOL_ADMIN
    );
  });

  it('Set Discount Rate', async function () {
    await expect(tempVariableDebtTokenAdmin.setDiscountRate(discountRate))
      .to.emit(tempVariableDebtTokenAdmin, 'DiscountRateSet')
      .withArgs(0, discountRate);
  });

  it('Get Discount Rate', async function () {
    expect(await tempVariableDebtToken.getDiscountRate()).to.be.equal(discountRate);
  });

  it('Set Discount Rate - not permissioned (expect revert)', async function () {
    await expect(tempVariableDebtToken.setDiscountRate(100)).to.be.revertedWith(
      CALLER_NOT_POOL_ADMIN
    );
  });

  it('Set Discount Rate - too large (expect revert)', async function () {
    await expect(tempVariableDebtTokenAdmin.setDiscountRate(1000000)).to.be.revertedWith(
      'DISCOUNT_RATE_TOO_LARGE'
    );
  });

  it('Set Max Discount Rate', async function () {
    await expect(tempVariableDebtTokenAdmin.setMaxDiscountRate(maxDiscountRate))
      .to.emit(tempVariableDebtTokenAdmin, 'MaxDiscountRateSet')
      .withArgs(0, maxDiscountRate);
  });

  it('Get Max Discount Rate', async function () {
    expect(await tempVariableDebtToken.getMaxDiscountRate()).to.be.equal(maxDiscountRate);
  });

  it('Set Max Discount Rate - not permissioned (expect revert)', async function () {
    await expect(tempVariableDebtToken.setMaxDiscountRate(1000)).to.be.revertedWith(
      CALLER_NOT_POOL_ADMIN
    );
  });

  it('Set Max Discount Rate - not permissioned (expect revert)', async function () {
    await expect(tempVariableDebtTokenAdmin.setMaxDiscountRate(1000000)).to.be.revertedWith(
      'MAX_DISCOUNT_RATE_TOO_LARGE'
    );
  });
});
