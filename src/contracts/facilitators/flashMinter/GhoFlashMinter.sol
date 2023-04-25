// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IACLManager} from '@aave/core-v3/contracts/interfaces/IACLManager.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';
import {IGhoToken} from '../../gho/interfaces/IGhoToken.sol';
import {IGhoFacilitator} from '../../gho/interfaces/IGhoFacilitator.sol';
import {IGhoFlashMinter} from './interfaces/IGhoFlashMinter.sol';

/**
 * @title GhoFlashMinter
 * @author Aave
 * @notice Contract that enables FlashMinting of GHO.
 * @dev Based heavily on the EIP3156 reference implementation
 */
contract GhoFlashMinter is IGhoFlashMinter {
  using PercentageMath for uint256;

  // @inheritdoc IGhoFlashMinter
  bytes32 public constant CALLBACK_SUCCESS = keccak256('ERC3156FlashBorrower.onFlashLoan');

  // @inheritdoc IGhoFlashMinter
  uint256 public constant MAX_FEE = 1e4;

  // @inheritdoc IGhoFlashMinter
  IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;

  // @inheritdoc IGhoFlashMinter
  IGhoToken public immutable GHO_TOKEN;

  // The Access Control List manager contract
  IACLManager private immutable ACL_MANAGER;

  // The flashmint fee, expressed in bps (a value of 10000 results in 100.00%)
  uint256 private _fee;

  // The GHO treasury, the recipient of fee distributions
  address private _ghoTreasury;

  /**
   * @dev Only pool admin can call functions marked by this modifier.
   */
  modifier onlyPoolAdmin() {
    require(ACL_MANAGER.isPoolAdmin(msg.sender), 'CALLER_NOT_POOL_ADMIN');
    _;
  }

  /**
   * @dev Constructor
   * @param ghoToken The address of the GHO token contract
   * @param ghoTreasury The address of the GHO treasury
   * @param fee The percentage of the flash-mint amount that needs to be repaid, on top of the principal (in bps)
   * @param addressesProvider The address of the Aave PoolAddressesProvider
   */
  constructor(address ghoToken, address ghoTreasury, uint256 fee, address addressesProvider) {
    require(fee <= MAX_FEE, 'FlashMinter: Fee out of range');
    GHO_TOKEN = IGhoToken(ghoToken);
    _ghoTreasury = ghoTreasury;
    _fee = fee;
    ADDRESSES_PROVIDER = IPoolAddressesProvider(addressesProvider);
    ACL_MANAGER = IACLManager(IPoolAddressesProvider(addressesProvider).getACLManager());
  }

  /// @inheritdoc IERC3156FlashLender
  function flashLoan(
    IERC3156FlashBorrower receiver,
    address token,
    uint256 amount,
    bytes calldata data
  ) external override returns (bool) {
    require(token == address(GHO_TOKEN), 'FlashMinter: Unsupported currency');

    uint256 fee = ACL_MANAGER.isFlashBorrower(msg.sender) ? 0 : _flashFee(amount);
    GHO_TOKEN.mint(address(receiver), amount);

    require(
      receiver.onFlashLoan(msg.sender, address(GHO_TOKEN), amount, fee, data) == CALLBACK_SUCCESS,
      'FlashMinter: Callback failed'
    );

    GHO_TOKEN.transferFrom(address(receiver), address(this), amount + fee);
    GHO_TOKEN.burn(amount);

    emit FlashMint(address(receiver), msg.sender, address(GHO_TOKEN), amount, fee);

    return true;
  }

  /// @inheritdoc IGhoFacilitator
  function distributeFeesToTreasury() external override {
    uint256 balance = GHO_TOKEN.balanceOf(address(this));
    GHO_TOKEN.transfer(_ghoTreasury, balance);
    emit FeesDistributedToTreasury(_ghoTreasury, address(GHO_TOKEN), balance);
  }

  // @inheritdoc IGhoFlashMinter
  function updateFee(uint256 newFee) external override onlyPoolAdmin {
    require(newFee <= MAX_FEE, 'FlashMinter: Fee out of range');
    uint256 oldFee = _fee;
    _fee = newFee;
    emit FeeUpdated(oldFee, newFee);
  }

  /// @inheritdoc IGhoFacilitator
  function updateGhoTreasury(address newGhoTreasury) external override onlyPoolAdmin {
    address oldGhoTreasury = _ghoTreasury;
    _ghoTreasury = newGhoTreasury;
    emit GhoTreasuryUpdated(oldGhoTreasury, newGhoTreasury);
  }

  /// @inheritdoc IERC3156FlashLender
  function maxFlashLoan(address token) external view override returns (uint256) {
    if (token != address(GHO_TOKEN)) {
      return 0;
    } else {
      IGhoToken.Facilitator memory flashMinterFacilitator = GHO_TOKEN.getFacilitator(address(this));
      uint256 capacity = flashMinterFacilitator.bucketCapacity;
      uint256 level = flashMinterFacilitator.bucketLevel;
      return capacity > level ? capacity - level : 0;
    }
  }

  /// @inheritdoc IERC3156FlashLender
  function flashFee(address token, uint256 amount) external view override returns (uint256) {
    require(token == address(GHO_TOKEN), 'FlashMinter: Unsupported currency');
    return ACL_MANAGER.isFlashBorrower(msg.sender) ? 0 : _flashFee(amount);
  }

  /// @inheritdoc IGhoFlashMinter
  function getFee() external view override returns (uint256) {
    return _fee;
  }

  /// @inheritdoc IGhoFacilitator
  function getGhoTreasury() external view override returns (address) {
    return _ghoTreasury;
  }

  /**
   * @notice Returns the fee to charge for a given flashloan.
   * @dev Internal function with no checks.
   * @param amount The amount of tokens to be borrowed.
   * @return The amount of `token` to be charged for the flashloan, on top of the returned principal.
   */
  function _flashFee(uint256 amount) internal view returns (uint256) {
    return amount.percentMul(_fee);
  }
}
