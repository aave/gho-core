// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IAaveIncentivesController {
  function handleAction(
    address user,
    uint256 userBalance,
    uint256 totalSupply
  ) external;
}
