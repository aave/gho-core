import hre from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from './helpers/make-suite';
import { GhoToken__factory, IGhoToken } from '../types';
import { HardhatEthersHelpers } from '@nomiclabs/hardhat-ethers/types';
import { BigNumber } from 'ethers';
import { HARDHAT_CHAINID, MAX_UINT_AMOUNT, ZERO_ADDRESS } from './../helpers/constants';
import { buildPermitParams, getSignatureFromTypedData } from './helpers/helpers';
import { keccak256, toUtf8Bytes } from 'ethers/lib/utils';

describe('GhoToken Unit Test', () => {
  let ethers: typeof import('ethers/lib/ethers') & HardhatEthersHelpers;
  let ghoTokenFactory: GhoToken__factory;

  let users: SignerWithAddress[] = [];

  let facilitator1: SignerWithAddress;
  let facilitator1Label: string;
  let facilitator1Cap: BigNumber;
  let facilitator1Config: IGhoToken.FacilitatorStruct;

  let facilitator2: SignerWithAddress;

  let ghoToken;

  const EIP712_REVISION = '1';

  before(async () => {
    ethers = hre.ethers;

    const signers = await ethers.getSigners();

    for (const signer of signers) {
      users.push({
        signer,
        address: await signer.getAddress(),
      });
    }

    // setup facilitator1
    facilitator1 = users[1];
    facilitator1Label = 'Alice_Facilitator';
    facilitator1Cap = ethers.utils.parseUnits('100000000', 18);
    facilitator1Config = {
      bucketCapacity: facilitator1Cap,
      bucketLevel: 0,
      label: facilitator1Label,
    };

    // setup facilitator2
    facilitator2 = users[2];

    ghoTokenFactory = new GhoToken__factory(users[0].signer);
  });

  it('Deploys GHO and adds the first facilitator', async function () {
    ghoToken = await ghoTokenFactory.deploy(users[0].address);

    const FACILITATOR_MANAGER_ROLE = ethers.utils.hexZeroPad(
      keccak256(toUtf8Bytes('FACILITATOR_MANAGER_ROLE')),
      32
    );
    const BUCKET_MANAGER_ROLE = ethers.utils.hexZeroPad(
      keccak256(toUtf8Bytes('BUCKET_MANAGER_ROLE')),
      32
    );

    const grantFacilitatorRoleTx = await ghoToken
      .connect(users[0].signer)
      .grantRole(FACILITATOR_MANAGER_ROLE, users[0].address);
    const grantBucketRoleTx = await ghoToken
      .connect(users[0].signer)
      .grantRole(BUCKET_MANAGER_ROLE, users[0].address);

    await expect(grantFacilitatorRoleTx).to.emit(ghoToken, 'RoleGranted');
    await expect(grantBucketRoleTx).to.emit(ghoToken, 'RoleGranted');

    const labelHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(facilitator1Label));

    await expect(
      ghoToken
        .connect(users[0].signer)
        .addFacilitator(
          facilitator1.address,
          facilitator1Config.label,
          facilitator1Config.bucketCapacity
        )
    )
      .to.emit(ghoToken, 'FacilitatorAdded')
      .withArgs(facilitator1.address, labelHash, facilitator1Cap);
  });

  it('Mint from facilitator 1', async function () {
    const mintAmount = ethers.utils.parseUnits('250000.0', 18);

    await expect(ghoToken.connect(facilitator1.signer).mint(facilitator1.address, mintAmount))
      .to.emit(ghoToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, facilitator1.address, mintAmount)
      .to.emit(ghoToken, 'FacilitatorBucketLevelUpdated')
      .withArgs(facilitator1.address, 0, mintAmount);

    const [, level] = await ghoToken.getFacilitatorBucket(facilitator1.address);

    expect(level).to.be.equal(mintAmount);
  });

  it('Checks the domain separator', async () => {
    const separator = await ghoToken.connect(facilitator1.signer).DOMAIN_SEPARATOR();

    const domain = {
      name: await ghoToken.name(),
      version: EIP712_REVISION,
      chainId: hre.network.config.chainId,
      verifyingContract: ghoToken.address,
    };
    const domainSeparator = ethers.utils._TypedDataEncoder.hashDomain(domain);

    expect(separator).to.be.equal(domainSeparator);
  });

  it('Submits a permit with 0 expiration (revert expected)', async () => {
    const owner = await ethers.Wallet.createRandom();
    const spender = facilitator2;
    const tokenName = await ghoToken.name();

    const chainId = hre.network.config.chainId || HARDHAT_CHAINID;
    const expiration = 0;
    const nonce = (await ghoToken.nonces(owner.address)).toNumber();
    const permitAmount = ethers.utils.parseEther('2').toString();
    const msgParams = buildPermitParams(
      chainId,
      ghoToken.address,
      EIP712_REVISION,
      tokenName,
      owner.address,
      spender.address,
      nonce,
      permitAmount,
      expiration.toFixed()
    );

    expect((await ghoToken.allowance(owner.address, spender.address)).toString()).to.be.equal(
      '0',
      'INVALID_ALLOWANCE_BEFORE_PERMIT'
    );

    const { v, r, s } = getSignatureFromTypedData(owner.privateKey, msgParams);

    await expect(
      ghoToken
        .connect(spender.signer)
        .permit(owner.address, spender.address, permitAmount, expiration, v, r, s)
    ).to.be.revertedWith('PERMIT_DEADLINE_EXPIRED');

    expect((await ghoToken.allowance(owner.address, spender.address)).toString()).to.be.equal('0');
  });

  it('Submits a permit with maximum expiration length', async () => {
    const owner = await ethers.Wallet.createRandom();
    const spender = facilitator2;

    const chainId = hre.network.config.chainId || HARDHAT_CHAINID;
    const deadline = MAX_UINT_AMOUNT;
    const nonce = (await ghoToken.nonces(owner.address)).toNumber();
    const permitAmount = ethers.utils.parseEther('2').toString();
    const msgParams = buildPermitParams(
      chainId,
      ghoToken.address,
      EIP712_REVISION,
      await ghoToken.name(),
      owner.address,
      spender.address,
      nonce,
      deadline,
      permitAmount
    );

    expect((await ghoToken.allowance(owner.address, spender.address)).toString()).to.be.equal(
      '0',
      'INVALID_ALLOWANCE_BEFORE_PERMIT'
    );

    const { v, r, s } = getSignatureFromTypedData(owner.privateKey, msgParams);

    expect(
      await ghoToken
        .connect(spender.signer)
        .permit(owner.address, spender.address, permitAmount, deadline, v, r, s)
    );

    expect((await ghoToken.nonces(owner.address)).toNumber()).to.be.equal(1);
  });

  it('Cancels the previous permit', async () => {
    const owner = await ethers.Wallet.createRandom();
    const spender = facilitator2;

    const chainId = hre.network.config.chainId || HARDHAT_CHAINID;
    const deadline = MAX_UINT_AMOUNT;
    const permitAmount = ethers.utils.parseEther('2').toString();
    const msgParams = buildPermitParams(
      chainId,
      ghoToken.address,
      EIP712_REVISION,
      await ghoToken.name(),
      owner.address,
      spender.address,
      (await ghoToken.nonces(owner.address)).toNumber(),
      deadline,
      permitAmount
    );
    const { v, r, s } = getSignatureFromTypedData(owner.privateKey, msgParams);

    expect(
      await ghoToken
        .connect(spender.signer)
        .permit(owner.address, spender.address, permitAmount, deadline, v, r, s)
    );
    expect((await ghoToken.allowance(owner.address, spender.address)).toString()).to.be.equal(
      ethers.utils.parseEther('2')
    );

    const newPermitAmount = '0';
    const newMsgParams = buildPermitParams(
      chainId,
      ghoToken.address,
      EIP712_REVISION,
      await ghoToken.name(),
      owner.address,
      spender.address,
      (await ghoToken.nonces(owner.address)).toNumber(),
      deadline,
      newPermitAmount
    );
    const { v: newV, r: newR, s: newS } = getSignatureFromTypedData(owner.privateKey, newMsgParams);

    expect(
      await ghoToken
        .connect(spender.signer)
        .permit(owner.address, spender.address, newPermitAmount, deadline, newV, newR, newS)
    );
    expect((await ghoToken.allowance(owner.address, spender.address)).toString()).to.be.equal(
      newPermitAmount,
      'INVALID_ALLOWANCE_AFTER_PERMIT'
    );

    expect((await ghoToken.nonces(owner.address)).toNumber()).to.be.equal(2);
  });

  it('Tries to submit a permit with invalid nonce (revert expected)', async () => {
    const owner = await ethers.Wallet.createRandom();
    const spender = facilitator2;

    const chainId = hre.network.config.chainId || HARDHAT_CHAINID;
    const deadline = MAX_UINT_AMOUNT;
    const nonce = 1000;
    const permitAmount = '0';
    const msgParams = buildPermitParams(
      chainId,
      ghoToken.address,
      EIP712_REVISION,
      await ghoToken.name(),
      owner.address,
      spender.address,
      nonce,
      deadline,
      permitAmount
    );

    const { v, r, s } = getSignatureFromTypedData(owner.privateKey, msgParams);

    await expect(
      ghoToken
        .connect(spender.signer)
        .permit(owner.address, spender.address, permitAmount, deadline, v, r, s)
    ).to.be.revertedWith('INVALID_SIGNER');
  });

  it('Tries to submit a permit with invalid expiration (previous to the current block) (revert expected)', async () => {
    const owner = await ethers.Wallet.createRandom();
    const spender = facilitator2;

    const chainId = hre.network.config.chainId || HARDHAT_CHAINID;
    const expiration = '1';
    const nonce = (await ghoToken.nonces(owner.address)).toNumber();
    const permitAmount = '0';
    const msgParams = buildPermitParams(
      chainId,
      ghoToken.address,
      EIP712_REVISION,
      await ghoToken.name(),
      owner.address,
      spender.address,
      nonce,
      expiration,
      permitAmount
    );

    const { v, r, s } = getSignatureFromTypedData(owner.privateKey, msgParams);

    await expect(
      ghoToken
        .connect(spender.signer)
        .permit(owner.address, spender.address, expiration, permitAmount, v, r, s)
    ).to.be.revertedWith('PERMIT_DEADLINE_EXPIRED');
  });

  it('Tries to submit a permit with invalid signature (revert expected)', async () => {
    const owner = await ethers.Wallet.createRandom();
    const spender = facilitator2;

    const chainId = hre.network.config.chainId || HARDHAT_CHAINID;
    const deadline = MAX_UINT_AMOUNT;
    const nonce = (await ghoToken.nonces(owner.address)).toNumber();
    const permitAmount = '0';
    const msgParams = buildPermitParams(
      chainId,
      ghoToken.address,
      EIP712_REVISION,
      await ghoToken.name(),
      owner.address,
      spender.address,
      nonce,
      deadline,
      permitAmount
    );

    const { v, r, s } = getSignatureFromTypedData(owner.privateKey, msgParams);

    await expect(
      ghoToken
        .connect(spender.signer)
        .permit(owner.address, ZERO_ADDRESS, permitAmount, deadline, v, r, s)
    ).to.be.revertedWith('INVALID_SIGNER');
  });

  it('Tries to submit a permit with invalid owner (revert expected)', async () => {
    const owner = await ethers.Wallet.createRandom();
    const spender = facilitator2;

    const chainId = hre.network.config.chainId || HARDHAT_CHAINID;
    const deadline = MAX_UINT_AMOUNT;
    const nonce = (await ghoToken.nonces(owner.address)).toNumber();
    const permitAmount = '0';
    const msgParams = buildPermitParams(
      chainId,
      ghoToken.address,
      EIP712_REVISION,
      await ghoToken.name(),
      owner.address,
      spender.address,
      nonce,
      deadline,
      permitAmount
    );

    const { v, r, s } = getSignatureFromTypedData(owner.privateKey, msgParams);

    await expect(
      ghoToken
        .connect(spender.signer)
        .permit(ZERO_ADDRESS, spender.address, permitAmount, deadline, v, r, s)
    ).to.be.revertedWith('INVALID_SIGNER');
  });
});
