pragma solidity ^0.8.0;

import './IERC3156FlashLender.sol';

/**
 * @title IGhoFlashMinter
 * @author Aave
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
  event FlashMint(address receiver, address initiator, address asset, uint256 amount, uint256 fee);

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
