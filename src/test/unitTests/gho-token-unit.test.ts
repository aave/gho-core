import hre from 'hardhat';
import { expect } from 'chai';
import { DRE } from '../../helpers/misc-utils';
import { SignerWithAddress } from '../helpers/make-suite';
import { ghoTokenConfig } from '../../helpers/config';
import { GhoToken__factory, IGhoToken } from '../../../types';
import { HardhatEthersHelpers } from '@nomiclabs/hardhat-ethers/types';
import { BigNumber } from 'ethers';
import { ZERO_ADDRESS } from '../../helpers/constants';

describe('GhoToken Unit Test', () => {
  let ethers: typeof import('ethers/lib/ethers') & HardhatEthersHelpers;
  let ghoTokenFactory: GhoToken__factory;

  let users: SignerWithAddress[] = [];

  let facilitator1: SignerWithAddress;
  let facilitator1Label: string;
  let facilitator1Cap: BigNumber;
  let facilitator1UpdatedCap: BigNumber;
  let bucket1: IGhoToken.BucketStruct;
  let facilitator1Config: IGhoToken.FacilitatorStruct;

  let facilitator2: SignerWithAddress;
  let facilitator2Label: string;
  let facilitator2Cap: BigNumber;
  let bucket2: IGhoToken.BucketStruct;
  let facilitator2Config: IGhoToken.FacilitatorStruct;

  let facilitator3: SignerWithAddress;
  let facilitator3Label: string;
  let facilitator3Cap: BigNumber;
  let bucket3: IGhoToken.BucketStruct;
  let facilitator3Config: IGhoToken.FacilitatorStruct;

  let facilitator4: SignerWithAddress;
  let facilitator4Label: string;
  let facilitator4Cap: BigNumber;
  let bucket4: IGhoToken.BucketStruct;
  let facilitator4Config: IGhoToken.FacilitatorStruct;

  let facilitator5: SignerWithAddress;
  let facilitator5Label: string;
  let facilitator5Cap: BigNumber;
  let bucket5: IGhoToken.BucketStruct;
  let facilitator5Config: IGhoToken.FacilitatorStruct;

  let ghoToken;

  before(async () => {
    await hre.run('set-DRE');
    ethers = DRE.ethers;

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
    facilitator1UpdatedCap = ethers.utils.parseUnits('900000000', 18);
    bucket1 = {
      capacity: facilitator1Cap,
      level: 0,
    };
    facilitator1Config = {
      bucket: bucket1,
      label: facilitator1Label,
    };

    // setup facilitator2
    facilitator2 = users[2];
    facilitator2Label = 'Bob_Facilitator';
    facilitator2Cap = ethers.utils.parseUnits('200000000', 18);
    bucket2 = {
      capacity: facilitator2Cap,
      level: 0,
    };
    facilitator2Config = {
      bucket: bucket2,
      label: facilitator2Label,
    };

    // setup facilitator3
    facilitator3 = users[3];
    facilitator3Label = 'Cat_Facilitator';
    facilitator3Cap = ethers.utils.parseUnits('300000000', 18);
    bucket3 = {
      capacity: facilitator3Cap,
      level: 0,
    };
    facilitator3Config = {
      bucket: bucket3,
      label: facilitator3Label,
    };

    // setup facilitator3
    facilitator4 = users[4];
    facilitator4Label = 'Dom_Facilitator';
    facilitator4Cap = ethers.utils.parseUnits('400000000', 18);
    bucket4 = {
      capacity: facilitator4Cap,
      level: 0,
    };
    facilitator4Config = {
      bucket: bucket4,
      label: facilitator4Label,
    };

    // setup facilitator3
    facilitator5 = users[5];
    facilitator5Label = 'Ed_Facilitator';
    facilitator5Cap = ethers.utils.parseUnits('500000000', 18);
    bucket5 = {
      capacity: facilitator5Cap,
      level: 0,
    };
    facilitator5Config = {
      bucket: bucket5,
      label: facilitator5Label,
    };

    ghoTokenFactory = new GhoToken__factory(users[0].signer);
  });

  it('Deploy GhoToken without facilitators', async function () {
    const tempGhoToken = await ghoTokenFactory.deploy([], []);

    const { TOKEN_DECIMALS, TOKEN_NAME, TOKEN_SYMBOL } = ghoTokenConfig;

    expect(await tempGhoToken.decimals()).to.be.equal(TOKEN_DECIMALS);
    expect(await tempGhoToken.name()).to.be.equal(TOKEN_NAME);
    expect(await tempGhoToken.symbol()).to.be.equal(TOKEN_SYMBOL);

    expect((await tempGhoToken.getFacilitatorsList()).length).to.be.equal(0);
  });

  it('Deploy GhoToken with one facilitator', async function () {
    const tempGhoToken = await ghoTokenFactory.deploy([facilitator1.address], [facilitator1Config]);

    const deploymentReceipt = await ethers.provider.getTransactionReceipt(
      tempGhoToken.deployTransaction.hash
    );
    expect(deploymentReceipt.logs.length).to.be.equal(2);

    const ownershipEvent = tempGhoToken.interface.parseLog(deploymentReceipt.logs[0]);
    const facilitatorAddedEvent = tempGhoToken.interface.parseLog(deploymentReceipt.logs[1]);

    expect(ownershipEvent.name).to.equal('OwnershipTransferred');
    expect(ownershipEvent.args.previousOwner).to.equal(ZERO_ADDRESS);
    expect(ownershipEvent.args.newOwner).to.equal(users[0].address);

    expect(facilitatorAddedEvent.name).to.equal('FacilitatorAdded');
    expect(facilitatorAddedEvent.args[0]).to.equal(facilitator1.address);
    // expect(facilitatorAddedEvent.args[1]).to.equal(facilitator1Label);
    expect(facilitatorAddedEvent.args[2]).to.equal(facilitator1Cap);

    const { TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS } = ghoTokenConfig;

    expect(await tempGhoToken.decimals()).to.be.equal(TOKEN_DECIMALS);
    expect(await tempGhoToken.name()).to.be.equal(TOKEN_NAME);
    expect(await tempGhoToken.symbol()).to.be.equal(TOKEN_SYMBOL);

    const facilitatorList = await tempGhoToken.getFacilitatorsList();
    expect(facilitatorList.length).to.be.equal(1);

    let facilitatorAddr = facilitatorList[0];
    let facilitator = await tempGhoToken.getFacilitator(facilitatorAddr);
    expect(facilitator.label).to.be.equal(facilitator1Label);
    expect(facilitator.bucket.level).to.be.equal(0);
    expect(facilitator.bucket.capacity).to.be.equal(facilitator1Cap);
  });

  it('Deploy GhoToken with two facilitators', async function () {
    ghoToken = await ghoTokenFactory.deploy(
      [facilitator1.address, facilitator2.address],
      [facilitator1Config, facilitator2Config]
    );

    const deploymentReceipt = await ethers.provider.getTransactionReceipt(
      ghoToken.deployTransaction.hash
    );
    expect(deploymentReceipt.logs.length).to.be.equal(3);

    const ownershipEvent = ghoToken.interface.parseLog(deploymentReceipt.logs[0]);
    const facilitatorAddedEvent1 = ghoToken.interface.parseLog(deploymentReceipt.logs[1]);
    const facilitatorAddedEvent2 = ghoToken.interface.parseLog(deploymentReceipt.logs[2]);

    expect(ownershipEvent.name).to.equal('OwnershipTransferred');
    expect(ownershipEvent.args.previousOwner).to.equal(ZERO_ADDRESS);
    expect(ownershipEvent.args.newOwner).to.equal(users[0].address);

    expect(facilitatorAddedEvent1.name).to.equal('FacilitatorAdded');
    expect(facilitatorAddedEvent1.args[0]).to.equal(facilitator1.address);
    // expect(facilitatorAddedEvent1.args[1]).to.equal(facilitator1Label);
    expect(facilitatorAddedEvent1.args[2]).to.equal(facilitator1Cap);

    expect(facilitatorAddedEvent2.name).to.equal('FacilitatorAdded');
    expect(facilitatorAddedEvent2.args[0]).to.equal(facilitator2.address);
    // expect(facilitatorAddedEvent.args[1]).to.equal(facilitator1Label);
    expect(facilitatorAddedEvent2.args[2]).to.equal(facilitator2Cap);

    const { TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS } = ghoTokenConfig;

    expect(await ghoToken.decimals()).to.be.equal(TOKEN_DECIMALS);
    expect(await ghoToken.name()).to.be.equal(TOKEN_NAME);
    expect(await ghoToken.symbol()).to.be.equal(TOKEN_SYMBOL);

    const facilitatorList = await ghoToken.getFacilitatorsList();
    expect(facilitatorList.length).to.be.equal(2);

    let tempFacilitator = await ghoToken.getFacilitator(facilitatorList[0]);
    expect(tempFacilitator.label).to.be.equal(facilitator1Label);
    expect(tempFacilitator.bucket.level).to.be.equal(0);
    expect(tempFacilitator.bucket.capacity).to.be.equal(facilitator1Cap);

    tempFacilitator = await ghoToken.getFacilitator(facilitatorList[1]);
    expect(tempFacilitator.label).to.be.equal(facilitator2Label);
    expect(tempFacilitator.bucket.level).to.be.equal(0);
    expect(tempFacilitator.bucket.capacity).to.be.equal(facilitator2Cap);
  });

  it('Mint from facilitator 1', async function () {
    const mintAmount = ethers.utils.parseUnits('250000.0', 18);
    await expect(ghoToken.connect(facilitator1.signer).mint(facilitator1.address, mintAmount))
      .to.emit(ghoToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, facilitator1.address, mintAmount)
      .to.emit(ghoToken, 'BucketLevelChanged')
      .withArgs(facilitator1.address, 0, mintAmount);

    const facilitatorBucket = await ghoToken.getFacilitatorBucket(facilitator1.address);

    expect(facilitatorBucket.level).to.be.equal(mintAmount);
  });

  it('Mint from facilitator 2', async function () {
    const mintAmount = ethers.utils.parseUnits('500000.0', 18);
    await expect(ghoToken.connect(facilitator2.signer).mint(facilitator2.address, mintAmount))
      .to.emit(ghoToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, facilitator2.address, mintAmount)
      .to.emit(ghoToken, 'BucketLevelChanged')
      .withArgs(facilitator2.address, 0, mintAmount);

    const facilitatorBucket = await ghoToken.getFacilitatorBucket(facilitator2.address);

    expect(facilitatorBucket.level).to.be.equal(mintAmount);
  });

  it('Mint from non-facilitator - (revert expected)', async function () {
    const mintAmount = ethers.utils.parseUnits('500000.0', 18);
    await expect(
      ghoToken.connect(users[0].signer).mint(users[0].address, mintAmount)
    ).to.be.revertedWith('INVALID_FACILITATOR');
  });

  it('Mint exceeding bucket capacity - (revert expected)', async function () {
    await expect(
      ghoToken.connect(facilitator1.signer).mint(facilitator1.address, facilitator1Cap)
    ).to.be.revertedWith('FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
  });

  it('Burn from facilitator 1', async function () {
    const previouslyMinted = ethers.utils.parseUnits('250000.0', 18);
    const burnAmount = ethers.utils.parseUnits('250000.0', 18);

    await expect(ghoToken.connect(facilitator1.signer).burn(burnAmount))
      .to.emit(ghoToken, 'Transfer')
      .withArgs(facilitator1.address, ZERO_ADDRESS, burnAmount)
      .to.emit(ghoToken, 'BucketLevelChanged')
      .withArgs(facilitator1.address, previouslyMinted, previouslyMinted.sub(burnAmount));

    const facilitatorBucket = await ghoToken.getFacilitatorBucket(facilitator1.address);

    expect(facilitatorBucket.level).to.be.equal(previouslyMinted.sub(burnAmount));
  });

  it('Burn from facilitator 2', async function () {
    const previouslyMinted = ethers.utils.parseUnits('500000.0', 18);
    const burnAmount = ethers.utils.parseUnits('250000.0', 18);

    await expect(ghoToken.connect(facilitator2.signer).burn(burnAmount))
      .to.emit(ghoToken, 'Transfer')
      .withArgs(facilitator2.address, ZERO_ADDRESS, burnAmount)
      .to.emit(ghoToken, 'BucketLevelChanged')
      .withArgs(facilitator2.address, previouslyMinted, previouslyMinted.sub(burnAmount));

    const facilitatorBucket = await ghoToken.getFacilitatorBucket(facilitator2.address);

    expect(facilitatorBucket.level).to.be.equal(previouslyMinted.sub(burnAmount));
  });

  it('Burn more than minted facilitator 1 - (revert expected)', async function () {
    const burnAmount = ethers.utils.parseUnits('250000.0', 18);

    await expect(ghoToken.connect(facilitator1.signer).burn(burnAmount)).to.be.revertedWith('0x11');
  });

  it('Burn from a non-facilitator - (revert expected)', async function () {
    const burnAmount = ethers.utils.parseUnits('250000.0', 18);

    await expect(ghoToken.connect(users[0].signer).burn(burnAmount)).to.be.revertedWith('0x11');
  });

  it('Update facilitator1 capacity', async function () {
    await expect(
      ghoToken.setFacilitatorBucketCapacity(facilitator1.address, facilitator1UpdatedCap)
    )
      .to.emit(ghoToken, 'FacilitatorBucketCapacityUpdated')
      .withArgs(facilitator1.address, facilitator1Cap, facilitator1UpdatedCap);

    const facilitatorBucket = await ghoToken.getFacilitatorBucket(facilitator1.address);

    expect(facilitatorBucket.capacity).to.be.equal(facilitator1UpdatedCap);
  });

  it('Update facilitator1 capacity from non-owner - (revert expected)', async function () {
    await expect(
      ghoToken
        .connect(facilitator1.signer)
        .setFacilitatorBucketCapacity(facilitator1.address, facilitator1UpdatedCap)
    ).to.be.revertedWith('Ownable: caller is not the owner');
  });

  it('Update capacity of a non-existent facilitator - (revert expected)', async function () {
    await expect(
      ghoToken.setFacilitatorBucketCapacity(users[0].address, facilitator1UpdatedCap)
    ).to.be.revertedWith('FACILITATOR_DOES_NOT_EXIST');
  });

  it('Mint after facilitator1 capacity increase', async function () {
    const mintAmount = facilitator1Cap;

    await expect(ghoToken.connect(facilitator1.signer).mint(facilitator1.address, mintAmount))
      .to.emit(ghoToken, 'Transfer')
      .withArgs(ZERO_ADDRESS, facilitator1.address, mintAmount)
      .to.emit(ghoToken, 'BucketLevelChanged')
      .withArgs(facilitator1.address, 0, mintAmount);

    const facilitatorBucket = await ghoToken.getFacilitatorBucket(facilitator1.address);

    expect(facilitatorBucket.level).to.be.equal(mintAmount);
  });

  // adding facilitators
  it('Add one facilitator', async function () {
    const labelHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(facilitator3Label));

    await expect(ghoToken.addFacilitators([facilitator3.address], [facilitator3Config]))
      .to.emit(ghoToken, 'FacilitatorAdded')
      .withArgs(facilitator3.address, labelHash, facilitator3Cap);

    const facilitatorList = await ghoToken.getFacilitatorsList();
    expect(facilitatorList.length).to.be.equal(3);
  });

  it('Add facilitator from non-owner - (revert expected)', async function () {
    await expect(
      ghoToken
        .connect(facilitator1.signer)
        .addFacilitators([facilitator4.address], [facilitator4Config])
    ).to.be.revertedWith('Ownable: caller is not the owner');
  });

  it('Add facilitator already added - (revert expected)', async function () {
    await expect(
      ghoToken.addFacilitators([facilitator1.address], [facilitator1Config])
    ).to.be.revertedWith('FACILITATOR_ALREADY_EXISTS');
  });

  it('Add facilitator with invalid label - (revert expected)', async function () {
    facilitator4Config.label = '';
    await expect(
      ghoToken.addFacilitators([facilitator4.address], [facilitator4Config])
    ).to.be.revertedWith('INVALID_LABEL');

    // reset facilitator 4 label
    facilitator4Config.label = facilitator4Label;
  });

  it('Add facilitator with invalid level - (revert expected)', async function () {
    facilitator4Config.bucket.level = ethers.utils.parseUnits('100000000', 18);
    await expect(
      ghoToken.addFacilitators([facilitator4.address], [facilitator4Config])
    ).to.be.revertedWith('INVALID_BUCKET_CONFIGURATION');

    // reset facilitator 4 level
    facilitator4Config.bucket.level = 0;
  });

  it('Add facilitator with address and config length mis-match - (revert expected)', async function () {
    await expect(
      ghoToken.addFacilitators([facilitator4.address], [facilitator4Config, facilitator5Config])
    ).to.be.revertedWith('INVALID_INPUT');
  });

  it('Add two facilitator', async function () {
    const label4Hash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(facilitator4Label));
    const label5Hash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(facilitator5Label));

    await expect(
      ghoToken.addFacilitators(
        [facilitator4.address, facilitator5.address],
        [facilitator4Config, facilitator5Config]
      )
    )
      .to.emit(ghoToken, 'FacilitatorAdded')
      .withArgs(facilitator4.address, label4Hash, facilitator4Cap)
      .to.emit(ghoToken, 'FacilitatorAdded')
      .withArgs(facilitator5.address, label5Hash, facilitator5Cap);

    const facilitatorList = await ghoToken.getFacilitatorsList();
    expect(facilitatorList.length).to.be.equal(5);
  });

  // remove facilitators
  it('Remove facilitator3', async function () {
    const labelHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(facilitator3Label));

    await expect(ghoToken.removeFacilitators([facilitator3.address]))
      .to.emit(ghoToken, 'FacilitatorRemoved')
      .withArgs(facilitator3.address);

    const facilitatorList = await ghoToken.getFacilitatorsList();
    expect(facilitatorList.length).to.be.equal(4);

    expect(facilitatorList[0]).to.be.equal(facilitator1.address);
    expect(facilitatorList[1]).to.be.equal(facilitator2.address);
    expect(facilitatorList[2]).to.be.equal(facilitator5.address);
    expect(facilitatorList[3]).to.be.equal(facilitator4.address);
  });

  it('Remove facilitator3 that does not exist - (revert expected)', async function () {
    await expect(ghoToken.removeFacilitators([facilitator3.address])).to.be.revertedWith(
      'FACILITATOR_DOES_NOT_EXIST'
    );

    const facilitatorList = await ghoToken.getFacilitatorsList();
    expect(facilitatorList.length).to.be.equal(4);

    expect(facilitatorList[0]).to.be.equal(facilitator1.address);
    expect(facilitatorList[1]).to.be.equal(facilitator2.address);
    expect(facilitatorList[2]).to.be.equal(facilitator5.address);
    expect(facilitatorList[3]).to.be.equal(facilitator4.address);
  });

  it('Remove facilitator2 - (revert expected)', async function () {
    await expect(ghoToken.removeFacilitators([facilitator2.address])).to.be.revertedWith(
      'FACILITATOR_BUCKET_LEVEL_NOT_ZERO'
    );
  });
});
