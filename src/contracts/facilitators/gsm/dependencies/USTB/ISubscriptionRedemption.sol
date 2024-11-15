// Simple interface for subscriptions/redemptions of USTB/USDC
pragma solidity ^0.8.10;

/**
 * @title ISubscriptionRedemption
 */
interface ISubscriptionRedemption {
  /**
   * @notice Subscribes an amount of USTB in exchange for USDC
   * @param amount The amount of USDC to subscribe
   */
  function subscribe(uint256 amount) external;

  /**
   * @notice Redeems an amount of USDC in exchange for USTB
   * @param amount The amount of the USTB to redeem
   */
  function redeem(uint256 amount) external;

  /**
   * @notice Calculates the amount of USTB required to redeem to get a given amount of USDC
   * @param usdcOutAmount The amount of USDC to receive
   * @return ustbInAmount The amount of USTB required to redeem to get usdcOutAmount
   * @return usdPerUstbChainlinkRaw The price of USTB in USD, in Chainlink raw format
   */
  function calculateUstbIn(
    uint256 usdcOutAmount
  ) external view returns (uint256 ustbInAmount, uint256 usdPerUstbChainlinkRaw);

  /**
   * @notice Calculates the amount of USDC that will be received when redeeming a given amount of USTB
   * @param superstateTokenInAmount The amount of USTB to redeem
   * @return usdcOutAmount The amount of USDC to receive
   * @return usdPerUstbChainlinkRaw The price of USTB in USD, in Chainlink raw format
   */
  function calculateUsdcOut(
    uint256 superstateTokenInAmount
  ) external view returns (uint256 usdcOutAmount, uint256 usdPerUstbChainlinkRaw);
}
