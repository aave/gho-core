// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Interface of a mintable erc-20 token
 */
interface IERC20Mintable {
  /**
   * @dev Creates `amount` new tokens for `account`
   * @param account The address to create tokens for
   * @param amount The amount of tokens to create
   */
  function mint(address account, uint256 amount) external;
}
