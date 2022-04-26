import hre from 'hardhat';
import { expect } from 'chai';
import { DRE } from '../../helpers/misc-utils';
import { aaveMarketAddresses, asdTokenConfig } from '../../helpers/config';
import { impersonateAccountHardhat } from '../../helpers/misc-utils';
import { ZERO_ADDRESS } from '../../helpers/constants';
import { solidity } from 'ethereum-waffle';

describe('Antei AToken Unit Test', () => {
  const { TOKEN_NAME, TOKEN_DECIMALS, TOKEN_SYMBOL } = asdTokenConfig;
  const aaveGovernance = aaveMarketAddresses.shortExecutor;

  const entity1 = '0x2acAb3DEa77832C09420663b0E1cB386031bA17B';
  const entity2 = '0x6fC355D4e0EE44b292E50878F49798ff755A5bbC';
  const entity3 = '0x492E71Fa9f56d558f30388c20779e13e7A13e0dA';
  const entity4 = '0x0811F26C17284B6E331Beaa2328471107576e601';

  let ethers;

  let asd;
  let asdAdmin;

  let tenMillion;
  let twentyMillion;
  let fiftyMillion;
  let eightyMillion;

  before(async () => {
    await hre.run('set-DRE');
    ethers = DRE.ethers;

    tenMillion = ethers.utils.parseUnits('1.0', 7 + 18);
    twentyMillion = ethers.utils.parseUnits('2.0', 7 + 18);
    fiftyMillion = ethers.utils.parseUnits('5.0', 7 + 18);
    eightyMillion = ethers.utils.parseUnits('8.0', 7 + 18);

    const asd_factory = await ethers.getContractFactory('AnteiStableDollarEntities');
    asd = await asd_factory.deploy([], [], TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);

    const adminSigner = await impersonateAccountHardhat(aaveGovernance);
    asdAdmin = asd.connect(adminSigner);
  });

  it('Test transfer ownership', async function () {
    const originalOwner = asd.deployTransaction.from;

    await expect(asd.transferOwnership(aaveGovernance))
      .to.emit(asd, 'OwnershipTransferred')
      .withArgs(originalOwner, aaveGovernance);
  });

  it('Test new owner', async function () {
    expect(await asd.owner()).to.be.equal(aaveGovernance);
  });

  it('Test no entity deployment - token info', async function () {
    expect(await asd.name()).to.be.equal(TOKEN_NAME);
    expect(await asd.symbol()).to.be.equal(TOKEN_SYMBOL);
    expect(await asd.decimals()).to.be.equal(TOKEN_DECIMALS);
  });

  it('Test no entity deployment - isEntity', async function () {
    expect(await asd.isEntity(entity1)).to.be.false;
  });

  it('Test no entity deployment - getEntityList', async function () {
    const entityList = await asd.getEntityList();
    expect(entityList.length).to.be.equal(0);
  });

  it('Add an entity', async function () {
    await expect(asdAdmin.addEntities([entity1], [tenMillion]))
      .to.emit(asd, 'EntityAdded')
      .withArgs(entity1)
      .to.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity1, tenMillion);
  });

  it('Check entity list', async function () {
    const entityList = await asd.getEntityList();
    expect(entityList.length).to.be.equal(1);
    expect(entityList[0]).to.be.equal(entity1);
  });

  it('Check isEntity', async function () {
    expect(await asd.isEntity(entity1)).to.be.true;
  });

  it('Check new entity ASD balance', async function () {
    expect(await asd.balanceOf(entity1)).to.be.equal(tenMillion);
  });

  it('Check ASD total supply', async function () {
    expect(await asd.totalSupply()).to.be.equal(tenMillion);
  });

  it('Add multiple entities', async function () {
    await expect(asdAdmin.addEntities([entity2, entity3], [twentyMillion, fiftyMillion]))
      .to.emit(asd, 'EntityAdded')
      .withArgs(entity2)
      .to.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity2, twentyMillion)
      .to.emit(asd, 'EntityAdded')
      .withArgs(entity3)
      .to.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity3, fiftyMillion);
  });

  it('Check entity list', async function () {
    const entityList = await asd.getEntityList();
    expect(entityList.length).to.be.equal(3);
    expect(entityList[0]).to.be.equal(entity1);
    expect(entityList[1]).to.be.equal(entity2);
    expect(entityList[2]).to.be.equal(entity3);
  });

  it('Check isEntity', async function () {
    expect(await asd.isEntity(entity2)).to.be.true;
    expect(await asd.isEntity(entity3)).to.be.true;
    expect(await asd.isEntity(ZERO_ADDRESS)).to.be.false;
  });

  it('Check new entity ASD balance', async function () {
    expect(await asd.balanceOf(entity2)).to.be.equal(twentyMillion);
    expect(await asd.balanceOf(entity3)).to.be.equal(fiftyMillion);
  });

  it('Check updated ASD total supply', async function () {
    expect(await asd.totalSupply()).to.be.equal(tenMillion.add(twentyMillion).add(fiftyMillion));
  });

  it('Mint entity 2 more ASD', async function () {
    await expect(asdAdmin.mint(entity2, tenMillion))
      .to.be.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity2, tenMillion);
  });

  it('Check entity 2 balance', async function () {
    expect(await asd.balanceOf(entity2)).to.be.equal(twentyMillion.add(tenMillion));
  });

  it('Check updated total supply', async function () {
    const expectedTotalSupply = tenMillion.add(twentyMillion).add(fiftyMillion).add(tenMillion);

    expect(await asd.totalSupply()).to.be.equal(expectedTotalSupply);
  });

  it('Entity 1 burn ASD', async function () {
    const entity1Signer = await impersonateAccountHardhat(entity1);
    const asdFromEntity1 = asd.connect(entity1Signer);
    await expect(asdFromEntity1.burn(tenMillion))
      .to.be.emit(asd, 'Transfer')
      .withArgs(entity1, ZERO_ADDRESS, tenMillion);
  });

  it('Check entity 1 ASD balance', async function () {
    expect(await asd.balanceOf(entity1)).to.be.equal(0);
  });

  it('Check updated total supply', async function () {
    const expectedTotalSupply = tenMillion.add(twentyMillion).add(fiftyMillion);
    expect(await asd.totalSupply()).to.be.equal(expectedTotalSupply);
  });

  it('Governance removes entity 1', async function () {
    await expect(asdAdmin.removeEntities([entity1]))
      .to.emit(asd, 'EntityRemoved')
      .withArgs(entity1);
  });

  it('Check entity 1 isEntity', async function () {
    expect(await asdAdmin.isEntity(entity1)).to.be.false;
  });

  it('Check updated entity list', async function () {
    const entityList = await asd.getEntityList();
    expect(entityList.length).to.be.equal(2);
    expect(entityList[0]).to.be.equal(entity3);
    expect(entityList[1]).to.be.equal(entity2);
  });

  it('Add entity with amount 0 - skip minting', async function () {
    const tx = await asdAdmin.addEntities([entity1], [0]);
    const receipt = await tx.wait();

    const transferEvents = receipt.events.filter((e) => e.event === 'Transfer');
    const entityAddedEvents = receipt.events.filter((e) => e.event === 'EntityAdded');

    expect(transferEvents.length).to.be.equal(0);
    expect(entityAddedEvents.length).to.be.equal(1);
  });

  /************** EXPECT REVERTS **********************/
  it('Add entity from non-owner - (revert expected)', async function () {
    await expect(asd.addEntities([entity4], [eightyMillion])).to.be.revertedWith(
      'Ownable: caller is not the owner'
    );
  });

  it('Add entities with in correct amounts length - (revert expected)', async function () {
    await expect(
      asdAdmin.addEntities([entity4], [eightyMillion, twentyMillion])
    ).to.be.revertedWith('INPUT_ENTITIES_AND_AMOUNTS_MUST_BE_SAME_LENGTH');
  });

  it('Add entity that is already added - (revert expected)', async function () {
    await expect(asdAdmin.addEntities([entity2], [eightyMillion])).to.be.revertedWith(
      'ENTITY_ALREADY_ADDED'
    );
  });

  it('Remove entity from non-owner - (revert expected)', async function () {
    await expect(asd.removeEntities([entity1])).to.be.revertedWith(
      'Ownable: caller is not the owner'
    );
  });

  it('Remove entity does not exist - (revert expected)', async function () {
    await expect(asdAdmin.removeEntities([entity4])).to.be.revertedWith('ENTITY_DOES_NOT_EXIST');
  });

  it('Mint from non-owner - (revert expected)', async function () {
    await expect(asd.mint(entity1, eightyMillion)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    );
  });

  it('Mint to a non-entity - (revert expected)', async function () {
    await expect(asdAdmin.mint(entity4, eightyMillion)).to.be.revertedWith('ENTITY_DOES_NOT_EXIST');
  });

  it('Burn from non entity - (revert expected)', async function () {
    await expect(asd.burn(eightyMillion)).to.be.revertedWith('CALLER_IS_NOT_AN_ENTITY');
  });

  /************** MULTI-ENTITY DEPLOYMENTS **********************/

  it('Deploy ASD with multiple entities to start', async function () {
    const asd_factory = await ethers.getContractFactory('AnteiStableDollarEntities');
    asd = await asd_factory.deploy(
      [entity1, entity2, entity3, entity4],
      [tenMillion, twentyMillion, fiftyMillion, eightyMillion],
      TOKEN_NAME,
      TOKEN_SYMBOL,
      TOKEN_DECIMALS
    );
    await expect(asd.deployTransaction)
      .to.emit(asd, 'EntityAdded')
      .withArgs(entity1)
      .to.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity1, tenMillion)
      .to.emit(asd, 'EntityAdded')
      .withArgs(entity2)
      .to.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity2, twentyMillion)
      .to.emit(asd, 'EntityAdded')
      .withArgs(entity3)
      .to.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity3, fiftyMillion)
      .to.emit(asd, 'EntityAdded')
      .withArgs(entity4)
      .to.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity4, eightyMillion);
  });

  it('Check ASD balances with multi-entity deploy', async function () {
    const asd_factory = await ethers.getContractFactory('AnteiStableDollarEntities');
    asd = await asd_factory.deploy(
      [entity1, entity2, entity3, entity4],
      [tenMillion, twentyMillion, fiftyMillion, eightyMillion],
      TOKEN_NAME,
      TOKEN_SYMBOL,
      TOKEN_DECIMALS
    );
    await expect(asd.deployTransaction)
      .to.emit(asd, 'EntityAdded')
      .withArgs(entity1)
      .to.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity1, tenMillion)
      .to.emit(asd, 'EntityAdded')
      .withArgs(entity2)
      .to.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity2, twentyMillion)
      .to.emit(asd, 'EntityAdded')
      .withArgs(entity3)
      .to.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity3, fiftyMillion)
      .to.emit(asd, 'EntityAdded')
      .withArgs(entity4)
      .to.emit(asd, 'Transfer')
      .withArgs(ZERO_ADDRESS, entity4, eightyMillion);
  });

  it('Check balances - multi entity deploy', async function () {
    expect(await asd.balanceOf(entity1)).to.be.equal(tenMillion);
    expect(await asd.balanceOf(entity2)).to.be.equal(twentyMillion);
    expect(await asd.balanceOf(entity3)).to.be.equal(fiftyMillion);
    expect(await asd.balanceOf(entity4)).to.be.equal(eightyMillion);
  });

  it('Check totalSupply - multi entity deploy', async function () {
    const expectedTotalSupply = tenMillion.add(twentyMillion).add(fiftyMillion).add(eightyMillion);

    expect(await asd.totalSupply()).to.be.equal(expectedTotalSupply);
  });

  it('Check entity list - multi entity deploy', async function () {
    const entityList = await asd.getEntityList();
    expect(entityList.length).to.be.equal(4);
    expect(entityList[0]).to.be.equal(entity1);
    expect(entityList[1]).to.be.equal(entity2);
    expect(entityList[2]).to.be.equal(entity3);
    expect(entityList[3]).to.be.equal(entity4);
  });

  it('Multi entity removal', async function () {
    await expect(asd.removeEntities([entity2, entity3]))
      .to.emit(asd, 'EntityRemoved')
      .withArgs(entity2)
      .to.emit(asd, 'EntityRemoved')
      .withArgs(entity3);
  });

  it('Check entity list - multi entity removal', async function () {
    const entityList = await asd.getEntityList();
    expect(entityList.length).to.be.equal(2);
    expect(entityList[0]).to.be.equal(entity1);
    expect(entityList[1]).to.be.equal(entity4);
  });
});
