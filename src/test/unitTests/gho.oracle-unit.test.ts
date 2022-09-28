import hardhat, { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { GhoOracle, GhoOracle__factory } from '../../../types';
import { evmRevert, evmSnapshot } from '../../helpers/misc-utils';

const GHO_ORACLE_DECIMALS = 8;
const TOKEN_TYPE = 1;
const GHO_PRICE = ethers.utils.parseUnits('1', 8);

describe('Gho Oracle Unit Test', () => {
  let ghoOracle: GhoOracle;
  let deployer: SignerWithAddress;
  let users: SignerWithAddress[];

  let snapId;

  before(async () => {
    await hardhat.run('set-DRE');
    [deployer, ...users] = await hardhat.ethers.getSigners();
    ghoOracle = await new GhoOracle__factory(deployer).deploy(GHO_PRICE);
  });

  beforeEach(async () => {
    snapId = await evmSnapshot();
  });

  afterEach(async () => {
    await evmRevert(snapId);
  });

  it('Check initial config params of GHO oracle', async () => {
    expect(await ghoOracle.decimals()).to.equal(GHO_ORACLE_DECIMALS);
    expect(await ghoOracle.getTokenType()).to.equal(TOKEN_TYPE);
  });

  it('Check price of GHO', async () => {
    expect(await ghoOracle.latestAnswer()).to.equal(GHO_PRICE);
  });
});
