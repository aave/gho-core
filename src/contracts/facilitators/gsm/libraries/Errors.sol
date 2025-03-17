// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library Errors {
  string public constant INVALID_ZERO_ADDRESS = '1'; // Address cannot be the zero-address
  string public constant GSM_FROZEN = '2'; // The GSM is currently frozen and swaps cannot be performed
  string public constant GSM_UNFROZEN = '3'; // The GSM is already unfrozen
  string public constant GSM_SEIZED = '4'; // The GSM has been seized and is no longer operational
  string public constant GSM_NOT_SEIZED = '5'; // The GSM has been seized and is no longer operational
  string public constant INVALID_PRICE_STRATEGY = '6'; // Invalid price strategy provided
  string public constant INVALID_SIG = '7'; // The signature is invalid
  string public constant SIG_EXPIRED = '8'; // The signature deadline has passed
  string public constant INSUFFICIENT_EXO_RESC = '9'; // Insufficient exogenous asset balance to perform rescue
  string public constant INSUFFICIENT_GHO_RESC = '10'; // Insufficient GHO balance to perform rescue
  string public constant INVALID_AMOUNT = '11'; // Amount must be greater than zero
  string public constant INVALID_LIQ_PROVIDER = '12'; // Only approved provider can supply liquidity
  string public constant INSUFFICIENT_EXO_LIQ = '13'; // Insufficient available exogenous liquidity
  string public constant EXO_LIQ_HIGH = '14'; // Exogenous asset exposure too high
}
