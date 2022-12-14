// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

/**
 * @title IGhoFlashReceiver
 * @author Aave
 * @notice It defines the basic interface of a GhoFlashReceiver
 */
interface IGhoFlashReceiver {
  /**
   * @notice Receive a flash loan.
   * @param initiator The initiator of the loan.
   * @param amount The amount of tokens lent
   * @param fee The additional amount of tokens to repay.
   * @param data Arbitrary data structure, intended to contain user-defined parameters.
   * @return The keccak256 hash of "GhoFlashMinter.onFlashLoan"
   */
  function onFlashLoan(
    address initiator,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external returns (bytes32);
}
