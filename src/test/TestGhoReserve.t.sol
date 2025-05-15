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

  function testRevertInitializeTwice() public {
    GhoReserve reserve = _deployReserve();
    vm.expectRevert('Contract instance has already been initialized');
    reserve.initialize(address(0));
  }

  function testRevertUseGhoNoCapacity() public {
    vm.expectRevert('LIMIT_REACHED');
    GHO_RESERVE.use(100 ether);
  }

  function testUseGho() public {
    uint256 capacity = 100_000 ether;
    GHO_RESERVE.setEntityLimit(address(this), capacity);
    assertEq(GHO_RESERVE.getUsed(address(this)), 0);
    assertEq(GHO_RESERVE.getLimit(address(this)), capacity);

    GHO_RESERVE.use(capacity / 2);

    (uint256 limit, uint256 used) = GHO_RESERVE.getUsage(address(this));

    assertEq(GHO_RESERVE.getUsed(address(this)), capacity / 2);
    assertEq(limit - used, capacity / 2);
  }

  function testRevertRestoreGhoNoWithdrawnAmount() public {
    GHO_RESERVE.setEntityLimit(address(this), 10_000 ether);

    vm.expectRevert();
    GHO_RESERVE.restore(10_000 ether);
  }

  function testRestoreGho() public {
    uint256 capacity = 100_000 ether;
    GHO_RESERVE.setEntityLimit(address(this), capacity);
    assertEq(GHO_RESERVE.getUsed(address(this)), 0);
    assertEq(GHO_RESERVE.getLimit(address(this)), capacity);

    GHO_RESERVE.use(capacity / 2);

    (uint256 limit, uint256 used) = GHO_RESERVE.getUsage(address(this));

    assertEq(GHO_RESERVE.getUsed(address(this)), capacity / 2);
    assertEq(limit - used, capacity / 2);

    uint256 repayAmount = 25_000 ether;
    GHO_TOKEN.approve(address(GHO_RESERVE), repayAmount);
    GHO_RESERVE.restore(repayAmount);

    (limit, used) = GHO_RESERVE.getUsage(address(this));

    assertEq(GHO_RESERVE.getUsed(address(this)), capacity / 4);
    assertEq(limit - used, capacity - repayAmount);
  }

  function testsetEntityLimit() public {
    address alice = makeAddr('alice');
    uint256 capacity = 100_000 ether;

    vm.expectEmit(true, true, true, true, address(GHO_RESERVE));
    emit EntityLimitUpdated(alice, capacity);
    GHO_RESERVE.setEntityLimit(alice, capacity);
  }

  function testTransferGho() public {
    GhoReserve reserve = _deployReserve();
    address facilitator = makeAddr('facilitator');
    uint256 amount = 1_000 ether;

    deal(address(GHO_TOKEN), address(reserve), 5_000 ether);

    vm.expectEmit(true, true, true, true, address(reserve));
    emit GhoTokenTransfered(facilitator, amount);
    reserve.transfer(facilitator, amount);

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), 5_000 ether - amount);
  }

  function testRevertTransferInvalidCaller() public {
    GhoReserve reserve = _deployReserve();
    address facilitator = makeAddr('facilitator');
    uint256 amount = 1_000 ether;

    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(address(GHO_TOKEN));
    reserve.transfer(facilitator, amount);
  }

  function testRevertTransferNoFunds() public {
    GhoReserve reserve = _deployReserve();
    address facilitator = makeAddr('facilitator');
    uint256 amount = 1_000 ether;

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), 0);

    vm.expectRevert();
    reserve.transfer(facilitator, amount);
  }

  function testTransferFull() public {
    GhoReserve reserve = _deployReserve();
    address facilitator = makeAddr('facilitator');
    uint256 amount = 1_000 ether;

    deal(address(GHO_TOKEN), address(reserve), amount);

    vm.expectEmit(true, true, true, true, address(reserve));
    emit GhoTokenTransfered(facilitator, amount);
    reserve.transfer(facilitator, amount);

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), 0);
  }

  function testRevertTransferAmountGreaterThanBalance() public {
    GhoReserve reserve = _deployReserve();
    address facilitator = makeAddr('facilitator');
    uint256 amount = 1_000 ether;

    deal(address(GHO_TOKEN), address(reserve), amount);

    vm.expectRevert();
    reserve.transfer(facilitator, amount + 1);
  }

  function testTransferAfterGhoUsedAndReturned() public {
    GhoReserve reserve = _deployReserve();
    address facilitator = makeAddr('facilitator');
    uint256 amount = 1_000 ether;

    reserve.setEntityLimit(address(this), amount);
    deal(address(GHO_TOKEN), address(reserve), amount);

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), amount);

    reserve.use(amount);

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), 0);

    // No GHO to transfer
    vm.expectRevert();
    reserve.transfer(facilitator, amount);

    GHO_TOKEN.approve(address(reserve), amount / 2);
    reserve.restore(amount / 2);

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), amount / 2);

    reserve.transfer(facilitator, amount / 2);

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), 0);
  }

  function _deployReserve() public returns (GhoReserve) {
    GhoReserve reserve = new GhoReserve(address(this), address(GHO_TOKEN));
    reserve.initialize(address(this));

    return reserve;
  }
}
