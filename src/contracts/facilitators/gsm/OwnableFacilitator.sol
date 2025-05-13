// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IOwnableFacilitator} from 'src/contracts/facilitators/gsm/interfaces/IOwnableFacilitator.sol';
import {IGhoToken} from 'src/contracts/gho/interfaces/IGhoToken.sol';

/**
 * @title OwnableFacilitator
 * @author Aave/TokenLogic
 * @notice GHO Facilitator used to directly mint GHO to a given address.
 */
contract OwnableFacilitator is Ownable, VersionedInitializable, IOwnableFacilitator {
  /// @inheritdoc IOwnableFacilitator
  address public immutable GHO_TOKEN;

  /**
   * @dev Constructor
   * @param initialOwner Address of the initial owner of the contract
   * @param ghoAddress Address of GHO token on mainnet
   */
  constructor(address initialOwner, address ghoAddress) {
    require(initialOwner != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(ghoAddress != address(0), 'ZERO_ADDRESS_NOT_VALID');

    _transferOwnership(initialOwner);

    GHO_TOKEN = ghoAddress;
  }

  /**
   * @dev Initializer
   * @param newOwner The address of the owner
   */
  function initialize(address newOwner) external initializer {
    require(newOwner != address(0), 'ZERO_ADDRESS_NOT_VALID');
    _transferOwnership(newOwner);
  }

  /// @inheritdoc IOwnableFacilitator
  function mint(address account, uint256 amount) external onlyOwner {
    IGhoToken(GHO_TOKEN).mint(account, amount);
  }

  /// @inheritdoc IOwnableFacilitator
  function burn(uint256 amount) external onlyOwner {
    IGhoToken(GHO_TOKEN).burn(amount);
  }

  /// @inheritdoc IOwnableFacilitator
  function OWNABLE_FACILITATOR_REVISION() public pure virtual override returns (uint256) {
    return 1;
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return OWNABLE_FACILITATOR_REVISION();
  }
}
