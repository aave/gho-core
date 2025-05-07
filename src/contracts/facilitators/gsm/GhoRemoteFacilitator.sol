// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IGhoToken} from 'src/contracts/gho/interfaces/IGhoToken.sol';

contract GhoRemoteFacilitator is Ownable {
  /// @notice Address of GHO token
  address public immutable GHO_TOKEN;

  /**
   * @dev Constructor
   * @param ghoAddress Address of GHO token on mainnet
   */
  constructor(address ghoAddress) {
    require(ghoAddress != address(0), 'ZERO_ADDRESS_NOT_VALID');

    GHO_TOKEN = ghoAddress;
  }

  /**
   * Mints specified amount of GHO to specified address
   * @param receiver Address receiving GHO
   * @param amount Amount of GHO to be minted
   */
  function mintAndBridge(address receiver, uint256 amount) external onlyOwner {
    IGhoToken(GHO_TOKEN).mint(address(receiver), amount);
  }

  /**
   * Burns specified amount of GHO
   * @param amount Amount of GHO to be burned
   */
  function burn(uint256 amount) external onlyOwner {
    IGhoToken(GHO_TOKEN).burn(amount);
  }
}
