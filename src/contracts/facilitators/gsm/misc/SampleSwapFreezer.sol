// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IGsm} from '../interfaces/IGsm.sol';

/**
 * @title SampleSwapFreezer
 * @author Aave
 * @notice Minimal Swap Freezer that can serve as sample contract
 */
contract SampleSwapFreezer is Ownable {
  /**
   * @notice Triggers freezing of a GSM
   * @param gsm Address of the GSM
   */
  function triggerFreeze(address gsm) external onlyOwner {
    IGsm(gsm).setSwapFreeze(true);
  }

  /**
   * @notice Triggers unfreezing of a GSM
   * @param gsm Address of the GSM
   */
  function triggerUnfreeze(address gsm) external onlyOwner {
    IGsm(gsm).setSwapFreeze(false);
  }
}
