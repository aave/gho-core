// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IGhoToken} from '../gho/interfaces/IGhoToken.sol';
import {IGhoCcipSteward} from './interfaces/IGhoCcipSteward.sol';
import {RiskCouncilControlled} from './RiskCouncilControlled.sol';
import {UpgradeableLockReleaseTokenPool, RateLimiter} from './deps/Dependencies.sol';

/**
 * @title GhoCcipSteward
 * @author Aave Labs
 * @notice Helper contract for managing parameters of the CCIP token pools
 * @dev Only the Risk Council is able to action contract's functions, based on specific conditions that have been agreed upon with the community.
 * @dev Requires roles RateLimitAdmin and BridgeLimitAdmin (if on Ethereum) on GhoTokenPool
 */
contract GhoCcipSteward is Ownable, RiskCouncilControlled, IGhoCcipSteward {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @inheritdoc IGhoCcipSteward
  uint256 public constant MINIMUM_DELAY = 2 days;

  /// @inheritdoc IGhoCcipSteward
  address public immutable GHO_TOKEN;

  /// @inheritdoc IGhoCcipSteward
  address public immutable GHO_TOKEN_POOL;

  /// @inheritdoc IGhoCcipSteward
  function RISK_COUNCIL() public view override returns (address) {
    return COUNCIL;
  }

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
   * @param ghoToken The address of the GhoToken
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

    GHO_TOKEN = ghoToken;
    GHO_TOKEN_POOL = ghoTokenPool;

    _transferOwnership(owner);
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
      RateLimiter.Config({isEnabled: inboundEnabled, capacity: inboundCapacity, rate: inboundRate})
    );
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
