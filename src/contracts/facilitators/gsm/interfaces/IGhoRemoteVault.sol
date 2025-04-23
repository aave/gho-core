// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from '@openzeppelin/contracts/access/IAccessControl.sol';

interface IGhoRemoteVault is IAccessControl {
  /**
   * @dev Emitted when GHO tokens are withdrawn
   * @param user Address withdrawing GHO
   * @param amount Amount of GHO withdrawn
   */
  event GhoWithdrawn(address indexed user, uint256 amount);

  /**
   * @dev Emitted when GHO tokens are returned
   * @param user Address returning GHO
   * @param amount Amount of GHO returned
   */
  event GhoReturned(address indexed user, uint256 amount);

  /**
   * @notice Returns the identifier of the Funds Admin Role
   * @return The bytes32 id hash of the Funds Admin role
   */
  function FUNDS_ADMIN_ROLE() external pure returns (bytes32);

  /**
   * @notice Returns the address of the GHO token
   * @return The address of GHO token contract
   */
  function GHO_TOKEN() external view returns (address);

  /**
   * @notice Accepts GHO to be repaied by caller
   * @param amount The amount of GHO to return
   */
  function returnGho(uint256 amount) external;

  /**
   * @notice Allows allowed caller to withdraw GHO from vault
   * @param amount The amount of GHO to withdraw
   */
  function withdrawGho(uint256 amount) external;

  /**
   * Returns amount of GHO withdrawn by a specified address
   * @param withdrawer Address of the contract that withdrew GHO from vault
   */
  function getWithdrawnGho(address withdrawer) external view returns (uint256);

  /**
   * @notice Returns the GhoRemoteVault revision number
   * @return The revision number
   */
  function GHO_REMOTE_VAULT_REVISION() external pure returns (uint256);
}
