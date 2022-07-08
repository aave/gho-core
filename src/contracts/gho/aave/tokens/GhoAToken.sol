// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IERC20} from '../../dependencies/aave-core/dependencies/openzeppelin/contracts/IERC20.sol';
import {SafeERC20} from '../../dependencies/aave-core/dependencies/openzeppelin/contracts/SafeERC20.sol';
import {ILendingPool} from '../../dependencies/aave-core/interfaces/ILendingPool.sol';
import {WadRayMath} from '../../dependencies/aave-core/protocol/libraries/math/WadRayMath.sol';
import {Errors} from '../../dependencies/aave-core/protocol/libraries/helpers/Errors.sol';
import {VersionedInitializable} from '../../dependencies/aave-core/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IncentivizedERC20} from '../../dependencies/aave-tokens/IncentivizedERC20.sol';
import {IAaveIncentivesController} from '../../dependencies/aave-tokens/interfaces/IAaveIncentivesController.sol';

// Gho Imports
import {IGhoAToken} from './interfaces/IGhoAToken.sol';
import {ILendingPoolAddressesProvider} from '../../dependencies/aave-core/interfaces/ILendingPoolAddressesProvider.sol';
import {GhoVariableDebtToken} from './GhoVariableDebtToken.sol';
import {IMintableERC20} from '../../interfaces/IMintableERC20.sol';
import {IBurnableERC20} from '../../interfaces/IBurnableERC20.sol';

/**
 * @title Aave ERC20 AToken
 * @dev Implementation of the interest bearing token for the Aave protocol
 * @author Aave
 */
contract GhoAToken is VersionedInitializable, IncentivizedERC20, IGhoAToken {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  bytes public constant EIP712_REVISION = bytes('1');
  bytes32 internal constant EIP712_DOMAIN =
    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');
  bytes32 public constant PERMIT_TYPEHASH =
    keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

  uint256 public constant ATOKEN_REVISION = 0x1;
  address public immutable UNDERLYING_ASSET_ADDRESS;
  address public immutable RESERVE_TREASURY_ADDRESS;
  ILendingPool public immutable POOL;

  /// @dev owner => next valid nonce to submit with permit()
  mapping(address => uint256) public _nonces;

  bytes32 public DOMAIN_SEPARATOR;

  // NEW Gho STORAGE
  address public immutable ADDRESSES_PROVIDER;
  GhoVariableDebtToken internal _ghoVariableDebtToken;
  address internal _ghoTreasury;

  modifier onlyLendingPool() {
    require(_msgSender() == address(POOL), Errors.CT_CALLER_MUST_BE_LENDING_POOL);
    _;
  }

  /**
   * @dev Only pool admin can call functions marked by this modifier.
   **/
  modifier onlyLendingPoolAdmin() {
    ILendingPoolAddressesProvider addressesProvider = POOL.getAddressesProvider();
    require(addressesProvider.getPoolAdmin() == msg.sender, Errors.CALLER_NOT_POOL_ADMIN);
    _;
  }

  constructor(
    ILendingPool pool,
    address underlyingAssetAddress,
    address reserveTreasuryAddress,
    string memory tokenName,
    string memory tokenSymbol,
    address incentivesController,
    address addressesProvider
  ) public IncentivizedERC20(tokenName, tokenSymbol, 18, incentivesController) {
    POOL = pool;
    UNDERLYING_ASSET_ADDRESS = underlyingAssetAddress;
    RESERVE_TREASURY_ADDRESS = reserveTreasuryAddress;
  }

  function getRevision() internal pure virtual override returns (uint256) {
    return ATOKEN_REVISION;
  }

  function initialize(
    uint8 underlyingAssetDecimals,
    string calldata tokenName,
    string calldata tokenSymbol
  ) external virtual initializer {
    uint256 chainId;

    //solium-disable-next-line
    assembly {
      chainId := chainid()
    }

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        EIP712_DOMAIN,
        keccak256(bytes(tokenName)),
        keccak256(EIP712_REVISION),
        chainId,
        address(this)
      )
    );

    _setName(tokenName);
    _setSymbol(tokenSymbol);
    _setDecimals(underlyingAssetDecimals);

    emit Initialized(
      UNDERLYING_ASSET_ADDRESS,
      address(POOL),
      RESERVE_TREASURY_ADDRESS,
      address(_incentivesController),
      underlyingAssetDecimals,
      tokenName,
      tokenSymbol,
      ''
    );
  }

  /**
   * @dev Burns aTokens from `user` and sends the equivalent amount of underlying to `receiverOfUnderlying`
   * - Only callable by the LendingPool, as extra state updates there need to be managed
   * @param user The owner of the aTokens, getting them burned
   * @param receiverOfUnderlying The address that will receive the underlying
   * @param amount The amount being burned
   * @param index The new liquidity index of the reserve
   **/
  function burn(
    address user,
    address receiverOfUnderlying,
    uint256 amount,
    uint256 index
  ) external override onlyLendingPool {
    revert('OPERATION_NOT_PERMITTED');
  }

  /**
   * @dev Mints `amount` aTokens to `user`
   * - Only callable by the LendingPool, as extra state updates there need to be managed
   * @param user The address receiving the minted tokens
   * @param amount The amount of tokens getting minted
   * @param index The new liquidity index of the reserve
   * @return `true` if the the previous balance of the user was 0
   */
  function mint(
    address user,
    uint256 amount,
    uint256 index
  ) external override onlyLendingPool returns (bool) {
    revert('OPERATION_NOT_PERMITTED');
  }

  /**
   * @dev Mints aTokens to the reserve treasury
   * - Only callable by the LendingPool
   * @param amount The amount of tokens getting minted
   * @param index The new liquidity index of the reserve
   */
  function mintToTreasury(uint256 amount, uint256 index) external override onlyLendingPool {
    if (amount == 0) {
      return;
    }

    // Compared to the normal mint, we don't check for rounding errors.
    // The amount to mint can easily be very small since it is a fraction of the interest ccrued.
    // In that case, the treasury will experience a (very small) loss, but it
    // wont cause potentially valid transactions to fail.
    _mint(RESERVE_TREASURY_ADDRESS, amount.rayDiv(index));

    emit Transfer(address(0), RESERVE_TREASURY_ADDRESS, amount);
    emit Mint(RESERVE_TREASURY_ADDRESS, amount, index);
  }

  /**
   * @dev Transfers aTokens in the event of a borrow being liquidated, in case the liquidators reclaims the aToken
   * - Only callable by the LendingPool
   * @param from The address getting liquidated, current owner of the aTokens
   * @param to The recipient
   * @param value The amount of tokens getting transferred
   **/
  function transferOnLiquidation(
    address from,
    address to,
    uint256 value
  ) external override onlyLendingPool {
    // Being a normal transfer, the Transfer() and BalanceTransfer() are emitted
    // so no need to emit a specific event here
    _transfer(from, to, value, false);

    emit Transfer(from, to, value);
  }

  /**
   * @dev Calculates the balance of the user: principal balance + interest generated by the principal
   * @param user The user whose balance is calculated
   * @return The balance of the user
   **/
  function balanceOf(address user)
    public
    view
    override(IncentivizedERC20, IERC20)
    returns (uint256)
  {
    return super.balanceOf(user).rayMul(POOL.getReserveNormalizedIncome(UNDERLYING_ASSET_ADDRESS));
  }

  /**
   * @dev Returns the scaled balance of the user. The scaled balance is the sum of all the
   * updated stored balance divided by the reserve's liquidity index at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   **/
  function scaledBalanceOf(address user) external view override returns (uint256) {
    return super.balanceOf(user);
  }

  /**
   * @dev Returns the scaled balance of the user and the scaled total supply.
   * @param user The address of the user
   * @return The scaled balance of the user
   * @return The scaled balance and the scaled total supply
   **/
  function getScaledUserBalanceAndSupply(address user)
    external
    view
    override
    returns (uint256, uint256)
  {
    return (super.balanceOf(user), super.totalSupply());
  }

  /**
   * @dev calculates the total supply of the specific aToken
   * since the balance of every single user increases over time, the total supply
   * does that too.
   * @return the current total supply
   **/
  function totalSupply() public view override(IncentivizedERC20, IERC20) returns (uint256) {
    return type(uint256).max;
  }

  /**
   * @dev Returns the address of the incentives controller contract
   **/
  function getIncentivesController() external view override returns (IAaveIncentivesController) {
    return _incentivesController;
  }

  /**
   * @dev Returns the scaled total supply of the variable debt token. Represents sum(debt/index)
   * @return the scaled total supply
   **/
  function scaledTotalSupply() public view virtual override returns (uint256) {
    return super.totalSupply();
  }

  /**
   * @dev Mints GHO to `target` address Used by the LendingPool to transfer
   * assets in borrow(), withdraw() and flashLoan()
   * @param target The recipient of the GHO
   * @param amount The amount getting minted
   * @return The amount minted
   **/
  function transferUnderlyingTo(address target, uint256 amount)
    external
    override
    onlyLendingPool
    returns (uint256)
  {
    IMintableERC20(UNDERLYING_ASSET_ADDRESS).mint(target, amount);
    return amount;
  }

  /**
   * @dev Invoked to execute actions on the aToken side after a repayment.
   * @param user The user executing the repayment
   * @param amount The amount getting repaid
   **/
  function handleRepayment(address user, uint256 amount) external override onlyLendingPool {
    uint256 balanceFromInterest = _ghoVariableDebtToken.getBalanceFromInterest(user);
    if (amount <= balanceFromInterest) {
      _repayInterest(user, amount);
    } else {
      _repayInterest(user, balanceFromInterest);
      IBurnableERC20(UNDERLYING_ASSET_ADDRESS).burn(address(this), amount - balanceFromInterest);
    }
  }

  /**
   * @dev implements the permit function as for
   * https://github.com/ethereum/EIPs/blob/8a34d644aacf0f9f8f00815307fd7dd5da07655f/EIPS/eip-2612.md
   * @param owner The owner of the funds
   * @param spender The spender
   * @param value The amount
   * @param deadline The deadline timestamp, type(uint256).max for max deadline
   * @param v Signature param
   * @param s Signature param
   * @param r Signature param
   */
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(owner != address(0), 'INVALID_OWNER');
    //solium-disable-next-line
    require(block.timestamp <= deadline, 'INVALID_EXPIRATION');
    uint256 currentValidNonce = _nonces[owner];
    bytes32 digest = keccak256(
      abi.encodePacked(
        '\x19\x01',
        DOMAIN_SEPARATOR,
        keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, currentValidNonce, deadline))
      )
    );
    require(owner == ecrecover(digest, v, r, s), 'INVALID_SIGNATURE');
    _nonces[owner] = currentValidNonce.add(1);
    _approve(owner, spender, value);
  }

  /**
   * @dev Transfers the aTokens between two users. Validates the transfer
   * (ie checks for valid HF after the transfer) if required
   * @param from The source address
   * @param to The destination address
   * @param amount The amount getting transferred
   * @param validate `true` if the transfer needs to be validated
   **/
  function _transfer(
    address from,
    address to,
    uint256 amount,
    bool validate
  ) internal {
    uint256 index = POOL.getReserveNormalizedIncome(UNDERLYING_ASSET_ADDRESS);

    uint256 fromBalanceBefore = super.balanceOf(from).rayMul(index);
    uint256 toBalanceBefore = super.balanceOf(to).rayMul(index);

    super._transfer(from, to, amount.rayDiv(index));

    if (validate) {
      POOL.finalizeTransfer(
        UNDERLYING_ASSET_ADDRESS,
        from,
        to,
        amount,
        fromBalanceBefore,
        toBalanceBefore
      );
    }

    emit BalanceTransfer(from, to, amount, index);
  }

  /// @inheritdoc IGhoAToken
  function setVariableDebtToken(address ghoVariableDebtAddress)
    external
    override
    onlyLendingPoolAdmin
  {
    require(address(_ghoVariableDebtToken) == address(0), 'VARIABLE_DEBT_TOKEN_ALREADY_SET');
    _ghoVariableDebtToken = GhoVariableDebtToken(ghoVariableDebtAddress);
    emit VariableDebtTokenSet(ghoVariableDebtAddress);
  }

  /// @inheritdoc IGhoAToken
  function getVariableDebtToken() external view override returns (address) {
    return address(_ghoVariableDebtToken);
  }

  /// @inheritdoc IGhoAToken
  function setTreasury(address newTreasury) external override onlyLendingPoolAdmin {
    address previousTreasury = _ghoTreasury;
    _ghoTreasury = newTreasury;
    emit TreasuryUpdated(previousTreasury, newTreasury);
  }

  /// @inheritdoc IGhoAToken
  function getTreasury() external view override returns (address) {
    return _ghoTreasury;
  }

  /**
   * @dev Overrides the parent _transfer to force validated transfer() and transferFrom()
   * @param from The source address
   * @param to The destination address
   * @param amount The amount getting transferred
   **/
  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    _transfer(from, to, amount, true);
  }

  function _repayInterest(address user, uint256 amount) internal {
    IERC20(UNDERLYING_ASSET_ADDRESS).transfer(_ghoTreasury, amount);
    _ghoVariableDebtToken.decreaseBalanceFromInterest(user, amount);
  }
}
