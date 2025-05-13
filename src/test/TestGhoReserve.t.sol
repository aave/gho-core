// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoReserve is TestGhoBase {
  function testConstructor() public {
    GhoReserve reserve = new GhoReserve(address(this), address(GHO_TOKEN));
    assertEq(reserve.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(reserve.owner(), address(this));
  }

  function testRevertConstructorInvalidOwner() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GhoReserve(address(0), address(GHO_TOKEN));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GhoReserve(address(this), address(0));
  }

  function testInitialize() public {
    GhoReserve reserve = new GhoReserve(address(this), address(GHO_TOKEN));
    vm.expectEmit(true, true, true, true, address(reserve));
    emit OwnershipTransferred(address(this), address(this));
    reserve.initialize(address(this));
    assertEq(reserve.owner(), address(this));
  }

  function testRevertInitializeInvalidZeroOwner() public {
    GhoReserve reserve = new GhoReserve(address(this), address(GHO_TOKEN));
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    reserve.initialize(address(0));
  }

  function testRevertUseGhoNoCapacity() public {
    vm.expectRevert('CAPACITY_REACHED');
    GHO_RESERVE.useGho(100 ether);
  }

  function testUseGho() public {
    uint256 capacity = 100_000 ether;
    GHO_RESERVE.setWithdrawerCapacity(address(this), capacity);
    assertEq(GHO_RESERVE.getWithdrawnGho(address(this)), 0);
    assertEq(GHO_RESERVE.getCapacity(address(this)), capacity);

    GHO_RESERVE.useGho(capacity / 2);

    assertEq(GHO_RESERVE.getWithdrawnGho(address(this)), capacity / 2);
    assertEq(GHO_RESERVE.getAvailableCapacity(address(this)), capacity / 2);
  }

  function testRevertRestoreGhoNoWithdrawnAmount() public {
    GHO_RESERVE.setWithdrawerCapacity(address(this), 10_000 ether);

    vm.expectRevert();
    GHO_RESERVE.restoreGho(10_000 ether);
  }

  function testRestoreGho() public {
    uint256 capacity = 100_000 ether;
    GHO_RESERVE.setWithdrawerCapacity(address(this), capacity);
    assertEq(GHO_RESERVE.getWithdrawnGho(address(this)), 0);
    assertEq(GHO_RESERVE.getCapacity(address(this)), capacity);

    GHO_RESERVE.useGho(capacity / 2);

    assertEq(GHO_RESERVE.getWithdrawnGho(address(this)), capacity / 2);
    assertEq(GHO_RESERVE.getAvailableCapacity(address(this)), capacity / 2);

    uint256 repayAmount = 25_000 ether;
    GHO_TOKEN.approve(address(GHO_RESERVE), repayAmount);
    GHO_RESERVE.restoreGho(repayAmount);

    assertEq(GHO_RESERVE.getWithdrawnGho(address(this)), capacity / 4);
    assertEq(GHO_RESERVE.getAvailableCapacity(address(this)), capacity - repayAmount);
  }

  function testSetWithdrawerCapacity() public {
    address alice = makeAddr('alice');
    uint256 capacity = 100_000 ether;

    vm.expectEmit(true, true, true, true, address(GHO_RESERVE));
    emit WithdrawerCapacityUpdated(alice, capacity);
    GHO_RESERVE.setWithdrawerCapacity(alice, capacity);
  }

  function testTransferGho() public {
    address facilitator = makeAddr('facilitator');
    uint256 amount = 1_000 ether;

    deal(address(GHO_TOKEN), address(this), 5_000 ether);

    vm.expectEmit(true, true, true, true, address(GHO_RESERVE));
    emit GhoTokenTransfered(facilitator, amount);
    GHO_RESERVE.transferGho(facilitator, amount);
  }
}
