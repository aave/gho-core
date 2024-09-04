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

/**
 * @title IRedemption
 */
interface IRedemption {
  /**
   * @notice The asset being redeemed.
   * @return The address of the asset token.
   */
  function asset() external view returns (address);

  /**
   * @notice The liquidity token that the asset is being redeemed for.
   * @return The address of the liquidity token.
   */
  function liquidity() external view returns (address);

  /**
   * @notice Redeems an amount of asset for liquidity
   * @param amount The amount of the asset token to redeem
   */
  function redeem(uint256 amount) external;
}
