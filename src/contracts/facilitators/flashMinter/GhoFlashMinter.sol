pragma solidity ^0.8.0;

import '@aave/core-v3/contracts/protocol/configuration/ACLManager.sol';
import '@aave/core-v3/contracts/protocol/configuration/PoolAddressesProvider.sol';

import './interfaces/IERC3156FlashBorrower.sol';
import './interfaces/IERC3156FlashLender.sol';
import './interfaces/IGhoTokenWithErc20.sol';
import './interfaces/IGhoFlashMinter.sol';

/**
 * @title GhoFlashMinter
 * @author Aave
 * @notice Based heavily on the EIP3156 reference implementation by Alberto Cuesta Cañada
 * @dev Contract that enables FlashMinting of GHO.
 */
contract GhoFlashMinter is IGhoFlashMinter {
  bytes32 public constant CALLBACK_SUCCESS = keccak256('ERC3156FlashBorrower.onFlashLoan');
  uint256 private _fee; //  1 == 0.01 %.

  IGhoTokenWithErc20 private _ghoToken;
  address private _ghoTreasury;
  PoolAddressesProvider private _addressesProvider;

  /**
   * @dev Only pool admin can call functions marked by this modifier.
   **/
  modifier onlyPoolAdmin() {
    IACLManager aclManager = IACLManager(_addressesProvider.getACLManager());
    require(aclManager.isPoolAdmin(msg.sender), 'CALLER_NOT_POOL_ADMIN');
    _;
  }

  /**
   * @param ghoToken The address of the ghoToken contract
   * @param ghoTreasury The address of the ghoTreasury
   * @param fee The percentage of the flashmint `amount` that needs to be repaid, in addition to `amount`. 1 == 0.01 %.
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
    IGhoToken.Facilitator memory flashMinterFacilitator = _ghoToken.getFacilitator(address(this));
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
   * @dev The fee to be charged for a given loan. Internal function with no checks.
   * @param token The loan currency.
   * @param amount The amount of tokens lent.
   * @return The amount of `token` to be charged for the loan, on top of the returned principal.
   */
  function _flashFee(address token, uint256 amount) internal view returns (uint256) {
    return (amount * _fee) / 10000;
  }
}
