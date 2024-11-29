// Simple minimal interface for subscriptions of USTB
pragma solidity ^0.8.10;

interface ISubscription {
  /**
   * @notice Subscribes an amount of USTB in exchange for USDC
   * @param amount The amount of USDC to subscribe
   * @param stablecoin The address of the stablecoin to calculate with
   */
  function subscribe(uint256 inAmount, address stablecoin) external;
}
