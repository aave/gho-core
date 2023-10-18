// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {GPv2SafeERC20} from '@aave/core-v3/contracts/dependencies/gnosis/contracts/GPv2SafeERC20.sol';
import {EIP712} from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {IGhoFacilitator} from '../../gho/interfaces/IGhoFacilitator.sol';
import {IGhoToken} from '../../gho/interfaces/IGhoToken.sol';
import {IGsmPriceStrategy} from './priceStrategy/interfaces/IGsmPriceStrategy.sol';
import {IGsmFeeStrategy} from './feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {IGsm} from './interfaces/IGsm.sol';

/**
 * @title Gsm
 * @author Aave
 * @notice GHO Stability Module. It provides buy/sell facilities to go to/from an underlying asset to/from GHO.
 * @dev To be covered by a proxy contract.
 */
contract Gsm is AccessControl, VersionedInitializable, EIP712, IGsm {
  using GPv2SafeERC20 for IERC20;

  /// @inheritdoc IGsm
  bytes32 public constant CONFIGURATOR_ROLE = keccak256('CONFIGURATOR_ROLE');

  /// @inheritdoc IGsm
  bytes32 public constant TOKEN_RESCUER_ROLE = keccak256('TOKEN_RESCUER_ROLE');

  /// @inheritdoc IGsm
  bytes32 public constant SWAP_FREEZER_ROLE = keccak256('SWAP_FREEZER_ROLE');

  /// @inheritdoc IGsm
  bytes32 public constant LIQUIDATOR_ROLE = keccak256('LIQUIDATOR_ROLE');

  /// @inheritdoc IGsm
  bytes32 public constant BUY_ASSET_WITH_SIG_TYPEHASH =
    keccak256(
      'BuyAssetWithSig(address originator,uint128 amount,address receiver,uint256 nonce,uint256 deadline)'
    );

  /// @inheritdoc IGsm
  bytes32 public constant SELL_ASSET_WITH_SIG_TYPEHASH =
    keccak256(
      'SellAssetWithSig(address originator,uint128 amount,address receiver,uint256 nonce,uint256 deadline)'
    );

  /// @inheritdoc IGsm
  address public immutable GHO_TOKEN;

  /// @inheritdoc IGsm
  address public immutable UNDERLYING_ASSET;

  /// @inheritdoc IGsm
  mapping(address => uint256) public nonces;

  address internal _ghoTreasury;
  address internal _priceStrategy;
  bool internal _isFrozen;
  bool internal _isSeized;
  address internal _feeStrategy;
  uint128 internal _exposureCap;
  uint128 internal _currentExposure;
  uint128 internal _accruedFees;

  /**
   * @dev Require GSM to not be frozen for functions marked by this modifier
   */
  modifier notFrozen() {
    require(!_isFrozen, 'GSM_FROZEN_SWAPS_DISABLED');
    _;
  }

  /**
   * @dev Require GSM to not be seized for functions marked by this modifier
   */
  modifier notSeized() {
    require(!_isSeized, 'GSM_SEIZED_SWAPS_DISABLED');
    _;
  }

  /**
   * @dev Constructor
   * @param ghoToken The address of the GHO token contract
   * @param underlyingAsset The address of the collateral asset
   */
  constructor(address ghoToken, address underlyingAsset) EIP712('GSM', '1') {
    GHO_TOKEN = ghoToken;
    UNDERLYING_ASSET = underlyingAsset;
  }

  /**
   * @notice GSM initializer
   * @param admin The address of the default admin role
   * @param ghoTreasury The address of the GHO treasury
   * @param priceStrategy The address of the price strategy
   * @param exposureCap Maximum amount of user-supplied underlying asset in GSM
   */
  function initialize(
    address admin,
    address ghoTreasury,
    address priceStrategy,
    uint128 exposureCap
  ) external initializer {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(CONFIGURATOR_ROLE, admin);
    _ghoTreasury = ghoTreasury;
    _updatePriceStrategy(priceStrategy);
    _updateExposureCap(exposureCap);
  }

  /// @inheritdoc IGsm
  function buyAsset(uint128 amount, address receiver) external notFrozen notSeized {
    _buyAsset(msg.sender, amount, receiver);
  }

  /// @inheritdoc IGsm
  function buyAssetWithSig(
    address originator,
    uint128 amount,
    address receiver,
    uint256 deadline,
    bytes calldata signature
  ) external notFrozen notSeized {
    require(deadline > block.timestamp, 'SIGNATURE_DEADLINE_EXPIRED');
    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        _domainSeparatorV4(),
        BUY_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(originator, amount, receiver, nonces[originator]++, deadline)
      )
    );
    require(
      SignatureChecker.isValidSignatureNow(originator, digest, signature),
      'SIGNATURE_INVALID'
    );

    _buyAsset(originator, amount, receiver);
  }

  /// @inheritdoc IGsm
  function sellAsset(uint128 amount, address receiver) external notFrozen notSeized {
    _sellAsset(msg.sender, amount, receiver);
  }

  /// @inheritdoc IGsm
  function sellAssetWithSig(
    address originator,
    uint128 amount,
    address receiver,
    uint256 deadline,
    bytes calldata signature
  ) external notFrozen notSeized {
    require(deadline > block.timestamp, 'SIGNATURE_DEADLINE_EXPIRED');
    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        _domainSeparatorV4(),
        SELL_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(originator, amount, receiver, nonces[originator]++, deadline)
      )
    );
    require(
      SignatureChecker.isValidSignatureNow(originator, digest, signature),
      'SIGNATURE_INVALID'
    );

    _sellAsset(originator, amount, receiver);
  }

  /// @inheritdoc IGsm
  function rescueTokens(
    address token,
    address to,
    uint256 amount
  ) external onlyRole(TOKEN_RESCUER_ROLE) {
    if (token == GHO_TOKEN) {
      uint256 rescuableBalance = IERC20(token).balanceOf(address(this)) - _accruedFees;
      require(rescuableBalance >= amount, 'INSUFFICIENT_GHO_TO_RESCUE');
    }
    if (token == UNDERLYING_ASSET) {
      uint256 rescuableBalance = IERC20(token).balanceOf(address(this)) - _currentExposure;
      require(rescuableBalance >= amount, 'INSUFFICIENT_EXOGENOUS_ASSET_TO_RESCUE');
    }
    IERC20(token).safeTransfer(to, amount);
    emit TokensRescued(token, to, amount);
  }

  /// @inheritdoc IGsm
  function setSwapFreeze(bool enable) external onlyRole(SWAP_FREEZER_ROLE) {
    if (enable) {
      require(!_isFrozen, 'GSM_ALREADY_FROZEN');
      _isFrozen = true;
      emit SwapFreeze(msg.sender, true);
    } else {
      require(_isFrozen, 'GSM_ALREADY_UNFROZEN');
      _isFrozen = false;
      emit SwapFreeze(msg.sender, false);
    }
  }

  /// @inheritdoc IGsm
  function seize() external notSeized onlyRole(LIQUIDATOR_ROLE) {
    _isSeized = true;

    (, uint256 ghoMinted) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(address(this));
    uint256 underlyingBalance = IERC20(UNDERLYING_ASSET).balanceOf(address(this));
    IERC20(UNDERLYING_ASSET).safeTransfer(_ghoTreasury, underlyingBalance);
    emit Seized(msg.sender, _ghoTreasury, underlyingBalance, ghoMinted);
  }

  /// @inheritdoc IGsm
  function burnAfterSeize(uint256 amount) external onlyRole(LIQUIDATOR_ROLE) {
    require(_isSeized, 'GSM_NOT_SEIZED');

    (, uint256 ghoMinted) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(address(this));
    if (amount > ghoMinted) {
      amount = ghoMinted;
    }
    IGhoToken(GHO_TOKEN).transferFrom(msg.sender, address(this), amount);
    IGhoToken(GHO_TOKEN).burn(amount);

    emit BurnAfterSeize(msg.sender, amount, (ghoMinted - amount));
  }

  /// @inheritdoc IGsm
  function backWith(address asset, uint128 amount) external onlyRole(CONFIGURATOR_ROLE) {
    require(amount > 0, 'INVALID_AMOUNT');
    require(asset == GHO_TOKEN || asset == UNDERLYING_ASSET, 'INVALID_ASSET');

    (, uint256 ghoMinted) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(address(this));
    (, uint256 deficit) = _getCurrentBacking(ghoMinted);
    require(deficit > 0, 'NO_CURRENT_DEFICIT_BACKING');

    uint256 ghoToBack = (asset == GHO_TOKEN)
      ? amount
      : IGsmPriceStrategy(_priceStrategy).getAssetPriceInGho(amount);
    require(ghoToBack <= deficit, 'AMOUNT_EXCEEDS_DEFICIT');

    if (asset == GHO_TOKEN) {
      IGhoToken(GHO_TOKEN).transferFrom(msg.sender, address(this), amount);
      IGhoToken(GHO_TOKEN).burn(amount);

      emit BackingProvided(msg.sender, GHO_TOKEN, amount, amount, deficit - amount);
    } else {
      _currentExposure += amount;
      IERC20(UNDERLYING_ASSET).safeTransferFrom(msg.sender, address(this), amount);

      emit BackingProvided(msg.sender, UNDERLYING_ASSET, amount, ghoToBack, deficit - ghoToBack);
    }
  }

  /// @inheritdoc IGsm
  function updatePriceStrategy(address priceStrategy) public virtual onlyRole(CONFIGURATOR_ROLE) {
    _updatePriceStrategy(priceStrategy);
  }

  /// @inheritdoc IGsm
  function updateFeeStrategy(address feeStrategy) external onlyRole(CONFIGURATOR_ROLE) {
    _updateFeeStrategy(feeStrategy);
  }

  /// @inheritdoc IGsm
  function updateExposureCap(uint128 exposureCap) external onlyRole(CONFIGURATOR_ROLE) {
    _updateExposureCap(exposureCap);
  }

  /// @inheritdoc IGhoFacilitator
  function distributeFeesToTreasury() public virtual override {
    uint256 accruedFees = _accruedFees;
    _accruedFees = 0;
    IERC20(GHO_TOKEN).transfer(_ghoTreasury, accruedFees);
    emit FeesDistributedToTreasury(_ghoTreasury, GHO_TOKEN, accruedFees);
  }

  /// @inheritdoc IGhoFacilitator
  function updateGhoTreasury(address newGhoTreasury) external override onlyRole(CONFIGURATOR_ROLE) {
    require(newGhoTreasury != address(0), 'ZERO_ADDRESS_NOT_VALID');
    address oldGhoTreasury = _ghoTreasury;
    _ghoTreasury = newGhoTreasury;
    emit GhoTreasuryUpdated(oldGhoTreasury, newGhoTreasury);
  }

  /// @inheritdoc IGsm
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparatorV4();
  }

  /// @inheritdoc IGsm
  function getGhoAmountForBuyAsset(
    uint256 assetAmount
  ) external view returns (uint256, uint256, uint256) {
    (uint256 totalAmount, uint256 grossAmount, uint256 fee) = _calculateGhoAmountForBuyAsset(
      assetAmount
    );
    return (totalAmount, grossAmount, fee);
  }

  /// @inheritdoc IGsm
  function getGhoAmountForSellAsset(
    uint256 assetAmount
  ) external view returns (uint256, uint256, uint256) {
    (uint256 totalAmount, uint256 grossAmount, uint256 fee) = _calculateGhoAmountForSellAsset(
      assetAmount
    );
    return (totalAmount, grossAmount, fee);
  }

  /// @inheritdoc IGsm
  function getAssetAmountForBuyAsset(
    uint256 ghoAmount
  ) external view returns (uint256, uint256, uint256) {
    uint256 grossAmount = _feeStrategy != address(0)
      ? IGsmFeeStrategy(_feeStrategy).getGrossAmountFromTotalBought(ghoAmount)
      : ghoAmount;
    return (
      IGsmPriceStrategy(_priceStrategy).getGhoPriceInAsset(grossAmount),
      grossAmount,
      ghoAmount - grossAmount
    );
  }

  /// @inheritdoc IGsm
  function getAssetAmountForSellAsset(
    uint256 ghoAmount
  ) external view returns (uint256, uint256, uint256) {
    uint256 grossAmount = _feeStrategy != address(0)
      ? IGsmFeeStrategy(_feeStrategy).getGrossAmountFromTotalSold(ghoAmount)
      : ghoAmount;
    return (
      IGsmPriceStrategy(_priceStrategy).getGhoPriceInAsset(grossAmount),
      grossAmount,
      grossAmount - ghoAmount
    );
  }

  /// @inheritdoc IGsm
  function getAvailableUnderlyingExposure() external view returns (uint256) {
    return _exposureCap >= _currentExposure ? _exposureCap - _currentExposure : 0;
  }

  /// @inheritdoc IGsm
  function getAvailableLiquidity() external view returns (uint256) {
    return _currentExposure;
  }

  /// @inheritdoc IGsm
  function getCurrentBacking() external view returns (uint256, uint256) {
    (, uint256 ghoMinted) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(address(this));
    return _getCurrentBacking(ghoMinted);
  }

  /// @inheritdoc IGsm
  function getFeeStrategy() external view returns (address) {
    return _feeStrategy;
  }

  /// @inheritdoc IGsm
  function getPriceStrategy() external view returns (address) {
    return _priceStrategy;
  }

  /// @inheritdoc IGsm
  function getAccruedFees() external view returns (uint256) {
    return _accruedFees;
  }

  /// @inheritdoc IGsm
  function getIsFrozen() external view returns (bool) {
    return _isFrozen;
  }

  /// @inheritdoc IGsm
  function getIsSeized() external view returns (bool) {
    return _isSeized;
  }

  /// @inheritdoc IGhoFacilitator
  function getGhoTreasury() external view override returns (address) {
    return _ghoTreasury;
  }

  /// @inheritdoc IGsm
  function GSM_REVISION() public pure virtual override returns (uint256) {
    return 1;
  }

  /**
   * @notice Buys an underlying asset with GHO
   * @param originator The originator of the request
   * @param amount The amount of the underlying asset desired for purchase
   * @param receiver The recipient address of the underlying asset being purchased
   */
  function _buyAsset(address originator, uint128 amount, address receiver) internal {
    _beforeBuyAsset(originator, amount, receiver);

    require(amount > 0, 'INVALID_AMOUNT');
    require(_currentExposure >= amount, 'INSUFFICIENT_AVAILABLE_EXOGENOUS_ASSET_LIQUIDITY');

    _currentExposure -= amount;
    (uint256 ghoSold, uint256 grossAmount, uint256 fee) = _calculateGhoAmountForBuyAsset(amount);
    _accruedFees += uint128(fee);
    IGhoToken(GHO_TOKEN).transferFrom(originator, address(this), ghoSold);
    IGhoToken(GHO_TOKEN).burn(grossAmount);
    IERC20(UNDERLYING_ASSET).safeTransfer(receiver, amount);
    emit BuyAsset(originator, receiver, amount, ghoSold, fee);
  }

  /**
   * @dev Hook that is called before `buyAsset`.
   * @dev This can be used to add custom logic
   * @param originator Originator of the request
   * @param amount The amount of the underlying asset desired for purchase
   * @param user Recipient address of the underlying asset being purchased
   */
  function _beforeBuyAsset(address originator, uint128 amount, address user) internal virtual {}

  /**
   * @notice Sells an underlying asset for GHO
   * @param originator The originator of the request
   * @param amount The amount of the underlying asset desired to sell
   * @param receiver The recipient address of the GHO being purchased
   */
  function _sellAsset(address originator, uint128 amount, address receiver) internal {
    _beforeSellAsset(originator, amount, receiver);

    require(amount > 0, 'INVALID_AMOUNT');
    _currentExposure += amount;
    require(_currentExposure <= _exposureCap, 'EXOGENOUS_ASSET_EXPOSURE_TOO_HIGH');

    (uint256 ghoBought, uint256 grossAmount, uint256 fee) = _calculateGhoAmountForSellAsset(amount);
    _accruedFees += uint128(fee);
    IERC20(UNDERLYING_ASSET).safeTransferFrom(originator, address(this), amount);

    IGhoToken(GHO_TOKEN).mint(address(this), grossAmount);
    IGhoToken(GHO_TOKEN).transfer(receiver, ghoBought);

    emit SellAsset(originator, receiver, amount, grossAmount, fee);
  }

  /**
   * @dev Hook that is called before `sellAsset`.
   * @dev This can be used to add custom logic
   * @param originator Originator of the request
   * @param amount The amount of the underlying asset desired to sell
   * @param user Recipient address of the GHO being purchased
   */
  function _beforeSellAsset(address originator, uint128 amount, address user) internal virtual {}

  /**
   * @dev Returns the amount of GHO sold in exchange of buying underlying asset
   * @param assetAmount The amount of underlying asset to buy
   * @return The total amount of GHO the user sells (gross amount in GHO plus fee)
   * @return The gross amount of GHO
   * @return The fee amount in GHO, applied on top of gross amount of GHO
   */
  function _calculateGhoAmountForBuyAsset(
    uint256 assetAmount
  ) internal view returns (uint256, uint256, uint256) {
    uint256 grossAmount = IGsmPriceStrategy(_priceStrategy).getAssetPriceInGho(assetAmount);
    uint256 fee = _feeStrategy != address(0)
      ? IGsmFeeStrategy(_feeStrategy).getBuyFee(grossAmount)
      : 0;
    return (grossAmount + fee, grossAmount, fee);
  }

  /**
   * @dev Returns the amount of GHO bought in exchange of a given amount of underlying asset
   * @param assetAmount The amount of underlying asset to sell
   * @return The total amount of GHO the user buys (gross amount in GHO minus fee)
   * @return The gross amount of GHO
   * @return The fee amount in GHO, applied to the gross amount of GHO
   */
  function _calculateGhoAmountForSellAsset(
    uint256 assetAmount
  ) internal view returns (uint256, uint256, uint256) {
    uint256 grossAmount = IGsmPriceStrategy(_priceStrategy).getAssetPriceInGho(assetAmount);
    uint256 fee = _feeStrategy != address(0)
      ? IGsmFeeStrategy(_feeStrategy).getSellFee(grossAmount)
      : 0;
    return (grossAmount - fee, grossAmount, fee);
  }

  /**
   * @notice Updates Price Strategy
   * @param priceStrategy The address of the new Price Strategy
   */
  function _updatePriceStrategy(address priceStrategy) internal {
    require(
      IGsmPriceStrategy(priceStrategy).UNDERLYING_ASSET() == UNDERLYING_ASSET,
      'INVALID_PRICE_STRATEGY_FOR_ASSET'
    );
    address oldPriceStrategy = _priceStrategy;
    _priceStrategy = priceStrategy;
    emit PriceStrategyUpdated(oldPriceStrategy, priceStrategy);
  }

  /**
   * @notice Updates Fee Strategy
   * @param feeStrategy The address of the new Fee Strategy
   */
  function _updateFeeStrategy(address feeStrategy) internal {
    address oldFeeStrategy = _feeStrategy;
    _feeStrategy = feeStrategy;
    emit FeeStrategyUpdated(oldFeeStrategy, feeStrategy);
  }

  /**
   * @notice Updates Exposure Cap
   * @param exposureCap The value of the new Exposure Cap
   */
  function _updateExposureCap(uint128 exposureCap) internal {
    uint128 oldExposureCap = _exposureCap;
    _exposureCap = exposureCap;
    emit ExposureCapUpdated(oldExposureCap, exposureCap);
  }

  /**
   * @notice Calculates the excess or deficit of GHO minted, reflective of GSM backing
   * @param ghoMinted The amount of GHO currently minted by the GSM
   * @return The excess amount of GHO minted, relative to the value of the underlying
   * @return The deficit of GHO minted, relative to the value of the underlying
   */
  function _getCurrentBacking(uint256 ghoMinted) internal view returns (uint256, uint256) {
    uint256 ghoToBack = IGsmPriceStrategy(_priceStrategy).getAssetPriceInGho(_currentExposure);
    if (ghoToBack >= ghoMinted) {
      return (ghoToBack - ghoMinted, 0);
    } else {
      return (0, ghoMinted - ghoToBack);
    }
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return GSM_REVISION();
  }
}
