// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoStewardV2 is TestGhoBase {
  function testRevertConstructorInvalidAddressesProvider() public {
    vm.expectRevert('INVALID_ADDRESSES_PROVIDER');
    new GhoSteward(address(0), address(0x002), address(0x003), address(0x004));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new GhoSteward(address(0x001), address(0), address(0x003), address(0x004));
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new GhoSteward(address(0x001), address(0x002), address(0), address(0x004));
  }

  function testRevertConstructorInvalidShortExecutor() public {
    vm.expectRevert('INVALID_SHORT_EXECUTOR');
    new GhoSteward(address(0x001), address(0x002), address(0x003), address(0));
  }
}
