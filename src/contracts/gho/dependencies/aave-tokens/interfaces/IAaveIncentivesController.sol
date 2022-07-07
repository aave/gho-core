// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

interface IAaveIncentivesController {
  function handleAction(
    address user,
    uint256 userBalance,
    uint256 totalSupply
  ) external;
}
