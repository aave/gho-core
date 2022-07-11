// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.6.0 <0.9.0;

import {IERC20} from '../../aave-core/dependencies/openzeppelin/contracts/IERC20.sol';

interface IERC20WithPermit is IERC20 {
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;
}
