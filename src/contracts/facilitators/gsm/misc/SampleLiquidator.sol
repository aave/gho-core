// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IGhoToken} from '../../../gho/interfaces/IGhoToken.sol';
import {IGsm} from '../interfaces/IGsm.sol';

/**
 * @title SampleLiquidator
 * @author Aave
 * @notice Minimal Liquidator that can serve as sample contract
 */
contract SampleLiquidator is Ownable {
  /**
   * @notice Triggers seizure of a GSM, sending seized funds to the Treasury
   * @param gsm Address of the GSM
   * @return The amount of underlying asset seized and transferred to Treasury
   */
  function triggerSeize(address gsm) external onlyOwner returns (uint256) {
    return IGsm(gsm).seize();
  }

  /**
   * @notice Pulls GHO from the sender and burns it via the GSM
   * @param gsm Address of the GSM
   * @param amount The maximum amount of GHO to be burned
   * @return The amount of GHO burned
   */
  function triggerBurnAfterSeize(address gsm, uint256 amount) external onlyOwner returns (uint256) {
    IERC20 ghoToken = IERC20(IGsm(gsm).GHO_TOKEN());
    uint256 usedGho = IGsm(gsm).getUsedGho();
    if (amount > usedGho) {
      amount = usedGho;
    }
    ghoToken.transferFrom(msg.sender, address(this), amount);
    ghoToken.approve(gsm, amount);
    return IGsm(gsm).burnAfterSeize(amount);
  }
}
