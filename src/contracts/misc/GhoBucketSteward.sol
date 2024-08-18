// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IGhoToken} from '../gho/interfaces/IGhoToken.sol';
import {RiskCouncilControlled} from './RiskCouncilControlled.sol';
import {IGhoBucketSteward} from './interfaces/IGhoBucketSteward.sol';

/**
 * @title GhoBucketSteward
 * @author Aave Labs
 * @notice Helper contract for managing bucket capacities of controlled facilitators
 * @dev Only the Risk Council is able to action contract's functions, based on specific conditions that have been agreed upon with the community.
 * @dev Requires role GHO_TOKEN_BUCKET_MANAGER_ROLE on GhoToken
 */
contract GhoBucketSteward is Ownable, RiskCouncilControlled, IGhoBucketSteward {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @inheritdoc IGhoBucketSteward
  uint256 public constant MINIMUM_DELAY = 2 days;

  /// @inheritdoc IGhoBucketSteward
  address public immutable GHO_TOKEN;

  mapping(address => uint40) internal _facilitatorsBucketCapacityTimelocks;

  mapping(address => bool) internal _controlledFacilitatorsByAddress;
  EnumerableSet.AddressSet internal _controlledFacilitators;

  /**
   * @dev Only methods that are not timelocked can be called if marked by this modifier.
   */
  modifier notTimelocked(uint40 timelock) {
    require(block.timestamp - timelock > MINIMUM_DELAY, 'DEBOUNCE_NOT_RESPECTED');
    _;
  }

  /**
   * @dev Constructor
   * @param owner The address of the contract's owner
   * @param ghoToken The address of the GhoToken
   * @param riskCouncil The address of the risk council
   */
  constructor(
    address owner,
    address ghoToken,
    address riskCouncil
  ) RiskCouncilControlled(riskCouncil) {
    require(owner != address(0), 'INVALID_OWNER');
    require(ghoToken != address(0), 'INVALID_GHO_TOKEN');

    GHO_TOKEN = ghoToken;

    _transferOwnership(owner);
  }

  /// @inheritdoc IGhoBucketSteward
  function updateFacilitatorBucketCapacity(
    address facilitator,
    uint128 newBucketCapacity
  ) external onlyRiskCouncil notTimelocked(_facilitatorsBucketCapacityTimelocks[facilitator]) {
    require(_controlledFacilitatorsByAddress[facilitator], 'FACILITATOR_NOT_CONTROLLED');
    (uint256 currentBucketCapacity, ) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(facilitator);
    require(newBucketCapacity != currentBucketCapacity, 'NO_CHANGE_IN_BUCKET_CAPACITY');
    require(
      _isIncreaseLowerThanMax(currentBucketCapacity, newBucketCapacity, currentBucketCapacity),
      'INVALID_BUCKET_CAPACITY_UPDATE'
    );

    _facilitatorsBucketCapacityTimelocks[facilitator] = uint40(block.timestamp);

    IGhoToken(GHO_TOKEN).setFacilitatorBucketCapacity(facilitator, newBucketCapacity);
  }

  /// @inheritdoc IGhoBucketSteward
  function setControlledFacilitator(
    address[] memory facilitatorList,
    bool approve
  ) external onlyOwner {
    for (uint256 i = 0; i < facilitatorList.length; i++) {
      _controlledFacilitatorsByAddress[facilitatorList[i]] = approve;
      if (approve) {
        _controlledFacilitators.add(facilitatorList[i]);
      } else {
        _controlledFacilitators.remove(facilitatorList[i]);
      }
    }
  }

  /// @inheritdoc IGhoBucketSteward
  function getControlledFacilitators() external view returns (address[] memory) {
    return _controlledFacilitators.values();
  }

  /// @inheritdoc IGhoBucketSteward
  function getFacilitatorBucketCapacityTimelock(
    address facilitator
  ) external view returns (uint40) {
    return _facilitatorsBucketCapacityTimelocks[facilitator];
  }

  /// @inheritdoc IGhoBucketSteward
  function RISK_COUNCIL() public view override returns (address) {
    return COUNCIL;
  }

  /**
   * @dev Ensures that the change is positive and the difference is lower than max.
   * @param from current value
   * @param to new value
   * @param max maximum difference between from and to
   * @return bool true if difference between values is positive and lower than max, false otherwise
   */
  function _isIncreaseLowerThanMax(
    uint256 from,
    uint256 to,
    uint256 max
  ) internal pure returns (bool) {
    return to >= from && to - from <= max;
  }
}
