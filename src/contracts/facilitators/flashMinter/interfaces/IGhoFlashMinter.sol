pragma solidity ^0.8.0;

import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';

interface IGhoFlashMinter is IERC3156FlashLender {
  /**
   * @dev emitted when the flash fee is updated
   * @param oldFee The old fee
   * @param newFee The new fee
   */
  event FeeUpdated(uint256 oldFee, uint256 newFee);

  /**
   * @dev emitted when a FlashMint occurs
   * @param receiver The receiver of the FlashMinted tokens, and the receiver of the callback.
   * @param initiator The address initiating the FlashMint
   * @param asset The asset being FlashMinted. Always GHO.
   * @param amount The pricipal being FlashMinted
   * @param fee The fee returned ontop of the principal
   */
  event FlashMint(address receiver, address initiator, address asset, uint256 amount, uint256 fee);

  /**
   * @notice Update the flash fee
   * @param newFee The percentage of the flashmint `amount` that needs to be repaid, in addition to `amount`. 1 == 0.01 %.
   */
  function updateFee(uint256 newFee) external;

  /**
   * @notice The percentage of each flash mint taken as a fee
   * @return The percentage of the flashmint `amount` that needs to be repaid, in addition to `amount`. 1 == 0.01 %.
   */
  function getFee() external view returns (uint256);
}
