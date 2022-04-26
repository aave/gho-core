// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IAnteiStableDollar} from './interfaces/IAnteiStableDollar.sol';
import {ERC20} from '@rari-capital/solmate/src/tokens/ERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

contract AnteiStableDollarEntities is IAnteiStableDollar, ERC20, Ownable {
  mapping(address => bool) internal _entities;

  address[] internal _entityList;
  mapping(address => uint256) internal _entityIndexes;

  /**
   * @dev Throws if called by an account that is not an entity
   */
  modifier onlyEntity() {
    require(_entities[msg.sender], 'CALLER_IS_NOT_AN_ENTITY');
    _;
  }

  constructor(
    address[] memory entities,
    uint256[] memory amounts,
    string memory inputName,
    string memory inputSymbol,
    uint8 inputDecimals
  ) ERC20(inputName, inputSymbol, inputDecimals) {
    _addEntities(entities, amounts);
  }

  function addEntities(address[] memory entities, uint256[] memory amounts)
    external
    override
    onlyOwner
  {
    _addEntities(entities, amounts);
  }

  function removeEntities(address[] memory entities) external override onlyOwner {
    for (uint256 i = 0; i < entities.length; i++) {
      _removeEntity(entities[i]);
    }
  }

  function mint(address entity, uint256 amount) external override onlyOwner {
    require(_entities[entity], 'ENTITY_DOES_NOT_EXIST');
    _mint(entity, amount);
  }

  function burn(uint256 amount) external override onlyEntity {
    _burn(msg.sender, amount);
  }

  function isEntity(address entity) external view override returns (bool) {
    return _entities[entity];
  }

  function getEntityList() external view override returns (address[] memory) {
    return _entityList;
  }

  function _addEntities(address[] memory entities, uint256[] memory amounts) internal {
    require(entities.length == amounts.length, 'INPUT_ENTITIES_AND_AMOUNTS_MUST_BE_SAME_LENGTH');
    for (uint256 i = 0; i < entities.length; i++) {
      _addEntity(entities[i], amounts[i]);
    }
  }

  function _addEntity(address entity, uint256 amount) internal {
    require(!_entities[entity], 'ENTITY_ALREADY_ADDED');
    _entities[entity] = true;

    _addToEntityList(entity);
    if (amount > 0) {
      _mint(entity, amount);
    }

    emit EntityAdded(entity);
  }

  function _removeEntity(address entity) internal {
    require(_entities[entity], 'ENTITY_DOES_NOT_EXIST');
    _entities[entity] = false;

    _removeFromEntityList(entity);

    emit EntityRemoved(entity);
  }

  /**
   * @notice Adds the addresses provider address to the list.
   * @param entity The address of the PoolAddressesProvider
   */
  function _addToEntityList(address entity) internal {
    _entityIndexes[entity] = _entityList.length;
    _entityList.push(entity);
  }

  /**
   * @notice Removes the entity from the entityList.
   * @param entity The entity to remove
   */
  function _removeFromEntityList(address entity) internal {
    uint256 index = _entityIndexes[entity];

    _entityIndexes[entity] = 0;

    // Swap the index of the last entity in the list with the index of the entity to remove
    uint256 lastIndex = _entityList.length - 1;
    if (index < lastIndex) {
      address lastEntity = _entityList[lastIndex];
      _entityList[index] = lastEntity;
      _entityIndexes[lastEntity] = index;
    }
    _entityList.pop();
  }
}
