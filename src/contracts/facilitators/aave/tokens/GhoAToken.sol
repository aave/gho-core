// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {GPv2SafeERC20} from '@aave/core-v3/contracts/dependencies/gnosis/contracts/GPv2SafeERC20.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {WadRayMath} from '@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {IAToken} from '@aave/core-v3/contracts/interfaces/IAToken.sol';
import {IAaveIncentivesController} from '@aave/core-v3/contracts/interfaces/IAaveIncentivesController.sol';
import {IInitializableAToken} from '@aave/core-v3/contracts/interfaces/IInitializableAToken.sol';
import {ScaledBalanceTokenBase} from '@aave/core-v3/contracts/protocol/tokenization/base/ScaledBalanceTokenBase.sol';
import {IncentivizedERC20} from '@aave/core-v3/contracts/protocol/tokenization/base/IncentivizedERC20.sol';
import {EIP712Base} from '@aave/core-v3/contracts/protocol/tokenization/base/EIP712Base.sol';

// Gho Imports
import {IERC20Burnable} from '../../../gho/interfaces/IERC20Burnable.sol';
import {IERC20Mintable} from '../../../gho/interfaces/IERC20Mintable.sol';
import {IGhoFacilitator} from '../../../gho/interfaces/IGhoFacilitator.sol';
import {IGhoAToken} from './interfaces/IGhoAToken.sol';
import {GhoVariableDebtToken} from './GhoVariableDebtToken.sol';

/**
 * @title Aave ERC20 GhoAToken
 * @author Aave
 * @notice Implementation of the interest bearing token for the Aave protocol
 */
contract GhoAToken is
  VersionedInitializable,
  ScaledBalanceTokenBase,
  EIP712Base,
  IGhoAToken,
  IGhoFacilitator
{
  using WadRayMath for uint256;
  using GPv2SafeERC20 for IERC20;

  bytes32 public constant PERMIT_TYPEHASH =
    keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

  uint256 public constant ATOKEN_REVISION = 0x1;

  address internal _treasury;
  address internal _underlyingAsset;

  // Gho Storage
  GhoVariableDebtToken internal _ghoVariableDebtToken;
  address internal _ghoTreasury;

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return ATOKEN_REVISION;
  }

  /**
   * @dev Constructor.
   * @param pool The address of the Pool contract
   */
  constructor(IPool pool)
    ScaledBalanceTokenBase(pool, 'ATOKEN_IMPL', 'ATOKEN_IMPL', 0)
    EIP712Base()
  {
    // Intentionally left blank
  }

  /// @inheritdoc IInitializableAToken
  function initialize(
    IPool initializingPool,
    address treasury,
    address underlyingAsset,
    IAaveIncentivesController incentivesController,
    uint8 aTokenDecimals,
    string calldata aTokenName,
    string calldata aTokenSymbol,
    bytes calldata params
  ) external override initializer {
    require(initializingPool == POOL, Errors.POOL_ADDRESSES_DO_NOT_MATCH);
    _setName(aTokenName);
    _setSymbol(aTokenSymbol);
    _setDecimals(aTokenDecimals);

    _treasury = treasury;
    _underlyingAsset = underlyingAsset;
    _incentivesController = incentivesController;

    _domainSeparator = _calculateDomainSeparator();

    emit Initialized(
      underlyingAsset,
      address(POOL),
      treasury,
      address(incentivesController),
      aTokenDecimals,
      aTokenName,
      aTokenSymbol,
      params
    );
  }

  /// @inheritdoc IAToken
  function mint(
    address caller,
    address onBehalfOf,
    uint256 amount,
    uint256 index
  ) external virtual override onlyPool returns (bool) {
    revert('OPERATION_NOT_PERMITTED');
  }

  /// @inheritdoc IAToken
  function burn(
    address from,
    address receiverOfUnderlying,
    uint256 amount,
    uint256 index
  ) external virtual override onlyPool {
    revert('OPERATION_NOT_PERMITTED');
  }

  /// @inheritdoc IAToken
  function mintToTreasury(uint256 amount, uint256 index) external override onlyPool {
    revert('OPERATION_NOT_PERMITTED');
  }

  /// @inheritdoc IAToken
  function transferOnLiquidation(
    address from,
    address to,
    uint256 value
  ) external override onlyPool {
    revert('OPERATION_NOT_PERMITTED');
  }

  /// @inheritdoc IERC20
  function balanceOf(address user)
    public
    view
    virtual
    override(IncentivizedERC20, IERC20)
    returns (uint256)
  {
    return super.balanceOf(user).rayMul(POOL.getReserveNormalizedIncome(_underlyingAsset));
  }

  /// @inheritdoc IERC20
  function totalSupply() public view virtual override(IncentivizedERC20, IERC20) returns (uint256) {
    uint256 currentSupplyScaled = super.totalSupply();

    if (currentSupplyScaled == 0) {
      return 0;
    }

    return currentSupplyScaled.rayMul(POOL.getReserveNormalizedIncome(_underlyingAsset));
  }

  /// @inheritdoc IAToken
  function RESERVE_TREASURY_ADDRESS() external view override returns (address) {
    return _treasury;
  }

  /// @inheritdoc IAToken
  function UNDERLYING_ASSET_ADDRESS() external view override returns (address) {
    return _underlyingAsset;
  }

  /// @inheritdoc IAToken
  function transferUnderlyingTo(address target, uint256 amount) external virtual override onlyPool {
    // Mints GHO on behalf of the `target`
    IERC20Mintable(_underlyingAsset).mint(target, amount);
  }

  /// @inheritdoc IAToken
  function handleRepayment(address user, uint256 amount) external virtual override onlyPool {
    uint256 balanceFromInterest = _ghoVariableDebtToken.getBalanceFromInterest(user);
    if (amount <= balanceFromInterest) {
      _ghoVariableDebtToken.decreaseBalanceFromInterest(user, amount);
    } else {
      _ghoVariableDebtToken.decreaseBalanceFromInterest(user, balanceFromInterest);
      IERC20Burnable(_underlyingAsset).burn(amount - balanceFromInterest);
    }
  }

  /// @inheritdoc IGhoFacilitator
  function distributeFeesToTreasury() external virtual override {
    uint256 balance = IERC20(_underlyingAsset).balanceOf(address(this));
    IERC20(_underlyingAsset).transfer(_ghoTreasury, balance);
    emit FeesDistributedToTreasury(_ghoTreasury, balance);
  }

  /// @inheritdoc IAToken
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external override {
    revert('OPERATION_NOT_PERMITTED');
  }

  /**
   * @notice Transfers the aTokens between two users. Validates the transfer
   * (ie checks for valid HF after the transfer) if required
   * @param from The source address
   * @param to The destination address
   * @param amount The amount getting transferred
   * @param validate True if the transfer needs to be validated, false otherwise
   */
  function _transfer(
    address from,
    address to,
    uint256 amount,
    bool validate
  ) internal {
    revert('OPERATION_NOT_PERMITTED');
  }

  /**
   * @notice Overrides the parent _transfer to force validated transfer() and transferFrom()
   * @param from The source address
   * @param to The destination address
   * @param amount The amount getting transferred
   */
  function _transfer(
    address from,
    address to,
    uint128 amount
  ) internal override {
    revert('OPERATION_NOT_PERMITTED');
  }

  /**
   * @dev Overrides the base function to fully implement IAToken
   * @dev see `EIP712Base.DOMAIN_SEPARATOR()` for more detailed documentation
   */
  function DOMAIN_SEPARATOR() public view override(IAToken, EIP712Base) returns (bytes32) {
    return super.DOMAIN_SEPARATOR();
  }

  /**
   * @dev Overrides the base function to fully implement IAToken
   * @dev see `EIP712Base.nonces()` for more detailed documentation
   */
  function nonces(address owner) public view override(IAToken, EIP712Base) returns (uint256) {
    return super.nonces(owner);
  }

  /// @inheritdoc EIP712Base
  function _EIP712BaseId() internal view override returns (string memory) {
    return name();
  }

  /// @inheritdoc IAToken
  function rescueTokens(
    address token,
    address to,
    uint256 amount
  ) external override onlyPoolAdmin {
    require(token != _underlyingAsset, Errors.UNDERLYING_CANNOT_BE_RESCUED);
    IERC20(token).safeTransfer(to, amount);
  }

  /// @inheritdoc IGhoAToken
  function setVariableDebtToken(address ghoVariableDebtToken) external override onlyPoolAdmin {
    require(address(_ghoVariableDebtToken) == address(0), 'VARIABLE_DEBT_TOKEN_ALREADY_SET');
    _ghoVariableDebtToken = GhoVariableDebtToken(ghoVariableDebtToken);
    emit VariableDebtTokenSet(ghoVariableDebtToken);
  }

  /// @inheritdoc IGhoAToken
  function getVariableDebtToken() external view override returns (address) {
    return address(_ghoVariableDebtToken);
  }

  /// @inheritdoc IGhoAToken
  function updateGhoTreasury(address newGhoTreasury) external override onlyPoolAdmin {
    address oldGhoTreasury = _ghoTreasury;
    _ghoTreasury = newGhoTreasury;
    emit GhoTreasuryUpdated(oldGhoTreasury, newGhoTreasury);
  }

  /// @inheritdoc IGhoAToken
  function getGhoTreasury() external view override returns (address) {
    return _ghoTreasury;
  }
}
