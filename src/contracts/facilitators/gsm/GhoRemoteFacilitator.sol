// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IGhoToken} from 'src/contracts/gho/interfaces/IGhoToken.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

contract GhoRemoteFacilitator is Ownable {
  address public immutable GHO;

  /**
   * @dev Constructor
   * @param ghoAddress Address of GHO token on the remote chain
   */
  constructor(address ghoAddress) {
    GHO = ghoAddress;
  }

  /**
   * Mints specified amount of GHO and bridges to remote chain
   * @param receiver Address receiving GHO
   * @param amount Amount of GHO to be minted
   */
  function mintAndBridge(address receiver, uint256 amount) external onlyOwner {
    IGhoToken(GHO).mint(address(receiver), amount);
    // IBridge(receiver).bridge()...
  }

  /**
   * Burns specified amount of GHO
   * @param amount Amount of GHO to be burned
   */
  function burn(uint256 amount) external onlyOwner {
    IGhoToken(GHO).burn(amount);
  }
}
