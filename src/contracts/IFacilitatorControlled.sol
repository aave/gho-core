// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title IFacilitatorControlled
 * @notice Defines the interface of a contract controlled by facilitators.
 * @author Aave
 */
interface IFacilitatorControlled {
  /**
   * @dev Event emitted when a new entity is added as Minter
   * @param entityId The identifier of the entity
   * @param minter The address of the minter
   */
  event MinterAdded(uint256 indexed entityId, address indexed minter);

  /**
   * @dev Event emitted when a new entity is added as Burner
   * @param entityId The identifier of the entity
   * @param burner The address of the minter
   */
  event BurnerAdded(uint256 indexed entityId, address indexed burner);

  /**
   * @dev Event emitted when a Minter is removed
   * @param entityId The identifier of the entity
   * @param minter The address of the minter
   */
  event MinterRemoved(uint256 indexed entityId, address indexed minter);

  /**
   * @dev Event emitted when a Burner is removed
   * @param entityId The identifier of the entity
   * @param burner The address of the minter
   */
  event BurnerRemoved(uint256 indexed entityId, address indexed burner);

  /**
   * @dev Event emitted when a new Entity is created
   * @param id The identifier of the entity
   * @param label A human readable identifier for the entity
   * @param entityAddress The address of the entity
   * @param mintLimit The amount of GHO the entity is entitled to mint
   */
  event EntityCreated(uint256 indexed id, string label, address entityAddress, uint256 mintLimit);

  /**
   * @dev Event emitted when an entity is activated or deactivated
   * @param entityId The identifier of the entity
   * @param active True if the entity is activated, false otherwise
   */
  event EntityActivated(uint256 indexed entityId, bool active);

  /**
   * @dev Event emitted when the mint limit of an entity is updated
   * @param entityId The identifier of the entity
   * @param oldMintLimit The previous mint limit of the entity
   * @param newMintLimit The new mint limit of the entity
   */
  event EntityMintLimitUpdated(
    uint256 indexed entityId,
    uint256 oldMintLimit,
    uint256 newMintLimit
  );

  struct InternalEntity {
    uint256 id;
    string label;
    address entityAddress;
    uint256 mintLimit;
    uint256 mintBalance;
    address[] minters;
    address[] burners;
    bool active;
    mapping(address => uint256) mintersIndexes;
    mapping(address => uint256) burnersIndexes;
  }

  struct InputEntity {
    string label;
    address entityAddress;
    uint256 mintLimit;
    address[] minters;
    address[] burners;
    bool active;
  }

  struct Entity {
    string label;
    address entityAddress;
    uint256 mintLimit;
    uint256 mintBalance;
    address[] minters;
    address[] burners;
    bool active;
  }
}
