import hre from 'hardhat';
import { expect } from 'chai';
import { DRE } from '../../helpers/misc-utils';
import { SignerWithAddress } from '../helpers/make-suite';
import { ghoTokenConfig } from '../../helpers/config';
import { GhoToken__factory, IGhoToken } from '../../../types';
import { HardhatEthersHelpers } from '@nomiclabs/hardhat-ethers/types';
import { BigNumber } from 'ethers';

describe('GhoToken Unit Test', () => {
  let ethers: typeof import('ethers/lib/ethers') & HardhatEthersHelpers;
  let ghoTokenFactory: GhoToken__factory;

  let users: SignerWithAddress[] = [];

  let facilitator1: SignerWithAddress;
  let facilitator1Label: string;
  let facilitator1Cap: BigNumber;
  let bucket1: IGhoToken.BucketStruct;
  let facilitator1Config: IGhoToken.FacilitatorStruct;

  let facilitator2: SignerWithAddress;
  let facilitator2Label: string;
  let facilitator2Cap: BigNumber;
  let bucket2: IGhoToken.BucketStruct;
  let facilitator2Config: IGhoToken.FacilitatorStruct;

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
    bucket1 = {
      maxCapacity: facilitator1Cap,
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
      maxCapacity: facilitator2Cap,
      level: 0,
    };
    facilitator2Config = {
      bucket: bucket2,
      label: facilitator2Label,
    };

    ghoTokenFactory = new GhoToken__factory(users[0].signer);
  });

  it('Deploy GhoToken without facilitators', async function () {
    const ghoToken = await ghoTokenFactory.deploy([], []);

    const { TOKEN_DECIMALS, TOKEN_NAME, TOKEN_SYMBOL } = ghoTokenConfig;

    expect(await ghoToken.decimals()).to.be.equal(TOKEN_DECIMALS);
    expect(await ghoToken.name()).to.be.equal(TOKEN_NAME);
    expect(await ghoToken.symbol()).to.be.equal(TOKEN_SYMBOL);

    expect((await ghoToken.getFacilitatorsList()).length).to.be.equal(0);
  });

  it('Deploy GhoToken with one facilitator', async function () {
    const ghoToken = await ghoTokenFactory.deploy([facilitator1.address], [facilitator1Config]);

    const deploymentReceipt = await ethers.provider.getTransactionReceipt(
      ghoToken.deployTransaction.hash
    );
    expect(deploymentReceipt.logs.length).to.be.equal(2);

    const { TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS } = ghoTokenConfig;

    expect(await ghoToken.decimals()).to.be.equal(TOKEN_DECIMALS);
    expect(await ghoToken.name()).to.be.equal(TOKEN_NAME);
    expect(await ghoToken.symbol()).to.be.equal(TOKEN_SYMBOL);

    const facilitatorList = await ghoToken.getFacilitatorsList();
    expect(facilitatorList.length).to.be.equal(1);

    let facilitatorAddr = facilitatorList[0];
    let facilitator = await ghoToken.getFacilitator(facilitatorAddr);
    expect(facilitator.label).to.be.equal(facilitator1Label);
    expect(facilitator.bucket.level).to.be.equal(0);
    expect(facilitator.bucket.maxCapacity).to.be.equal(facilitator1Cap);

    facilitator = await ghoToken.getFacilitator(facilitator1.address);
    expect(facilitator.label).to.be.equal(facilitator1Label);
    expect(facilitator.bucket.level).to.be.equal(0);
    expect(facilitator.bucket.maxCapacity).to.be.equal(facilitator1Cap);
  });
});
