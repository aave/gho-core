// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {RateLimiter} from 'src/contracts/misc/deps/Dependencies.sol';

contract TestGhoCcipSteward is TestGhoBase {
  RateLimiter.Config rateLimitConfig =
    RateLimiter.Config({isEnabled: true, capacity: type(uint128).max, rate: 1e15});

  event ChainConfigured(
    uint64 remoteChainSelector,
    RateLimiter.Config outboundRateLimiterConfig,
    RateLimiter.Config inboundRateLimiterConfig
  );

  function setUp() public {
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

    assertEq(GHO_CCIP_STEWARD.owner(), SHORT_EXECUTOR);
    assertEq(GHO_CCIP_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_CCIP_STEWARD.GHO_TOKEN_POOL(), address(GHO_TOKEN_POOL));
    assertEq(GHO_CCIP_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);
  }

  function testRevertConstructorInvalidExecutor() public {
    vm.expectRevert('INVALID_OWNER');
    new GhoCcipSteward(address(0), address(0x002), address(0x003), address(0x004));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new GhoCcipSteward(address(0x001), address(0), address(0x003), address(0x004));
  }

  function testRevertConstructorInvalidGhoTokenPool() public {
    vm.expectRevert('INVALID_GHO_TOKEN_POOL');
    new GhoCcipSteward(address(0x001), address(0x002), address(0), address(0x004));
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new GhoCcipSteward(address(0x001), address(0x002), address(0x003), address(0));
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

  function testUpdateRateLimit() public {
    vm.expectEmit(false, false, false, true);
    emit ChainConfigured(2, rateLimitConfig, rateLimitConfig);
    vm.prank(RISK_COUNCIL);
    GHO_CCIP_STEWARD.updateRateLimit(
      2,
      rateLimitConfig.isEnabled,
      rateLimitConfig.capacity,
      rateLimitConfig.rate,
      rateLimitConfig.isEnabled,
      rateLimitConfig.capacity,
      rateLimitConfig.rate
    );
  }

  function testRevertUpdateRateLimitIfUnauthorized() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_CALLER');
    GHO_CCIP_STEWARD.updateRateLimit(
      2,
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
      2,
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
      2,
      invalidConfig.isEnabled,
      invalidConfig.capacity,
      invalidConfig.rate,
      rateLimitConfig.isEnabled,
      rateLimitConfig.capacity,
      rateLimitConfig.rate
    );
  }
}
