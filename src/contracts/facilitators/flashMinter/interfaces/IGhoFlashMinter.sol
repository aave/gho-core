// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';

/**
 * @title IGhoFlashMinter
 * @author Aavegit a
 * @notice Defines the behavior of the GHO Flash Minter
 */
interface IGhoFlashMinter is IERC3156FlashLender {
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
   * @notice Distribute accumulated fees to the GHO treasury
   */
  function distributeToTreasury() external;

  /**
   * @dev Emitted when GHO treasury address is updated
   * @param oldGhoTreasury The address of the old GhoTreasury
   * @param newGhoTreasury The address of the new GhoTreasury
   **/
  event GhoTreasuryUpdated(address indexed oldGhoTreasury, address indexed newGhoTreasury);

  /**
   * @notice Returns the address of the Aave Pool Addresses Provider contract
   * @return The address of the PoolAddressesProvider
   */
  function ADDRESSES_PROVIDER() external view returns (address);

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

  /**
   * @notice Returns the maximum value the fee can be set to
   * @return The maximum percentage fee of the flash-minted amount that the flashFee can be set to (in bps).
   */
  function MAX_FEE() external view returns (uint256);

  /**
   * @notice Updates the address of the GHO treasury, where interest earned by the protocol is sent
   * @param newGhoTreasury The address of the GhoTreasury
   **/
  function updateGhoTreasury(address newGhoTreasury) external;

  /**
   * @notice Returns the address of the GHO treasury
   * @return The address of the GhoTreasury contract
   **/
  function getGhoTreasury() external view returns (address);
}
