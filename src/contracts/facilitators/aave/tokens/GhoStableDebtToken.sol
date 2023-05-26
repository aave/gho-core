// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {MathUtils} from '@aave/core-v3/contracts/protocol/libraries/math/MathUtils.sol';
import {WadRayMath} from '@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {IAaveIncentivesController} from '@aave/core-v3/contracts/interfaces/IAaveIncentivesController.sol';
import {IInitializableDebtToken} from '@aave/core-v3/contracts/interfaces/IInitializableDebtToken.sol';
import {IStableDebtToken} from '@aave/core-v3/contracts/interfaces/IStableDebtToken.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {EIP712Base} from '@aave/core-v3/contracts/protocol/tokenization/base/EIP712Base.sol';
import {DebtTokenBase} from '@aave/core-v3/contracts/protocol/tokenization/base/DebtTokenBase.sol';
import {IncentivizedERC20} from '@aave/core-v3/contracts/protocol/tokenization/base/IncentivizedERC20.sol';
import {SafeCast} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/SafeCast.sol';

/**
 * @title GhoStableDebtToken
 * @author Aave
 * @notice Implements a non-usable and reverting stable debt token, only used for listing configuration purposes.
 * @dev All write operations revert and read functions return 0
 */
contract GhoStableDebtToken is DebtTokenBase, IncentivizedERC20, IStableDebtToken {
  using WadRayMath for uint256;
  using SafeCast for uint256;

  uint256 public constant DEBT_TOKEN_REVISION = 0x1;

  /**
   * @dev Constructor.
   * @param pool The address of the Pool contract
   */
  constructor(
    IPool pool
  )
    DebtTokenBase()
    IncentivizedERC20(pool, 'GHO_STABLE_DEBT_TOKEN_IMPL', 'GHO_STABLE_DEBT_TOKEN_IMPL', 0)
  {
    // Intentionally left blank
  }

  /// @inheritdoc IInitializableDebtToken
  function initialize(
    IPool initializingPool,
    address underlyingAsset,
    IAaveIncentivesController incentivesController,
    uint8 debtTokenDecimals,
    string memory debtTokenName,
    string memory debtTokenSymbol,
    bytes calldata params
  ) external override initializer {
    require(initializingPool == POOL, Errors.POOL_ADDRESSES_DO_NOT_MATCH);
    _setName(debtTokenName);
    _setSymbol(debtTokenSymbol);
    _setDecimals(debtTokenDecimals);

    _underlyingAsset = underlyingAsset;
    _incentivesController = incentivesController;

    _domainSeparator = _calculateDomainSeparator();

    emit Initialized(
      underlyingAsset,
      address(POOL),
      address(incentivesController),
      debtTokenDecimals,
      debtTokenName,
      debtTokenSymbol,
      params
    );
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return DEBT_TOKEN_REVISION;
  }

  /// @inheritdoc IStableDebtToken
  function getAverageStableRate() external pure virtual override returns (uint256) {
    return 0;
  }

  /// @inheritdoc IStableDebtToken
  function getUserLastUpdated(address) external pure virtual override returns (uint40) {
    return 0;
  }

  /// @inheritdoc IStableDebtToken
  function getUserStableRate(address) external pure virtual override returns (uint256) {
    return 0;
  }

  /// @inheritdoc IERC20
  function balanceOf(address) public pure virtual override returns (uint256) {
    return 0;
  }

  /// @inheritdoc IStableDebtToken
  function mint(
    address,
    address,
    uint256,
    uint256
  ) external virtual override onlyPool returns (bool, uint256, uint256) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IStableDebtToken
  function burn(address, uint256) external virtual override onlyPool returns (uint256, uint256) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IStableDebtToken
  function getSupplyData() external pure override returns (uint256, uint256, uint256, uint40) {
    return (0, 0, 0, 0);
  }

  /// @inheritdoc IStableDebtToken
  function getTotalSupplyAndAvgRate() external pure override returns (uint256, uint256) {
    return (0, 0);
  }

  /// @inheritdoc IERC20
  function totalSupply() public view virtual override returns (uint256) {
    return 0;
  }

  /// @inheritdoc IStableDebtToken
  function getTotalSupplyLastUpdated() external pure override returns (uint40) {
    return 0;
  }

  /// @inheritdoc IStableDebtToken
  function principalBalanceOf(address) external view virtual override returns (uint256) {
    return 0;
  }

  /// @inheritdoc IStableDebtToken
  function UNDERLYING_ASSET_ADDRESS() external view override returns (address) {
    return _underlyingAsset;
  }

  /// @inheritdoc EIP712Base
  function _EIP712BaseId() internal view override returns (string memory) {
    return name();
  }

  /**
   * @dev Being non transferrable, the debt token does not implement any of the
   * standard ERC20 functions for transfer and allowance.
   */
  function transfer(address, uint256) external virtual override returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  function allowance(address, address) external view virtual override returns (uint256) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  function approve(address, uint256) external virtual override returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  function transferFrom(address, address, uint256) external virtual override returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  function increaseAllowance(address, uint256) external virtual override returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  function decreaseAllowance(address, uint256) external virtual override returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }
}
