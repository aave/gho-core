// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import './TestEnv.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {DebtUtils} from './libraries/DebtUtils.sol';
import {GhoActions} from './libraries/GhoActions.sol';

contract TestGhoFlashMinter is Test, GhoActions {
  address public alice;
  address public bob;
  address public carlos;
  uint256 flashMintAmount = 200e18;

  function setUp() public {
    alice = users[0];
    bob = users[1];
    carlos = users[2];
  }

  function testConstructor() public {
    GhoFlashMinter flashMinter = new GhoFlashMinter(
      address(GHO_TOKEN),
      treasury,
      DEFAULT_FLASH_FEE,
      address(PROVIDER)
    );
    assertEq(address(flashMinter.GHO_TOKEN()), address(GHO_TOKEN), 'Wrong GHO token address');
    assertEq(flashMinter.getFee(), DEFAULT_FLASH_FEE, 'Wrong fee');
    assertEq(flashMinter.getGhoTreasury(), treasury, 'Wrong treasury address');
    assertEq(
      address(flashMinter.ADDRESSES_PROVIDER()),
      address(PROVIDER),
      'Wrong addresses provider address'
    );
  }

  function testRevertFlashloanNonRecipient() public {
    vm.expectRevert();
    GHO_FLASH_MINTER.flashLoan(
      IERC3156FlashBorrower(address(this)),
      address(GHO_TOKEN),
      flashMintAmount,
      ''
    );
  }

  function testRevertFlashloanWrongToken() public {
    vm.expectRevert('FlashMinter: Unsupported currency');
    GHO_FLASH_MINTER.flashLoan(
      IERC3156FlashBorrower(address(FLASH_BORROWER)),
      address(0),
      flashMintAmount,
      ''
    );
  }

  function testRevertFlashloanMoreThanCapacity() public {
    vm.expectRevert();
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
    vm.expectRevert();
    FLASH_BORROWER.flashBorrow(address(GHO_TOKEN), flashMintAmount);
  }

  function testFlashloan() public {
    ACL_MANAGER.setState(true);
    uint256 feeAmount = (DEFAULT_FLASH_FEE * flashMintAmount) / 100e2;
    ghoFaucet(address(FLASH_BORROWER), feeAmount);
    FLASH_BORROWER.flashBorrow(address(GHO_TOKEN), flashMintAmount);
  }
}
