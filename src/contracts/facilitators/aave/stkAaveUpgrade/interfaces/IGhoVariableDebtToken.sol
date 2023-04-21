// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGhoVariableDebtToken {
  /**
   * @notice Updates the discount percents of the users when a discount token transfer occurs
   * @param sender The address of sender
   * @param recipient The address of recipient
   * @param senderDiscountTokenBalance The sender discount token balance
   * @param recipientDiscountTokenBalance The recipient discount token balance
   * @param amount The amount of discount token being transferred
   */
  function updateDiscountDistribution(
    address sender,
    address recipient,
    uint256 senderDiscountTokenBalance,
    uint256 recipientDiscountTokenBalance,
    uint256 amount
  ) external;
}
