// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGhoRemoteReserve {
  /**
   * Struct representing GSM's maximum allowed GHO withdrawal and capacity used
   * @param capacity The maximum amount of GHO that can be withdrawn
   * @param withdrawn The current amount of GHO withdrawn
   */
  struct GhoCapacity {
    uint128 capacity;
    uint128 withdrawn;
  }

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
   * @dev Emitted when the GHO capacity for a given user is updated
   * @param user Address that can withdraw GHO
   * @param capacity Maximum capacity
   */
  event WithdrawerCapacityUpdated(address indexed user, uint256 capacity);

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
   * @notice Allows allowed caller to withdraw GHO from reserve
   * @param amount The amount of GHO to withdraw
   */
  function withdrawGho(uint256 amount) external;

  /**
   * Sets a given addresses' capacity
   * @param withdrawer Address that can withdraw GHO
   * @param capacity Maximum amount of GHO that can be withdrawn
   */
  function setWithdrawerCapacity(address withdrawer, uint256 capacity) external;

  /**
   * Returns amount of GHO withdrawn by a specified address
   * @param withdrawer Address of the contract that withdrew GHO from reserve
   */
  function getWithdrawnGho(address withdrawer) external view returns (uint256);

  /**
   * Returns maximum amount of GHO that can be withdrawn by a specified address
   * @param withdrawer Address of the contract that withdraws GHO from reserve
   */
  function getCapacity(address withdrawer) external view returns (uint256);

  /**
   * @notice Returns the GhoRemoteReserve revision number
   * @return The revision number
   */
  function GHO_REMOTE_RESERVE_REVISION() external pure returns (uint256);
}
