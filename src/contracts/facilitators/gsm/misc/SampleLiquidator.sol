// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IGsm} from '../interfaces/IGsm.sol';

/**
 * @title SampleLiquidator
 * @author Aave
 * @notice Minimal Last Resort Liquidator that can serve as sample contract
 */
contract SampleLiquidator is Ownable {
  /**
   * @notice Triggers seizure of a GSM, sending seized funds to a recipient
   * @param gsm Address of the GSM
   * @param recipient Address of the recipient of seized funds
   */
  function triggerSeize(address gsm, address recipient) external onlyOwner {
    IGsm(gsm).seize(recipient);
  }
}
