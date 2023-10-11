// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IGsmRegistry
 * @author Aave
 * @notice Defines the behaviour of the GsmRegistry
 */
interface IGsmRegistry {
  /**
   * @dev Emitted when a new GSM is added to the registry
   * @param gsmAddress The address of the GSM contract
   */
  event GsmAdded(address indexed gsmAddress);

  /**
   * @dev Emitted when a new GSM is removed from the registry
   * @param gsmAddress The address of the GSM contract
   */
  event GsmRemoved(address indexed gsmAddress);

  /**
   * @notice Adds a new GSM to the registry
   * @param gsmAddress The address of the GSM contract
   */
  function addGsm(address gsmAddress) external;

  /**
   * @notice Removes a GSM from the registry
   * @param gsmAddress The address of the GSM contract
   */
  function removeGsm(address gsmAddress) external;

  /**
   * @notice Returns a list of GSM addresses to the registry
   * @return A list of GSM contract addresses
   */
  function getGsmList() external view returns (address[] memory);

  /**
   * @notice Returns the length of the list of GSM addresses
   * @return The size of the GSM list
   */
  function getGsmListLength() external view returns (uint256);

  /**
   * @notice Returns the address of the GSM placed in the list at the given index
   * @param index The index of the GSM within the list
   * @return The GSM address
   */
  function getGsmAtIndex(uint256 index) external view returns (address);
}
