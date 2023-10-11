// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmUpgrade is TestGhoBase {
  function testUpgrade() public {
    assertEq(GHO_GSM.GSM_REVISION(), 1, 'Unexpected pre-upgrade GSM revision');

    bytes32[] memory beforeSnapshot = _getStorageSnapshot();

    // Sanity check on select storage variable
    assertEq(uint256(beforeSnapshot[1]), uint160(TREASURY), 'GHO Treasury address not set');

    // Perform the mock upgrade
    address gsmV2 = address(
      new MockGsmV2(address(GHO_TOKEN), address(USDC_TOKEN), address(GHO_GSM_FIXED_PRICE_STRATEGY))
    );
    bytes memory data = abi.encodeWithSelector(MockGsmV2.initialize.selector);
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit Upgraded(gsmV2);
    vm.prank(SHORT_EXECUTOR);
    AdminUpgradeabilityProxy(payable(address(GHO_GSM))).upgradeToAndCall(gsmV2, data);

    assertEq(GHO_GSM.GSM_REVISION(), 2, 'Unexpected post-upgrade GSM revision');

    bytes32[] memory afterSnapshot = _getStorageSnapshot();
    // First storage item should be different, the rest the same post-upgrade
    assertTrue(afterSnapshot[0] != beforeSnapshot[0], 'Unexpected lastInitializedRevision');
    for (uint8 i = 1; i < afterSnapshot.length; i++) {
      assertEq(afterSnapshot[i], beforeSnapshot[i], 'Unexpected storage value updated');
    }
  }

  function _getStorageSnapshot() internal view returns (bytes32[] memory) {
    // Snapshot values for lastInitializedRevision (slot 1) and GSM local storage (54-58)
    bytes32[] memory data = new bytes32[](6);
    data[0] = vm.load(address(GHO_GSM), bytes32(uint256(1)));
    data[1] = vm.load(address(GHO_GSM), bytes32(uint256(54)));
    data[2] = vm.load(address(GHO_GSM), bytes32(uint256(55)));
    data[3] = vm.load(address(GHO_GSM), bytes32(uint256(56)));
    data[4] = vm.load(address(GHO_GSM), bytes32(uint256(57)));
    data[5] = vm.load(address(GHO_GSM), bytes32(uint256(58)));
    return data;
  }
}
