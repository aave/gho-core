// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {IGhoRemoteVault} from './interfaces/IGhoRemoteVault.sol';

contract GhoRemoteVault is IGhoRemoteVault, AccessControl {
  /// @inheritdoc IGhoRemoteVault
  bytes32 public constant FUNDS_ADMIN_ROLE = 'FUNDS_ADMIN';

  address public immutable GHO;

  /// @dev Mapping to keep track of GHO withdrawn by an address
  mapping(address => uint256) private _ghoWithdrawn;

  /**
   * @dev Throws if the caller does not have the FUNDS_ADMIN role
   */
  modifier onlyFundsAdmin() {
    require(_onlyFundsAdmin(), 'ONLY_FUNDS_ADMIN');
    _;
  }

  /**
   * @dev Constructor
   * @param initialAdmin Address of the initial admin of the contract
   * @param ghoAddress Address of GHO token on the remote chain
   */
  constructor(address initialAdmin, address ghoAddress) {
    require(ghoAddress != address(0), 'INVALID_ZERO_ADDRESS');

    _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    GHO = ghoAddress;
  }

  function withdrawGho(uint256 amount) external onlyFundsAdmin {
    _ghoWithdrawn[msg.sender] += amount;
    IERC20(GHO).transfer(msg.sender, amount);
  }

  function returnGho(uint256 amount) external onlyFundsAdmin {
    _ghoWithdrawn[msg.sender] -= amount;
    IERC20(GHO).transferFrom(msg.sender, address(this), amount);
  }

  function bridgeGho(uint256 amount) external onlyFundsAdmin {
    // Intentionally left bank
  }

  /// @inheritdoc IGhoRemoteVault
  function getWithdrawnGho(address withdrawer) external view returns (uint256) {
    return _ghoWithdrawn[withdrawer];
  }

  function _onlyFundsAdmin() internal view returns (bool) {
    return hasRole(FUNDS_ADMIN_ROLE, msg.sender);
  }
}
