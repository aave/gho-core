// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from '@openzeppelin/contracts/access/IAccessControl.sol';
import {IGhoFacilitator} from '../../../gho/interfaces/IGhoFacilitator.sol';

/**
 * @title IGsm
 * @author Aave
 * @notice Defines the behaviour of a GHO Stability Module
 */
interface IGsm is IAccessControl, IGhoFacilitator {
  /**
   * @dev Emitted when a user buys an asset (selling GHO) in the GSM
   * @param originator The address of the buyer originating the request
   * @param receiver The address of the receiver of the underlying asset
   * @param underlyingAmount The amount of the underlying asset bought
   * @param ghoAmount The amount of GHO sold, inclusive of fee
   * @param fee The fee paid by the buyer, in GHO
   */
  event BuyAsset(
    address indexed originator,
    address indexed receiver,
    uint256 underlyingAmount,
    uint256 ghoAmount,
    uint256 fee
  );

  /**
   * @dev Emitted when a user sells an asset (buying GHO) in the GSM
   * @param originator The address of the seller originating the request
   * @param receiver The address of the receiver of GHO
   * @param underlyingAmount The amount of the underlying asset sold
   * @param ghoAmount The amount of GHO bought, inclusive of fee
   * @param fee The fee paid by the buyer, in GHO
   */
  event SellAsset(
    address indexed originator,
    address indexed receiver,
    uint256 underlyingAmount,
    uint256 ghoAmount,
    uint256 fee
  );

  /**
   * @dev Emitted when a user buys a tokenized version of an asset (selling GHO) in the GSM
   * @param originator The address of the redeemer originating the request
   * @param receiver The address of the receiver of the underlying asset
   * @param tokenizedAmount The amount of the tokenized asset bought
   * @param ghoAmount The amount of GHO sold, inclusive of fee
   * @param fee The fee paid by the buyer, in GHO
   */
  event BuyTokenizedAsset(
    address indexed originator,
    address indexed receiver,
    uint256 tokenizedAmount,
    uint256 ghoAmount,
    uint256 fee
  );

  /**
   * @dev Emitted when a user redeems the tokenized underlying asset for the underlying asset itself
   * @param originator The address of the redeemer originating the request
   * @param receiver The address receiving the redeemed underlying asset
   * @param amount The amount of tokenized underlying asset redeemed
   */
  event RedeemTokenizedAsset(address indexed originator, address indexed receiver, uint256 amount);

  /**
   * @dev Emitted when the Swap Freezer freezes buys/sells
   * @param freezer The address of the Swap Freezer
   * @param enabled True if swap functions are frozen, False otherwise
   */
  event SwapFreeze(address indexed freezer, bool enabled);

  /**
   * @dev Emitted when a Liquidator seizes GSM funds
   * @param seizer The address originating the seizure request
   * @param recipient The address of the recipient of seized funds
   * @param underlyingAmount The amount of the underlying asset seized
   * @param ghoOutstanding The amount of remaining GHO that the GSM had minted
   */
  event Seized(
    address indexed seizer,
    address indexed recipient,
    uint256 underlyingAmount,
    uint256 ghoOutstanding
  );

  /**
   * @dev Emitted when burning GHO after a seizure of GSM funds
   * @param burner The address of the burner
   * @param amount The amount of GHO burned
   * @param ghoOutstanding The amount of remaining GHO that the GSM had minted
   */
  event BurnAfterSeize(address indexed burner, uint256 amount, uint256 ghoOutstanding);

  /**
   * @dev Emitted when an asset is provided to the GSM to backstop a loss
   * @param backer The address of the backer
   * @param asset The address of the provided asset
   * @param amount The amount of the asset
   * @param ghoAmount The amount of the asset, in GHO terms
   * @param remainingLoss The loss balance that remains after the operation
   */
  event BackingProvided(
    address indexed backer,
    address indexed asset,
    uint256 amount,
    uint256 ghoAmount,
    uint256 remainingLoss
  );

  /**
   * @dev Emitted when the GSM Token is updated
   * @param oldGsmToken The address of the old GSM Token
   * @param newGsmToken The address of the new GSM Token
   */
  event GsmTokenUpdated(address indexed oldGsmToken, address indexed newGsmToken);

  /**
   * @dev Emitted when the Price Strategy is updated
   * @param oldPriceStrategy The address of the old Price Strategy
   * @param newPriceStrategy The address of the new Price Strategy
   */
  event PriceStrategyUpdated(address indexed oldPriceStrategy, address indexed newPriceStrategy);

  /**
   * @dev Emitted when the Fee Strategy is updated
   * @param oldFeeStrategy The address of the old Fee Strategy
   * @param newFeeStrategy The address of the new Fee Strategy
   */
  event FeeStrategyUpdated(address indexed oldFeeStrategy, address indexed newFeeStrategy);

  /**
   * @dev Emitted when the GSM underlying asset Exposure Cap is updated
   * @param oldExposureCap The amount of the old Exposure Cap
   * @param newExposureCap The amount of the new Exposure Cap
   */
  event ExposureCapUpdated(uint256 oldExposureCap, uint256 newExposureCap);

  /**
   * @dev Emitted when tokens are rescued from the GSM
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
   * @notice Returns the EIP712 domain separator
   * @return The EIP712 domain separator
   */
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  /**
   * @notice Buying the GSM underlying asset in exchange for selling GHO + fee
   * @dev Use `getAssetAmountForBuyAsset` function to calculate the amount based on the GHO amount to sell
   * @param amount The amount of the underlying asset desired for purchase
   * @param receiver Recipient address of the underlying asset being purchased
   * @param isTokenized If true, user receives tokenized version of underlying asset
   */
  function buyAsset(uint128 amount, address receiver, bool isTokenized) external;

  /**
   * @notice Buying the GSM underlying asset in exchange for selling GHO + fee, using an EIP-712 signature
   * @dev Use `getAssetAmountForBuyAsset` function to calculate the amount based on the GHO amount to sell
   * @param originator Signer of the request
   * @param amount The amount of the underlying asset desired for purchase
   * @param receiver Recipient address of the underlying asset being purchased
   * @param isTokenized If true, user receives tokenized version of underlying asset
   * @param deadline Signature expiration deadline
   * @param signature Signature data
   */
  function buyAssetWithSig(
    address originator,
    uint128 amount,
    address receiver,
    bool isTokenized,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /**
   * @notice Selling the GSM underlying asset in exchange for buying GHO + fee
   * @dev Use `getAssetAmountForSellAsset` function to calculate the amount based on the GHO amount to buy
   * @param amount The amount of the underlying asset desired to sell
   * @param receiver Recipient address of the GHO being purchased
   */
  function sellAsset(uint128 amount, address receiver) external;

  /**
   * @notice Selling the GSM underlying asset in exchange for buying GHO + fee, using an EIP-712 signature
   * @dev Use `getAssetAmountForSellAsset` function to calculate the amount based on the GHO amount to buy
   * @param originator Signer of the request
   * @param amount The amount of the underlying asset desired to sell
   * @param receiver Recipient address of the GHO being purchased
   * @param deadline Signature expiration deadline
   * @param signature Signature data
   */
  function sellAssetWithSig(
    address originator,
    uint128 amount,
    address receiver,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /**
   * @notice Redeems the tokenized underlying asset for the underlying asset itself
   * @param amount The amount of the tokenized underlying asset to exchange for the underlying asset
   * @param receiver Recipient address of the underlying asset redeemed
   */
  function redeemTokenizedAsset(uint128 amount, address receiver) external;

  /**
   * @notice Rescue and transfer tokens locked in this contract
   * @param token The address of the token
   * @param to The address of the recipient
   * @param amount The amount of token to transfer
   */
  function rescueTokens(address token, address to, uint256 amount) external;

  /**
   * @notice Enable or disable the swap freeze
   * @param enable True to freeze swap functions, false otherwise
   */
  function setSwapFreeze(bool enable) external;

  /**
   * @notice Seizes all of the underlying asset from the GSM
   * @param recipient The address to send underlying assets to after seizure
   */
  function seize(address recipient) external;

  /**
   * @notice Once the GSM has assets seized, GHO can be burned (for nothing) to return facilitator bucket to zero
   * @param amount The amount of GHO to burn
   */
  function burnAfterSeize(uint256 amount) external;

  /**
   * @notice Restores backing of GHO by providing GHO or underlying asset
   * @dev Useful in the event the underlying value declines relative to GHO minted
   * @param asset The address of the asset (GHO or underlying asset)
   * @param amount The amount of the asset to be used for backing
   */
  function backWith(address asset, uint128 amount) external;

  /**
   * @notice Updates the address of the Gsm Token
   * @param token The address of the new GsmToken
   */
  function updateGsmToken(address token) external;

  /**
   * @notice Updates the address of the Price Strategy
   * @dev Changing the price strategy can impact the backing of the GSM
   * @param priceStrategy The address of the new PriceStrategy
   */
  function updatePriceStrategy(address priceStrategy) external;

  /**
   * @notice Updates the address of the Fee Strategy
   * @param feeStrategy The address of the new FeeStrategy
   */
  function updateFeeStrategy(address feeStrategy) external;

  /**
   * @notice Updates the exposure cap of the underlying asset
   * @param exposureCap The new value for the exposure cap (in underlying asset terms)
   */
  function updateExposureCap(uint128 exposureCap) external;

  /**
   * @notice Returns the total amount of GHO, gross amount and fee result of buying assets
   * @param assetAmount The amount of underlying asset to buy
   * @return The total amount of GHO the user sells (gross amount in GHO plus fee)
   * @return The gross amount of GHO
   * @return The fee amount in GHO, applied on top of gross amount of GHO
   */
  function getGhoAmountForBuyAsset(
    uint256 assetAmount
  ) external view returns (uint256, uint256, uint256);

  /**
   * @notice Returns the total amount of GHO, gross amount and fee result of selling assets
   * @param assetAmount The amount of underlying asset to sell
   * @return The total amount of GHO the user buys (gross amount in GHO minus fee)
   * @return The gross amount of GHO
   * @return The fee amount in GHO, applied to the gross amount of GHO
   */
  function getGhoAmountForSellAsset(
    uint256 assetAmount
  ) external view returns (uint256, uint256, uint256);

  /**
   * @notice Returns the amount of underlying asset, gross amount of GHO and fee result of buying assets
   * @param ghoAmount The amount of GHO the user provides for buying underlying asset
   * @return The amount of underlying asset the user buys
   * @return The gross amount of GHO corresponding to the given total amount of GHO
   * @return The fee amount in GHO, charged for buying assets
   */
  function getAssetAmountForBuyAsset(
    uint256 ghoAmount
  ) external view returns (uint256, uint256, uint256);

  /**
   * @notice Returns the amount of underlying asset, gross amount of GHO and fee result of selling assets
   * @param ghoAmount The amount of GHO the user receives for selling underlying asset
   * @return The amount of underlying asset the user sells
   * @return The gross amount of GHO corresponding to the given total amount of GHO
   * @return The fee amount in GHO, charged for selling assets
   */
  function getAssetAmountForSellAsset(
    uint256 ghoAmount
  ) external view returns (uint256, uint256, uint256);

  /**
   * @notice Returns the remaining GSM exposure capacity
   * @return The amount of underlying asset that can be sold to the GSM
   */
  function getAvailableUnderlyingExposure() external view returns (uint256);

  /**
   * @notice Returns the actual underlying asset balance immediately available in the GSM
   * @return The amount of underlying asset that can be bought from the GSM
   */
  function getAvailableLiquidity() external view returns (uint256);

  /**
   * @notice Returns the excess or dearth of GHO, reflecting current GSM backing
   * @return The excess amount of GHO minted, relative to the value of the underlying
   * @return The dearth of GHO minted, relative to the value of the underlying
   */
  function getCurrentBacking() external view returns (uint256, uint256);

  /**
   * @notice Returns the Fee Strategy for the GSM
   * @dev It returns 0x0 in case of no fee strategy
   * @return The address of the FeeStrategy
   */
  function getFeeStrategy() external view returns (address);

  /**
   * @notice Returns the Price Strategy for the GSM
   * @return The address of the PriceStrategy
   */
  function getPriceStrategy() external view returns (address);

  /**
   * @notice Returns the address of the Gsm Token for the GSM
   * @dev It returns 0x0 in case of no GSM token
   * @return The address of the GsmToken
   */
  function getGsmToken() external view returns (address);

  /**
   * @notice Returns the amount of assets currently tokenized for this GSM
   * @return The amount of tokenized assets
   */
  function getTokenizedAssets() external view returns (uint256);

  /**
   * @notice Returns the freeze status of the GSM
   * @return True if frozen, false if not
   */
  function getIsFrozen() external view returns (bool);

  /**
   * @notice Returns the current seizure status of the GSM
   * @return True if the GSM has been seized, false if not
   */
  function getIsSeized() external view returns (bool);

  /**
   * @notice Returns the GSM revision number
   * @return The revision number
   */
  function GSM_REVISION() external pure returns (uint256);

  /**
   * @notice Returns the address of the GHO token
   * @return The address of GHO token contract
   */
  function GHO_TOKEN() external view returns (address);

  /**
   * @notice Returns the underlying asset of the GSM
   * @return The address of the underlying asset
   */
  function UNDERLYING_ASSET() external view returns (address);

  /**
   * @notice Returns the current nonce (for EIP-712 signature methods) of an address
   * @param user The address of the user
   * @return The current nonce of the user
   */
  function nonces(address user) external view returns (uint256);

  /**
   * @notice Returns the identifier of the Configurator Role
   * @return The bytes32 id hash of the Configurator role
   */
  function CONFIGURATOR_ROLE() external pure returns (bytes32);

  /**
   * @notice Returns the identifier of the Token Rescuer Role
   * @return The bytes32 id hash of the TokenRescuer role
   */
  function TOKEN_RESCUER_ROLE() external pure returns (bytes32);

  /**
   * @notice Returns the identifier of the Swap Freezer Role
   * @return The bytes32 id hash of the SwapFreezer role
   */
  function SWAP_FREEZER_ROLE() external pure returns (bytes32);

  /**
   * @notice Returns the identifier of the Liquidator Role
   * @return The bytes32 id hash of the Liquidator role
   */
  function LIQUIDATOR_ROLE() external pure returns (bytes32);

  /**
   * @notice Returns the EIP-712 signature typehash for buyAssetWithSig
   * @return The bytes32 signature typehash for buyAssetWithSig
   */
  function BUY_ASSET_WITH_SIG_TYPEHASH() external pure returns (bytes32);

  /**
   * @notice Returns the EIP-712 signature typehash for sellAssetWithSig
   * @return The bytes32 signature typehash for sellAssetWithSig
   */
  function SELL_ASSET_WITH_SIG_TYPEHASH() external pure returns (bytes32);
}
