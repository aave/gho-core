// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import {IACLManager} from '@aave/core-v3/contracts/interfaces/IACLManager.sol';
import {PoolAddressesProvider} from '@aave/core-v3/contracts/protocol/configuration/PoolAddressesProvider.sol';
import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';

import {IGhoTokenWithErc20} from './interfaces/IGhoTokenWithErc20.sol';
import {IGhoFlashMinter} from './interfaces/IGhoFlashMinter.sol';

/**
 * @title GhoFlashMinter
 * @author Aave
 * @notice Contract that enables FlashMinting of GHO.
 * @dev Based heavily on the EIP3156 reference implementation
 */
contract GhoFlashMinter is IGhoFlashMinter {
  /**
   * @dev Hash of `ERC3156FlashBorrower.onFlashLoan` that must be returned by `onFlashLoan` callback
   */
  bytes32 public constant CALLBACK_SUCCESS = keccak256('ERC3156FlashBorrower.onFlashLoan');

  /**
   * @dev Percentage fee of the flash-minted amount used to calculate the flash fee to charge
   * Expressed in bps. A value of 100 results in 1.00%
   */
  uint256 private _fee;

  IGhoTokenWithErc20 private _ghoToken;
  address private _ghoTreasury;
  PoolAddressesProvider private immutable _addressesProvider;

  /**
   * @dev Only pool admin can call functions marked by this modifier.
   **/
  modifier onlyPoolAdmin() {
    IACLManager aclManager = IACLManager(_addressesProvider.getACLManager());
    require(aclManager.isPoolAdmin(msg.sender), 'CALLER_NOT_POOL_ADMIN');
    _;
  }

  /**
   * @dev Constructor
   * @param ghoToken The address of the GHO token contract
   * @param ghoTreasury The address of the GHO treasury
   * @param fee The percentage of the flash-mint amount that needs to be repaid, on top of the principal (in bps)
   * @param addressesProvider The address of the Aave PoolAddressesProvider
   */
  constructor(
    address ghoToken,
    address ghoTreasury,
    uint256 fee,
    address addressesProvider
  ) {
    _ghoToken = IGhoTokenWithErc20(ghoToken);
    _ghoTreasury = ghoTreasury;
    _fee = fee;
    _addressesProvider = PoolAddressesProvider(addressesProvider);
  }

  // @inheritdoc IERC3156FlashLender
  function maxFlashLoan(address token) external view override returns (uint256) {
    IGhoTokenWithErc20.Facilitator memory flashMinterFacilitator = _ghoToken.getFacilitator(
      address(this)
    );
    return flashMinterFacilitator.bucket.maxCapacity - flashMinterFacilitator.bucket.level;
  }

  // @inheritdoc IERC3156FlashLender
  function flashLoan(
    IERC3156FlashBorrower receiver,
    address token,
    uint256 amount,
    bytes calldata data
  ) external override returns (bool) {
    require(token == address(_ghoToken), 'FlashMinter: Unsupported currency');
    uint256 fee = _flashFee(token, amount);
    _ghoToken.mint(address(receiver), amount);
    require(
      receiver.onFlashLoan(msg.sender, token, amount, fee, data) == CALLBACK_SUCCESS,
      'FlashMinter: Callback failed'
    );
    uint256 _allowance = _ghoToken.allowance(address(receiver), address(this));
    require(_allowance >= (amount + fee), 'FlashMinter: Repay not approved');

    _ghoToken.transferFrom(address(receiver), address(this), amount + fee);
    _ghoToken.transfer(_ghoTreasury, fee);
    _ghoToken.burn(amount);

    emit FlashMint(address(receiver), msg.sender, token, amount, fee);

    return true;
  }

  // @inheritdoc IERC3156FlashLender
  function flashFee(address token, uint256 amount) external view override returns (uint256) {
    require(token == address(_ghoToken), 'FlashMinter: Unsupported currency');
    return _flashFee(token, amount);
  }

  // @inheritdoc IGhoFlashMinter
  function updateFee(uint256 newFee) external onlyPoolAdmin {
    uint256 oldFee = _fee;
    _fee = newFee;
    emit FeeUpdated(oldFee, newFee);
  }

  // @inheritdoc IGhoFlashMinter
  function getFee() external view returns (uint256) {
    return _fee;
  }

  /**
   * @notice Returns the fee to charge for a given flashloan.
   * @dev Internal function with no checks.
   * @param token The address of the asset to be borrowed.
   * @param amount The amount of tokens to be borrowed.
   * @return The amount of `token` to be charged for the flashloan, on top of the returned principal.
   */
  function _flashFee(address token, uint256 amount) internal view returns (uint256) {
    return (amount * _fee) / 10000;
  }
}