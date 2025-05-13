// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestOwnableFacilitator is TestGhoBase {
  function testConstructor() public {
    OwnableFacilitator facilitator = new OwnableFacilitator(address(this), address(GHO_TOKEN));
    assertEq(facilitator.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(facilitator.owner(), address(this));
  }

  function testRevertConstructorInvalidOwner() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new OwnableFacilitator(address(0), address(GHO_TOKEN));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new OwnableFacilitator(address(this), address(0));
  }

  function testInitialize() public {
    OwnableFacilitator facilitator = new OwnableFacilitator(address(this), address(GHO_TOKEN));
    vm.expectEmit(true, true, true, true, address(facilitator));
    emit OwnershipTransferred(address(this), address(this));
    facilitator.initialize(address(this));
    assertEq(facilitator.owner(), address(this));
  }

  function testRevertInitializeInvalidZeroOwner() public {
    OwnableFacilitator facilitator = new OwnableFacilitator(address(this), address(GHO_TOKEN));
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    facilitator.initialize(address(0));
  }

  function testMint() public {
    uint256 amount = 50_000_000 ether;
    uint256 ghoBalanceBefore = GHO_TOKEN.balanceOf(address(this));
    (uint256 capacity, uint256 level) = GHO_TOKEN.getFacilitatorBucket(
      address(OWNABLE_FACILITATOR)
    );

    assertEq(capacity, DEFAULT_CAPACITY);
    assertEq(level, 0);
    assertEq(ghoBalanceBefore, 0);

    OWNABLE_FACILITATOR.mint(address(this), amount);

    (capacity, level) = GHO_TOKEN.getFacilitatorBucket(address(OWNABLE_FACILITATOR));
    uint256 ghoBalanceAfter = GHO_TOKEN.balanceOf(address(this));

    assertEq(capacity, DEFAULT_CAPACITY);
    assertEq(level, amount);
    assertEq(amount, ghoBalanceAfter);
  }

  function testRevertMintIfMintIsTooHigh() public {
    vm.expectRevert('FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
    OWNABLE_FACILITATOR.mint(address(this), 101_000_000 ether);
  }

  function testBurn() public {
    uint256 amount = 50_000_000 ether;
    uint256 ghoBalanceBefore = GHO_TOKEN.balanceOf(address(this));
    (uint256 capacity, uint256 level) = GHO_TOKEN.getFacilitatorBucket(
      address(OWNABLE_FACILITATOR)
    );

    assertEq(capacity, DEFAULT_CAPACITY);
    assertEq(level, 0);
    assertEq(ghoBalanceBefore, 0);

    OWNABLE_FACILITATOR.mint(address(this), amount);

    (capacity, level) = GHO_TOKEN.getFacilitatorBucket(address(OWNABLE_FACILITATOR));
    uint256 ghoBalanceAfter = GHO_TOKEN.balanceOf(address(this));

    assertEq(capacity, DEFAULT_CAPACITY);
    assertEq(level, amount);
    assertEq(amount, ghoBalanceAfter);

    GHO_TOKEN.transfer(address(OWNABLE_FACILITATOR), amount / 2);
    OWNABLE_FACILITATOR.burn(amount / 2);

    (capacity, level) = GHO_TOKEN.getFacilitatorBucket(address(OWNABLE_FACILITATOR));
    ghoBalanceAfter = GHO_TOKEN.balanceOf(address(this));

    assertEq(capacity, DEFAULT_CAPACITY);
    assertEq(level, amount / 2);
    assertEq(amount / 2, ghoBalanceAfter);
  }

  function testRevertBurnIfNoBalance() public {
    vm.expectRevert();
    OWNABLE_FACILITATOR.burn(50_000 ether);
  }
}
