// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IAccessControl} from '@openzeppelin/contracts/access/IAccessControl.sol';
import {IACLManager} from '@aave/core-v3/contracts/interfaces/IACLManager.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {FixedFeeStrategyFactory} from 'src/contracts/facilitators/gsm/feeStrategy/FixedFeeStrategyFactory.sol';
import {IGhoAaveSteward} from 'src/contracts/misc/interfaces/IGhoAaveSteward.sol';
import {GhoAaveSteward} from 'src/contracts/misc/GhoAaveSteward.sol';
import {GhoBucketSteward} from 'src/contracts/misc/GhoBucketSteward.sol';
import {GhoCcipSteward} from 'src/contracts/misc/GhoCcipSteward.sol';
import {GhoGsmSteward} from 'src/contracts/misc/GhoGsmSteward.sol';

contract TestGhoStewards is Test {
  address public OWNER = makeAddr('OWNER');
  address public RISK_COUNCIL = makeAddr('RISK_COUNCIL');
  address public POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
  address public POOL_DATA_PROVIDER = 0x5c5228aC8BC1528482514aF3e27E692495148717;
  address public GHO_TOKEN = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
  address public GHO_TOKEN_POOL = 0x5756880B6a1EAba0175227bf02a7E87c1e02B28C;
  address public AAVE_V3_ETHEREUM_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
  address public ACL_ADMIN = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;
  address public ACL_MANAGER;

  GhoAaveSteward public ghoAaveSteward;
  GhoBucketSteward public ghoBucketSteward;
  GhoCcipSteward public ghoCcipSteward;
  GhoGsmSteward public ghoGsmSteward;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 20580302);
    ACL_MANAGER = IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getACLManager();

    IGhoAaveSteward.BorrowRateConfig memory defaultBorrowRateConfig = IGhoAaveSteward
      .BorrowRateConfig({
        optimalUsageRatioMaxChange: 10_00,
        baseVariableBorrowRateMaxChange: 5_00,
        variableRateSlope1MaxChange: 10_00,
        variableRateSlope2MaxChange: 10_00
      });

    // Deploy Gho Aave Steward
    ghoAaveSteward = new GhoAaveSteward(
      OWNER,
      POOL_ADDRESSES_PROVIDER,
      POOL_DATA_PROVIDER,
      GHO_TOKEN,
      RISK_COUNCIL,
      defaultBorrowRateConfig
    );
    // Grant roles
    vm.startPrank(ACL_ADMIN);
    IAccessControl(ACL_MANAGER).grantRole(
      IACLManager(ACL_MANAGER).RISK_ADMIN_ROLE(),
      address(ghoAaveSteward)
    );
    vm.stopPrank();

    // Deploy Gho Bucket Steward
    ghoBucketSteward = new GhoBucketSteward(OWNER, GHO_TOKEN, RISK_COUNCIL);

    // Deploy Gho Ccip Steward
    ghoCcipSteward = new GhoCcipSteward(GHO_TOKEN, GHO_TOKEN_POOL, RISK_COUNCIL, true);

    // Deploy Gho Gsm Steward
    FixedFeeStrategyFactory strategyFactory = new FixedFeeStrategyFactory();
    ghoGsmSteward = new GhoGsmSteward(address(strategyFactory), RISK_COUNCIL);

    // TODO: Find which contracts are already deployed that we need
    // TODO: Deploy stewards, using corresponding contracts
    // TODO: Ensure we grant all appropriate roles
  }

  function testSetup() public {
    assertEq(
      IAccessControl(ACL_MANAGER).hasRole(
        IACLManager(ACL_MANAGER).RISK_ADMIN_ROLE(),
        address(ghoAaveSteward)
      ),
      true
    );
  }
}
