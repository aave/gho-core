// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626} from '@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract MockERC4626 is ERC4626 {
  constructor(
    string memory name,
    string memory symbol,
    address asset
  ) ERC4626(IERC20(asset)) ERC20(name, symbol) {}

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }
}
