// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IAccessControl} from '@openzeppelin/contracts/access/IAccessControl.sol';
import {TransparentUpgradeableProxy} from 'solidity-utils/contracts/transparent-proxy/TransparentUpgradeableProxy.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';
import {MiscArbitrum} from 'aave-address-book/MiscArbitrum.sol';
import {IPoolAddressesProvider, IPoolDataProvider, IPool} from 'aave-address-book/AaveV3.sol';
import {GhoToken} from '../contracts/gho/GhoToken.sol';
import {GhoBucketSteward} from '../contracts/misc/GhoBucketSteward.sol';
import {GhoCcipSteward} from '../contracts/misc/GhoCcipSteward.sol';
import {RateLimiter, IUpgradeableLockReleaseTokenPool} from '../contracts/misc/dependencies/Ccip.sol';
import {IDefaultInterestRateStrategyV2} from '../contracts/misc/dependencies/AaveV3-1.sol';
import {MockUpgradeableLockReleaseTokenPool} from './mocks/MockUpgradeableLockReleaseTokenPool.sol';
import {MockUpgradeableBurnMintTokenPool} from './mocks/MockUpgradeableBurnMintTokenPool.sol';

contract TestGhoStewardsForkRemote is Test {
  address public OWNER = makeAddr('OWNER');
  address public RISK_COUNCIL = makeAddr('RISK_COUNCIL');
  IPoolDataProvider public POOL_DATA_PROVIDER = AaveV3Arbitrum.AAVE_PROTOCOL_DATA_PROVIDER;
  IPoolAddressesProvider public POOL_ADDRESSES_PROVIDER = AaveV3Arbitrum.POOL_ADDRESSES_PROVIDER;
  address public GHO_TOKEN = 0x7dfF72693f6A4149b17e7C6314655f6A9F7c8B33;
  address public GHO_ATOKEN = 0xeBe517846d0F36eCEd99C735cbF6131e1fEB775D;
  address public ARM_PROXY = 0xC311a21e6fEf769344EB1515588B9d535662a145;
  IPool public POOL = AaveV3Arbitrum.POOL;
  address public ACL_ADMIN = AaveV3Arbitrum.ACL_ADMIN;
  address public GHO_TOKEN_POOL = MiscArbitrum.GHO_CCIP_TOKEN_POOL;
  address public PROXY_ADMIN = MiscArbitrum.PROXY_ADMIN;
  address public ACL_MANAGER;

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

    GHO_BUCKET_STEWARD = new GhoBucketSteward(OWNER, GHO_TOKEN, RISK_COUNCIL);
    GhoToken(GHO_TOKEN).grantRole(
      GhoToken(GHO_TOKEN).BUCKET_MANAGER_ROLE(),
      address(GHO_BUCKET_STEWARD)
    );

    GHO_CCIP_STEWARD = new GhoCcipSteward(GHO_TOKEN, GHO_TOKEN_POOL, RISK_COUNCIL, true);

    address[] memory controlledFacilitators = new address[](1);
    controlledFacilitators[0] = address(GHO_ATOKEN);
    changePrank(OWNER);
    GHO_BUCKET_STEWARD.setControlledFacilitator(controlledFacilitators, true);

    vm.stopPrank();
  }

  function testStewardsPermissions() public {
    assertEq(
      IAccessControl(GHO_TOKEN).hasRole(
        GhoToken(GHO_TOKEN).BUCKET_MANAGER_ROLE(),
        address(GHO_BUCKET_STEWARD)
      ),
      true
    );
  }

  function testGhoBucketStewardUpdateFacilitatorBucketCapacity() public {
    (uint256 currentBucketCapacity, ) = GhoToken(GHO_TOKEN).getFacilitatorBucket(
      address(GHO_ATOKEN)
    );
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    // Currently bucket capacity set to 0, so can't even change by 1 because 100% of 0 is 0
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    (uint256 capacity, ) = GhoToken(GHO_TOKEN).getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, 0);
  }

  function testGhoBucketStewardSetControlledFacilitator() public {
    address[] memory newGsmList = new address[](1);
    address gho_gsm_4626 = makeAddr('gho_gsm_4626');
    newGsmList[0] = gho_gsm_4626;
    vm.prank(OWNER);
    GHO_BUCKET_STEWARD.setControlledFacilitator(newGsmList, true);
    assertTrue(_isControlledFacilitator(gho_gsm_4626));
    vm.prank(OWNER);
    GHO_BUCKET_STEWARD.setControlledFacilitator(newGsmList, false);
    assertFalse(_isControlledFacilitator(gho_gsm_4626));
  }

  function testGhoCcipStewardUpdateRateLimit() public {
    RateLimiter.TokenBucket memory outboundConfig = MockUpgradeableLockReleaseTokenPool(
      GHO_TOKEN_POOL
    ).getCurrentOutboundRateLimiterState(remoteChainSelector);
    RateLimiter.TokenBucket memory inboundConfig = MockUpgradeableLockReleaseTokenPool(
      GHO_TOKEN_POOL
    ).getCurrentInboundRateLimiterState(remoteChainSelector);

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

  function _isControlledFacilitator(address target) internal view returns (bool) {
    address[] memory controlledFacilitators = GHO_BUCKET_STEWARD.getControlledFacilitators();
    for (uint256 i = 0; i < controlledFacilitators.length; i++) {
      if (controlledFacilitators[i] == target) {
        return true;
      }
    }
    return false;
  }
}
