/**
 * Copyright 2024 Circle Internet Financial, LTD. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity ^0.8.10;

import {IRedemption} from '../../contracts/facilitators/gsm/dependencies/circle/IRedemption.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**
 * @title MockRedemption
 * @dev Asset token is ERC20-compatible
 * @dev Liquidity token is ERC20-compatible
 */
contract MockRedemption is IRedemption {
  using SafeERC20 for IERC20;

  /**
   * @inheritdoc IRedemption
   */
  address public immutable asset;

  /**
   * @inheritdoc IRedemption
   */
  address public immutable liquidity;

  /**
   * @param _asset Address of asset token
   * @param _liquidity Address of liquidity token
   */
  constructor(address _asset, address _liquidity) {
    asset = _asset;
    liquidity = _liquidity;
  }

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

  /**
   * @inheritdoc IRedemption
   */
  function redeem(uint256 amount) external {
    // Intentionally left blank.
  }
}
