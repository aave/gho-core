// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {UpgradeableERC20} from './UpgradeableERC20.sol';
import {IGhoToken} from './interfaces/IGhoToken.sol';

/**
 * @title Upgradeable GHO Token
 * @author Aave Labs
 */
contract UpgradeableGhoToken is Initializable, UpgradeableERC20, AccessControl, IGhoToken {
  using EnumerableSet for EnumerableSet.AddressSet;

  mapping(address => Facilitator) internal _facilitators;
  EnumerableSet.AddressSet internal _facilitatorsList;

  /// @inheritdoc IGhoToken
  bytes32 public constant FACILITATOR_MANAGER_ROLE = keccak256('FACILITATOR_MANAGER_ROLE');

  /// @inheritdoc IGhoToken
  bytes32 public constant BUCKET_MANAGER_ROLE = keccak256('BUCKET_MANAGER_ROLE');

  /**
   * @dev Constructor
   */
  constructor() UpgradeableERC20(18) {
    // Intentionally left bank
  }

  /**
   * @dev Initializer
   * @param admin This is the initial holder of the default admin role
   */
  function initialize(address admin) public virtual initializer {
    _ERC20_init('Gho Token', 'GHO');

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IGhoToken
  function mint(address account, uint256 amount) external {
    require(amount > 0, 'INVALID_MINT_AMOUNT');
    Facilitator storage f = _facilitators[msg.sender];

    uint256 currentBucketLevel = f.bucketLevel;
    uint256 newBucketLevel = currentBucketLevel + amount;
    require(f.bucketCapacity >= newBucketLevel, 'FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
    f.bucketLevel = uint128(newBucketLevel);

    _mint(account, amount);

    emit FacilitatorBucketLevelUpdated(msg.sender, currentBucketLevel, newBucketLevel);
  }

  /// @inheritdoc IGhoToken
  function burn(uint256 amount) external {
    require(amount > 0, 'INVALID_BURN_AMOUNT');

    Facilitator storage f = _facilitators[msg.sender];
    uint256 currentBucketLevel = f.bucketLevel;
    uint256 newBucketLevel = currentBucketLevel - amount;
    f.bucketLevel = uint128(newBucketLevel);

    _burn(msg.sender, amount);

    emit FacilitatorBucketLevelUpdated(msg.sender, currentBucketLevel, newBucketLevel);
  }

  /// @inheritdoc IGhoToken
  function addFacilitator(
    address facilitatorAddress,
    string calldata facilitatorLabel,
    uint128 bucketCapacity
  ) external onlyRole(FACILITATOR_MANAGER_ROLE) {
    Facilitator storage facilitator = _facilitators[facilitatorAddress];
    require(bytes(facilitator.label).length == 0, 'FACILITATOR_ALREADY_EXISTS');
    require(bytes(facilitatorLabel).length > 0, 'INVALID_LABEL');

    facilitator.label = facilitatorLabel;
    facilitator.bucketCapacity = bucketCapacity;

    _facilitatorsList.add(facilitatorAddress);

    emit FacilitatorAdded(
      facilitatorAddress,
      keccak256(abi.encodePacked(facilitatorLabel)),
      bucketCapacity
    );
  }

  /// @inheritdoc IGhoToken
  function removeFacilitator(
    address facilitatorAddress
  ) external onlyRole(FACILITATOR_MANAGER_ROLE) {
    require(
      bytes(_facilitators[facilitatorAddress].label).length > 0,
      'FACILITATOR_DOES_NOT_EXIST'
    );
    require(
      _facilitators[facilitatorAddress].bucketLevel == 0,
      'FACILITATOR_BUCKET_LEVEL_NOT_ZERO'
    );

    delete _facilitators[facilitatorAddress];
    _facilitatorsList.remove(facilitatorAddress);

    emit FacilitatorRemoved(facilitatorAddress);
  }

  /// @inheritdoc IGhoToken
  function setFacilitatorBucketCapacity(
    address facilitator,
    uint128 newCapacity
  ) external onlyRole(BUCKET_MANAGER_ROLE) {
    require(bytes(_facilitators[facilitator].label).length > 0, 'FACILITATOR_DOES_NOT_EXIST');

    uint256 oldCapacity = _facilitators[facilitator].bucketCapacity;
    _facilitators[facilitator].bucketCapacity = newCapacity;

    emit FacilitatorBucketCapacityUpdated(facilitator, oldCapacity, newCapacity);
  }

  /// @inheritdoc IGhoToken
  function getFacilitator(address facilitator) external view returns (Facilitator memory) {
    return _facilitators[facilitator];
  }

  /// @inheritdoc IGhoToken
  function getFacilitatorBucket(address facilitator) external view returns (uint256, uint256) {
    return (_facilitators[facilitator].bucketCapacity, _facilitators[facilitator].bucketLevel);
  }

  /// @inheritdoc IGhoToken
  function getFacilitatorsList() external view returns (address[] memory) {
    return _facilitatorsList.values();
  }
}
