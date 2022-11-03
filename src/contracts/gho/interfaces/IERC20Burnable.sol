// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.6.0 <0.9.0;

/**
 * @dev Interface of a burnable erc-20 token
 */
interface IERC20Burnable {
  /**
   * @dev Destroys `amount` tokens from caller
   * @param amount The amount of tokens to destroy
   */
  function burn(uint256 amount) external;
}
