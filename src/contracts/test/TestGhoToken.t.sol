// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import './TestGhoBase.t.sol';

contract TestGhoToken is TestGhoBase {
  function testConstructor() public {
    GhoToken ghoToken = new GhoToken();
    assertEq(ghoToken.name(), 'Gho Token', 'Wrong default ERC20 name');
    assertEq(ghoToken.symbol(), 'GHO', 'Wrong default ERC20 symbol');
    assertEq(ghoToken.decimals(), 18, 'Wrong default ERC20 decimals');
    assertEq(ghoToken.getFacilitatorsList().length, 0, 'Facilitator list not empty');
  }

  function testGetFacilitatorData() public {
    IGhoToken.Facilitator memory data = GHO_TOKEN.getFacilitator(address(GHO_ATOKEN));
    assertEq(data.label, 'Gho Atoken Market', 'Unexpected facilitator label');
    assertEq(data.bucketCapacity, DEFAULT_CAPACITY, 'Unexpected bucket capacity');
    assertEq(data.bucketLevel, 0, 'Unexpected bucket level');
  }

  function testGetNonFacilitatorData() public {
    IGhoToken.Facilitator memory data = GHO_TOKEN.getFacilitator(alice);
    assertEq(data.label, '', 'Unexpected facilitator label');
    assertEq(data.bucketCapacity, 0, 'Unexpected bucket capacity');
    assertEq(data.bucketLevel, 0, 'Unexpected bucket level');
  }

  function testGetFacilitatorBucket() public {
    (uint256 capacity, uint256 level) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, DEFAULT_CAPACITY, 'Unexpected bucket capacity');
    assertEq(level, 0, 'Unexpected bucket level');
  }

  function testGetNonFacilitatorBucket() public {
    (uint256 capacity, uint256 level) = GHO_TOKEN.getFacilitatorBucket(alice);
    assertEq(capacity, 0, 'Unexpected bucket capacity');
    assertEq(level, 0, 'Unexpected bucket level');
  }

  function testGetPopulatedFacilitatorsList() public {
    address[] memory facilitatorList = GHO_TOKEN.getFacilitatorsList();
    assertEq(facilitatorList.length, 4, 'Unexpected number of facilitators');
    assertEq(facilitatorList[0], address(GHO_ATOKEN), 'Unexpected address for mock facilitator 1');
    assertEq(
      facilitatorList[1],
      address(GHO_FLASH_MINTER),
      'Unexpected address for mock facilitator 2'
    );
    assertEq(
      facilitatorList[2],
      address(FLASH_BORROWER),
      'Unexpected address for mock facilitator 3'
    );
    assertEq(facilitatorList[3], faucet, 'Unexpected address for mock facilitator 4');
  }

  function testAddFacilitator() public {
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit FacilitatorAdded(alice, keccak256(abi.encodePacked('Alice')), DEFAULT_CAPACITY);
    GHO_TOKEN.addFacilitator(alice, 'Alice', DEFAULT_CAPACITY);
  }

  function testRevertAddExistingFacilitator() public {
    vm.expectRevert('FACILITATOR_ALREADY_EXISTS');
    GHO_TOKEN.addFacilitator(address(GHO_ATOKEN), 'Gho Atoken Market', DEFAULT_CAPACITY);
  }

  function testRevertAddFacilitatorNoLabel() public {
    vm.expectRevert('INVALID_LABEL');
    GHO_TOKEN.addFacilitator(alice, '', DEFAULT_CAPACITY);
  }

  function testRevertSetBucketCapacityNonFacilitator() public {
    vm.expectRevert('FACILITATOR_DOES_NOT_EXIST');
    GHO_TOKEN.setFacilitatorBucketCapacity(alice, DEFAULT_CAPACITY);
  }

  function testSetNewBucketCapacity() public {
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketCapacityUpdated(address(GHO_ATOKEN), DEFAULT_CAPACITY, 0);
    GHO_TOKEN.setFacilitatorBucketCapacity(address(GHO_ATOKEN), 0);
  }

  function testRevertRemoveNonFacilitator() public {
    vm.expectRevert('FACILITATOR_DOES_NOT_EXIST');
    GHO_TOKEN.removeFacilitator(alice);
  }

  function testRevertRemoveFacilitatorNonzeroBucket() public {
    ghoFaucet(alice, 1);
    vm.expectRevert('FACILITATOR_BUCKET_LEVEL_NOT_ZERO');
    GHO_TOKEN.removeFacilitator(faucet);
  }

  function testRemoveFacilitator() public {
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorRemoved(address(GHO_ATOKEN));
    GHO_TOKEN.removeFacilitator(address(GHO_ATOKEN));
  }

  function testRevertMintBadFacilitator() public {
    vm.prank(alice);
    vm.expectRevert('INVALID_FACILITATOR');
    GHO_TOKEN.mint(alice, DEFAULT_BORROW_AMOUNT);
  }

  function testRevertMintExceedCapacity() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectRevert('FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
    GHO_TOKEN.mint(alice, DEFAULT_CAPACITY + 1);
  }

  function testMint() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit Transfer(address(0), alice, DEFAULT_CAPACITY);
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketLevelUpdated(address(GHO_ATOKEN), 0, DEFAULT_CAPACITY);
    GHO_TOKEN.mint(alice, DEFAULT_CAPACITY);
  }

  function testRevertZeroBurn() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectRevert('INVALID_BURN_AMOUNT');
    GHO_TOKEN.burn(0);
  }

  function testRevertBurnMoreThanMinted() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketLevelUpdated(address(GHO_ATOKEN), 0, DEFAULT_CAPACITY);
    GHO_TOKEN.mint(address(GHO_ATOKEN), DEFAULT_CAPACITY);

    vm.prank(address(GHO_ATOKEN));
    vm.expectRevert();
    GHO_TOKEN.burn(DEFAULT_CAPACITY + 1);
  }

  function testRevertBurnOthersTokens() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit Transfer(address(0), alice, DEFAULT_CAPACITY);
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketLevelUpdated(address(GHO_ATOKEN), 0, DEFAULT_CAPACITY);
    GHO_TOKEN.mint(alice, DEFAULT_CAPACITY);

    vm.prank(address(GHO_ATOKEN));
    vm.expectRevert();
    GHO_TOKEN.burn(DEFAULT_CAPACITY);
  }

  function testBurn() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit Transfer(address(0), address(GHO_ATOKEN), DEFAULT_CAPACITY);
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketLevelUpdated(address(GHO_ATOKEN), 0, DEFAULT_CAPACITY);
    GHO_TOKEN.mint(address(GHO_ATOKEN), DEFAULT_CAPACITY);

    vm.prank(address(GHO_ATOKEN));
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketLevelUpdated(
      address(GHO_ATOKEN),
      DEFAULT_CAPACITY,
      DEFAULT_CAPACITY - DEFAULT_BORROW_AMOUNT
    );
    GHO_TOKEN.burn(DEFAULT_BORROW_AMOUNT);
  }
}
