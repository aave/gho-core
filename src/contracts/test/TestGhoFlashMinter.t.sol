// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoFlashMinter is TestGhoBase {
  function testConstructor() public {
    GhoFlashMinter flashMinter = new GhoFlashMinter(
      address(GHO_TOKEN),
      TREASURY,
      DEFAULT_FLASH_FEE,
      address(PROVIDER)
    );
    assertEq(address(flashMinter.GHO_TOKEN()), address(GHO_TOKEN), 'Wrong GHO token address');
    assertEq(flashMinter.getFee(), DEFAULT_FLASH_FEE, 'Wrong fee');
    assertEq(flashMinter.getGhoTreasury(), TREASURY, 'Wrong TREASURY address');
    assertEq(
      address(flashMinter.ADDRESSES_PROVIDER()),
      address(PROVIDER),
      'Wrong addresses provider address'
    );
  }

  function testRevertConstructorFeeOutOfRange() public {
    vm.expectRevert('FlashMinter: Fee out of range');
    new GhoFlashMinter(address(GHO_TOKEN), TREASURY, 10001, address(PROVIDER));
  }

  function testRevertFlashloanNonRecipient() public {
    vm.expectRevert();
    GHO_FLASH_MINTER.flashLoan(
      IERC3156FlashBorrower(address(this)),
      address(GHO_TOKEN),
      DEFAULT_BORROW_AMOUNT,
      ''
    );
  }

  function testRevertFlashloanWrongToken() public {
    vm.expectRevert('FlashMinter: Unsupported currency');
    GHO_FLASH_MINTER.flashLoan(
      IERC3156FlashBorrower(address(FLASH_BORROWER)),
      address(0),
      DEFAULT_BORROW_AMOUNT,
      ''
    );
  }

  function testRevertFlashloanMoreThanCapacity() public {
    vm.expectRevert('FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
    GHO_FLASH_MINTER.flashLoan(
      IERC3156FlashBorrower(address(FLASH_BORROWER)),
      address(GHO_TOKEN),
      DEFAULT_CAPACITY + 1,
      ''
    );
  }

  function testRevertFlashloanInsufficientReturned() public {
    ACL_MANAGER.setState(false);
    assertEq(
      ACL_MANAGER.isFlashBorrower(address(FLASH_BORROWER)),
      false,
      'Flash borrower should not be a whitelisted borrower'
    );
    vm.expectRevert(stdError.arithmeticError);
    FLASH_BORROWER.flashBorrow(address(GHO_TOKEN), DEFAULT_BORROW_AMOUNT);
  }

  function testRevertFlashloanWrongCallback() public {
    FLASH_BORROWER.setAllowCallback(false);
    vm.expectRevert('FlashMinter: Callback failed');
    FLASH_BORROWER.flashBorrow(address(GHO_TOKEN), DEFAULT_BORROW_AMOUNT);
  }

  function testRevertUpdateFeeNotPoolAdmin() public {
    ACL_MANAGER.setState(false);
    assertEq(
      ACL_MANAGER.isPoolAdmin(address(GHO_FLASH_MINTER)),
      false,
      'GhoFlashMinter should not be a pool admin'
    );

    vm.expectRevert('CALLER_NOT_POOL_ADMIN');
    GHO_FLASH_MINTER.updateFee(100);
  }

  function testRevertUpdateFeeOutOfRange() public {
    vm.expectRevert('FlashMinter: Fee out of range');
    GHO_FLASH_MINTER.updateFee(10001);
  }

  function testRevertUpdateTreasuryNotPoolAdmin() public {
    ACL_MANAGER.setState(false);
    assertEq(
      ACL_MANAGER.isPoolAdmin(address(GHO_FLASH_MINTER)),
      false,
      'GhoFlashMinter should not be a pool admin'
    );

    vm.expectRevert('CALLER_NOT_POOL_ADMIN');
    GHO_FLASH_MINTER.updateGhoTreasury(address(0));
  }

  function testRevertFlashfeeNotGho() public {
    vm.expectRevert('FlashMinter: Unsupported currency');
    GHO_FLASH_MINTER.flashFee(address(0), DEFAULT_BORROW_AMOUNT);
  }

  // Positives

  function testFlashloan() public {
    ACL_MANAGER.setState(false);
    assertEq(
      ACL_MANAGER.isFlashBorrower(address(FLASH_BORROWER)),
      false,
      'Flash borrower should not be a whitelisted borrower'
    );

    uint256 feeAmount = (DEFAULT_FLASH_FEE * DEFAULT_BORROW_AMOUNT) / 100e2;
    ghoFaucet(address(FLASH_BORROWER), feeAmount);

    vm.expectEmit(true, true, true, true, address(GHO_FLASH_MINTER));
    emit FlashMint(
      address(FLASH_BORROWER),
      address(FLASH_BORROWER),
      address(GHO_TOKEN),
      DEFAULT_BORROW_AMOUNT,
      feeAmount
    );
    FLASH_BORROWER.flashBorrow(address(GHO_TOKEN), DEFAULT_BORROW_AMOUNT);
  }

  function testDistributeFeesToTreasury() public {
    uint256 treasuryBalanceBefore = GHO_TOKEN.balanceOf(TREASURY);

    ghoFaucet(address(GHO_FLASH_MINTER), 100e18);
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_FLASH_MINTER)),
      100e18,
      'GhoFlashMinter should have 100 GHO'
    );

    vm.expectEmit(true, true, false, true, address(GHO_FLASH_MINTER));
    emit FeesDistributedToTreasury(TREASURY, address(GHO_TOKEN), 100e18);
    GHO_FLASH_MINTER.distributeFeesToTreasury();

    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_FLASH_MINTER)),
      0,
      'GhoFlashMinter should have no GHO left after fee distribution'
    );
    assertEq(
      GHO_TOKEN.balanceOf(TREASURY),
      treasuryBalanceBefore + 100e18,
      'Treasury should have 100 more GHO'
    );
  }

  function testUpdateFee() public {
    assertEq(GHO_FLASH_MINTER.getFee(), DEFAULT_FLASH_FEE, 'Flashminter non-default fee');
    assertTrue(DEFAULT_FLASH_FEE != 100);
    vm.expectEmit(false, false, false, true, address(GHO_FLASH_MINTER));
    emit FeeUpdated(DEFAULT_FLASH_FEE, 100);
    GHO_FLASH_MINTER.updateFee(100);
  }

  function testUpdateGhoTreasury() public {
    assertEq(GHO_FLASH_MINTER.getGhoTreasury(), TREASURY, 'Flashminter non-default TREASURY');
    assertTrue(TREASURY != address(this));
    vm.expectEmit(true, true, false, false, address(GHO_FLASH_MINTER));
    emit GhoTreasuryUpdated(TREASURY, address(this));
    GHO_FLASH_MINTER.updateGhoTreasury(address(this));
  }

  function testMaxFlashloanNotGho() public {
    assertEq(
      GHO_FLASH_MINTER.maxFlashLoan(address(0)),
      0,
      'Max flash loan should be 0 for non-GHO token'
    );
  }

  function testMaxFlashloanGho() public {
    assertEq(
      GHO_FLASH_MINTER.maxFlashLoan(address(GHO_TOKEN)),
      DEFAULT_CAPACITY,
      'Max flash loan should be DEFAULT_CAPACITY for GHO token'
    );
  }

  function testWhitelistedFlashFee() public {
    assertEq(
      GHO_FLASH_MINTER.flashFee(address(GHO_TOKEN), DEFAULT_BORROW_AMOUNT),
      0,
      'Flash fee should be 0 for whitelisted borrowers'
    );
  }

  function testNotWhitelistedFlashFee() public {
    ACL_MANAGER.setState(false);
    assertEq(
      ACL_MANAGER.isFlashBorrower(address(this)),
      false,
      'Flash borrower should not be a whitelisted borrower'
    );
    uint256 fee = GHO_FLASH_MINTER.flashFee(address(GHO_TOKEN), DEFAULT_BORROW_AMOUNT);
    uint256 expectedFee = (DEFAULT_FLASH_FEE * DEFAULT_BORROW_AMOUNT) / 100e2;
    assertEq(fee, expectedFee, 'Flash fee should be correct');
  }

  // Fuzzing
  function testFuzzFlashFee(uint256 feeToSet, uint256 amount) public {
    vm.assume(feeToSet <= 10000);
    vm.assume(amount <= DEFAULT_CAPACITY);
    GHO_FLASH_MINTER.updateFee(feeToSet);
    ACL_MANAGER.setState(false); // Set ACL manager to return false so there are no whitelisted borrowers.

    uint256 fee = GHO_FLASH_MINTER.flashFee(address(GHO_TOKEN), amount);
    uint256 expectedFee = (feeToSet * amount) / 100e2;

    // We account for +/- 1 wei of rounding error.
    assertTrue(
      fee >= (expectedFee == 0 ? 0 : expectedFee - 1),
      'Flash fee should be greater than or equal to expected fee - 1'
    );
    assertTrue(
      fee <= expectedFee + 1,
      'Flash fee should be less than or equal to expected fee + 1'
    );
  }
}
