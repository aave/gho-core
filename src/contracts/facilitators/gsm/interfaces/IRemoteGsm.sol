// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGsm} from './IGsm.sol';

/**
 * @title IRemoteGsm
 * @author Aave
 * @notice Defines the behaviour of a Remote GHO Stability Module
 */
interface IRemoteGsm is IGsm {
  /**
   * @dev Emitted when the GSM's reserve is updated
   * @param oldReserve The address of the old reserve
   * @param newReserve The address of the new reserve
   */
  event GhoReserveUpdated(address oldReserve, address newReserve);

  /**
   * Returns the address of the GHO reserve
   */
  function getGhoReserve() external view returns (address);

  /**
   * @notice Updates the GHO reserve address
   * @param ghoReserve The new address of the reserve holding GHO
   */
  function updateGhoReserve(address ghoReserve) external;
}
