// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IGhoReserve
 * @author Aave/TokenLogic
 * @notice Defines the behaviour of a GhoReserve
 */
interface IGhoReserve {
  /**
   * @dev Struct data representing GHO usage.
   * @param limit The maximum amount of GHO that can be used
   * @param used The current amount of GHO used
   */
  struct GhoUsage {
    uint128 limit;
    uint128 used;
  }

  /**
   * @dev Emitted when an entity is added to the GhoReserve entities set
   * @param entity The address of the entity
   */
  event EntityAdded(address indexed entity);

  /**
   * @dev Emitted when an entity is removed from the GhoReserve entities set
   * @param entity The address of the entity
   */
  event EntityRemoved(address indexed entity);

  /**
   * @dev Emitted when GHO is restored to the reserve by an entity
   * @param entity The address restoring the GHO tokens
   * @param amount The amount of token restored
   */
  event GhoUsed(address indexed entity, uint256 amount);

  /**
   * @dev Emitted when GHO is transferred from the reserve to an entity
   * @param entity The address receiving the GHO tokens
   * @param amount The amount of token to transfer
   */
  event GhoRestored(address indexed entity, uint256 amount);

  /**
   * @dev Emitted when GHO is transferred from the reserve
   * @param to The address receiving the GHO tokens
   * @param amount The amount of token to transfer
   */
  event GhoTransferred(address indexed to, uint256 amount);

  /**
   * @dev Emitted when the GHO limit for a given entity is updated
   * @param entity The address of the entity
   * @param limit The new usage limit
   */
  event GhoLimitUpdated(address indexed entity, uint256 limit);

  /**
   * @notice Restores a specified amount of GHO to the reserve.
   * @dev The entity must grant allowance in advance to enable the reserve to pull the funds.
   * @dev Only callable by approved reserve entities.
   * @param amount The amount of GHO to restore.
   */
  function restore(uint256 amount) external;

  /**
   * @notice Uses a specified amount of GHO from the reserve.
   * @dev Callable only by entities with sufficient usage limit.
   * @param amount The amount of GHO to use.
   */
  function use(uint256 amount) external;

  /**
   * @notice Transfers a specified amount of GHO from the reserve
   * @param to The address receiving the GHO tokens
   * @param amount The amount of GHO to transfer
   */
  function transfer(address to, uint256 amount) external;

  /**
   * @notice Adds an entity to the reserve
   * @param entity The address of the entity
   */
  function addEntity(address entity) external;

  /**
   * @notice Removes an entity from the reserve
   * @param entity The address of the entity
   */
  function removeEntity(address entity) external;

  /**
   * @notice Sets a usage limit for a specified entity.
   * @dev The new usage limit can be set below the amount of GHO currently used
   * @param entity The address of the entity
   * @param limit The maximum amount of GHO that can be used
   */
  function setLimit(address entity, uint256 limit) external;

  /**
   * @notice Returns the address of the GHO token
   * @return The address of GHO token contract
   */
  function GHO_TOKEN() external view returns (address);

  /**
   * @notice Returns the list of all entities currently in the reserve
   * @return The array of addresses
   */
  function getEntities() external view returns (address[] memory);

  /**
   * @notice Returns the amount of GHO used by a specified entity
   * @param entity The address of the entity
   * @return The amount of GHO used
   */
  function getUsed(address entity) external view returns (uint256);

  /**
   * @notice Returns the usage data of a specified entity
   * @param entity The address of the entity
   * @return The usage limit
   * @return The amount of GHO used
   */
  function getUsage(address entity) external view returns (uint256, uint256);

  /**
   * @notice Returns the usage limit of a specified entity
   * @param entity The address of the entity
   * @return The usage limit
   */
  function getLimit(address entity) external view returns (uint256);

  /**
   * @notice Returns whether the entity is part of the reserve
   * @param entity The address of the entity
   * @return True if the entity is part of the set
   */
  function isEntity(address entity) external view returns (bool);

  /**
   * @notice Returns the number of entities in the reserve
   * @return The total number of entities
   */
  function totalEntities() external view returns (uint256);

  /**
   * @notice Returns the GhoReserve revision number
   * @return The revision number
   */
  function GHO_REMOTE_RESERVE_REVISION() external pure returns (uint256);
}
