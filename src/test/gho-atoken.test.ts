import hre from 'hardhat';
import { expect } from 'chai';
import { impersonateAccountHardhat } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { ONE_ADDRESS } from '../helpers/constants';

makeSuite('Gho AToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  const testAddressOne = '0x2acAb3DEa77832C09420663b0E1cB386031bA17B';
  const testAddressTwo = '0x6fC355D4e0EE44b292E50878F49798ff755A5bbC';

  let poolSigner;

  const CALLER_MUST_BE_POOL = '23';
  const CALLER_NOT_POOL_ADMIN = '1';
  const OPERATION_NOT_SUPPORTED = '80';
  const UNDERLYING_CANNOT_BE_RESCUED = '85';

  before(async () => {
    ethers = hre.ethers;

    const { pool } = testEnv;
    poolSigner = await impersonateAccountHardhat(pool.address);
  });

  it('Checks initial parameters', async function () {
    const { aToken, gho } = testEnv;
    expect(await aToken.UNDERLYING_ASSET_ADDRESS()).to.be.equal(gho.address);
    expect(await aToken.ATOKEN_REVISION()).to.be.equal(1);
  });

  it('Checks the domain separator', async () => {
    const { aToken } = testEnv;
    const EIP712_REVISION = '1';

    const domain = {
      name: await aToken.name(),
      version: EIP712_REVISION,
      chainId: hre.network.config.chainId,
      verifyingContract: aToken.address,
    };
    const domainSeparator = ethers.utils._TypedDataEncoder.hashDomain(domain);

    expect(await aToken.DOMAIN_SEPARATOR()).to.be.equal(domainSeparator);
  });

  it('Check permission of onlyPool modified functions (revert expected)', async () => {
    const { aToken, users } = testEnv;
    const nonPoolAdmin = users[2];

    const randomAddress = ONE_ADDRESS;
    const randomNumber = '0';
    const calls = [
      { fn: 'mint', args: [randomAddress, randomAddress, randomNumber, randomNumber] },
      { fn: 'burn', args: [randomAddress, randomAddress, randomNumber, randomNumber] },
      { fn: 'mintToTreasury', args: [randomNumber, randomNumber] },
      { fn: 'transferOnLiquidation', args: [randomAddress, randomAddress, randomNumber] },
      { fn: 'transferUnderlyingTo', args: [randomAddress, randomNumber] },
      { fn: 'handleRepayment', args: [randomAddress, randomAddress, randomNumber] },
    ];
    for (const call of calls) {
      await expect(aToken.connect(nonPoolAdmin.signer)[call.fn](...call.args)).to.be.revertedWith(
        CALLER_MUST_BE_POOL
      );
    }
  });

  it('Check permission of onlyPoolAdmin modified functions (revert expected)', async () => {
    const { aToken, users } = testEnv;
    const nonPoolAdmin = users[2];

    const randomAddress = ONE_ADDRESS;
    const randomNumber = '0';
    const calls = [
      { fn: 'rescueTokens', args: [randomAddress, randomAddress, randomNumber] },
      { fn: 'setVariableDebtToken', args: [randomAddress] },
      { fn: 'updateGhoTreasury', args: [randomAddress] },
    ];
    for (const call of calls) {
      await expect(aToken.connect(nonPoolAdmin.signer)[call.fn](...call.args)).to.be.revertedWith(
        CALLER_NOT_POOL_ADMIN
      );
    }
  });

  it('Check operations not permitted (revert expected)', async () => {
    const { aToken } = testEnv;

    const randomAddress = ONE_ADDRESS;
    const randomNumber = '0';
    const calls = [
      { fn: 'mint', args: [randomAddress, randomAddress, randomNumber, randomNumber] },
      { fn: 'burn', args: [randomAddress, randomAddress, randomNumber, randomNumber] },
      { fn: 'mintToTreasury', args: [randomNumber, randomNumber] },
      { fn: 'transferOnLiquidation', args: [randomAddress, randomAddress, randomNumber] },
      {
        fn: 'permit',
        args: [
          randomAddress,
          randomAddress,
          randomNumber,
          randomNumber,
          randomNumber,
          ethers.constants.HashZero,
          ethers.constants.HashZero,
        ],
      },
    ];
    for (const call of calls) {
      await expect(aToken.connect(poolSigner)[call.fn](...call.args)).to.be.revertedWith(
        OPERATION_NOT_SUPPORTED
      );
    }
  });

  it('Get VariableDebtToken', async function () {
    const { aToken, variableDebtToken } = testEnv;
    const variableDebtTokenAddress = await aToken.getVariableDebtToken();
    expect(variableDebtTokenAddress).to.be.equal(variableDebtToken.address);
  });

  it('Get Treasury', async function () {
    const { aToken, treasuryAddress } = testEnv;
    const aTokenTreasuryAddress = await aToken.getGhoTreasury();
    expect(aTokenTreasuryAddress).to.be.equal(treasuryAddress);
  });

  it('Burn AToken - not permissioned (revert expected)', async function () {
    const { aToken, users } = testEnv;

    await expect(
      aToken.connect(users[5].signer).burn(testAddressOne, testAddressOne, 1000, 1)
    ).to.be.revertedWith(CALLER_MUST_BE_POOL);
  });

  it('Get VariableDebtToken', async function () {
    const { aToken, variableDebtToken } = testEnv;

    const variableDebtTokenAddress = await aToken.getVariableDebtToken();
    expect(variableDebtTokenAddress).to.be.equal(variableDebtToken.address);
  });

  it('Set Treasury', async function () {
    const { aToken, deployer, treasuryAddress } = testEnv;

    await expect(aToken.connect(deployer.signer).updateGhoTreasury(testAddressTwo))
      .to.emit(aToken, 'GhoTreasuryUpdated')
      .withArgs(treasuryAddress, testAddressTwo);
  });

  it('Get Treasury', async function () {
    const { aToken } = testEnv;

    const ghoTreasury = await aToken.getGhoTreasury();
    expect(ghoTreasury).to.be.equal(testAddressTwo);
  });

  it('Set VariableDebtToken - already set (expect revert)', async function () {
    const { aToken, poolAdmin } = testEnv;

    await expect(
      aToken.connect(poolAdmin.signer).setVariableDebtToken(testAddressTwo)
    ).to.be.revertedWith('VARIABLE_DEBT_TOKEN_ALREADY_SET');
  });

  it('Total Supply - always zero', async function () {
    const { aToken } = testEnv;

    await expect(await aToken.totalSupply()).to.be.equal(0);
  });

  it('User balanceOf - always zero', async function () {
    const { aToken, users } = testEnv;

    for (const user of users) {
      await expect(await aToken.balanceOf(user.address)).to.be.eq(0);
    }
  });

  it('User nonces - always zero', async function () {
    const { aToken, users } = testEnv;

    for (const user of users) {
      await expect(await aToken.nonces(user.address)).to.be.eq(0);
    }
  });

  it('PoolAdmin rescue tokens from AToken', async () => {
    const {
      poolAdmin,
      pool,
      gho,
      usdc,
      aToken,
      users: [locker],
    } = testEnv;

    const amountToLock = 2;

    // Lock GHO
    const aTokenGhoBalanceBefore = await gho.balanceOf(aToken.address);
    const aTokenSigner = await impersonateAccountHardhat(aToken.address);
    expect(await gho.connect(aTokenSigner).mint(aToken.address, amountToLock));
    expect(await gho.balanceOf(aToken.address)).to.be.eq(aTokenGhoBalanceBefore.add(amountToLock));

    // Underlying cannot be rescued
    await expect(
      aToken.connect(poolAdmin.signer).rescueTokens(gho.address, locker.address, 2)
    ).to.be.revertedWith(UNDERLYING_CANNOT_BE_RESCUED);
    expect(await gho.balanceOf(aToken.address)).to.be.eq(aTokenGhoBalanceBefore.add(amountToLock));

    // Lock USDC
    const aTokenUsdcBalanceBefore = await usdc.balanceOf(aToken.address);
    expect(await usdc.connect(locker.signer).transfer(aToken.address, amountToLock));
    expect(await usdc.balanceOf(aToken.address)).to.be.eq(
      aTokenUsdcBalanceBefore.add(amountToLock)
    );

    // Rescue
    expect(
      await aToken
        .connect(poolAdmin.signer)
        .rescueTokens(usdc.address, locker.address, amountToLock)
    );
  });
});
