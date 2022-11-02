// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IGhoToken} from '../../../gho/interfaces/IGhoToken.sol';

interface IGhoTokenWithErc20 is IERC20, IGhoToken {}
