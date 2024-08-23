// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IAccessControl} from '@openzeppelin/contracts/access/IAccessControl.sol';
import {IACLManager} from '@aave/core-v3/contracts/interfaces/IACLManager.sol';
import {IPoolDataProvider} from '@aave/core-v3/contracts/interfaces/IPoolDataProvider.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {ReserveConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {FixedFeeStrategyFactory} from '../contracts/facilitators/gsm/feeStrategy/FixedFeeStrategyFactory.sol';
import {IGsmFeeStrategy} from '../contracts/facilitators/gsm/feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {Gsm} from '../contracts/facilitators/gsm/Gsm.sol';
import {GhoToken} from '../contracts/gho/GhoToken.sol';
import {IGhoAaveSteward} from '../contracts/misc/interfaces/IGhoAaveSteward.sol';
import {GhoAaveSteward} from '../contracts/misc/GhoAaveSteward.sol';
import {GhoBucketSteward} from '../contracts/misc/GhoBucketSteward.sol';
import {GhoCcipSteward} from '../contracts/misc/GhoCcipSteward.sol';
import {GhoGsmSteward} from '../contracts/misc/GhoGsmSteward.sol';
import {RateLimiter, IUpgradeableLockReleaseTokenPool} from '../contracts/misc/dependencies/Ccip.sol';
import {IDefaultInterestRateStrategyV2} from '../contracts/misc/dependencies/AaveV3-1.sol';
import {MockPool} from './mocks/MockPool.sol';
import {MockUpgradeableLockReleaseTokenPool} from './mocks/MockUpgradeableLockReleaseTokenPool.sol';

contract TestGhoStewards is Test {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  address public OWNER = makeAddr('OWNER');
  address public RISK_COUNCIL = makeAddr('RISK_COUNCIL');
  address public POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
  address public POOL_DATA_PROVIDER = 0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3;
  address public GHO_TOKEN = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
  address public GHO_ATOKEN = 0x00907f9921424583e7ffBfEdf84F92B7B2Be4977;
  address public GHO_TOKEN_POOL = 0x5756880B6a1EAba0175227bf02a7E87c1e02B28C;
  address public POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
  address public ACL_ADMIN = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;
  address public GHO_GSM_USDC = 0x0d8eFfC11dF3F229AA1EA0509BC9DFa632A13578;
  address public GHO_GSM_USDT = 0x686F8D21520f4ecEc7ba577be08354F4d1EB8262;
  address public ACL_MANAGER;

  GhoAaveSteward public GHO_AAVE_STEWARD;
  GhoBucketSteward public GHO_BUCKET_STEWARD;
  GhoCcipSteward public GHO_CCIP_STEWARD;
  GhoGsmSteward public GHO_GSM_STEWARD;

  uint64 public remoteChainSelector = 4949039107694359620;

  event ChainConfigured(
    uint64 remoteChainSelector,
    RateLimiter.Config outboundRateLimiterConfig,
    RateLimiter.Config inboundRateLimiterConfig
  );

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 20580302);
    vm.startPrank(ACL_ADMIN);
    ACL_MANAGER = IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getACLManager();

    IGhoAaveSteward.BorrowRateConfig memory defaultBorrowRateConfig = IGhoAaveSteward
      .BorrowRateConfig({
        optimalUsageRatioMaxChange: 10_00,
        baseVariableBorrowRateMaxChange: 5_00,
        variableRateSlope1MaxChange: 10_00,
        variableRateSlope2MaxChange: 10_00
      });

    GHO_AAVE_STEWARD = new GhoAaveSteward(
      OWNER,
      POOL_ADDRESSES_PROVIDER,
      POOL_DATA_PROVIDER,
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
    IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).setRateLimitAdmin(address(GHO_CCIP_STEWARD));
    IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).setBridgeLimitAdmin(address(GHO_CCIP_STEWARD));

    FixedFeeStrategyFactory strategyFactory = new FixedFeeStrategyFactory();
    GHO_GSM_STEWARD = new GhoGsmSteward(address(strategyFactory), RISK_COUNCIL);
    Gsm(GHO_GSM_USDC).grantRole(Gsm(GHO_GSM_USDC).CONFIGURATOR_ROLE(), address(GHO_GSM_STEWARD));
    Gsm(GHO_GSM_USDT).grantRole(Gsm(GHO_GSM_USDT).CONFIGURATOR_ROLE(), address(GHO_GSM_STEWARD));

    address[] memory controlledFacilitators = new address[](3);
    controlledFacilitators[0] = address(GHO_ATOKEN);
    controlledFacilitators[1] = address(GHO_GSM_USDC);
    controlledFacilitators[2] = address(GHO_GSM_USDT);
    changePrank(OWNER);
    GHO_BUCKET_STEWARD.setControlledFacilitator(controlledFacilitators, true);

    vm.stopPrank();
  }

  function testSetup() public {
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

    assertEq(
      IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).getRateLimitAdmin(),
      address(GHO_CCIP_STEWARD)
    );
    assertEq(
      IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).getBridgeLimitAdmin(),
      address(GHO_CCIP_STEWARD)
    );

    assertEq(
      Gsm(GHO_GSM_USDC).hasRole(Gsm(GHO_GSM_USDC).CONFIGURATOR_ROLE(), address(GHO_GSM_STEWARD)),
      true
    );
    assertEq(
      Gsm(GHO_GSM_USDT).hasRole(Gsm(GHO_GSM_USDT).CONFIGURATOR_ROLE(), address(GHO_GSM_STEWARD)),
      true
    );
  }

  function testGhoAaveStewardUpdateGhoBorrowCap() public {
    uint256 currentBorrowCap = _getGhoBorrowCap();
    uint256 newBorrowCap = currentBorrowCap + 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowCap(newBorrowCap);
    assertEq(_getGhoBorrowCap(), newBorrowCap);
  }

  function testGhoAaveStewardUpdateGhoSupplyCap() public {
    uint256 currentSupplyCap = _getGhoSupplyCap();
    assertEq(currentSupplyCap, 0);
    uint256 newSupplyCap = currentSupplyCap + 1;
    // Can't update supply cap even by 1 since it's 0, and 100% of 0 is 0
    vm.expectRevert('INVALID_SUPPLY_CAP_UPDATE');
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoSupplyCap(newSupplyCap);
  }

  function testGhoAaveStewardUpdateGhoBorrowRate() public {
    IDefaultInterestRateStrategyV2.InterestRateData memory currentRates = _getGhoBorrowRates();
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      currentRates.optimalUsageRatio,
      currentRates.baseVariableBorrowRate + 1,
      currentRates.variableRateSlope1,
      currentRates.variableRateSlope2
    );
    assertEq(_getGhoBorrowRate(), currentRates.baseVariableBorrowRate + 1);
  }

  function testGhoBucketStewardUpdateFacilitatorBucketCapacity() public {
    (uint256 currentBucketCapacity, ) = GhoToken(GHO_TOKEN).getFacilitatorBucket(
      address(GHO_ATOKEN)
    );
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    GHO_BUCKET_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    (uint256 capacity, ) = GhoToken(GHO_TOKEN).getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(newBucketCapacity, capacity);
  }

  function testGhoBucketStewardSetControlledFacilitatorAdd() public {
    address[] memory oldControlledFacilitators = GHO_BUCKET_STEWARD.getControlledFacilitators();
    address[] memory newGsmList = new address[](1);
    address gho_gsm_4626 = makeAddr('gho_gsm_4626');
    newGsmList[0] = gho_gsm_4626;
    vm.prank(OWNER);
    GHO_BUCKET_STEWARD.setControlledFacilitator(newGsmList, true);
    address[] memory newControlledFacilitators = GHO_BUCKET_STEWARD.getControlledFacilitators();
    assertEq(newControlledFacilitators.length, oldControlledFacilitators.length + 1);
    assertTrue(_contains(newControlledFacilitators, gho_gsm_4626));
  }

  function testGhoCcipStewardUpdateBridgeLimit() public {
    uint256 oldBridgeLimit = IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).getBridgeLimit();
    uint256 newBridgeLimit = oldBridgeLimit + 1;
    vm.prank(RISK_COUNCIL);
    GHO_CCIP_STEWARD.updateBridgeLimit(newBridgeLimit);
    uint256 currentBridgeLimit = IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).getBridgeLimit();
    assertEq(currentBridgeLimit, newBridgeLimit);
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

  function testGhoGsmStewardUpdateExposureCap() public {
    uint128 oldExposureCap = Gsm(GHO_GSM_USDC).getExposureCap();
    uint128 newExposureCap = oldExposureCap + 1;
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmExposureCap(GHO_GSM_USDC, newExposureCap);
    uint128 currentExposureCap = Gsm(GHO_GSM_USDC).getExposureCap();
    assertEq(currentExposureCap, newExposureCap);
  }

  function testGhoGsmStewardUpdateGsmBuySellFees() public {
    address feeStrategy = Gsm(GHO_GSM_USDC).getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(GHO_GSM_USDC, buyFee + 1, sellFee);
    address newStrategy = Gsm(GHO_GSM_USDC).getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    assertEq(newBuyFee, buyFee + 1);
  }

  function _getGhoBorrowCap() internal view returns (uint256) {
    DataTypes.ReserveConfigurationMap memory configuration = IPool(POOL).getConfiguration(
      GHO_TOKEN
    );
    return configuration.getBorrowCap();
  }

  function _getGhoSupplyCap() internal view returns (uint256) {
    DataTypes.ReserveConfigurationMap memory configuration = IPool(POOL).getConfiguration(
      address(GHO_TOKEN)
    );
    return configuration.getSupplyCap();
  }

  function _getGhoBorrowRate() internal view returns (uint32) {
    IDefaultInterestRateStrategyV2.InterestRateData memory currentRates = _getGhoBorrowRates();
    return currentRates.baseVariableBorrowRate;
  }

  function _getGhoBorrowRates()
    internal
    view
    returns (IDefaultInterestRateStrategyV2.InterestRateData memory)
  {
    address rateStrategyAddress = IPoolDataProvider(POOL_DATA_PROVIDER)
      .getInterestRateStrategyAddress(GHO_TOKEN);
    return IDefaultInterestRateStrategyV2(rateStrategyAddress).getInterestRateDataBps(GHO_TOKEN);
  }

  function _contains(address[] memory list, address item) internal pure returns (bool) {
    for (uint256 i = 0; i < list.length; i++) {
      if (list[i] == item) {
        return true;
      }
    }
    return false;
  }
}
