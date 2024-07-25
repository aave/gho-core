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
    GHO_TOKEN.grantRole(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(GHO_CCIP_STEWARD));
  }

  function testConstructor() public {
    assertEq(GHO_CCIP_STEWARD.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(GHO_CCIP_STEWARD.owner(), SHORT_EXECUTOR);
    assertEq(GHO_CCIP_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_CCIP_STEWARD.GHO_TOKEN_POOL(), address(GHO_TOKEN_POOL));
    assertEq(GHO_CCIP_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);

    address[] memory controlledFacilitators = GHO_CCIP_STEWARD.getControlledFacilitators();
    assertEq(controlledFacilitators.length, 2);

    uint40 facilitatorTimelock = GHO_CCIP_STEWARD.getFacilitatorBucketCapacityTimelock(
      controlledFacilitators[0]
    );
    assertEq(facilitatorTimelock, 0);
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

  function testUpdateFacilitatorBucketCapacity() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    GHO_CCIP_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(newBucketCapacity, capacity);
  }

  function testUpdateFacilitatorBucketCapacityMaxValue() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newBucketCapacity = uint128(currentBucketCapacity * 2);
    vm.prank(RISK_COUNCIL);
    GHO_CCIP_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacity);
  }

  function testUpdateFacilitatorBucketCapacityTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    GHO_CCIP_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
    uint40 timelock = GHO_CCIP_STEWARD.getFacilitatorBucketCapacityTimelock(address(GHO_ATOKEN));
    assertEq(timelock, block.timestamp);
  }

  function testUpdateFacilitatorBucketCapacityAfterTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    GHO_CCIP_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    skip(GHO_CCIP_STEWARD.MINIMUM_DELAY() + 1);
    uint128 newBucketCapacityAfterTimelock = newBucketCapacity + 1;
    vm.prank(RISK_COUNCIL);
    GHO_CCIP_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      newBucketCapacityAfterTimelock
    );
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacityAfterTimelock);
  }

  function testRevertUpdateFacilitatorBucketCapacityIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    GHO_CCIP_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), 123);
  }

  function testRevertUpdateFaciltatorBucketCapacityIfUpdatedTooSoon() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    GHO_CCIP_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_CCIP_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 2
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfFacilitatorNotInControl() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('FACILITATOR_NOT_CONTROLLED');
    GHO_CCIP_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_GSM_4626),
      uint128(currentBucketCapacity) + 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfStewardLostBucketManagerRole() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    GHO_TOKEN.revokeRole(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(GHO_CCIP_STEWARD));
    vm.expectRevert(
      AccessControlErrorsLib.MISSING_ROLE(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(GHO_CCIP_STEWARD))
    );
    vm.prank(RISK_COUNCIL);
    GHO_CCIP_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfMoreThanDouble() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_CCIP_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity * 2) + 1
    );
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

  function testSetControlledFacilitatorAdd() public {
    address[] memory oldControlledFacilitators = GHO_CCIP_STEWARD.getControlledFacilitators();
    address[] memory newGsmList = new address[](1);
    newGsmList[0] = address(GHO_GSM_4626);
    vm.prank(SHORT_EXECUTOR);
    GHO_CCIP_STEWARD.setControlledFacilitator(newGsmList, true);
    address[] memory newControlledFacilitators = GHO_CCIP_STEWARD.getControlledFacilitators();
    assertEq(newControlledFacilitators.length, oldControlledFacilitators.length + 1);
    assertTrue(_contains(newControlledFacilitators, address(GHO_GSM_4626)));
  }

  function testSetControlledFacilitatorsRemove() public {
    address[] memory oldControlledFacilitators = GHO_CCIP_STEWARD.getControlledFacilitators();
    address[] memory disableGsmList = new address[](1);
    disableGsmList[0] = address(GHO_GSM);
    vm.prank(SHORT_EXECUTOR);
    GHO_CCIP_STEWARD.setControlledFacilitator(disableGsmList, false);
    address[] memory newControlledFacilitators = GHO_CCIP_STEWARD.getControlledFacilitators();
    assertEq(newControlledFacilitators.length, oldControlledFacilitators.length - 1);
    assertFalse(_contains(newControlledFacilitators, address(GHO_GSM)));
  }

  function testRevertSetControlledFacilitatorIfUnauthorized() public {
    vm.expectRevert(OwnableErrorsLib.CALLER_NOT_OWNER());
    vm.prank(RISK_COUNCIL);
    address[] memory newGsmList = new address[](1);
    newGsmList[0] = address(GHO_GSM_4626);
    GHO_CCIP_STEWARD.setControlledFacilitator(newGsmList, true);
  }
}
