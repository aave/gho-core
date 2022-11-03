// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

import {IGhoToken} from './interfaces/IGhoToken.sol';
import {ERC20} from '@rari-capital/solmate/src/tokens/ERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title GHO Token
 * @author Aave
 * @notice This contract defines the basic implementation of the GHO Token.
 */
contract GhoToken is IGhoToken, ERC20, Ownable {
  using EnumerableSet for EnumerableSet.AddressSet;
  mapping(address => Facilitator) internal _facilitators;
  EnumerableSet.AddressSet internal _facilitatorsList;

  constructor(address[] memory facilitatorsAddresses, Facilitator[] memory facilitatorsConfig)
    ERC20('Gho Token', 'GHO', 18)
  {
    _addFacilitators(facilitatorsAddresses, facilitatorsConfig);
  }

  /**
   * @notice Mints the requested amount of tokens to the account address. Only facilitators with enough bucket capacity available can mint.
   * @dev The bucket level is increased upon minting.
   * @param account The address receiving the GHO tokens
   * @param amount The amount to mint
   */
  function mint(address account, uint256 amount) external override {
    uint256 maxBucketCapacity = _facilitators[msg.sender].bucket.maxCapacity;
    require(maxBucketCapacity > 0, 'INVALID_FACILITATOR');

    uint256 currentBucketLevel = _facilitators[msg.sender].bucket.level;
    uint256 newBucketLevel = currentBucketLevel + amount;
    require(maxBucketCapacity >= newBucketLevel, 'FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
    _facilitators[msg.sender].bucket.level = uint128(newBucketLevel);

    emit BucketLevelChanged(msg.sender, currentBucketLevel, newBucketLevel);
    _mint(account, amount);
  }

  /**
   * @notice Burns the requested amount of tokens from the account address. Only active facilitators (capacity > 0) can burn.
   * @dev The bucket level is decreased upon burning.
   * @param amount The amount to burn
   */
  function burn(uint256 amount) external override {
    uint256 currentBucketLevel = _facilitators[msg.sender].bucket.level;
    uint256 newBucketLevel = currentBucketLevel - amount;
    _facilitators[msg.sender].bucket.level = uint128(newBucketLevel);
    emit BucketLevelChanged(msg.sender, currentBucketLevel, newBucketLevel);
    _burn(msg.sender, amount);
  }

  ///@inheritdoc IGhoToken
  function addFacilitators(
    address[] memory facilitatorsAddresses,
    Facilitator[] memory facilitatorsConfig
  ) external onlyOwner {
    _addFacilitators(facilitatorsAddresses, facilitatorsConfig);
  }

  ///@inheritdoc IGhoToken
  function removeFacilitators(address[] calldata facilitators) external onlyOwner {
    unchecked {
      for (uint256 i = 0; i < facilitators.length; ++i) {
        _removeFacilitator(facilitators[i]);
      }
    }
  }

  ///@inheritdoc IGhoToken
  function setFacilitatorBucketCapacity(address facilitator, uint128 newCapacity)
    external
    onlyOwner
  {
    require(bytes(_facilitators[facilitator].label).length > 0, 'FACILITATOR_DOES_NOT_EXIST');

    uint256 oldCapacity = _facilitators[facilitator].bucket.maxCapacity;
    _facilitators[facilitator].bucket.maxCapacity = newCapacity;

    emit FacilitatorBucketCapacityUpdated(facilitator, oldCapacity, newCapacity);
  }

  ///@inheritdoc IGhoToken
  function getFacilitator(address facilitator) external view returns (Facilitator memory) {
    return _facilitators[facilitator];
  }

  ///@inheritdoc IGhoToken
  function getFacilitatorBucket(address facilitator) external view returns (Bucket memory) {
    return _facilitators[facilitator].bucket;
  }

  ///@inheritdoc IGhoToken
  function getFacilitatorsList() external view returns (address[] memory) {
    return _facilitatorsList.values();
  }

  function _addFacilitators(
    address[] memory facilitatorsAddresses,
    Facilitator[] memory facilitatorsConfig
  ) internal {
    require(facilitatorsAddresses.length == facilitatorsConfig.length, 'INVALID_INPUT');
    unchecked {
      for (uint256 i = 0; i < facilitatorsConfig.length; ++i) {
        _addFacilitator(facilitatorsAddresses[i], facilitatorsConfig[i]);
      }
    }
  }

  function _addFacilitator(address facilitatorAddress, Facilitator memory facilitatorConfig)
    internal
  {
    Facilitator storage facilitator = _facilitators[facilitatorAddress];
    require(bytes(facilitator.label).length == 0, 'FACILITATOR_ALREADY_EXISTS');
    require(bytes(facilitatorConfig.label).length > 0, 'INVALID_LABEL');
    require(facilitatorConfig.bucket.level == 0, 'INVALID_BUCKET_CONFIGURATION');

    facilitator.label = facilitatorConfig.label;
    facilitator.bucket = facilitatorConfig.bucket;

    _facilitatorsList.add(facilitatorAddress);

    emit FacilitatorAdded(
      facilitatorAddress,
      facilitatorConfig.label,
      facilitatorConfig.bucket.maxCapacity
    );
  }

  function _removeFacilitator(address facilitatorAddress) internal {
    require(
      _facilitators[facilitatorAddress].bucket.level == 0,
      'FACILITATOR_BUCKET_LEVEL_NOT_ZERO'
    );

    delete _facilitators[facilitatorAddress];
    _facilitatorsList.remove(facilitatorAddress);

    emit FacilitatorRemoved(facilitatorAddress);
  }
}
