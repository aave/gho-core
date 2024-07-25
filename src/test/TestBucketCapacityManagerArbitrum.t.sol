// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestBucketCapacityManagerArbitrum is TestGhoBase {
  function setUp() public {
    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(ARB_BUCKET_CAPACITY_MANAGER.MINIMUM_DELAY() + 1);

    // Grant roles
    GHO_TOKEN.grantRole(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(ARB_BUCKET_CAPACITY_MANAGER));
  }

  function testConstructor() public {
    assertEq(ARB_BUCKET_CAPACITY_MANAGER.owner(), SHORT_EXECUTOR);
    assertEq(ARB_BUCKET_CAPACITY_MANAGER.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(ARB_BUCKET_CAPACITY_MANAGER.RISK_COUNCIL(), RISK_COUNCIL);

    address[] memory controlledFacilitators = ARB_BUCKET_CAPACITY_MANAGER
      .getControlledFacilitators();
    assertEq(controlledFacilitators.length, 2);

    uint40 facilitatorTimelock = ARB_BUCKET_CAPACITY_MANAGER.getFacilitatorBucketCapacityTimelock(
      controlledFacilitators[0]
    );
    assertEq(facilitatorTimelock, 0);
  }

  function testRevertConstructorInvalidExecutor() public {
    vm.expectRevert('INVALID_OWNER');
    new BucketCapacityManager(address(0), address(0x002), address(0x003));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new BucketCapacityManager(address(0x001), address(0), address(0x003));
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new BucketCapacityManager(address(0x001), address(0x002), address(0));
  }

  function testUpdateFacilitatorBucketCapacity() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    ARB_BUCKET_CAPACITY_MANAGER.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      newBucketCapacity
    );
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(newBucketCapacity, capacity);
  }

  function testUpdateFacilitatorBucketCapacityMaxValue() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newBucketCapacity = uint128(currentBucketCapacity * 2);
    vm.prank(RISK_COUNCIL);
    ARB_BUCKET_CAPACITY_MANAGER.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      newBucketCapacity
    );
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacity);
  }

  function testUpdateFacilitatorBucketCapacityTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    ARB_BUCKET_CAPACITY_MANAGER.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
    uint40 timelock = ARB_BUCKET_CAPACITY_MANAGER.getFacilitatorBucketCapacityTimelock(
      address(GHO_ATOKEN)
    );
    assertEq(timelock, block.timestamp);
  }

  function testUpdateFacilitatorBucketCapacityAfterTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    ARB_BUCKET_CAPACITY_MANAGER.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      newBucketCapacity
    );
    skip(ARB_BUCKET_CAPACITY_MANAGER.MINIMUM_DELAY() + 1);
    uint128 newBucketCapacityAfterTimelock = newBucketCapacity + 1;
    vm.prank(RISK_COUNCIL);
    ARB_BUCKET_CAPACITY_MANAGER.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      newBucketCapacityAfterTimelock
    );
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacityAfterTimelock);
  }

  function testRevertUpdateFacilitatorBucketCapacityIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    ARB_BUCKET_CAPACITY_MANAGER.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), 123);
  }

  function testRevertUpdateFaciltatorBucketCapacityIfUpdatedTooSoon() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    ARB_BUCKET_CAPACITY_MANAGER.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    ARB_BUCKET_CAPACITY_MANAGER.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 2
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfFacilitatorNotInControl() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('FACILITATOR_NOT_CONTROLLED');
    ARB_BUCKET_CAPACITY_MANAGER.updateFacilitatorBucketCapacity(
      address(GHO_GSM_4626),
      uint128(currentBucketCapacity) + 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfStewardLostBucketManagerRole() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    GHO_TOKEN.revokeRole(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(ARB_BUCKET_CAPACITY_MANAGER));
    vm.expectRevert(
      AccessControlErrorsLib.MISSING_ROLE(
        GHO_TOKEN_BUCKET_MANAGER_ROLE,
        address(ARB_BUCKET_CAPACITY_MANAGER)
      )
    );
    vm.prank(RISK_COUNCIL);
    ARB_BUCKET_CAPACITY_MANAGER.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfMoreThanDouble() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    ARB_BUCKET_CAPACITY_MANAGER.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity * 2) + 1
    );
  }

  function testSetControlledFacilitatorAdd() public {
    address[] memory oldControlledFacilitators = ARB_BUCKET_CAPACITY_MANAGER
      .getControlledFacilitators();
    address[] memory newGsmList = new address[](1);
    newGsmList[0] = address(GHO_GSM_4626);
    vm.prank(SHORT_EXECUTOR);
    ARB_BUCKET_CAPACITY_MANAGER.setControlledFacilitator(newGsmList, true);
    address[] memory newControlledFacilitators = ARB_BUCKET_CAPACITY_MANAGER
      .getControlledFacilitators();
    assertEq(newControlledFacilitators.length, oldControlledFacilitators.length + 1);
    assertTrue(_contains(newControlledFacilitators, address(GHO_GSM_4626)));
  }

  function testSetControlledFacilitatorsRemove() public {
    address[] memory oldControlledFacilitators = ARB_BUCKET_CAPACITY_MANAGER
      .getControlledFacilitators();
    address[] memory disableGsmList = new address[](1);
    disableGsmList[0] = address(GHO_GSM);
    vm.prank(SHORT_EXECUTOR);
    ARB_BUCKET_CAPACITY_MANAGER.setControlledFacilitator(disableGsmList, false);
    address[] memory newControlledFacilitators = ARB_BUCKET_CAPACITY_MANAGER
      .getControlledFacilitators();
    assertEq(newControlledFacilitators.length, oldControlledFacilitators.length - 1);
    assertFalse(_contains(newControlledFacilitators, address(GHO_GSM)));
  }

  function testRevertSetControlledFacilitatorIfUnauthorized() public {
    vm.expectRevert(OwnableErrorsLib.CALLER_NOT_OWNER());
    vm.prank(RISK_COUNCIL);
    address[] memory newGsmList = new address[](1);
    newGsmList[0] = address(GHO_GSM_4626);
    ARB_BUCKET_CAPACITY_MANAGER.setControlledFacilitator(newGsmList, true);
  }
}
