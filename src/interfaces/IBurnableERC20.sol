// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

/**
 * @dev Interface of a burnable erc-20 token
 */
interface IBurnableERC20 {
  function burn(address account, uint256 amount) external;
}
