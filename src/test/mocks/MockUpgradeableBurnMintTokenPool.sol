// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {RateLimiter} from 'src/contracts/misc/dependencies/Ccip.sol';
import {IRouter} from 'src/contracts/misc/dependencies/Ccip.sol';
import {IARM} from 'src/contracts/misc/dependencies/AaveV3-1.sol';

contract MockUpgradeableBurnMintTokenPool is Initializable {
  using SafeERC20 for IERC20;
  using RateLimiter for RateLimiter.TokenBucket;

  error Unauthorized(address caller);
  error ZeroAddressNotAllowed();

  event ChainConfigured(
    uint64 remoteChainSelector,
    RateLimiter.Config outboundRateLimiterConfig,
    RateLimiter.Config inboundRateLimiterConfig
  );

  struct ChainUpdate {
    uint64 remoteChainSelector;
    bool allowed;
    RateLimiter.Config outboundRateLimiterConfig;
    RateLimiter.Config inboundRateLimiterConfig;
  }

  address internal _owner;
  bool internal immutable i_acceptLiquidity;
  address internal s_rateLimitAdmin;
  uint256 private s_bridgeLimit;
  address internal s_bridgeLimitAdmin;
  IERC20 internal immutable i_token;
  address internal immutable i_armProxy;
  bool internal immutable i_allowlistEnabled;
  EnumerableSet.AddressSet internal s_allowList;
  IRouter internal s_router;
  EnumerableSet.UintSet internal s_remoteChainSelectors;
  mapping(uint64 => RateLimiter.TokenBucket) internal s_outboundRateLimits;
  mapping(uint64 => RateLimiter.TokenBucket) internal s_inboundRateLimits;

  constructor(address token, address armProxy, bool allowlistEnabled, bool acceptLiquidity) {
    i_acceptLiquidity = acceptLiquidity;
    if (address(token) == address(0)) revert ZeroAddressNotAllowed();
    i_token = IERC20(token);
    i_armProxy = armProxy;
    i_allowlistEnabled = allowlistEnabled;
  }

  function initialize(
    address owner,
    address[] memory allowlist,
    address router,
    uint256 bridgeLimit
  ) public virtual initializer {
    allowlist;
    if (owner == address(0)) revert ZeroAddressNotAllowed();
    if (router == address(0)) revert ZeroAddressNotAllowed();
    _transferOwnership(owner);

    s_router = IRouter(router);
    s_bridgeLimit = bridgeLimit;
  }

  function owner() public view returns (address) {
    return _owner;
  }

  function acceptOwnership() external {}

  function setRateLimitAdmin(address rateLimitAdmin) external {
    s_rateLimitAdmin = rateLimitAdmin;
  }

  function setBridgeLimit(uint256 newBridgeLimit) external {
    if (msg.sender != s_bridgeLimitAdmin && msg.sender != owner()) revert Unauthorized(msg.sender);
    s_bridgeLimit = newBridgeLimit;
  }

  function setBridgeLimitAdmin(address bridgeLimitAdmin) external {
    s_bridgeLimitAdmin = bridgeLimitAdmin;
  }

  function getBridgeLimit() external view virtual returns (uint256) {
    return s_bridgeLimit;
  }

  function getRateLimitAdmin() external view returns (address) {
    return s_rateLimitAdmin;
  }

  function getBridgeLimitAdmin() external view returns (address) {
    return s_bridgeLimitAdmin;
  }

  function setChainRateLimiterConfig(
    uint64 remoteChainSelector,
    RateLimiter.Config memory outboundConfig,
    RateLimiter.Config memory inboundConfig
  ) external {
    if (msg.sender != s_rateLimitAdmin && msg.sender != owner()) revert Unauthorized(msg.sender);

    _setRateLimitConfig(remoteChainSelector, outboundConfig, inboundConfig);
  }

  function _setRateLimitConfig(
    uint64 remoteChainSelector,
    RateLimiter.Config memory outboundConfig,
    RateLimiter.Config memory inboundConfig
  ) internal {
    RateLimiter._validateTokenBucketConfig(outboundConfig, false);
    s_outboundRateLimits[remoteChainSelector]._setTokenBucketConfig(outboundConfig);
    RateLimiter._validateTokenBucketConfig(inboundConfig, false);
    s_inboundRateLimits[remoteChainSelector]._setTokenBucketConfig(inboundConfig);
    emit ChainConfigured(remoteChainSelector, outboundConfig, inboundConfig);
  }

  function getCurrentOutboundRateLimiterState(
    uint64 remoteChainSelector
  ) external view returns (RateLimiter.TokenBucket memory) {
    return s_outboundRateLimits[remoteChainSelector]._currentTokenBucketState();
  }

  function getCurrentInboundRateLimiterState(
    uint64 remoteChainSelector
  ) external view returns (RateLimiter.TokenBucket memory) {
    return s_inboundRateLimits[remoteChainSelector]._currentTokenBucketState();
  }

  function applyChainUpdates(ChainUpdate[] calldata chains) external virtual {
    for (uint256 i = 0; i < chains.length; ++i) {
      ChainUpdate memory update = chains[i];
      s_outboundRateLimits[update.remoteChainSelector] = RateLimiter.TokenBucket({
        rate: update.outboundRateLimiterConfig.rate,
        capacity: update.outboundRateLimiterConfig.capacity,
        tokens: update.outboundRateLimiterConfig.capacity,
        lastUpdated: uint32(block.timestamp),
        isEnabled: update.outboundRateLimiterConfig.isEnabled
      });

      s_inboundRateLimits[update.remoteChainSelector] = RateLimiter.TokenBucket({
        rate: update.inboundRateLimiterConfig.rate,
        capacity: update.inboundRateLimiterConfig.capacity,
        tokens: update.inboundRateLimiterConfig.capacity,
        lastUpdated: uint32(block.timestamp),
        isEnabled: update.inboundRateLimiterConfig.isEnabled
      });
    }
  }

  function _transferOwnership(address newOwner) internal {
    _owner = newOwner;
  }
}
