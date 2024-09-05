// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmRegistry is TestGhoBase {
  function testConstructor(address newOwner) public {
    vm.assume(newOwner != address(this));
    vm.assume(newOwner != address(0));

    vm.expectEmit(true, true, false, true);
    emit OwnershipTransferred(address(0), address(this));
    vm.expectEmit(true, true, false, true);
    emit OwnershipTransferred(address(this), newOwner);

    GsmRegistry registry = new GsmRegistry(newOwner);
    assertEq(registry.owner(), newOwner, 'Unexpected contract owner');
    assertEq(registry.getGsmList().length, 0, 'Unexpected gsm list length');
    assertEq(registry.getGsmListLength(), 0, 'Unexpected gsm list length');
  }

  function testRevertConstructorZeroAddress() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GsmRegistry(address(0));
  }

  function testAddGsm(address newGsm) public {
    vm.assume(newGsm != address(0));

    vm.expectEmit(true, false, false, true);
    emit GsmAdded(newGsm);
    GHO_GSM_REGISTRY.addGsm(newGsm);

    assertEq(GHO_GSM_REGISTRY.getGsmListLength(), 1, 'Unexpected gsm list length');
    assertEq(GHO_GSM_REGISTRY.getGsmAtIndex(0), newGsm, 'Unexpected gsm registered');
  }

  function testAddGsmMultiple(uint256 size) public {
    size = bound(size, 0, 20);

    for (uint256 i = 0; i < size; i++) {
      address newGsm = address(uint160(i + 123));
      vm.expectEmit(true, false, false, true);
      emit GsmAdded(newGsm);
      GHO_GSM_REGISTRY.addGsm(newGsm);
      assertEq(GHO_GSM_REGISTRY.getGsmAtIndex(i), newGsm, 'Unexpected gsm registered');
    }

    assertEq(GHO_GSM_REGISTRY.getGsmListLength(), size, 'Unexpected gsm list length');
  }

  function testRevertAddGsmUnauthorized(address caller) public {
    vm.assume(caller != GHO_GSM_REGISTRY.owner());

    vm.expectRevert(OwnableErrorsLib.CALLER_NOT_OWNER());
    vm.prank(caller);
    GHO_GSM_REGISTRY.addGsm(address(123));
  }

  function testRevertAddGsmInvalidAddress() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    GHO_GSM_REGISTRY.addGsm(address(0));

    assertEq(GHO_GSM_REGISTRY.getGsmListLength(), 0, 'Unexpected gsm list length');
  }

  function testRevertAddSameGsmTwice(address newGsm) public {
    vm.assume(newGsm != address(0));
    vm.expectEmit(true, false, false, true);
    emit GsmAdded(newGsm);
    GHO_GSM_REGISTRY.addGsm(newGsm);

    assertEq(GHO_GSM_REGISTRY.getGsmListLength(), 1, 'Unexpected gsm list length');
    assertEq(GHO_GSM_REGISTRY.getGsmAtIndex(0), newGsm, 'Unexpected gsm registered');

    vm.expectRevert('GSM_ALREADY_ADDED');
    GHO_GSM_REGISTRY.addGsm(newGsm);

    assertEq(GHO_GSM_REGISTRY.getGsmListLength(), 1, 'Unexpected gsm list length');
    assertEq(GHO_GSM_REGISTRY.getGsmAtIndex(0), newGsm, 'Unexpected gsm registered');
  }

  function testRemoveGsm(address gsmToRemove) public {
    vm.assume(gsmToRemove != address(0));

    uint256 sizeBefore = GHO_GSM_REGISTRY.getGsmListLength();

    GHO_GSM_REGISTRY.addGsm(gsmToRemove);

    vm.expectEmit(true, false, false, true);
    emit GsmRemoved(gsmToRemove);
    GHO_GSM_REGISTRY.removeGsm(gsmToRemove);

    assertEq(GHO_GSM_REGISTRY.getGsmListLength(), sizeBefore, 'Unexpected gsm list length');
  }

  function testRemoveGsmMultiple(uint256 size) public {
    size = bound(size, 0, 20);

    for (uint256 i = 0; i < size; i++) {
      address newGsm = address(uint160(i + 123));

      GHO_GSM_REGISTRY.addGsm(newGsm);
      assertEq(GHO_GSM_REGISTRY.getGsmAtIndex(0), newGsm, 'Unexpected gsm registered');

      vm.expectEmit(true, false, false, true);
      emit GsmRemoved(newGsm);
      GHO_GSM_REGISTRY.removeGsm(newGsm);
    }

    assertEq(GHO_GSM_REGISTRY.getGsmListLength(), 0, 'Unexpected gsm list length');
  }

  function testRevertRemoveGsmUnauthorized(address caller) public {
    vm.assume(caller != GHO_GSM_REGISTRY.owner());

    vm.expectRevert(OwnableErrorsLib.CALLER_NOT_OWNER());
    vm.prank(caller);
    GHO_GSM_REGISTRY.removeGsm(address(123));
  }

  function testRevertRemoveGsmInvalidAddress() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    GHO_GSM_REGISTRY.removeGsm(address(0));
  }

  function testRevertRemoveSameGsmTwice(address newGsm) public {
    vm.assume(newGsm != address(0));
    GHO_GSM_REGISTRY.addGsm(newGsm);

    vm.expectEmit(true, false, false, true);
    emit GsmRemoved(newGsm);
    GHO_GSM_REGISTRY.removeGsm(newGsm);

    assertEq(GHO_GSM_REGISTRY.getGsmListLength(), 0, 'Unexpected gsm list length');

    vm.expectRevert('NONEXISTENT_GSM');
    GHO_GSM_REGISTRY.removeGsm(newGsm);

    assertEq(GHO_GSM_REGISTRY.getGsmListLength(), 0, 'Unexpected gsm list length');
  }

  function testGetGsmList(uint256 sizeToAdd, uint256 sizeToRemove) public {
    sizeToAdd = bound(sizeToAdd, 1, 20);
    sizeToRemove = bound(sizeToRemove, 0, sizeToAdd - 1);

    address[] memory localGsmList = new address[](sizeToAdd);

    uint256 i;
    for (i = 0; i < sizeToAdd; i++) {
      address newGsm = address(uint160(i + 123));
      localGsmList[i] = newGsm;
      GHO_GSM_REGISTRY.addGsm(newGsm);
    }

    for (i = 0; i < sizeToRemove; i++) {
      GHO_GSM_REGISTRY.removeGsm(localGsmList[sizeToAdd - i - 1]);
    }

    uint256 leftOvers = sizeToAdd - sizeToRemove;
    assertEq(leftOvers, GHO_GSM_REGISTRY.getGsmListLength());
    address[] memory gsmList = GHO_GSM_REGISTRY.getGsmList();
    for (i = 0; i < leftOvers; i++) {
      assertEq(gsmList[i], localGsmList[i], 'unexpected GSM address');
      assertEq(
        GHO_GSM_REGISTRY.getGsmAtIndex(i),
        localGsmList[i],
        'unexpected GSM address at given index'
      );
    }
  }

  function testRevertGetGsmAtIndex() public {
    assertEq(GHO_GSM_REGISTRY.getGsmListLength(), 0, 'Unexpected gsm list length');

    vm.expectRevert('INVALID_INDEX');
    GHO_GSM_REGISTRY.getGsmAtIndex(0);

    address newGsm = address(0x123);
    GHO_GSM_REGISTRY.addGsm(newGsm);
    assertEq(GHO_GSM_REGISTRY.getGsmListLength(), 1, 'Unexpected gsm list length');
    assertEq(GHO_GSM_REGISTRY.getGsmAtIndex(0), newGsm, 'Unexpected gsm address at index 0');

    vm.expectRevert('INVALID_INDEX');
    GHO_GSM_REGISTRY.getGsmAtIndex(1);
  }
}
