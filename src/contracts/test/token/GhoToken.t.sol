// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import 'ds-test/test.sol';
import 'forge-std/console.sol';
import {GhoToken} from '../../token/GhoToken.sol';

interface Vm {
  function expectEmit(
    bool,
    bool,
    bool,
    bool
  ) external;

  function prank(address) external;

  function expectRevert(bytes calldata) external;

  function startPrank(address) external;

  function stopPrank() external;
}

contract GhoTokenTest is DSTest {
  Vm vm = Vm(HEVM_ADDRESS);

  event MinterAdded(uint256 indexed entityId, address indexed minter);
  event BurnerAdded(uint256 indexed entityId, address indexed burner);
  event MinterRemoved(uint256 indexed entityId, address indexed minter);
  event BurnerRemoved(uint256 indexed entityId, address indexed burner);
  event EntityCreated(uint256 indexed id, string label, address entityAddress, uint256 mintLimit);
  event EntityActivated(uint256 indexed entityId, bool active);
  event EntityMintLimitUpdated(
    uint256 indexed entityId,
    uint256 oldMintLimit,
    uint256 newMintLimit
  );

  event Transfer(address indexed from, address indexed to, uint256 value);

  address private immutable minter1 = 0x0000000000000000000000000000000000000001;
  address private immutable minter2 = 0x0000000000000000000000000000000000000002;
  address private immutable minter3 = 0x0000000000000000000000000000000000000003;
  address private immutable minter4 = 0x0000000000000000000000000000000000000004;
  address private immutable minter5 = 0x0000000000000000000000000000000000000005;

  address private immutable burner1 = 0x0000000000000000000000000000000000000006;
  address private immutable burner2 = 0x0000000000000000000000000000000000000007;
  address private immutable burner3 = 0x0000000000000000000000000000000000000008;
  address private immutable burner4 = 0x0000000000000000000000000000000000000009;
  address private immutable burner5 = 0x000000000000000000000000000000000000000A;

  address private immutable user1 = 0x000000000000000000000000000000000000000b;
  address private immutable user2 = 0x000000000000000000000000000000000000000C;

  uint256 private immutable mintAmount = 10e18;

  address[] private expectedAddresses;

  GhoToken private gho;

  /****** Entity Data *******/
  string private constant entity1Label = 'entity-one-label';
  address private constant entity1Address = address(100);
  uint256 private constant entity1MintLimit = 1000000000e18;
  address[] private entity1Minters;
  address[] private entity1Burners;
  bool private constant entity1Active = true;

  string private constant entity2Label = 'entity-two-label';
  address private constant entity2Address = address(200);
  uint256 private constant entity2MintLimit = 2000000000e18;
  address[] private entity2Minters;
  address[] private entity2Burners;
  bool private constant entity2Active = true;

  GhoToken.InputEntity private inputEntity1;
  GhoToken.InputEntity private inputEntity2;
  GhoToken.InputEntity[] inputEntities;

  function setUp() public {
    entity1Minters.push(minter1);
    entity1Burners.push(burner1);

    entity2Minters.push(minter2);
    entity2Minters.push(minter3);
    entity2Burners.push(burner2);
    entity2Burners.push(burner3);

    inputEntity1 = GhoToken.InputEntity({
      label: entity1Label,
      entityAddress: entity1Address,
      mintLimit: entity1MintLimit,
      minters: entity1Minters,
      burners: entity1Burners,
      active: entity1Active
    });

    inputEntity2 = GhoToken.InputEntity({
      label: entity2Label,
      entityAddress: entity2Address,
      mintLimit: entity2MintLimit,
      minters: entity2Minters,
      burners: entity2Burners,
      active: entity2Active
    });

    inputEntities.push(inputEntity1);
    inputEntities.push(inputEntity2);
    gho = new GhoToken(inputEntities);
  }

  /****** Deployment Tests *******/

  function testDeployNoParams() public {
    inputEntities.pop();
    inputEntities.pop();

    GhoToken tempGho = new GhoToken(inputEntities);

    GhoToken.Entity memory entity = tempGho.getEntityById(1);

    assertEq(entity.label, '');
    assertEq(entity.entityAddress, address(0));
    assertEq(entity.mintLimit, 0);
    assertEq(entity.mintBalance, 0);
    _compareAddressArrays(entity.minters, expectedAddresses);
    _compareAddressArrays(entity.burners, expectedAddresses);
    assertTrue(!entity.active);

    assertEq(tempGho.getEntityCount(), 0);

    assertEq(tempGho.name(), 'Gho Token');
    assertEq(tempGho.symbol(), 'GHO');
    assertEq(tempGho.decimals(), 18);
  }

  function testDeployOneEntity() public {
    inputEntities.pop();

    vm.expectEmit(true, true, false, true);
    emit MinterAdded(1, minter1);
    vm.expectEmit(true, true, false, true);
    emit BurnerAdded(1, burner1);
    vm.expectEmit(true, false, false, true);
    emit EntityCreated(1, entity1Label, entity1Address, entity1MintLimit);
    vm.expectEmit(true, false, false, true);
    emit EntityActivated(1, true);
    vm.expectEmit(true, false, false, true);
    emit EntityMintLimitUpdated(1, 0, entity1MintLimit);

    GhoToken tempGho = new GhoToken(inputEntities);

    GhoToken.Entity memory entity = tempGho.getEntityById(1);
    assertEq(entity.label, entity1Label);
    assertEq(entity.entityAddress, entity1Address);
    assertEq(entity.mintLimit, entity1MintLimit);
    assertEq(entity.mintBalance, 0);
    _compareAddressArrays(entity.minters, entity1Minters);
    _compareAddressArrays(entity.burners, entity1Burners);
    assertTrue(entity.active);

    assertEq(gho.getMinterEntity(minter1), 1);
    assertEq(gho.getBurnerEntity(burner1), 1);
    assertEq(tempGho.getEntityCount(), 1);

    assertEq(tempGho.name(), 'Gho Token');
    assertEq(tempGho.symbol(), 'GHO');
    assertEq(tempGho.decimals(), 18);
  }

  function testDeployTwoEntities() public {
    inputEntities[1].active = false;

    vm.expectEmit(true, true, false, true);
    emit MinterAdded(1, minter1);
    vm.expectEmit(true, true, false, true);
    emit BurnerAdded(1, burner1);
    vm.expectEmit(true, false, false, true);
    emit EntityCreated(1, entity1Label, entity1Address, entity1MintLimit);
    vm.expectEmit(true, false, false, true);
    emit EntityActivated(1, true);
    vm.expectEmit(true, false, false, true);
    emit EntityMintLimitUpdated(1, 0, entity1MintLimit);
    vm.expectEmit(true, true, false, true);
    emit MinterAdded(2, minter2);
    vm.expectEmit(true, true, false, true);
    emit MinterAdded(2, minter3);
    vm.expectEmit(true, true, false, true);
    emit BurnerAdded(2, burner2);
    vm.expectEmit(true, true, false, true);
    emit BurnerAdded(2, burner3);
    vm.expectEmit(true, false, false, true);
    emit EntityCreated(2, entity2Label, entity2Address, entity2MintLimit);
    vm.expectEmit(true, false, false, true);
    emit EntityActivated(2, false);
    vm.expectEmit(true, false, false, true);
    emit EntityMintLimitUpdated(2, 0, entity2MintLimit);

    GhoToken tempGho = new GhoToken(inputEntities);

    GhoToken.Entity memory entity = tempGho.getEntityById(1);
    assertEq(entity.label, entity1Label);
    assertEq(entity.entityAddress, entity1Address);
    assertEq(entity.mintLimit, entity1MintLimit);
    assertEq(entity.mintBalance, 0);
    _compareAddressArrays(entity.minters, entity1Minters);
    _compareAddressArrays(entity.burners, entity1Burners);
    assertTrue(entity.active);

    assertEq(gho.getMinterEntity(minter1), 1);
    assertEq(gho.getBurnerEntity(burner1), 1);

    entity = tempGho.getEntityById(2);
    assertEq(entity.label, entity2Label);
    assertEq(entity.entityAddress, entity2Address);
    assertEq(entity.mintLimit, entity2MintLimit);
    assertEq(entity.mintBalance, 0);
    _compareAddressArrays(entity.minters, entity2Minters);
    _compareAddressArrays(entity.burners, entity2Burners);
    assertTrue(!entity.active);

    assertEq(tempGho.getEntityCount(), 2);

    assertEq(gho.getMinterEntity(minter2), 2);
    assertEq(gho.getBurnerEntity(burner2), 2);

    assertEq(gho.getMinterEntity(minter3), 2);
    assertEq(gho.getBurnerEntity(burner3), 2);

    assertEq(tempGho.name(), 'Gho Token');
    assertEq(tempGho.symbol(), 'GHO');
    assertEq(tempGho.decimals(), 18);
  }

  /****** Add and Remove Minters ******/

  function testAddMinterEntity1() public {
    vm.expectEmit(true, true, false, true);
    emit MinterAdded(1, minter4);

    gho.addMinter(1, minter4);

    entity1Minters.push(minter4);
    _compareAddressArrays(gho.getEntityMinters(1), entity1Minters);
    assertEq(gho.getMinterEntity(minter4), 1);
  }

  function testRemoveMinterEntityTwo() public {
    vm.expectEmit(true, true, false, true);
    emit MinterRemoved(2, minter3);

    gho.removeMinter(2, minter3);

    entity2Minters.pop();
    _compareAddressArrays(gho.getEntityMinters(2), entity2Minters);
    assertEq(gho.getMinterEntity(minter3), 0);
  }

  function testRemoveMultipleMinterEntity2() public {
    gho.addMinter(2, minter4);
    gho.addMinter(2, minter5);

    gho.removeMinter(2, minter3);

    expectedAddresses.push(minter2);
    expectedAddresses.push(minter5);
    expectedAddresses.push(minter4);

    _compareAddressArrays(gho.getEntityMinters(2), expectedAddresses);
    assertEq(gho.getMinterEntity(minter3), 0);

    gho.removeMinter(2, minter4);
    expectedAddresses.pop();

    _compareAddressArrays(gho.getEntityMinters(2), expectedAddresses);
    assertEq(gho.getMinterEntity(minter4), 0);
  }

  function testAddDuplicateMinterSameEntity_Revert() public {
    vm.expectRevert('MINTER_ALREADY_ADDED');
    gho.addMinter(1, minter1);
  }

  function testAddDuplicateMinterDifferentEntity_Revert() public {
    vm.expectRevert('MINTER_ALREADY_ADDED');
    gho.addMinter(1, minter2);
  }

  function testAddMinterToEmptyEntity_Revert() public {
    vm.expectRevert('ENTITY_DOES_NOT_EXIST');
    gho.addMinter(100, minter5);
  }

  function testRemoveMinteryEntity_Revert() public {
    vm.expectRevert('MINTER_NOT_REGISTERED_TO_PROVIDED_ENTITY');
    gho.removeMinter(1, minter2);
  }

  /****** Activate and Deactivate Entity ******/

  function testDeactivateEntity() public {
    vm.expectEmit(true, true, false, true);
    emit EntityActivated(1, false);

    gho.deactivateEntity(1);

    assertTrue(!gho.isActive(1));
  }

  function testActivateEntity() public {
    gho.deactivateEntity(1);

    vm.expectEmit(true, true, false, true);
    emit EntityActivated(1, true);

    gho.activateEntity(1);

    assertTrue(gho.isActive(1));
  }

  /****** Add and Remove Burners ******/

  function testAddBurnerEntity1() public {
    vm.expectEmit(true, true, false, true);
    emit BurnerAdded(1, burner4);

    gho.addBurner(1, burner4);

    entity1Burners.push(burner4);
    _compareAddressArrays(gho.getEntityBurners(1), entity1Burners);
    assertEq(gho.getBurnerEntity(burner4), 1);
  }

  function testRemoveBurnerEntity2() public {
    vm.expectEmit(true, true, false, true);
    emit BurnerRemoved(2, burner3);

    gho.removeBurner(2, burner3);

    entity2Burners.pop();
    _compareAddressArrays(gho.getEntityBurners(2), entity2Burners);
    assertEq(gho.getBurnerEntity(burner3), 0);
  }

  function testRemoveMultipleBurnersEntity2() public {
    gho.addBurner(2, burner4);
    gho.addBurner(2, burner5);

    gho.removeBurner(2, burner3);

    expectedAddresses.push(burner2);
    expectedAddresses.push(burner5);
    expectedAddresses.push(burner4);
    _compareAddressArrays(gho.getEntityBurners(2), expectedAddresses);
    assertEq(gho.getBurnerEntity(burner3), 0);

    gho.removeBurner(2, burner2);
    expectedAddresses.pop();
    expectedAddresses.pop();
    expectedAddresses.pop();
    expectedAddresses.push(burner4);
    expectedAddresses.push(burner5);
    _compareAddressArrays(gho.getEntityBurners(2), expectedAddresses);
    assertEq(gho.getBurnerEntity(burner2), 0);
  }

  function testAddBurnerAlreadyAdded_revert() public {
    vm.expectRevert('BURNER_ALREADY_ADDED');
    gho.addBurner(1, burner1);
  }

  function testAddBurnerAlreadyAddedDifEntity_revert() public {
    vm.expectRevert('BURNER_ALREADY_ADDED');
    gho.addBurner(2, burner1);
  }

  function testAddBurnerToNonExistantEntity_revert() public {
    vm.expectRevert('ENTITY_DOES_NOT_EXIST');
    gho.addBurner(100, burner1);
  }

  function testRemoveNonExistentBurner_revert() public {
    vm.expectRevert('BURNER_NOT_REGISTERED_TO_PROVIDED_ENTITY');
    gho.removeBurner(1, burner3);
  }

  /****** Mint Tests ******/

  function testMintFomEntity1Minter1() public {
    vm.prank(minter1);
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(0), user1, mintAmount);
    gho.mint(user1, mintAmount);

    assertEq(gho.totalSupply(), mintAmount);
    assertEq(gho.balanceOf(user1), mintAmount);
    assertEq(gho.getEntityBalance(1), mintAmount);
  }

  function testMintFromEntityMinter2() public {
    // previous step
    vm.prank(minter1);
    gho.mint(user1, mintAmount);

    // new step
    vm.prank(minter2);
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(0), user1, mintAmount);

    gho.mint(user1, mintAmount);

    assertEq(gho.totalSupply(), mintAmount * 2);
    assertEq(gho.balanceOf(user1), mintAmount * 2);
    assertEq(gho.getEntityBalance(2), mintAmount);
  }

  function testMultipleMints() public {
    vm.startPrank(minter1);
    gho.mint(user1, mintAmount);
    gho.mint(user1, 1e18);
    vm.stopPrank();

    assertEq(gho.totalSupply(), mintAmount + 1e18);
    assertEq(gho.balanceOf(user1), mintAmount + 1e18);
    assertEq(gho.getEntityBalance(1), mintAmount + 1e18);
  }

  function testMintFromNonMinter_revert() public {
    vm.prank(minter5);
    vm.expectRevert('MINTER_NOT_ASSIGNED_TO_AN_ENTITY');

    gho.mint(user1, mintAmount);
  }

  function testMintFromNonActiveEntity_revert() public {
    gho.deactivateEntity(1);

    vm.prank(minter1);
    vm.expectRevert('ENTITY_IS_NOT_ACTIVE');
    gho.mint(user1, mintAmount);
  }

  function testMintOverLimit_revert() public {
    vm.prank(minter1);
    vm.expectRevert('ENTITY_MINT_LIMIT_EXCEEDED');

    gho.mint(user1, entity1MintLimit + 1);
  }

  function testSetEntityMintLimit() public {
    vm.expectEmit(true, false, false, true);
    emit EntityMintLimitUpdated(1, entity1MintLimit, entity2MintLimit);
    gho.setEntityMintLimit(1, entity2MintLimit);

    vm.prank(minter1);
    gho.mint(user1, entity1MintLimit + 1);

    assertEq(gho.balanceOf(user1), entity1MintLimit + 1);
    assertEq(gho.getEntityBalance(1), entity1MintLimit + 1);
  }

  /****** Burn Tests ******/

  function testBurnFromEntity1Burner1() public {
    vm.prank(minter1);
    gho.mint(user1, mintAmount);

    assertEq(gho.balanceOf(user1), mintAmount);

    vm.expectEmit(true, true, false, true);
    emit Transfer(user1, address(0), mintAmount);

    vm.prank(burner1);
    gho.burn(user1, mintAmount);

    assertEq(gho.balanceOf(user1), 0);
    assertEq(gho.getEntityBalance(1), 0);
  }

  function testBurnFromNonBurner_revert() public {
    vm.prank(minter1);
    gho.mint(user1, mintAmount);

    vm.prank(burner5);
    vm.expectRevert('BURNER_NOT_ASSIGNED_TO_AN_ENTITY');
    gho.burn(user1, mintAmount);
  }

  function testBurnFromDeactivatedEnttiy_revert() public {
    gho.deactivateEntity(1);

    vm.prank(burner1);
    vm.expectRevert('ENTITY_IS_NOT_ACTIVE');
    gho.burn(user1, mintAmount);
  }

  /****** Only Owner Tests *******/

  function testAddMinterFromNonOwner_revert() public {
    vm.prank(minter1);
    vm.expectRevert('Ownable: caller is not the owner');

    gho.addMinter(1, minter5);
  }

  function testAddBurnerFromNonOwner_revert() public {
    vm.prank(burner1);
    vm.expectRevert('Ownable: caller is not the owner');

    gho.addBurner(1, burner5);
  }

  function testRemoveMinterFromNonOwner_revert() public {
    vm.prank(minter1);
    vm.expectRevert('Ownable: caller is not the owner');

    gho.removeMinter(1, minter1);
  }

  function testRemoveBurnerFromNonOwner_revert() public {
    vm.prank(burner1);
    vm.expectRevert('Ownable: caller is not the owner');

    gho.removeBurner(1, burner1);
  }

  function testSetEntityMinterLimitFromNonOwner_revert() public {
    vm.prank(minter1);
    vm.expectRevert('Ownable: caller is not the owner');

    gho.setEntityMintLimit(1, entity2MintLimit);
  }

  function testActivateEntityFromNonOwner_revert() public {
    vm.prank(minter1);
    vm.expectRevert('Ownable: caller is not the owner');

    gho.activateEntity(1);
  }

  function testDeactivateEntityFromNonOwner_revert() public {
    vm.prank(minter1);
    vm.expectRevert('Ownable: caller is not the owner');

    gho.deactivateEntity(1);
  }

  /****** Helpers *******/

  function _compareAddressArrays(address[] memory actual, address[] memory expected) internal {
    assertEq(actual.length, expected.length);
    for (uint256 i = 0; i < actual.length; i++) {
      assertEq(actual[i], expected[i]);
    }
  }
}
