// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IAccessControl} from '@openzeppelin/contracts/access/IAccessControl.sol';
import {IACLManager} from '@aave/core-v3/contracts/interfaces/IACLManager.sol';
import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {MiscArbitrum} from 'aave-address-book/MiscArbitrum.sol';
import {IPoolAddressesProvider, IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
import {GhoToken} from '../contracts/gho/GhoToken.sol';
import {IGhoAaveSteward} from '../contracts/misc/interfaces/IGhoAaveSteward.sol';
import {GhoAaveSteward} from '../contracts/misc/GhoAaveSteward.sol';
import {GhoBucketSteward} from '../contracts/misc/GhoBucketSteward.sol';
import {GhoCcipSteward} from '../contracts/misc/GhoCcipSteward.sol';
import {RateLimiter, IUpgradeableLockReleaseTokenPool} from '../contracts/misc/dependencies/Ccip.sol';
import {IDefaultInterestRateStrategyV2} from '../contracts/misc/dependencies/AaveV3-1.sol';
import {MockUpgradeableBurnMintTokenPool} from './mocks/MockUpgradeableBurnMintTokenPool.sol';

contract TestGhoStewardsForkRemote is Test {
  address public OWNER = makeAddr('OWNER');
  address public RISK_COUNCIL = makeAddr('RISK_COUNCIL');
  IPoolDataProvider public POOL_DATA_PROVIDER = AaveV3Arbitrum.AAVE_PROTOCOL_DATA_PROVIDER;
  IPoolAddressesProvider public POOL_ADDRESSES_PROVIDER = AaveV3Arbitrum.POOL_ADDRESSES_PROVIDER;
  address public GHO_TOKEN = 0x7dfF72693f6A4149b17e7C6314655f6A9F7c8B33;
  address public ARM_PROXY = 0xC311a21e6fEf769344EB1515588B9d535662a145;
  address public ACL_ADMIN = AaveV3Arbitrum.ACL_ADMIN;
  address public GHO_TOKEN_POOL = MiscArbitrum.GHO_CCIP_TOKEN_POOL;
  address public PROXY_ADMIN = MiscArbitrum.PROXY_ADMIN;
  address public ACL_MANAGER;

  GhoAaveSteward public GHO_AAVE_STEWARD;
  GhoBucketSteward public GHO_BUCKET_STEWARD;
  GhoCcipSteward public GHO_CCIP_STEWARD;

  uint64 public remoteChainSelector = 5009297550715157269;

  event ChainConfigured(
    uint64 remoteChainSelector,
    RateLimiter.Config outboundRateLimiterConfig,
    RateLimiter.Config inboundRateLimiterConfig
  );

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), 247477524);
    vm.startPrank(ACL_ADMIN);
    ACL_MANAGER = POOL_ADDRESSES_PROVIDER.getACLManager();

    IGhoAaveSteward.BorrowRateConfig memory defaultBorrowRateConfig = IGhoAaveSteward
      .BorrowRateConfig({
        optimalUsageRatioMaxChange: 5_00,
        baseVariableBorrowRateMaxChange: 5_00,
        variableRateSlope1MaxChange: 5_00,
        variableRateSlope2MaxChange: 5_00
      });

    GHO_AAVE_STEWARD = new GhoAaveSteward(
      OWNER,
      address(POOL_ADDRESSES_PROVIDER),
      address(POOL_DATA_PROVIDER),
      GHO_TOKEN,
      RISK_COUNCIL,
      defaultBorrowRateConfig
    );
    IAccessControl(ACL_MANAGER).grantRole(
      IACLManager(ACL_MANAGER).RISK_ADMIN_ROLE(),
      address(GHO_AAVE_STEWARD)
    );

    GHO_BUCKET_STEWARD = new GhoBucketSteward(OWNER, GHO_TOKEN, RISK_COUNCIL);
    GhoToken(GHO_TOKEN).grantRole(
      GhoToken(GHO_TOKEN).BUCKET_MANAGER_ROLE(),
      address(GHO_BUCKET_STEWARD)
    );

    GHO_CCIP_STEWARD = new GhoCcipSteward(GHO_TOKEN, GHO_TOKEN_POOL, RISK_COUNCIL, true);

    address[] memory controlledFacilitators = new address[](1);
    controlledFacilitators[0] = address(GHO_TOKEN_POOL);
    changePrank(OWNER);
    GHO_BUCKET_STEWARD.setControlledFacilitator(controlledFacilitators, true);

    vm.stopPrank();
  }

  function testStewardsPermissions() public {
    assertEq(
      IAccessControl(ACL_MANAGER).hasRole(
        IACLManager(ACL_MANAGER).RISK_ADMIN_ROLE(),
        address(GHO_AAVE_STEWARD)
      ),
      true
    );

    assertEq(
      IAccessControl(GHO_TOKEN).hasRole(
        GhoToken(GHO_TOKEN).BUCKET_MANAGER_ROLE(),
        address(GHO_BUCKET_STEWARD)
      ),
      true
    );
  }

  function testGhoAaveStewardUpdateGhoBorrowRate() public {
    address rateStrategyAddress = POOL_DATA_PROVIDER.getInterestRateStrategyAddress(GHO_TOKEN);

    IDefaultInterestRateStrategyV2.InterestRateData
      memory mockResponse = IDefaultInterestRateStrategyV2.InterestRateData({
        optimalUsageRatio: 100,
        baseVariableBorrowRate: 100,
        variableRateSlope1: 100,
        variableRateSlope2: 100
      });
    vm.mockCall(
      rateStrategyAddress,
      abi.encodeWithSelector(
        IDefaultInterestRateStrategyV2(rateStrategyAddress).getInterestRateDataBps.selector,
        GHO_TOKEN
      ),
      abi.encode(mockResponse)
    );

    IDefaultInterestRateStrategyV2.InterestRateData memory currentRates = _getGhoBorrowRates();
    uint16 newOptimalUsageRatio = currentRates.optimalUsageRatio + 1;
    uint32 newBaseVariableBorrowRate = currentRates.baseVariableBorrowRate + 1;
    uint32 newVariableRateSlope1 = currentRates.variableRateSlope1 - 1;
    uint32 newVariableRateSlope2 = currentRates.variableRateSlope2 - 1;

    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      newOptimalUsageRatio,
      newBaseVariableBorrowRate,
      newVariableRateSlope1,
      newVariableRateSlope2
    );

    vm.clearMockedCalls();

    assertEq(_getOptimalUsageRatio(), newOptimalUsageRatio);
    assertEq(_getBaseVariableBorrowRate(), newBaseVariableBorrowRate);
    assertEq(_getVariableRateSlope1(), newVariableRateSlope1);
    assertEq(_getVariableRateSlope2(), newVariableRateSlope2);
  }

  function testGhoBucketStewardUpdateFacilitatorBucketCapacity() public {
    (uint256 currentBucketCapacity, ) = GhoToken(GHO_TOKEN).getFacilitatorBucket(
      address(GHO_TOKEN_POOL)
    );
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(address(GHO_TOKEN_POOL), newBucketCapacity);
    (uint256 bucketCapacity, ) = GhoToken(GHO_TOKEN).getFacilitatorBucket(address(GHO_TOKEN_POOL));
    assertEq(bucketCapacity, newBucketCapacity);
  }

  function testGhoBucketStewardSetControlledFacilitator() public {
    address[] memory newGsmList = new address[](1);
    address gho_gsm_4626 = makeAddr('gho_gsm_4626');
    newGsmList[0] = gho_gsm_4626;
    vm.prank(OWNER);
    GHO_BUCKET_STEWARD.setControlledFacilitator(newGsmList, true);
    assertTrue(GHO_BUCKET_STEWARD.isControlledFacilitator(gho_gsm_4626));
    vm.prank(OWNER);
    GHO_BUCKET_STEWARD.setControlledFacilitator(newGsmList, false);
    assertFalse(GHO_BUCKET_STEWARD.isControlledFacilitator(gho_gsm_4626));
  }

  function testGhoCcipStewardUpdateRateLimit() public {
    RateLimiter.TokenBucket memory outboundConfig = IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
      .getCurrentOutboundRateLimiterState(remoteChainSelector);
    RateLimiter.TokenBucket memory inboundConfig = IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
      .getCurrentInboundRateLimiterState(remoteChainSelector);

    RateLimiter.Config memory newOutboundConfig = RateLimiter.Config({
      isEnabled: outboundConfig.isEnabled,
      capacity: outboundConfig.capacity + 1,
      rate: outboundConfig.rate
    });

    RateLimiter.Config memory newInboundConfig = RateLimiter.Config({
      isEnabled: outboundConfig.isEnabled,
      capacity: inboundConfig.capacity,
      rate: inboundConfig.rate
    });

    // Currently rate limit set to 0, so can't even change by 1 because 100% of 0 is 0
    vm.expectRevert('INVALID_RATE_LIMIT_UPDATE');
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

  function testGhoCcipStewardRevertUpdateRateLimitUnauthorizedBeforeUpgrade() public {
    RateLimiter.TokenBucket memory mockConfig = RateLimiter.TokenBucket({
      rate: 50,
      capacity: 50,
      tokens: 1,
      lastUpdated: 1,
      isEnabled: true
    });
    // Mocking response due to rate limit currently being 0
    vm.mockCall(
      GHO_TOKEN_POOL,
      abi.encodeWithSelector(
        IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
          .getCurrentOutboundRateLimiterState
          .selector,
        remoteChainSelector
      ),
      abi.encode(mockConfig)
    );

    RateLimiter.TokenBucket memory outboundConfig = IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
      .getCurrentOutboundRateLimiterState(remoteChainSelector);
    RateLimiter.TokenBucket memory inboundConfig = IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
      .getCurrentInboundRateLimiterState(remoteChainSelector);

    RateLimiter.Config memory newOutboundConfig = RateLimiter.Config({
      isEnabled: outboundConfig.isEnabled,
      capacity: outboundConfig.capacity,
      rate: outboundConfig.rate + 1
    });

    RateLimiter.Config memory newInboundConfig = RateLimiter.Config({
      isEnabled: outboundConfig.isEnabled,
      capacity: inboundConfig.capacity,
      rate: inboundConfig.rate
    });

    vm.expectRevert('Only callable by owner');
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

  function testGhoCcipStewardUpdateRateLimitAfterPoolUpgrade() public {
    MockUpgradeableBurnMintTokenPool tokenPoolImpl = new MockUpgradeableBurnMintTokenPool(
      address(GHO_TOKEN),
      address(ARM_PROXY),
      false,
      false
    );

    vm.prank(PROXY_ADMIN);
    TransparentUpgradeableProxy(payable(address(GHO_TOKEN_POOL))).upgradeTo(address(tokenPoolImpl));

    vm.prank(ACL_ADMIN);
    IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).setRateLimitAdmin(address(GHO_CCIP_STEWARD));

    RateLimiter.TokenBucket memory mockConfig = RateLimiter.TokenBucket({
      rate: 50,
      capacity: 50,
      tokens: 1,
      lastUpdated: 1,
      isEnabled: true
    });

    // Mocking response due to rate limit currently being 0
    vm.mockCall(
      GHO_TOKEN_POOL,
      abi.encodeWithSelector(
        IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
          .getCurrentOutboundRateLimiterState
          .selector,
        remoteChainSelector
      ),
      abi.encode(mockConfig)
    );
    vm.mockCall(
      GHO_TOKEN_POOL,
      abi.encodeWithSelector(
        IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).getCurrentInboundRateLimiterState.selector,
        remoteChainSelector
      ),
      abi.encode(mockConfig)
    );

    RateLimiter.TokenBucket memory outboundConfig = IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
      .getCurrentOutboundRateLimiterState(remoteChainSelector);
    RateLimiter.TokenBucket memory inboundConfig = IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL)
      .getCurrentInboundRateLimiterState(remoteChainSelector);

    RateLimiter.Config memory newOutboundConfig = RateLimiter.Config({
      isEnabled: outboundConfig.isEnabled,
      capacity: outboundConfig.capacity + 1,
      rate: outboundConfig.rate
    });

    RateLimiter.Config memory newInboundConfig = RateLimiter.Config({
      isEnabled: outboundConfig.isEnabled,
      capacity: inboundConfig.capacity + 1,
      rate: inboundConfig.rate
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

  function _getOptimalUsageRatio() internal view returns (uint16) {
    IDefaultInterestRateStrategyV2.InterestRateData memory currentRates = _getGhoBorrowRates();
    return currentRates.optimalUsageRatio;
  }

  function _getBaseVariableBorrowRate() internal view returns (uint32) {
    IDefaultInterestRateStrategyV2.InterestRateData memory currentRates = _getGhoBorrowRates();
    return currentRates.baseVariableBorrowRate;
  }

  function _getVariableRateSlope1() internal view returns (uint32) {
    IDefaultInterestRateStrategyV2.InterestRateData memory currentRates = _getGhoBorrowRates();
    return currentRates.variableRateSlope1;
  }

  function _getVariableRateSlope2() internal view returns (uint32) {
    IDefaultInterestRateStrategyV2.InterestRateData memory currentRates = _getGhoBorrowRates();
    return currentRates.variableRateSlope2;
  }

  function _getGhoBorrowRates()
    internal
    view
    returns (IDefaultInterestRateStrategyV2.InterestRateData memory)
  {
    address rateStrategyAddress = POOL_DATA_PROVIDER.getInterestRateStrategyAddress(GHO_TOKEN);
    return IDefaultInterestRateStrategyV2(rateStrategyAddress).getInterestRateDataBps(GHO_TOKEN);
  }
}
