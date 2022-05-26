import hre from 'hardhat';
import { expect } from 'chai';
import { DRE } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { impersonateAccountHardhat } from '../../helpers/misc-utils';
import { ZERO_ADDRESS, MAX_UINT_AMOUNT } from '../../helpers/constants';

describe('Antei AToken Unit Test', () => {
  let ethers;
  let tempAToken;
  let tempATokenAdmin;
  let tempATokenPool;

  const testAddressOne = '0x2acAb3DEa77832C09420663b0E1cB386031bA17B';
  const testAddressTwo = '0x6fC355D4e0EE44b292E50878F49798ff755A5bbC';
  const testTokenAddress = '0x492E71Fa9f56d558f30388c20779e13e7A13e0dA';

  const addressesProvider = aaveMarketAddresses.addressesProvider;

  const CT_CALLER_MUST_BE_LENDING_POOL = '29';
  const CALLER_NOT_POOL_ADMIN = '33';

  before(async () => {
    await hre.run('set-DRE');
    ethers = DRE.ethers;

    const anteiAToken_factory = await ethers.getContractFactory('AnteiAToken');
    tempAToken = await anteiAToken_factory.deploy(
      aaveMarketAddresses.pool,
      testTokenAddress,
      aaveMarketAddresses.treasury,
      'Dummy Token',
      'DT',
      aaveMarketAddresses.incentivesController,
      aaveMarketAddresses.addressesProvider
    );

    const adminSigner = await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor);
    tempATokenAdmin = tempAToken.connect(adminSigner);

    const poolSigner = await impersonateAccountHardhat(aaveMarketAddresses.pool);
    tempATokenPool = tempAToken.connect(poolSigner);
  });

  it('Mint AToken - not permissioned (revert expected)', async function () {
    await expect(tempAToken.mint(testAddressOne, 1000, 1)).to.be.revertedWith(
      CT_CALLER_MUST_BE_LENDING_POOL
    );
  });

  it('Mint AToken - no minting allowed (revert expected)', async function () {
    await expect(tempATokenPool.mint(testAddressOne, 1000, 1)).to.be.revertedWith(
      'OPERATION_NOT_PERMITTED'
    );
  });

  it('Burn AToken - not permissioned (revert expected)', async function () {
    await expect(tempATokenAdmin.burn(testAddressOne, testAddressOne, 1000, 1)).to.be.revertedWith(
      CT_CALLER_MUST_BE_LENDING_POOL
    );
  });

  it('Bur AToken - no burning allowed (revert expected)', async function () {
    await expect(tempATokenPool.burn(testAddressOne, testAddressOne, 1000, 1)).to.be.revertedWith(
      'OPERATION_NOT_PERMITTED'
    );
  });

  it('Get Addresses Provider', async function () {
    const currentAddressProvider = await tempAToken.ADDRESSES_PROVIDER();
    expect(currentAddressProvider).to.be.equal(addressesProvider);
  });

  it('Set VariableDebtToken', async function () {
    await expect(tempATokenAdmin.setVariableDebtToken(testAddressOne))
      .to.emit(tempAToken, 'VariableDebtTokenSet')
      .withArgs(testAddressOne);
  });

  it('Get VariableDebtToken', async function () {
    const variableDebtToken = await tempAToken.getVariableDebtToken();
    expect(variableDebtToken).to.be.equal(testAddressOne);
  });

  it('Set Treasury', async function () {
    await expect(tempATokenAdmin.setTreasury(testAddressTwo))
      .to.emit(tempAToken, 'TreasuryUpdated')
      .withArgs(ZERO_ADDRESS, testAddressTwo);
  });

  it('Get Treasury', async function () {
    const anteiTreasury = await tempAToken.getTreasury();
    expect(anteiTreasury).to.be.equal(testAddressTwo);
  });

  it('Set VariableDebtToken - already set (expect revert)', async function () {
    await expect(tempATokenAdmin.setVariableDebtToken(testAddressTwo)).to.be.revertedWith(
      'VARIABLE_DEBT_TOKEN_ALREADY_SET'
    );
  });

  it('Set VariableDebtToken - not permissioned (expect revert)', async function () {
    await expect(tempAToken.setVariableDebtToken(testAddressTwo)).to.be.revertedWith(
      CALLER_NOT_POOL_ADMIN
    );
  });

  it('Set Treasury - not permissioned (expect revert)', async function () {
    await expect(tempAToken.setTreasury(aaveMarketAddresses.treasury)).to.be.revertedWith(
      CALLER_NOT_POOL_ADMIN
    );
  });

  it('Total Supply - expect to be max int', async function () {
    const MAX_INT = ethers.BigNumber.from(MAX_UINT_AMOUNT);
    await expect(await tempAToken.totalSupply()).to.be.equal(MAX_INT);
  });
});
