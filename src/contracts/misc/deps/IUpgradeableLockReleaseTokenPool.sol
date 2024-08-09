// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RateLimiter} from './RateLimiter.sol';

/// @dev Reduced interface of CCIP UpgradeableLockReleaseTokenPool contract with needed functions only
/// @dev Adapted from https://github.com/aave/ccip/blob/ccip-gho/contracts/src/v0.8/ccip/pools/GHO/UpgradeableLockReleaseTokenPool.sol
interface IUpgradeableLockReleaseTokenPool {
  function setBridgeLimit(uint256 newBridgeLimit) external;

  function getBridgeLimit() external view returns (uint256);

  function getCurrentOutboundRateLimiterState(
    uint64 remoteChainSelector
  ) external view returns (RateLimiter.TokenBucket memory);

  function getCurrentInboundRateLimiterState(
    uint64 remoteChainSelector
  ) external view returns (RateLimiter.TokenBucket memory);

  function setChainRateLimiterConfig(
    uint64 remoteChainSelector,
    RateLimiter.Config memory outboundConfig,
    RateLimiter.Config memory inboundConfig
  ) external;
}
