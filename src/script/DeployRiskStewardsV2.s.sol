// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from 'forge-std/Script.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {GhoStewardV2} from '../contracts/misc/GhoStewardV2.sol';

contract DeployRiskStewardsV2 is Script {
  address public constant RISK_COUNCIL = 0x8513e6F37dBc52De87b166980Fa3F50639694B60;

  function run() external {
    vm.startBroadcast();
    _deploy();
    vm.stopBroadcast();
  }

  function _deploy() internal {
    GhoStewardV2 ghoSteward = new GhoStewardV2(
      GovernanceV3Ethereum.EXECUTOR_LVL_1, // owner
      address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER),
      MiscEthereum.GHO_TOKEN,
      RISK_COUNCIL
    );
    console2.log('Gho Steward V2: ', address(ghoSteward));
  }
}
