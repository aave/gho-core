// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGsmL2 {
  /// @dev Cannot sell more of underlying into GSM
  error ExogenousAssetExposureTooHigh();

  /// @dev The GSM has been fozen
  error GsmFrozen();

  /// @dev The GSM is not currently seized
  error GsmNotSeized();

  /// @dev The GSM has been seized
  error GsmSeized();

  /// @dev Not enough underlying asset to cover swap
  error InsufficientAvailableExogenousLiquidity();

  /// @dev Amount must be greater than zero
  error InvalidAmount();

  /// @dev Caller can only be liquidity provider
  error InvalidLiquidityProvider();

  /// @dev Provided address cannot be the zero-address
  error InvalidZeroAddress();

  /// @dev Price Strategy must be strategy for underlying asset
  error InvalidPriceStrategy();

  /// @dev Invalid signature provided
  error InvalidSignature();

  /// @dev The signature has expired
  error SignatureExpired();

  /**
   * @dev Emitted when the GSM's liquidity provider is updated
   * @param oldLiquidityProvider The address of the old liquidity provider
   * @param newLiquidityProvider The address of the new liquidity provider
   */
  event LiquidityProviderUpdated(address oldLiquidityProvider, address newLiquidityProvider);

  /**
   * @dev Emitted when the liquidity provider adds GHO to the GSM
   * @param provider The address of the liquidity provider
   * @param amount The amount of GHO provided
   */
  event LiquidityProvided(address provider, uint256 amount);

  /**
   * @notice Updates the address of the liquidity provider of the GSM. The liquidity provider
   * sends GHO to fund the GSM and receives GHO when the GSM is seized to burn the GHO.
   * @param liquidityProvider The new address of the liquidity provider
   */
  function updateLiquidityProvider(address liquidityProvider) external;

  /**
   * @notice Provides GHO tokens to the GSM in order to be able to swap for underlying asset
   * @param amount The amount of GHO provided
   */
  function provideLiquidity(uint256 amount) external;

  /**
   * Returns the address of the account that can supply GHO to the GSM
   */
  function getLiquidityProvider() external view returns (address);

  /**
   * Returns the current amount of GHO that is available for swaps
   */
  function getAvailableGhoLiquidity() external view returns (uint128);

  /**
   * Returns the current amount of GHO that was provided to the contract
   */
  function getProvidedGhoLiquidity() external view returns (uint128);
}
