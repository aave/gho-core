// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {RateLimiter} from 'src/contracts/misc/deps/RateLimiter.sol';

contract TestGhoCcipSteward is TestGhoBase {
  RateLimiter.Config rateLimitConfig =
    RateLimiter.Config({isEnabled: true, capacity: type(uint128).max, rate: 1e15});
  uint64 remoteChainSelector = 2;

  event ChainConfigured(
    uint64 remoteChainSelector,
    RateLimiter.Config outboundRateLimiterConfig,
    RateLimiter.Config inboundRateLimiterConfig
  );

  function setUp() public {
    // Deploy Gho CCIP Steward
    GHO_CCIP_STEWARD = new GhoCcipSteward(
      address(GHO_TOKEN),
      address(GHO_TOKEN_POOL),
      RISK_COUNCIL,
      true
    );

    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(GHO_CCIP_STEWARD.MINIMUM_DELAY() + 1);

    // Grant accesses to the Steward
    vm.startPrank(GHO_TOKEN_POOL.owner());
    GHO_TOKEN_POOL.setRateLimitAdmin(address(GHO_CCIP_STEWARD));
    GHO_TOKEN_POOL.setBridgeLimitAdmin(address(GHO_CCIP_STEWARD));
    vm.stopPrank();
  }

  function testConstructor() public {
    assertEq(GHO_CCIP_STEWARD.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(GHO_CCIP_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_CCIP_STEWARD.GHO_TOKEN_POOL(), address(GHO_TOKEN_POOL));
    assertEq(GHO_CCIP_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new GhoCcipSteward(address(0), address(0x002), address(0x003), true);
  }

  function testRevertConstructorInvalidGhoTokenPool() public {
    vm.expectRevert('INVALID_GHO_TOKEN_POOL');
    new GhoCcipSteward(address(0x001), address(0), address(0x003), true);
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new GhoCcipSteward(address(0x001), address(0x002), address(0), true);
  }

  function testUpdateBridgeLimit() public {
    uint256 oldBridgeLimit = GHO_TOKEN_POOL.getBridgeLimit();
    uint256 newBridgeLimit = oldBridgeLimit + 1;
    vm.prank(RISK_COUNCIL);
    GHO_CCIP_STEWARD.updateBridgeLimit(newBridgeLimit);
    uint256 currentBridgeLimit = GHO_TOKEN_POOL.getBridgeLimit();
    assertEq(currentBridgeLimit, newBridgeLimit);
  }

  function testRevertUpdateBridgeLimitIfUnauthorized() public {
    uint256 oldBridgeLimit = GHO_TOKEN_POOL.getBridgeLimit();
    uint256 newBridgeLimit = oldBridgeLimit + 1;
    vm.prank(ALICE);
    vm.expectRevert('INVALID_CALLER');
    GHO_CCIP_STEWARD.updateBridgeLimit(newBridgeLimit);
  }

  function testUpdateBridgeLimitTooHigh() public {
    uint256 oldBridgeLimit = GHO_TOKEN_POOL.getBridgeLimit();
    uint256 newBridgeLimit = (oldBridgeLimit + 1) * 2;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BRIDGE_LIMIT_UPDATE');
    GHO_CCIP_STEWARD.updateBridgeLimit(newBridgeLimit);
  }

  function testUpdateBridgeLimitFuzz(uint256 newBridgeLimit) public {
    uint256 oldBridgeLimit = GHO_TOKEN_POOL.getBridgeLimit();
    newBridgeLimit = bound(newBridgeLimit, 0, oldBridgeLimit * 2);
    vm.prank(RISK_COUNCIL);
    GHO_CCIP_STEWARD.updateBridgeLimit(newBridgeLimit);
    uint256 currentBridgeLimit = GHO_TOKEN_POOL.getBridgeLimit();
    assertEq(currentBridgeLimit, newBridgeLimit);
  }

  function testUpdateRateLimit() public {
    RateLimiter.TokenBucket memory outboundConfig = UpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
      .getCurrentOutboundRateLimiterState(remoteChainSelector);
    RateLimiter.TokenBucket memory inboundConfig = UpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
      .getCurrentInboundRateLimiterState(remoteChainSelector);

    RateLimiter.Config memory newOutboundConfig = RateLimiter.Config({
      isEnabled: true,
      capacity: outboundConfig.capacity + 1,
      rate: outboundConfig.rate + 1
    });

    RateLimiter.Config memory newInboundConfig = RateLimiter.Config({
      isEnabled: true,
      capacity: inboundConfig.capacity + 1,
      rate: inboundConfig.rate + 1
    });

    vm.expectEmit(false, false, false, true);
    emit ChainConfigured(remoteChainSelector, newOutboundConfig, newInboundConfig);
    vm.prank(RISK_COUNCIL);
    GHO_CCIP_STEWARD.updateRateLimit(
      remoteChainSelector,
      newOutboundConfig.isEnabled,
      newOutboundConfig.capacity,
      newOutboundConfig.rate,
      newInboundConfig.isEnabled,
      newInboundConfig.capacity,
      newInboundConfig.rate
    );
  }

  function testRevertUpdateRateLimitIfUnauthorized() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_CALLER');
    GHO_CCIP_STEWARD.updateRateLimit(
      remoteChainSelector,
      rateLimitConfig.isEnabled,
      rateLimitConfig.capacity,
      rateLimitConfig.rate,
      rateLimitConfig.isEnabled,
      rateLimitConfig.capacity,
      rateLimitConfig.rate
    );
  }

  function testRevertUpdateRateLimitToZero() public {
    RateLimiter.Config memory invalidConfig = RateLimiter.Config({
      isEnabled: true,
      capacity: 0,
      rate: 0
    });
    vm.prank(RISK_COUNCIL);
    vm.expectRevert();
    GHO_CCIP_STEWARD.updateRateLimit(
      remoteChainSelector,
      invalidConfig.isEnabled,
      invalidConfig.capacity,
      invalidConfig.rate,
      rateLimitConfig.isEnabled,
      rateLimitConfig.capacity,
      rateLimitConfig.rate
    );
  }

  function testRevertUpdateRateLimitRateGreaterThanCapacity() public {
    RateLimiter.Config memory invalidConfig = RateLimiter.Config({
      isEnabled: true,
      capacity: 10,
      rate: 100
    });
    vm.prank(RISK_COUNCIL);
    vm.expectRevert();
    GHO_CCIP_STEWARD.updateRateLimit(
      remoteChainSelector,
      invalidConfig.isEnabled,
      invalidConfig.capacity,
      invalidConfig.rate,
      rateLimitConfig.isEnabled,
      rateLimitConfig.capacity,
      rateLimitConfig.rate
    );
  }

  function testUpdateRateLimitFuzz(
    uint128 outboundCapacity,
    uint128 outboundRate,
    uint128 inboundCapacity,
    uint128 inboundRate
  ) public {
    RateLimiter.TokenBucket memory currentOutboundConfig = UpgradeableLockReleaseTokenPool(
      GHO_TOKEN_POOL
    ).getCurrentOutboundRateLimiterState(remoteChainSelector);
    RateLimiter.TokenBucket memory currentInboundConfig = UpgradeableLockReleaseTokenPool(
      GHO_TOKEN_POOL
    ).getCurrentInboundRateLimiterState(remoteChainSelector);

    // Capacity must be strictly greater than rate and nothing can change more than 100%
    outboundRate = uint128(bound(outboundRate, 1, currentOutboundConfig.rate * 2));
    outboundCapacity = uint128(
      bound(outboundCapacity, outboundRate + 1, currentOutboundConfig.capacity * 2)
    );
    inboundRate = uint128(bound(inboundRate, 1, currentInboundConfig.rate * 2));
    inboundCapacity = uint128(
      bound(inboundCapacity, inboundRate + 1, currentInboundConfig.capacity * 2)
    );

    vm.prank(RISK_COUNCIL);
    GHO_CCIP_STEWARD.updateRateLimit(
      remoteChainSelector,
      rateLimitConfig.isEnabled,
      outboundCapacity,
      outboundRate,
      rateLimitConfig.isEnabled,
      inboundCapacity,
      inboundRate
    );
  }
}
