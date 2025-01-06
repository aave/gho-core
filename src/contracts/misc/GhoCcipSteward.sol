// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IUpgradeableLockReleaseTokenPool, RateLimiter} from './dependencies/Ccip.sol';
import {IGhoCcipSteward} from './interfaces/IGhoCcipSteward.sol';
import {RiskCouncilControlled} from './RiskCouncilControlled.sol';

/**
 * @title GhoCcipSteward
 * @author Aave Labs
 * @notice Helper contract for managing parameters of the CCIP token pools
 * @dev Only the Risk Council is able to action contract's functions, based on specific conditions that have been agreed upon with the community.
 * @dev Requires roles RateLimitAdmin and BridgeLimitAdmin (if on Ethereum) on GhoTokenPool
 */
contract GhoCcipSteward is RiskCouncilControlled, IGhoCcipSteward {
  /// @inheritdoc IGhoCcipSteward
  uint256 public constant MINIMUM_DELAY = 1 days;

  /// @inheritdoc IGhoCcipSteward
  address public immutable GHO_TOKEN;

  /// @inheritdoc IGhoCcipSteward
  address public immutable GHO_TOKEN_POOL;

  /// @inheritdoc IGhoCcipSteward
  bool public immutable BRIDGE_LIMIT_ENABLED;

  CcipDebounce internal _ccipTimelocks;

  /**
   * @dev Only methods that are not timelocked can be called if marked by this modifier.
   */
  modifier notTimelocked(uint40 timelock) {
    require(block.timestamp - timelock > MINIMUM_DELAY, 'DEBOUNCE_NOT_RESPECTED');
    _;
  }

  /**
   * @dev Constructor
   * @param ghoToken The address of the GhoToken
   * @param ghoTokenPool The address of the Gho CCIP Token Pool
   * @param riskCouncil The address of the risk council
   * @param bridgeLimitEnabled Whether the bridge limit feature is supported in the GhoTokenPool
   */
  constructor(
    address ghoToken,
    address ghoTokenPool,
    address riskCouncil,
    bool bridgeLimitEnabled
  ) RiskCouncilControlled(riskCouncil) {
    require(ghoToken != address(0), 'INVALID_GHO_TOKEN');
    require(ghoTokenPool != address(0), 'INVALID_GHO_TOKEN_POOL');

    GHO_TOKEN = ghoToken;
    GHO_TOKEN_POOL = ghoTokenPool;
    BRIDGE_LIMIT_ENABLED = bridgeLimitEnabled;
  }

  /// @inheritdoc IGhoCcipSteward
  function updateBridgeLimit(
    uint256 newBridgeLimit
  ) external onlyRiskCouncil notTimelocked(_ccipTimelocks.bridgeLimitLastUpdate) {
    require(BRIDGE_LIMIT_ENABLED, 'BRIDGE_LIMIT_DISABLED');

    uint256 currentBridgeLimit = IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).getBridgeLimit();
    require(newBridgeLimit != currentBridgeLimit, 'NO_CHANGE_IN_BRIDGE_LIMIT');
    require(
      _isDifferenceLowerThanMax(currentBridgeLimit, newBridgeLimit, currentBridgeLimit),
      'INVALID_BRIDGE_LIMIT_UPDATE'
    );

    _ccipTimelocks.bridgeLimitLastUpdate = uint40(block.timestamp);

    IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).setBridgeLimit(newBridgeLimit);
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
  ) external onlyRiskCouncil notTimelocked(_ccipTimelocks.rateLimitLastUpdate) {
    RateLimiter.TokenBucket memory outboundConfig = IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
      .getCurrentOutboundRateLimiterState(remoteChainSelector);
    RateLimiter.TokenBucket memory inboundConfig = IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
      .getCurrentInboundRateLimiterState(remoteChainSelector);

    require(
      outboundEnabled != outboundConfig.isEnabled ||
        outboundCapacity != outboundConfig.capacity ||
        outboundRate != outboundConfig.rate ||
        inboundEnabled != inboundConfig.isEnabled ||
        inboundCapacity != inboundConfig.capacity ||
        inboundRate != inboundConfig.rate,
      'NO_CHANGE_IN_RATE_LIMIT'
    );

    require(
      _isDifferenceLowerThanMax(outboundConfig.capacity, outboundCapacity, outboundConfig.capacity),
      'INVALID_RATE_LIMIT_UPDATE'
    );
    require(
      _isDifferenceLowerThanMax(outboundConfig.rate, outboundRate, outboundConfig.rate),
      'INVALID_RATE_LIMIT_UPDATE'
    );
    require(
      _isDifferenceLowerThanMax(inboundConfig.capacity, inboundCapacity, inboundConfig.capacity),
      'INVALID_RATE_LIMIT_UPDATE'
    );
    require(
      _isDifferenceLowerThanMax(inboundConfig.rate, inboundRate, inboundConfig.rate),
      'INVALID_RATE_LIMIT_UPDATE'
    );

    _ccipTimelocks.rateLimitLastUpdate = uint40(block.timestamp);

    IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).setChainRateLimiterConfig(
      remoteChainSelector,
      RateLimiter.Config({
        isEnabled: outboundEnabled,
        capacity: outboundCapacity,
        rate: outboundRate
      }),
      RateLimiter.Config({isEnabled: inboundEnabled, capacity: inboundCapacity, rate: inboundRate})
    );
  }

  /// @inheritdoc IGhoCcipSteward
  function getCcipTimelocks() external view override returns (CcipDebounce memory) {
    return _ccipTimelocks;
  }

  /// @inheritdoc IGhoCcipSteward
  function RISK_COUNCIL() external view override returns (address) {
    return _riskCouncil;
  }

  /**
   * @dev Ensures that the change difference is lower than max.
   * @param from current value
   * @param to new value
   * @param max maximum difference between from and to
   * @return bool true if difference between values lower than max, false otherwise
   */
  function _isDifferenceLowerThanMax(
    uint256 from,
    uint256 to,
    uint256 max
  ) internal pure returns (bool) {
    return from < to ? to - from <= max : from - to <= max;
  }
}
