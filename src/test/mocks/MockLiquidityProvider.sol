// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IGsmL2} from '../../contracts/facilitators/gsm/interfaces/IGsmL2.sol';

contract MockLiquidityProvider {
  function provideLiquidity(address gho, address gsm, uint256 amount) external {
    IERC20(gho).approve(gsm, amount);
    IGsmL2(gsm).provideLiquidity(amount);
  }
}
