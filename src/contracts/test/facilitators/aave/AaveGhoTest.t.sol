// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

// test dependencies
import {AaveV2MarketHelper} from './helpers/AaveV2MarketHelper.sol';

// GHO imports
import {GhoToken} from '../../../token/GhoToken.sol';

// helpers
import 'ds-test/test.sol';
import 'forge-std/console.sol';

interface Vm {
  function expectEmit(
    bool,
    bool,
    bool,
    bool
  ) external;

  function prank(address) external;

  function expectRevert(bytes calldata) external;

  function startPrank(address) external;

  function stopPrank() external;
}

contract GhoTokenTest is DSTest, AaveV2MarketHelper {
  uint256 public constant one = 1;

  function setUp() public {}

  function test1() public {
    console.log(one);
  }

  function test2() public {
    uint256 two = 2;
    uint256 too = 2;
    assertEq(two, too);
  }
}
