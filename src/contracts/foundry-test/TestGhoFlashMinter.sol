// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import './TestEnv.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {DebtUtils} from './libraries/DebtUtils.sol';
import {GhoActions} from './libraries/GhoActions.sol';
import {MockFlashBorrower} from '../facilitators/flashMinter/mocks/MockFlashBorrower.sol';
import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';

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
      FLASH_FEE,
      address(PROVIDER)
    );
    assertEq(address(flashMinter.GHO_TOKEN()), address(GHO_TOKEN), 'Wrong GHO token address');
    assertEq(flashMinter.getGhoTreasury(), treasury, 'Wrong treasury address');
    assertEq(flashMinter.getFee(), FLASH_FEE, 'Wrong fee');
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
      abi.encodeWithSignature('')
    );
  }
}
