// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IGhoToken} from './interfaces/IGhoToken.sol';
import {ERC20} from '@rari-capital/solmate/src/tokens/ERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {DataTypes} from './DataTypes/DataTypes.sol';

/**
 * @title GHO Token
 * @author Aave
 * @notice This contract defines the basic implementation of the GHO Token.
 */
contract GhoToken is IGhoToken, ERC20, Ownable {
  mapping(address => DataTypes.Facilitator) internal _facilitators;
  address[] internal _facilitatorsList;
  uint256 internal _facilitatorsCount;

  constructor(
    address[] memory facilitatorsAddresses,
    DataTypes.Facilitator[] memory facilitatorsConfig
  ) ERC20('Gho Token', 'GHO', 18) {
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
    require(newBucketLevel < type(uint128).max, 'BUCKET_LEVEL_OVERFLOW');
    require(maxBucketCapacity >= newBucketLevel, 'FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
    _facilitators[msg.sender].bucket.level = uint128(newBucketLevel);
    emit BucketLevelChanged(msg.sender, currentBucketLevel, newBucketLevel);
    _mint(account, amount);
  }

  /**
   * @notice Burns the requested amount of tokens from the account address. Only active facilitators (capacity > 0) can burn.
   * @dev The bucket level is decresed upon burning.
   * @param account The address from which the GHO tokens are burned
   * @param amount The amount to burn
   */
  function burn(address account, uint256 amount) external override {
    uint256 maxBucketCapacity = _facilitators[msg.sender].bucket.maxCapacity;
    require(maxBucketCapacity > 0, 'INVALID_FACILITATOR');

    uint256 currentBucketLevel = _facilitators[msg.sender].bucket.level;
    uint256 newBucketLevel = currentBucketLevel - amount;
    _facilitators[msg.sender].bucket.level = uint128(newBucketLevel);
    emit BucketLevelChanged(msg.sender, currentBucketLevel, newBucketLevel);
    _burn(account, amount);
  }

  ///@inheritdoc IGhoToken
  function addFacilitators(
    address[] memory facilitatorsAddresses,
    DataTypes.Facilitator[] memory facilitatorsConfig
  ) external onlyOwner {
    _addFacilitators(facilitatorsAddresses, facilitatorsConfig);
  }

  ///@inheritdoc IGhoToken
  function removeFacilitators(address[] calldata facilitators) external onlyOwner {
    unchecked {
      for (uint256 i = 0; i < facilitators.length; i++) {
        _removeFacilitator(facilitators[i]);
        for (uint256 j = 0; j < _facilitatorsList.length; j++) {
          if (_facilitatorsList[j] == facilitators[i]) {
            _facilitatorsList[j] == address(0);
          }
        }
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
  function getFacilitator(address facilitator)
    external
    view
    returns (DataTypes.Facilitator memory)
  {
    return _facilitators[facilitator];
  }

  ///@inheritdoc IGhoToken
  function getFacilitatorBucket(address facilitator)
    external
    view
    returns (DataTypes.Bucket memory)
  {
    return _facilitators[facilitator].bucket;
  }

  ///@inheritdoc IGhoToken
  function getFacilitatorsList() external view returns (address[] memory) {
    return _facilitatorsList;
  }

  function _addFacilitators(
    address[] memory facilitatorsAddresses,
    DataTypes.Facilitator[] memory facilitatorsConfig
  ) internal {
    require(facilitatorsAddresses.length == facilitatorsConfig.length, 'INVALID_INPUT');

    for (uint256 i = 0; i < facilitatorsConfig.length; i++) {
      _addFacilitator(facilitatorsAddresses[i], facilitatorsConfig[i]);
    }
  }

  function _addFacilitator(
    address facilitatorAddress,
    DataTypes.Facilitator memory facilitatorConfig
  ) internal {
    DataTypes.Facilitator storage facilitator = _facilitators[facilitatorAddress];
    require(bytes(facilitatorConfig.label).length > 0, 'INVALID_LABEL');
    require(facilitatorConfig.bucket.level == 0, 'INVALID_BUCKET_CONFIGURATION');

    facilitator.label = facilitatorConfig.label;
    facilitator.bucket = facilitatorConfig.bucket;

    _facilitatorsList[_facilitatorsCount++] = facilitatorAddress;

    emit FacilitatorAdded(
      facilitatorAddress,
      facilitatorConfig.label,
      facilitatorConfig.bucket.maxCapacity
    );
  }

  function _removeFacilitator(address facilitatorAddress) internal {
    DataTypes.Facilitator storage facilitator = _facilitators[facilitatorAddress];
    require(facilitator.bucket.level == 0, 'FACILITATOR_BUCKET_LEVEL_NOT_ZERO');

    facilitator.bucket.maxCapacity = 0;
    delete facilitator.label;

    emit FacilitatorRemoved(facilitatorAddress);
  }
}
