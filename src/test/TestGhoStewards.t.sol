// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IAccessControl} from '@openzeppelin/contracts/access/IAccessControl.sol';
import {IACLManager} from '@aave/core-v3/contracts/interfaces/IACLManager.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {FixedFeeStrategyFactory} from '../contracts/facilitators/gsm/feeStrategy/FixedFeeStrategyFactory.sol';
import {Gsm} from '../contracts/facilitators/gsm/Gsm.sol';
import {GhoToken} from '../contracts/gho/GhoToken.sol';
import {IGhoAaveSteward} from '../contracts/misc/interfaces/IGhoAaveSteward.sol';
import {GhoAaveSteward} from '../contracts/misc/GhoAaveSteward.sol';
import {GhoBucketSteward} from '../contracts/misc/GhoBucketSteward.sol';
import {GhoCcipSteward} from '../contracts/misc/GhoCcipSteward.sol';
import {GhoGsmSteward} from '../contracts/misc/GhoGsmSteward.sol';
import {IUpgradeableLockReleaseTokenPool} from '../contracts/misc/dependencies/Ccip.sol';

contract TestGhoStewards is Test {
  address public OWNER = makeAddr('OWNER');
  address public RISK_COUNCIL = makeAddr('RISK_COUNCIL');
  address public POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
  address public POOL_DATA_PROVIDER = 0x5c5228aC8BC1528482514aF3e27E692495148717;
  address public GHO_TOKEN = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
  address public GHO_TOKEN_POOL = 0x5756880B6a1EAba0175227bf02a7E87c1e02B28C;
  address public AAVE_V3_ETHEREUM_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
  address public ACL_ADMIN = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;
  address public GHO_GSM_USDC = 0x0d8eFfC11dF3F229AA1EA0509BC9DFa632A13578;
  address public GHO_GSM_USDT = 0x686F8D21520f4ecEc7ba577be08354F4d1EB8262;
  address public ACL_MANAGER;

  GhoAaveSteward public ghoAaveSteward;
  GhoBucketSteward public ghoBucketSteward;
  GhoCcipSteward public ghoCcipSteward;
  GhoGsmSteward public ghoGsmSteward;

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

    ghoAaveSteward = new GhoAaveSteward(
      OWNER,
      POOL_ADDRESSES_PROVIDER,
      POOL_DATA_PROVIDER,
      GHO_TOKEN,
      RISK_COUNCIL,
      defaultBorrowRateConfig
    );
    IAccessControl(ACL_MANAGER).grantRole(
      IACLManager(ACL_MANAGER).RISK_ADMIN_ROLE(),
      address(ghoAaveSteward)
    );

    ghoBucketSteward = new GhoBucketSteward(OWNER, GHO_TOKEN, RISK_COUNCIL);
    GhoToken(GHO_TOKEN).grantRole(
      GhoToken(GHO_TOKEN).BUCKET_MANAGER_ROLE(),
      address(ghoBucketSteward)
    );

    ghoCcipSteward = new GhoCcipSteward(GHO_TOKEN, GHO_TOKEN_POOL, RISK_COUNCIL, true);
    IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).setRateLimitAdmin(address(ghoCcipSteward));
    IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).setBridgeLimitAdmin(address(ghoCcipSteward));

    FixedFeeStrategyFactory strategyFactory = new FixedFeeStrategyFactory();
    ghoGsmSteward = new GhoGsmSteward(address(strategyFactory), RISK_COUNCIL);
    Gsm(GHO_GSM_USDC).grantRole(Gsm(GHO_GSM_USDC).CONFIGURATOR_ROLE(), address(ghoGsmSteward));
    Gsm(GHO_GSM_USDT).grantRole(Gsm(GHO_GSM_USDT).CONFIGURATOR_ROLE(), address(ghoGsmSteward));

    // TODO: Find which contracts are already deployed that we need
  }

  function testSetup() public {
    assertEq(
      IAccessControl(ACL_MANAGER).hasRole(
        IACLManager(ACL_MANAGER).RISK_ADMIN_ROLE(),
        address(ghoAaveSteward)
      ),
      true
    );

    assertEq(
      IAccessControl(GHO_TOKEN).hasRole(
        GhoToken(GHO_TOKEN).BUCKET_MANAGER_ROLE(),
        address(ghoBucketSteward)
      ),
      true
    );

    assertEq(
      IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).getRateLimitAdmin(),
      address(ghoCcipSteward)
    );
    assertEq(
      IUpgradeableLockReleaseTokenPool(GHO_TOKEN_POOL).getBridgeLimitAdmin(),
      address(ghoCcipSteward)
    );

    assertEq(
      Gsm(GHO_GSM_USDC).hasRole(Gsm(GHO_GSM_USDC).CONFIGURATOR_ROLE(), address(ghoGsmSteward)),
      true
    );
    assertEq(
      Gsm(GHO_GSM_USDT).hasRole(Gsm(GHO_GSM_USDT).CONFIGURATOR_ROLE(), address(ghoGsmSteward)),
      true
    );
  }
}
