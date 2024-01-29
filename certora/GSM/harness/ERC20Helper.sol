// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;
import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';

contract ERC20Helper {
  function tokenBalanceOf(address token, address user) public returns (uint256) {
    return IERC20(token).balanceOf(user);
  }

  function tokenTotalSupply(address token) public returns (uint256) {
    return IERC20(token).totalSupply();
  }
}
