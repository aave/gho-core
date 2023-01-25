// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IGhoFacilitator} from '../../../gho/interfaces/IGhoFacilitator.sol';

/**
 * @title IGhoFlashMinter
 * @author Aave
 * @notice Defines the behavior of the GHO Flash Minter
 */
interface IGhoFlashMinter is IERC3156FlashLender, IGhoFacilitator {
  /**
   * @dev Emitted when the percentage fee is updated
   * @param oldFee The old fee (in bps)
   * @param newFee The new fee (in bps)
   */
  event FeeUpdated(uint256 oldFee, uint256 newFee);

  /**
   * @dev Emitted when a FlashMint occurs
   * @param receiver The receiver of the FlashMinted tokens (it is also the receiver of the callback)
   * @param initiator The address initiating the FlashMint
   * @param asset The asset being FlashMinted. Always GHO.
   * @param amount The principal being FlashMinted
   * @param fee The fee returned on top of the principal
   */
  event FlashMint(
    address indexed receiver,
    address indexed initiator,
    address asset,
    uint256 indexed amount,
    uint256 fee
  );

  /**
   * @notice Returns the address of the Aave Pool Addresses Provider contract
   * @return The address of the PoolAddressesProvider
   */
  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  /**
   * @notice Returns the maximum value the fee can be set to
   * @return The maximum percentage fee of the flash-minted amount that the flashFee can be set to (in bps).
   */
  function MAX_FEE() external view returns (uint256);

  /**
   * @notice Updates the percentage fee. It is the percentage of the flash-minted amount that needs to be repaid.
   * @dev The fee is expressed in bps. A value of 100, results in 1.00%
   * @param newFee The new percentage fee (in bps)
   */
  function updateFee(uint256 newFee) external;

  /**
   * @notice Returns the percentage of each flash mint taken as a fee
   * @return The percentage fee of the flash-minted amount that needs to be repaid, on top of the principal (in bps).
   */
  function getFee() external view returns (uint256);
}
