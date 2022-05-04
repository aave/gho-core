import { expect } from 'chai';
import { aaveMarketAddresses } from '../helpers/config';
import { DRE, advanceTimeAndBlock } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { getAToken, getVariableDebtToken } from '../helpers/contract-getters';
import { MAX_UINT_AMOUNT, ONE_YEAR } from '../helpers/constants';

makeSuite('Check upgraded pool', (testEnv: TestEnv) => {
  let ethers;

  let wethAToken;
  let usdcAToken;

  let wethVariableDebtToken;
  let usdcVariableDebtToken;

  let user1Address;
  let user2Address;

  let user1Signer;
  let user2Signer;

  let wethDeposit;

  let usdcDeposit;
  let usdcBorrow;

  before(async () => {
    ethers = DRE.ethers;
    const { usdc, weth, users, aaveDataProvider } = testEnv;

    const wethAddresses = await aaveDataProvider.getReserveTokensAddresses(weth.address);
    wethAToken = await getAToken(wethAddresses.aTokenAddress);
    wethVariableDebtToken = await getVariableDebtToken(wethAddresses.variableDebtTokenAddress);
    const usdcAddresses = await aaveDataProvider.getReserveTokensAddresses(usdc.address);
    usdcAToken = await getAToken(usdcAddresses.aTokenAddress);
    usdcVariableDebtToken = await getVariableDebtToken(usdcAddresses.variableDebtTokenAddress);

    user1Address = users[0].address;
    user1Signer = users[0].signer;

    user2Address = users[0].address;
    user2Signer = users[0].signer;

    wethDeposit = ethers.utils.parseUnits('10.0', 18);
    usdcDeposit = ethers.utils.parseUnits('50000.0', 6);

    usdcBorrow = ethers.utils.parseUnits('20000.0', 6);
  });

  it('Revision number check', async function () {
    const { pool } = testEnv;

    const revision = await pool.LENDINGPOOL_REVISION();

    expect(revision).to.be.equal(4);
  });

  it('AddressesProvider check', async function () {
    const { pool } = testEnv;

    const addressesProvider = await pool.getAddressesProvider();

    expect(addressesProvider).to.be.equal(aaveMarketAddresses.addressesProvider);
  });

  it('Basic End-to-End supply - supply', async function () {
    const { pool, usdc, weth } = testEnv;

    const user1StartWeth = await weth.balanceOf(user1Address);
    const user2StartUsdc = await usdc.balanceOf(user2Address);

    await weth.connect(user1Signer).approve(pool.address, ethers.BigNumber.from(MAX_UINT_AMOUNT));
    await pool.connect(user1Signer).deposit(weth.address, wethDeposit, user1Address, 0);

    expect(await weth.balanceOf(user1Address)).to.be.equal(user1StartWeth.sub(wethDeposit));
    expect(await wethAToken.balanceOf(user1Address)).to.be.equal(wethDeposit);

    await usdc.connect(user2Signer).approve(pool.address, ethers.BigNumber.from(MAX_UINT_AMOUNT));
    await pool.connect(user2Signer).deposit(usdc.address, usdcDeposit, user2Address, 0);

    expect(await usdc.balanceOf(user2Address)).to.be.equal(user2StartUsdc.sub(usdcDeposit));
    expect(await usdcAToken.balanceOf(user2Address)).to.be.equal(usdcDeposit);
  });

  it('Basic End-to-End supply - borrow', async function () {
    const { pool, usdc } = testEnv;

    const user1StartUsdc = await usdc.balanceOf(user1Address);
    await pool.connect(user1Signer).borrow(usdc.address, usdcBorrow, 2, 0, user1Address);

    expect(await usdc.balanceOf(user1Address)).to.be.equal(user1StartUsdc.add(usdcBorrow));
    expect(await usdcVariableDebtToken.balanceOf(user1Address)).to.be.closeTo(usdcBorrow, 1);
  });

  it('Basic End-to-End supply - year passes and repay', async function () {
    const { pool, usdc } = testEnv;

    await advanceTimeAndBlock(ONE_YEAR);
    const MAX_INT = ethers.BigNumber.from(MAX_UINT_AMOUNT);

    await pool.connect(user1Signer).repay(usdc.address, MAX_INT, 2, user1Address);
    expect(await usdcVariableDebtToken.balanceOf(user1Address)).to.be.equal(0);
  });

  it('Basic End-to-End supply - withdraw', async function () {
    const { pool, weth, usdc } = testEnv;

    const MAX_INT = ethers.BigNumber.from(MAX_UINT_AMOUNT);

    await pool.connect(user1Signer).withdraw(weth.address, MAX_INT, user1Address);
    await pool.connect(user2Signer).withdraw(usdc.address, MAX_INT, user2Address);

    expect(await wethAToken.balanceOf(user1Address)).to.be.equal(0);
    expect(await usdcAToken.balanceOf(user2Address)).to.be.equal(0);

    expect(await weth.balanceOf(user1Address)).to.be.gt(wethDeposit);
    expect(await usdc.balanceOf(user2Address)).to.be.gt(usdcDeposit);
  });
});
