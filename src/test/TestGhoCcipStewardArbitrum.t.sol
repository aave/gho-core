// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {IGhoCcipSteward} from '../contracts/misc/interfaces/IGhoCcipSteward.sol';
import {RateLimiter} from 'src/contracts/misc/deps/Dependencies.sol';

contract TestGhoCcipStewardArbitrum is TestGhoBase {
  RateLimiter.Config rateLimitConfig =
    RateLimiter.Config({isEnabled: true, capacity: type(uint128).max, rate: 1e15});

  event ChainConfigured(
    uint64 remoteChainSelector,
    RateLimiter.Config outboundRateLimiterConfig,
    RateLimiter.Config inboundRateLimiterConfig
  );
  function setUp() public {
    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(ARB_GHO_CCIP_STEWARD.MINIMUM_DELAY() + 1);

    // Grant required roles
    GHO_GSM.grantRole(GSM_CONFIGURATOR_ROLE, address(ARB_GHO_CCIP_STEWARD));
    vm.prank(ARB_GHO_TOKEN_POOL.owner());
    ARB_GHO_TOKEN_POOL.setRateLimitAdmin(address(ARB_GHO_CCIP_STEWARD));
  }

  function testConstructor() public {
    assertEq(ARB_GHO_CCIP_STEWARD.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(ARB_GHO_CCIP_STEWARD.owner(), SHORT_EXECUTOR);
    assertEq(ARB_GHO_CCIP_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(ARB_GHO_CCIP_STEWARD.GHO_TOKEN_POOL(), address(ARB_GHO_TOKEN_POOL));
    assertEq(ARB_GHO_CCIP_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);
  }
  function testUpdateRateLimit() public {
    vm.expectEmit(false, false, false, true);
    emit ChainConfigured(
      2,
      RateLimiter.Config({isEnabled: true, capacity: type(uint128).max, rate: 1e15}),
      RateLimiter.Config({isEnabled: true, capacity: type(uint128).max, rate: 1e15})
    );
    vm.prank(RISK_COUNCIL);
    ARB_GHO_CCIP_STEWARD.updateRateLimit(
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
    ARB_GHO_CCIP_STEWARD.updateRateLimit(
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
    ARB_GHO_CCIP_STEWARD.updateRateLimit(
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
    ARB_GHO_CCIP_STEWARD.updateRateLimit(
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
