// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IMintableERC20} from './interfaces/IMintableERC20.sol';
import {IBurnableERC20} from './interfaces/IBurnableERC20.sol';
import {ERC20} from '@rari-capital/solmate/src/tokens/ERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

contract AnteiStableDollarEntities is IMintableERC20, IBurnableERC20, ERC20, Ownable {
  event MinterAdded(uint256 indexed entityId, address indexed minter, uint256 indexed mintDistribution);
  event BurnerAdded(uint256 indexed entityId, address indexed burner);

  event MinterRemoved(uint256 indexed entityId, address indexed minter);
  event BurnerRemoved(uint256 indexed entityId, address indexed burner);

  event EntityCreated(uint256 indexed id, string label, address entityAddress, uint256 mintLimit);

  event EntityActivated(uint256 indexed entityId, bool active);

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
    uint256[] mintDistribution;
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

  mapping(uint256 => InternalEntity) internal _entities;

  mapping(address => uint256) internal _minterToEntity;
  mapping(address => uint256) internal _burnerToEntity;

  uint256 internal _entityCount;

  constructor(InputEntity[] memory inputEntities) ERC20('Antei Stable Dollar', 'ASD', 18) {
    _addEntities(inputEntities);
  }

  function addEntities(InputEntity[] memory inputEntities) external onlyOwner {
    _addEntities(inputEntities);
  }

  function mint(address account, uint256 amount) external override {
    uint256 entityId = _minterToEntity[msg.sender];
    require(entityId != 0, 'MINTER_NOT_ASSIGNED_TO_AN_ENTITY');
    require(_entities[entityId].active, 'ENTITY_IS_NOT_ACTIVE');

    uint256 newMintBalance = _entities[entityId].mintBalance + amount;
    require(_entities[entityId].mintLimit > newMintBalance, 'ENTITY_MINT_LIMIT_EXCEEDED');

    _entities[entityId].mintBalance = newMintBalance;
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external override {
    uint256 entityId = _burnerToEntity[msg.sender];

    require(entityId != 0, 'BURNER_NOT_ASSIGNED_TO_AN_ENTITY');
    require(_entities[entityId].active, 'ENTITY_IS_NOT_ACTIVE');

    _entities[entityId].mintBalance -= amount;
    _burn(account, amount);
  }

  function activateEntity(uint256 entityId) external onlyOwner {
    require(!_entities[entityId].active, 'ENTITY_ALREADY_ACTIVED');
    _entities[entityId].active = true;
    emit EntityActivated(entityId, true);
  }

  function deactivateEntity(uint256 entityId) external onlyOwner {
    require(_entities[entityId].active, 'ENTITY_ALREADY_DEACTIVATED');
    _entities[entityId].active = false;
    emit EntityActivated(entityId, false);
  }

  function addMinter(uint256 entityId, address minter, uint256 mintDistribution) external onlyOwner {
    require(_entities[entityId].id != 0, 'ENTITY_DOES_NOT_EXIST');
    require(_minterToEntity[minter] == 0, 'MINTER_ALREADY_ADDED');

    uint256 newMintBalance = _entities[entityId].mintBalance + mintDistribution;
    require(_entities[entityId].mintLimit > newMintBalance, 'ENTITY_MINT_LIMIT_EXCEEDED');

    uint256 minterIndex = _entities[entityId].minters.length;
    _entities[entityId].minters.push(minter);
    _entities[entityId].mintersIndexes[minter] = minterIndex;
    _minterToEntity[minter] = entityId;

    if(mintDistribution > 0){
      _entities[entityId].mintBalance = newMintBalance;
      _mint(minter, mintDistribution);
    }

    emit MinterAdded(entityId, minter, mintDistribution);
  }

  function addBurner(uint256 entityId, address burner) external onlyOwner {
    require(_entities[entityId].id != 0, 'ENTITY_DOES_NOT_EXIST');
    require(_burnerToEntity[burner] == 0, 'BURNER_ALREADY_ADDED');

    uint256 burnerIndex = _entities[entityId].burners.length;

    _entities[entityId].burners.push(burner);
    _entities[entityId].burnersIndexes[burner] = burnerIndex;
    _burnerToEntity[burner] = entityId;

    emit BurnerAdded(entityId, burner);
  }

  function removeMinter(uint256 entityId, address minter) external onlyOwner {
    require(_minterToEntity[minter] == entityId, 'MINTER_NOT_REGISTERED_TO_PROVIDED_ENTITY');

    _removeFromList(_entities[entityId].minters, _entities[entityId].mintersIndexes, minter);
    _minterToEntity[minter] = 0;

    emit MinterRemoved(entityId, minter);
  }

  function removeBurner(uint256 entityId, address burner) external onlyOwner {
    require(_burnerToEntity[burner] == entityId, 'BURNER_NOT_REGISTERED_TO_PROVIDED_ENTITY');

    _removeFromList(_entities[entityId].burners, _entities[entityId].burnersIndexes, burner);
    _burnerToEntity[burner] = 0;

    emit BurnerRemoved(entityId, burner);
  }

  // isMinter()
  // isBurner()

  // // to set mint limit to 0, remove minter
  // if mint limit is zero, what about repay?
  function setEntityMintLimit(uint256 entityId, uint256 newMintLimit) external onlyOwner {
    require(_entities[entityId].id != 0, 'ENTITY_DOES_NOT_EXIST');

    uint256 oldMintLimit = _entities[entityId].mintLimit;
    _entities[entityId].mintLimit = newMintLimit;

    emit EntityMintLimitUpdated(entityId, oldMintLimit, newMintLimit);
  }

  function getEntityById(uint256 entityId) external view returns (Entity memory) {
    Entity memory entity =
      Entity({
        label: _entities[entityId].label,
        entityAddress: _entities[entityId].entityAddress,
        mintLimit: _entities[entityId].mintLimit,
        mintBalance: _entities[entityId].mintBalance,
        minters: _entities[entityId].minters,
        burners: _entities[entityId].burners,
        active: _entities[entityId].active
      });
    return entity;
  }

  function getEntityMinters(uint256 entityId) external view returns (address[] memory) {
    return _entities[entityId].minters;
  }

  function getEntityBurners(uint256 entityId) external view returns (address[] memory) {
    return _entities[entityId].burners;
  }

  function getEntityMintLimit(uint256 entityId) external view returns (uint256) {
    return _entities[entityId].mintLimit;
  }

  function getEntityBalance(uint256 entityId) external view returns (uint256) {
    return _entities[entityId].mintBalance;
  }

  function getEntityCount() external view returns (uint256) {
    return _entityCount;
  }

  function isActive(uint256 entityId) public view returns (bool) {
    return _entities[entityId].active;
  }

  // if 0 - there is no entity;
  function getMinterEntity(address minter) external view returns (uint256) {
    return _minterToEntity[minter];
  }

  // if 0 - there is no entity;
  function getBurnerEntity(address burner) external view returns (uint256) {
    return _burnerToEntity[burner];
  }

  function _addEntities(InputEntity[] memory inputEntities) internal {
    for (uint256 i = 0; i < inputEntities.length; i++) {
      _addEntity(inputEntities[i]);
    }
  }

  // maybe add label hashes
  function _addEntity(InputEntity memory inputEntity) internal {
    require(inputEntity.minters.length == inputEntity.mintDistribution.length, "MINTERS_AND_MINT_DISTRIBUTION_MUST_BE_EQUAL");
    uint256 cachedEntityCount = ++_entityCount;

    InternalEntity storage newEntity = _entities[cachedEntityCount];

    newEntity.id = cachedEntityCount;
    newEntity.label = inputEntity.label;
    newEntity.entityAddress = inputEntity.entityAddress;
    newEntity.mintLimit = inputEntity.mintLimit;
    newEntity.minters = inputEntity.minters;
    newEntity.burners = inputEntity.burners;
    newEntity.active = inputEntity.active;

    // potentially use internal addMinter;
    uint256 amountDistributed;
    for (uint256 i = 0; i < inputEntity.minters.length; i++) {
      amountDistributed += inputEntity.mintDistribution[i];
      require(amountDistributed <= inputEntity.mintLimit, "CANNOT_DISTRIBUTE_MORE_THAN_MINT_LIMIT");
      if(inputEntity.mintDistribution[i] > 0){
        _mint(inputEntity.minters[i], inputEntity.mintDistribution[i]);
      }
      
      newEntity.mintersIndexes[inputEntity.minters[i]] = i;
      _minterToEntity[inputEntity.minters[i]] = cachedEntityCount;
      emit MinterAdded(cachedEntityCount, inputEntity.minters[i], inputEntity.mintDistribution[i]);
    }
    newEntity.mintBalance += amountDistributed;

    for (uint256 i = 0; i < inputEntity.burners.length; i++) {
      newEntity.burnersIndexes[inputEntity.burners[i]] = i;
      _burnerToEntity[inputEntity.burners[i]] = cachedEntityCount;
      emit BurnerAdded(cachedEntityCount, inputEntity.burners[i]);
    }
    emit EntityCreated(
      cachedEntityCount,
      inputEntity.label,
      inputEntity.entityAddress,
      inputEntity.mintLimit
    );
    emit EntityActivated(cachedEntityCount, inputEntity.active);
    emit EntityMintLimitUpdated(cachedEntityCount, 0, inputEntity.mintLimit);
  }

  function _removeFromList(
    address[] storage list,
    mapping(address => uint256) storage listIndexes,
    address listItem
  ) internal {
    uint256 listItemIndex = listIndexes[listItem];
    listIndexes[listItem] = 0;

    // Swap the index of the last addresses provider in the list with the index of the provider to remove
    uint256 lastIndex = list.length - 1;
    if (listItemIndex < lastIndex) {
      address lastAddress = list[lastIndex];
      list[listItemIndex] = lastAddress;
      listIndexes[lastAddress] = listItemIndex;
    }
    list.pop();
  }
}
