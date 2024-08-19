// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoBucketSteward is TestGhoBase {
  function setUp() public {
    // Deploy Gho Bucket Steward
    GHO_BUCKET_STEWARD = new GhoBucketSteward(SHORT_EXECUTOR, address(GHO_TOKEN), RISK_COUNCIL);
    address[] memory controlledFacilitators = new address[](2);
    controlledFacilitators[0] = address(GHO_ATOKEN);
    controlledFacilitators[1] = address(GHO_GSM);
    vm.prank(SHORT_EXECUTOR);
    GHO_BUCKET_STEWARD.setControlledFacilitator(controlledFacilitators, true);

    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(GHO_BUCKET_STEWARD.MINIMUM_DELAY() + 1);

    // Grant roles
    GHO_TOKEN.grantRole(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(GHO_BUCKET_STEWARD));
  }

  function testConstructor() public {
    assertEq(GHO_BUCKET_STEWARD.owner(), SHORT_EXECUTOR);
    assertEq(GHO_BUCKET_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_BUCKET_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);

    address[] memory controlledFacilitators = GHO_BUCKET_STEWARD.getControlledFacilitators();
    assertEq(controlledFacilitators.length, 2);

    uint40 facilitatorTimelock = GHO_BUCKET_STEWARD.getFacilitatorBucketCapacityTimelock(
      controlledFacilitators[0]
    );
    assertEq(facilitatorTimelock, 0);
  }

  function testRevertConstructorInvalidExecutor() public {
    vm.expectRevert('INVALID_OWNER');
    new GhoBucketSteward(address(0), address(0x002), address(0x003));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new GhoBucketSteward(address(0x001), address(0), address(0x003));
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new GhoBucketSteward(address(0x001), address(0x002), address(0));
  }

  function testChangeOwnership() public {
    address newOwner = makeAddr('newOwner');
    assertEq(GHO_BUCKET_STEWARD.owner(), SHORT_EXECUTOR);
    vm.prank(SHORT_EXECUTOR);
    GHO_BUCKET_STEWARD.transferOwnership(newOwner);
    assertEq(GHO_BUCKET_STEWARD.owner(), newOwner);
  }

  function testChangeOwnershipRevert() public {
    vm.expectRevert('Ownable: new owner is the zero address');
    vm.prank(SHORT_EXECUTOR);
    GHO_BUCKET_STEWARD.transferOwnership(address(0));
  }

  function testUpdateFacilitatorBucketCapacity() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(newBucketCapacity, capacity);
  }

  function testUpdateFacilitatorBucketCapacityMaxValue() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newBucketCapacity = uint128(currentBucketCapacity * 2);
    vm.prank(RISK_COUNCIL);
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacity);
  }

  function testUpdateFacilitatorBucketCapacityTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
    uint40 timelock = GHO_BUCKET_STEWARD.getFacilitatorBucketCapacityTimelock(address(GHO_ATOKEN));
    assertEq(timelock, block.timestamp);
  }

  function testUpdateFacilitatorBucketCapacityAfterTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    skip(GHO_BUCKET_STEWARD.MINIMUM_DELAY() + 1);
    uint128 newBucketCapacityAfterTimelock = newBucketCapacity + 1;
    vm.prank(RISK_COUNCIL);
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      newBucketCapacityAfterTimelock
    );
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacityAfterTimelock);
  }

  function testRevertUpdateFacilitatorBucketCapacityIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), 123);
  }

  function testRevertUpdateFacilitatorBucketCapacityIfUpdatedTooSoon() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 2
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityNoChange() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('NO_CHANGE_IN_BUCKET_CAPACITY');
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity)
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfFacilitatorNotInControl() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('FACILITATOR_NOT_CONTROLLED');
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_GSM_4626),
      uint128(currentBucketCapacity) + 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfStewardLostBucketManagerRole() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    GHO_TOKEN.revokeRole(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(GHO_BUCKET_STEWARD));
    vm.expectRevert(
      AccessControlErrorsLib.MISSING_ROLE(
        GHO_TOKEN_BUCKET_MANAGER_ROLE,
        address(GHO_BUCKET_STEWARD)
      )
    );
    vm.prank(RISK_COUNCIL);
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfMoreThanDouble() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity * 2) + 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityDecrement() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) - 1;
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
  }

  function testSetControlledFacilitatorAdd() public {
    address[] memory oldControlledFacilitators = GHO_BUCKET_STEWARD.getControlledFacilitators();
    address[] memory newGsmList = new address[](1);
    newGsmList[0] = address(GHO_GSM_4626);
    vm.prank(SHORT_EXECUTOR);
    GHO_BUCKET_STEWARD.setControlledFacilitator(newGsmList, true);
    address[] memory newControlledFacilitators = GHO_BUCKET_STEWARD.getControlledFacilitators();
    assertEq(newControlledFacilitators.length, oldControlledFacilitators.length + 1);
    assertTrue(_contains(newControlledFacilitators, address(GHO_GSM_4626)));
  }

  function testSetControlledFacilitatorsRemove() public {
    address[] memory oldControlledFacilitators = GHO_BUCKET_STEWARD.getControlledFacilitators();
    address[] memory disableGsmList = new address[](1);
    disableGsmList[0] = address(GHO_GSM);
    vm.prank(SHORT_EXECUTOR);
    GHO_BUCKET_STEWARD.setControlledFacilitator(disableGsmList, false);
    address[] memory newControlledFacilitators = GHO_BUCKET_STEWARD.getControlledFacilitators();
    assertEq(newControlledFacilitators.length, oldControlledFacilitators.length - 1);
    assertFalse(_contains(newControlledFacilitators, address(GHO_GSM)));
  }

  function testRevertSetControlledFacilitatorIfUnauthorized() public {
    vm.expectRevert(OwnableErrorsLib.CALLER_NOT_OWNER());
    vm.prank(RISK_COUNCIL);
    address[] memory newGsmList = new address[](1);
    newGsmList[0] = address(GHO_GSM_4626);
    GHO_BUCKET_STEWARD.setControlledFacilitator(newGsmList, true);
  }
}
