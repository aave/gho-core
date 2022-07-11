// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

interface IAaveOracle {
  /// @notice External function called by the Aave governance to set or replace sources of assets
  /// @param assets The addresses of the assets
  /// @param sources The address of the source of each asset
  function setAssetSources(address[] calldata assets, address[] calldata sources) external;
}
