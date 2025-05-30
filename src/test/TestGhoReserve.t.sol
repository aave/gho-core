// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoReserve is TestGhoBase {
  function testConstructor() public {
    GhoReserve reserve = new GhoReserve(address(GHO_TOKEN));
    assertEq(reserve.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(reserve.owner(), address(this));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GhoReserve(address(0));
  }

  function testInitialize() public {
    GhoReserve reserve = new GhoReserve(address(GHO_TOKEN));
    vm.expectEmit(true, true, true, true, address(reserve));
    emit OwnershipTransferred(address(this), address(this));
    reserve.initialize(address(this));
    assertEq(reserve.owner(), address(this));
  }

  function testRevertInitializeInvalidZeroOwner() public {
    GhoReserve reserve = new GhoReserve(address(GHO_TOKEN));
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    reserve.initialize(address(0));
  }

  function testRevertInitializeTwice() public {
    GhoReserve reserve = _deployReserve();
    vm.expectRevert('Contract instance has already been initialized');
    reserve.initialize(address(0));
  }

  function testRevertUseNoCapacity() public {
    vm.expectRevert('LIMIT_REACHED');
    GHO_RESERVE.use(100 ether);
  }

  function testUse() public {
    uint256 capacity = 100_000 ether;
    GHO_RESERVE.addEntity(address(this));
    GHO_RESERVE.setLimit(address(this), capacity);
    assertEq(GHO_RESERVE.getUsed(address(this)), 0);
    assertEq(GHO_RESERVE.getLimit(address(this)), capacity);

    vm.expectEmit(true, true, true, true, address(GHO_RESERVE));
    emit GhoUsed(address(this), capacity / 2);
    GHO_RESERVE.use(capacity / 2);

    (uint256 limit, uint256 used) = GHO_RESERVE.getUsage(address(this));

    assertEq(GHO_RESERVE.getUsed(address(this)), capacity / 2);
    assertEq(limit - used, capacity / 2);
  }

  function testRevertRestoreNoWithdrawnAmount() public {
    GHO_RESERVE.addEntity(address(this));
    GHO_RESERVE.setLimit(address(this), 10_000 ether);

    vm.expectRevert();
    GHO_RESERVE.restore(10_000 ether);
  }

  function testRestore() public {
    uint256 capacity = 100_000 ether;
    GHO_RESERVE.addEntity(address(this));
    GHO_RESERVE.setLimit(address(this), capacity);
    assertEq(GHO_RESERVE.getUsed(address(this)), 0);
    assertEq(GHO_RESERVE.getLimit(address(this)), capacity);

    vm.expectEmit(true, true, true, true, address(GHO_RESERVE));
    emit GhoUsed(address(this), capacity / 2);
    GHO_RESERVE.use(capacity / 2);

    (uint256 limit, uint256 used) = GHO_RESERVE.getUsage(address(this));

    assertEq(GHO_RESERVE.getUsed(address(this)), capacity / 2);
    assertEq(limit - used, capacity / 2);

    uint256 repayAmount = 25_000 ether;
    GHO_TOKEN.approve(address(GHO_RESERVE), repayAmount);

    vm.expectEmit(true, true, true, true, address(GHO_RESERVE));
    emit GhoRestored(address(this), repayAmount);
    GHO_RESERVE.restore(repayAmount);

    (limit, used) = GHO_RESERVE.getUsage(address(this));

    assertEq(GHO_RESERVE.getUsed(address(this)), capacity / 4);
    assertEq(limit - used, capacity - repayAmount);
  }

  function testAddEntity() public {
    address alice = makeAddr('alice');
    vm.expectEmit(true, true, true, true, address(GHO_RESERVE));
    emit EntityAdded(alice);
    GHO_RESERVE.addEntity(address(alice));

    assertTrue(GHO_RESERVE.isEntity(alice));
  }

  function testAddEntityAlreadyInSet() public {
    address alice = makeAddr('alice');
    vm.expectEmit(true, true, true, true, address(GHO_RESERVE));
    emit EntityAdded(alice);
    GHO_RESERVE.addEntity(address(alice));

    // Set already contains two entities from constructor
    assertEq(GHO_RESERVE.totalEntities(), 3);

    GHO_RESERVE.addEntity(address(alice));

    assertEq(GHO_RESERVE.totalEntities(), 3);
  }

  function testRemoveEntity() public {
    address alice = makeAddr('alice');
    vm.expectEmit(true, true, true, true, address(GHO_RESERVE));
    emit EntityAdded(alice);
    GHO_RESERVE.addEntity(address(alice));

    assertTrue(GHO_RESERVE.isEntity(alice));

    vm.expectEmit(true, true, true, true, address(GHO_RESERVE));
    emit EntityRemoved(alice);
    GHO_RESERVE.removeEntity(address(alice));

    assertFalse(GHO_RESERVE.isEntity(alice));
  }

  function testRemoveEntityNotInSet() public {
    address alice = makeAddr('alice');
    assertFalse(GHO_RESERVE.isEntity(alice));
    assertEq(GHO_RESERVE.totalEntities(), 2);

    GHO_RESERVE.removeEntity(address(alice));

    assertFalse(GHO_RESERVE.isEntity(alice));
    assertEq(GHO_RESERVE.totalEntities(), 2);
  }

  function testRevertRemoveEntityBalanceOutstanding() public {
    address alice = makeAddr('alice');
    uint256 capacity = 100_000 ether;
    GHO_RESERVE.addEntity(address(alice));
    GHO_RESERVE.setLimit(alice, capacity);

    vm.prank(alice);
    GHO_RESERVE.use(5_000 ether);

    vm.expectRevert('CANNOT_REMOVE_ENTITY_WITH_BALANCE');
    GHO_RESERVE.removeEntity(alice);
  }

  function testSetLimit() public {
    address alice = makeAddr('alice');
    uint256 capacity = 100_000 ether;
    GHO_RESERVE.addEntity(address(alice));

    vm.expectEmit(true, true, true, true, address(GHO_RESERVE));
    emit GhoLimitUpdated(alice, capacity);
    GHO_RESERVE.setLimit(alice, capacity);
  }

  function testTransfer() public {
    GhoReserve reserve = _deployReserve();
    address facilitator = makeAddr('facilitator');
    uint256 amount = 1_000 ether;

    deal(address(GHO_TOKEN), address(reserve), 5_000 ether);

    vm.expectEmit(true, true, true, true, address(reserve));
    emit GhoTransferred(facilitator, amount);
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
    emit GhoTransferred(facilitator, amount);
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

    reserve.addEntity(address(this));
    reserve.setLimit(address(this), amount);
    deal(address(GHO_TOKEN), address(reserve), amount);

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), amount);

    vm.expectEmit(true, true, true, true, address(reserve));
    emit GhoUsed(address(this), amount);
    reserve.use(amount);

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), 0);

    // No GHO to transfer
    vm.expectRevert();
    reserve.transfer(facilitator, amount);

    GHO_TOKEN.approve(address(reserve), amount / 2);

    vm.expectEmit(true, true, true, true, address(reserve));
    emit GhoRestored(address(this), amount / 2);
    reserve.restore(amount / 2);

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), amount / 2);

    reserve.transfer(facilitator, amount / 2);

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), 0);
  }

  function testGetEntities() public {
    address alice = makeAddr('alice');
    address[] memory entities = GHO_RESERVE.getEntities();

    assertEq(entities.length, 2);

    GHO_RESERVE.addEntity(alice);

    entities = GHO_RESERVE.getEntities();

    assertEq(entities.length, 3);

    assertEq(address(GHO_GSM), entities[0]);
    assertEq(address(GHO_GSM_4626), entities[1]);
    assertEq(alice, entities[2]);
  }

  function testIsEntity() public {
    assertTrue(GHO_RESERVE.isEntity(address(GHO_GSM)));
    assertFalse(GHO_RESERVE.isEntity(makeAddr('NOT_AN_ENTITY')));
  }

  function testTotalEntities() public {
    assertEq(GHO_RESERVE.totalEntities(), 2);

    GHO_RESERVE.addEntity(makeAddr('alice'));

    assertEq(GHO_RESERVE.totalEntities(), 3);
  }

  function _deployReserve() public returns (GhoReserve) {
    address proxyAdmin = makeAddr('PROXY_ADMIN');

    GhoReserve reserve = new GhoReserve(address(GHO_TOKEN));
    reserve.initialize(address(this));

    bytes memory ghoReserveInitParams = abi.encodeWithSignature(
      'initialize(address)',
      address(this)
    );

    TransparentUpgradeableProxy reserveProxy = new TransparentUpgradeableProxy(
      address(reserve),
      proxyAdmin,
      ghoReserveInitParams
    );

    return GhoReserve(address(reserveProxy));
  }
}
