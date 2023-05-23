// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoSteward is TestGhoBase {
  function testSetReserveInterestRateStrategy() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    GhoInterestRateStrategy newInterestStrategy = new GhoInterestRateStrategy(2e25);
    vm.expectEmit(true, true, true, true, address(CONFIGURATOR));
    emit ReserveInterestRateStrategyChanged(
      address(GHO_TOKEN),
      oldInterestStrategy,
      address(newInterestStrategy)
    );
    GHO_MANAGER.setReserveInterestRateStrategyAddress(address(newInterestStrategy));
  }

  function testRevertUnauthorizedSetReserveInterestRateStrategy() public {
    GhoInterestRateStrategy newInterestStrategy = new GhoInterestRateStrategy(2e25);
    vm.prank(ALICE);
    vm.expectRevert('Ownable: caller is not the owner');
    GHO_MANAGER.setReserveInterestRateStrategyAddress(address(newInterestStrategy));
  }

  function testSetVariableBorrowRate() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    vm.expectEmit(true, true, true, false, address(CONFIGURATOR));
    emit ReserveInterestRateStrategyChanged(
      address(GHO_TOKEN),
      oldInterestStrategy,
      address(0) // deployed by GhoSteward
    );
    GHO_MANAGER.setReserveVariableBorrowRate(2e25);
  }

  function testRevertUnauthorizedSetBorrowRate() public {
    vm.prank(ALICE);
    vm.expectRevert('Ownable: caller is not the owner');
    GHO_MANAGER.setReserveVariableBorrowRate(2e25);
  }

  function testSetFacilitatorBucketCapacity() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.expectEmit(true, true, true, true, address(GHO_TOKEN));
    emit FacilitatorBucketCapacityUpdated(address(GHO_ATOKEN), oldCapacity, 1e6);
    GHO_MANAGER.setFacilitatorBucketCapacity(1e6);
  }

  function testRevertUnauthorizedSetFacilitatorBucketCapacity() public {
    vm.prank(ALICE);
    vm.expectRevert('Ownable: caller is not the owner');
    GHO_MANAGER.setFacilitatorBucketCapacity(1e6);
  }
}
