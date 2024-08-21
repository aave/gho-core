// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

contract TestGhoStewards is Test {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 20580302);

    // TODO: Find which contracts are already deployed that we need
    // TODO: Deploy stewards, using corresponding contracts
  }
}
