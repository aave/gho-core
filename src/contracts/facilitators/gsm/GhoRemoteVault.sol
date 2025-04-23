// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IGhoRemoteVault} from './interfaces/IGhoRemoteVault.sol';

contract GhoRemoteVault is IGhoRemoteVault, AccessControl, VersionedInitializable {
  /// @inheritdoc IGhoRemoteVault
  bytes32 public constant FUNDS_ADMIN_ROLE = 'FUNDS_ADMIN';

  /// @inheritdoc IGhoRemoteVault
  address public immutable GHO_TOKEN;

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
   * @param ghoAddress Address of GHO token on the remote chain
   */
  constructor(address ghoAddress) {
    require(ghoAddress != address(0), 'INVALID_ZERO_ADDRESS');

    GHO_TOKEN = ghoAddress;
  }

  /**
   * @notice GhoRemoteVault initializer
   * @param admin The address of the default admin role
   */
  function initialize(address admin) external initializer {
    require(admin != address(0), 'ZERO_ADDRESS_NOT_VALID');
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IGhoRemoteVault
  function withdrawGho(uint256 amount) external onlyFundsAdmin {
    _ghoWithdrawn[msg.sender] += amount;
    IERC20(GHO_TOKEN).transfer(msg.sender, amount);
  }

  /// @inheritdoc IGhoRemoteVault
  function returnGho(uint256 amount) external onlyFundsAdmin {
    _ghoWithdrawn[msg.sender] -= amount;
    IERC20(GHO_TOKEN).transferFrom(msg.sender, address(this), amount);
  }

  function bridgeGho(uint256 amount) external onlyFundsAdmin {
    // Intentionally left bank
  }

  /// @inheritdoc IGhoRemoteVault
  function getWithdrawnGho(address withdrawer) external view returns (uint256) {
    return _ghoWithdrawn[withdrawer];
  }

  /// @inheritdoc IGhoRemoteVault
  function GHO_REMOTE_VAULT_REVISION() public pure virtual override returns (uint256) {
    return 1;
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return GHO_REMOTE_VAULT_REVISION();
  }

  function _onlyFundsAdmin() internal view returns (bool) {
    return hasRole(FUNDS_ADMIN_ROLE, msg.sender);
  }
}
