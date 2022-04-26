// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.6.0 <0.9.0;

/**
 * @dev Interface of the AnteiStableDollar
 */
interface IAnteiStableDollar {
  /**
   * @dev Emitted on addEntities() and on construction for each added entity
   * @param entity The address of an added entity
   **/
  event EntityAdded(address entity);

  /**
   * @dev Emitted on removeEntities() for each removed entity
   * @param entity The address of a removed entity
   **/
  event EntityRemoved(address entity);

  /**
   * @notice Mint ASD to the provided entity
   * @dev Only callable by the owner
   * @param entity The address of the entity that will receive ASD
   * @param amount The amount of ASD the entity will receive
   */
  function mint(address entity, uint256 amount) external;

  /**
   * @notice Burn ASD from the calling entity
   * @dev Only callable by an entity
   * @param amount The amount of ASD that will be burned
   */
  function burn(uint256 amount) external;

  /**
   * @notice Add entities and transfer each of them a defined amount of ASD
   * @dev Only callable by the owner
   * @param entities Array of addresses that have been approved to manage ASD
   * @param amounts The amount of ASD each entity will receive
   */
  function addEntities(address[] memory entities, uint256[] memory amounts) external;

  /**
   * @notice Remove entities from the approved list of ASD managers
   * @dev Only callable by the owner
   * @param entities Array of addresses that will be removed as approved entities
   */
  function removeEntities(address[] memory entities) external;

  /**
   * @notice Returns a boolean indicating if the provided address is an approved entity
   * @param entity An address of a potential entity
   * @return `true` if the address is an entity
   */
  function isEntity(address entity) external view returns (bool);

  /**
   * @notice Returns the list of approved entities
   * @dev The order of this list will change as entities are removed
   * @return the list of approved entities
   */
  function getEntityList() external view returns (address[] memory);
}
