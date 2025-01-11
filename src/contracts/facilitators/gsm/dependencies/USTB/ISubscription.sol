// Simple minimal interface for subscriptions of USTB
pragma solidity ^0.8.10;

interface ISubscription {
  /**
   * @notice The ```subscribe``` function takes in stablecoins and mints SuperstateToken in the proper amount for the msg.sender depending on the current Net Asset Value per Share.
   * @param inAmount The amount of the stablecoin in
   * @param stablecoin The address of the stablecoin to calculate with
   */
  function subscribe(uint256 inAmount, address stablecoin) external;

  function calculateSuperstateTokenOut(
    uint256 inAmount,
    address stablecoin
  )
    external
    view
    returns (
      uint256 superstateTokenOutAmount,
      uint256 stablecoinInAmountAfterFee,
      uint256 feeOnStablecoinInAmount
    );
}
