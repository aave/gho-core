// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IGhoToken} from '../gho/interfaces/IGhoToken.sol';
import {IGhoCcipSteward} from './interfaces/IGhoCcipSteward.sol';
import {RiskCouncilControlled} from './RiskCouncilControlled.sol';
import {UpgradeableLockReleaseTokenPool, RateLimiter} from './deps/Dependencies.sol';

/**
 * @title GhoCcipSteward
 * @author Aave Labs
 * @notice Helper contract for managing parameters of the GSM
 * @dev Only the Risk Council is able to action contract's functions, based on specific conditions that have been agreed upon with the community.
 */
contract GhoCcipSteward is Ownable, IGhoCcipSteward, RiskCouncilControlled {

  /// @inheritdoc IGhoCcipSteward
  uint256 public constant MINIMUM_DELAY = 2 days;

  /// @inheritdoc IGhoCcipSteward
  address public immutable GHO_TOKEN;

  /// @inheritdoc IGhoCcipSteward
  address public immutable GHO_TOKEN_POOL;

  /// @inheritdoc IGhoCcipSteward
  address public immutable RISK_COUNCIL;

  mapping(address => uint40) _facilitatorsBucketCapacityTimelocks;

  mapping(address => bool) internal _controlledFacilitatorsByAddress;

  /**
   * @dev Only methods that are not timelocked can be called if marked by this modifier.
   */
  modifier notTimelocked(uint40 timelock) {
    require(block.timestamp - timelock > MINIMUM_DELAY, 'DEBOUNCE_NOT_RESPECTED');
    _;
  }

  /**
   * @dev Constructor
   * @param owner The address of the owner of the contract
    * @param ghoTokenPool The address of the Gho CCIP Token Pool
   * @param riskCouncil The address of the risk council
   */
  constructor(
    address owner,
    address ghoToken,
    address ghoTokenPool,
    address riskCouncil
  ) RiskCouncilControlled(riskCouncil) {
    require(owner != address(0), 'INVALID_OWNER');
    require(ghoToken != address(0), 'INVALID_GHO_TOKEN');
    require(ghoTokenPool != address(0), 'INVALID_GHO_TOKEN_POOL');
    
    RISK_COUNCIL = riskCouncil;
    GHO_TOKEN = ghoToken;
    GHO_TOKEN_POOL = ghoTokenPool;

    _transferOwnership(owner);
  }

  /// @inheritdoc IGhoCcipSteward
  function updateFacilitatorBucketCapacity(address facilitator, uint128 newBucketCapacity) external onlyRiskCouncil notTimelocked(_facilitatorsBucketCapacityTimelocks[facilitator]) {
    require(_controlledFacilitatorsByAddress[facilitator], 'FACILITATOR_NOT_CONTROLLED');
    (uint256 currentBucketCapacity, ) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(facilitator);
    require(
      _isIncreaseLowerThanMax(currentBucketCapacity, newBucketCapacity, currentBucketCapacity),
      'INVALID_BUCKET_CAPACITY_UPDATE'
    );

    _facilitatorsBucketCapacityTimelocks[facilitator] = uint40(block.timestamp);

    IGhoToken(GHO_TOKEN).setFacilitatorBucketCapacity(facilitator, newBucketCapacity);
  }

  /// @inheritdoc IGhoCcipSteward
  function updateBridgeLimit(uint256 newBridgeLimit) external onlyRiskCouncil {
    UpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).setBridgeLimit(newBridgeLimit);
  }

  /// @inheritdoc IGhoCcipSteward
  function updateRateLimit(
    uint64 remoteChainSelector,
    bool outboundEnabled,
    uint128 outboundCapacity, 
    uint128 outboundRate,
    bool inboundEnabled,
    uint128 inboundCapacity,
    uint128 inboundRate
  ) external onlyRiskCouncil {
    UpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).setChainRateLimiterConfig(
      remoteChainSelector,
      RateLimiter.Config({
        isEnabled: outboundEnabled,
        capacity: outboundCapacity,
        rate: outboundRate
      }),
      RateLimiter.Config({
        isEnabled: inboundEnabled,
        capacity: inboundCapacity,
        rate: inboundRate
      })
    );
  }

  /// @inheritdoc IGhoCcipSteward
  function getFacilitatorBucketCapacityTimelock(address facilitator) external view returns (uint40) {
    return _facilitatorsBucketCapacityTimelocks[facilitator];
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