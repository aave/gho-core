// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IGsmConverter
 * @author Aave
 * @notice Defines the behaviour of GSM Converters for conversions/redemptions between two non-GHO assets
 * @dev
 */
interface IGsmConverter {
  /**
   * @dev Emitted when a user buys an asset (selling GHO) in the GSM after a redemption
   * @param originator The address of the buyer originating the request
   * @param receiver The address of the receiver of the underlying asset
   * @param redeemableAssetAmount The amount of the redeemable asset converted
   * @param ghoAmount The amount of total GHO sold, inclusive of fee
   */
  event BuyAssetThroughRedemption(
    address indexed originator,
    address indexed receiver,
    uint256 redeemableAssetAmount,
    uint256 ghoAmount
  );

  /**
   * @dev Emitted when tokens are rescued from the GSM converter
   * @param tokenRescued The address of the rescued token
   * @param recipient The address that received the rescued tokens
   * @param amountRescued The amount of token rescued
   */
  event TokensRescued(
    address indexed tokenRescued,
    address indexed recipient,
    uint256 amountRescued
  );

  /**
   * @notice Buys the GSM underlying asset in exchange for selling GHO, after asset redemption
   * @param minAmount The minimum amount of the underlying asset to buy (ie BUIDL)
   * @param receiver Recipient address of the underlying asset being purchased
   * @return The amount of underlying asset bought, after asset redemption
   * @return The amount of GHO sold by the user
   */
  function buyAsset(uint256 minAmount, address receiver) external returns (uint256, uint256);

  /**
   * @notice Buys the GSM underlying asset in exchange for selling GHO after asset redemption, using an EIP-712 signature
   * @dev Use `getAssetAmountForBuyAsset` function to calculate the amount based on the GHO amount to sell
   * @param originator The signer of the request
   * @param minAmount The minimum amount of the underlying asset to buy
   * @param receiver Recipient address of the underlying asset being purchased
   * @param deadline Signature expiration deadline
   * @param signature Signature data
   * @return The amount of underlying asset bought
   * @return The amount of GHO sold by the user
   */
  function buyAssetWithSig(
    address originator,
    uint256 minAmount,
    address receiver,
    uint256 deadline,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /**
   * @notice Sells the GSM underlying asset in exchange for buying GHO, after asset conversion
   * @param maxAmount The maximum amount of the underlying asset to sell
   * @param receiver Recipient address of the GHO being purchased
   * @return The amount of underlying asset sold, after asset conversion
   * @return The amount of GHO bought by the user
   */
  // function sellAsset(uint256 maxAmount, address receiver) external returns (uint256, uint256);

  /**
   * @notice Rescue and transfer tokens locked in this contract
   * @param token The address of the token
   * @param to The address of the recipient
   * @param amount The amount of token to transfer
   */
  function rescueTokens(address token, address to, uint256 amount) external;

  /**
   * @notice Returns the address of the GHO token
   * @return The address of GHO token contract
   */
  function GHO_TOKEN() external view returns (address);

  /**
   * @notice Returns the address of the GSM contract associated with the converter
   * @return The address of the GSM contract
   */
  function GSM() external view returns (address);

  /**
   * @notice Returns the address of the redeemable asset (token) associated with the converter
   * @return The address of the redeemable asset
   */
  function REDEEMABLE_ASSET() external view returns (address);

  /**
   * @notice Returns the address of the redeemed asset (token) associated with the converter
   * @return The address of the redeemed asset
   */
  function REDEEMED_ASSET() external view returns (address);

  /**
   * @notice Returns the address of the redemption contract that manages asset redemptions
   * @return The address of the redemption contract
   */
  function REDEMPTION_CONTRACT() external view returns (address);

  /**
   * @notice Returns the current nonce (for EIP-712 signature methods) of an address
   * @param user The address of the user
   * @return The current nonce of the user
   */
  function nonces(address user) external view returns (uint256);

  /**
   * @notice Returns the EIP-712 signature typehash for buyAssetWithSig
   * @return The bytes32 signature typehash for buyAssetWithSig
   */
  function BUY_ASSET_WITH_SIG_TYPEHASH() external pure returns (bytes32);
}
