// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGsmL2 {
  /// @dev The GSM has been fozen
  error GsmFrozen();

  /// @dev The GSM has been seized
  error GsmSeized();

  /// @dev Amount must be greater than zero
  error InvalidAmount();

  /// @dev Provided address cannot be the zero-address
  error InvalidZeroAddress();

  /// @dev Price Strategy must be strategy for underlying asset
  error InvalidPriceStrategy();

  /// @dev Invalid signature provided
  error InvalidSignature();

  /// @dev The signature has expired
  error SignatureExpired();
}
