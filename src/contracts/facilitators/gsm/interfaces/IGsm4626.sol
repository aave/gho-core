// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGsm} from './IGsm.sol';

/**
 * @title IGsm4626
 * @author Aave
 * @notice Defines the behaviour of a GHO Stability Module with an ERC-4626 underlying asset
 */
interface IGsm4626 is IGsm {
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
   * @notice Restores backing of GHO by burning GHO
   * @dev Useful in the event the underlying value declines relative to GHO minted
   * @dev Passing an amount higher than the current deficit will result in backing the entire deficit
   * @param amount The amount of GHO to be burned
   * @return The amount of GHO used for backing
   */
  function backWithGho(uint256 amount) external returns (uint256);

  /**
   * @notice Restores backing of GHO by providing underlying asset
   * @dev Useful in the event the underlying value declines relative to GHO minted
   * @dev Passing an amount higher than the current deficit will result in backing the entire deficit
   * @param amount The amount of underlying to be used for backing
   * @return The amount of underlying used for backing
   */
  function backWithUnderlying(uint256 amount) external returns (uint256);

  /**
   * @notice Returns the excess or deficit of GHO, reflecting current GSM backing
   * @return The excess amount of GHO minted, relative to the value of the underlying
   * @return The deficit of GHO minted, relative to the value of the underlying
   */
  function getCurrentBacking() external view returns (uint256, uint256);
}
