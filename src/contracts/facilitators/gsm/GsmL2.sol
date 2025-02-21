// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {GPv2SafeERC20} from '@aave/core-v3/contracts/dependencies/gnosis/contracts/GPv2SafeERC20.sol';
import {EIP712} from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';

import {IGhoFacilitator} from 'src/contracts/gho/interfaces/IGhoFacilitator.sol';
import {IGhoToken} from 'src/contracts/gho/interfaces/IGhoToken.sol';
import {IGsmPriceStrategy} from 'src/contracts/facilitators/gsm/priceStrategy/interfaces/IGsmPriceStrategy.sol';
import {IGsmFeeStrategy} from 'src/contracts/facilitators/gsm/feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {IGsm} from 'src/contracts/facilitators/gsm/interfaces/IGsm.sol';
import {IGsmL2} from 'src/contracts/facilitators/gsm/interfaces/IGsmL2.sol';

/**
 * @title GsmL2
 * @author Aave
 * @notice GHO Stability Module. It provides buy/sell facilities to go to/from an underlying asset to/from GHO.
 * @dev To be covered by a proxy contract.
 */
contract GsmL2 is IGsm, IGsmL2, AccessControl, VersionedInitializable, EIP712 {
  using GPv2SafeERC20 for IERC20;
  using SafeCast for uint256;

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
      'BuyAssetWithSig(address originator,uint256 minAmount,address receiver,uint256 nonce,uint256 deadline)'
    );

  /// @inheritdoc IGsm
  bytes32 public constant SELL_ASSET_WITH_SIG_TYPEHASH =
    keccak256(
      'SellAssetWithSig(address originator,uint256 maxAmount,address receiver,uint256 nonce,uint256 deadline)'
    );

  /// @inheritdoc IGsm
  address public immutable GHO_TOKEN;

  /// @inheritdoc IGsm
  address public immutable UNDERLYING_ASSET;

  /// @inheritdoc IGsm
  address public immutable PRICE_STRATEGY;

  /// @inheritdoc IGsm
  mapping(address => uint256) public nonces;

  address internal _ghoTreasury;
  address internal _feeStrategy;
  address internal _liquidityProvider;
  uint128 internal _exposureCap;
  uint128 internal _ghoLiquidity;
  uint128 internal _currentExposure;
  uint128 internal _accruedFees;
  bool internal _isFrozen;
  bool internal _isSeized;

  /**
   * @dev Require GSM to not be frozen for functions marked by this modifier
   */
  modifier notFrozen() {
    require(!_isFrozen, GsmFrozen());
    _;
  }

  /**
   * @dev Require GSM to not be seized for functions marked by this modifier
   */
  modifier notSeized() {
    require(!_isSeized, GsmSeized());
    _;
  }

  /**
   * @dev Constructor
   * @param ghoToken The address of the GHO token contract
   * @param underlyingAsset The address of the collateral asset
   * @param priceStrategy The address of the price strategy
   */
  constructor(address ghoToken, address underlyingAsset, address priceStrategy) EIP712('GSM', '1') {
    require(ghoToken != address(0), InvalidZeroAddress());
    require(underlyingAsset != address(0), InvalidZeroAddress());
    require(
      IGsmPriceStrategy(priceStrategy).UNDERLYING_ASSET() == underlyingAsset,
      InvalidPriceStrategy()
    );
    GHO_TOKEN = ghoToken;
    UNDERLYING_ASSET = underlyingAsset;
    PRICE_STRATEGY = priceStrategy;
  }

  /**
   * @notice GSM initializer
   * @param admin The address of the default admin role
   * @param ghoTreasury The address of the GHO treasury
   * @param exposureCap Maximum amount of user-supplied underlying asset in GSM
   * @param liquidityProvider The initial liquidity provider of GHO
   */
  function initialize(
    address admin,
    address ghoTreasury,
    uint128 exposureCap,
    address liquidityProvider
  ) external initializer {
    require(admin != address(0), InvalidZeroAddress());
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(CONFIGURATOR_ROLE, admin);
    _updateGhoTreasury(ghoTreasury);
    _updateExposureCap(exposureCap);
    _updateLiquidityProvider(liquidityProvider);
  }

  /// @inheritdoc IGsm
  function buyAsset(
    uint256 minAmount,
    address receiver
  ) external notFrozen notSeized returns (uint256, uint256) {
    return _buyAsset(msg.sender, minAmount, receiver);
  }

  /// @inheritdoc IGsm
  function buyAssetWithSig(
    address originator,
    uint256 minAmount,
    address receiver,
    uint256 deadline,
    bytes calldata signature
  ) external notFrozen notSeized returns (uint256, uint256) {
    require(deadline >= block.timestamp, SignatureExpired());
    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        _domainSeparatorV4(),
        BUY_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(originator, minAmount, receiver, nonces[originator]++, deadline)
      )
    );
    require(
      SignatureChecker.isValidSignatureNow(originator, digest, signature),
      InvalidSignature()
    );

    return _buyAsset(originator, minAmount, receiver);
  }

  /// @inheritdoc IGsm
  function sellAsset(
    uint256 maxAmount,
    address receiver
  ) external notFrozen notSeized returns (uint256, uint256) {
    return _sellAsset(msg.sender, maxAmount, receiver);
  }

  /// @inheritdoc IGsm
  function sellAssetWithSig(
    address originator,
    uint256 maxAmount,
    address receiver,
    uint256 deadline,
    bytes calldata signature
  ) external notFrozen notSeized returns (uint256, uint256) {
    require(deadline >= block.timestamp, SignatureExpired());
    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        _domainSeparatorV4(),
        SELL_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(originator, maxAmount, receiver, nonces[originator]++, deadline)
      )
    );
    require(
      SignatureChecker.isValidSignatureNow(originator, digest, signature),
      InvalidSignature()
    );

    return _sellAsset(originator, maxAmount, receiver);
  }

  /// @inheritdoc IGsm
  function rescueTokens(
    address token,
    address to,
    uint256 amount
  ) external onlyRole(TOKEN_RESCUER_ROLE) {
    require(amount > 0, InvalidAmount());
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
      require(!_isFrozen, GsmFrozen());
    } else {
      require(_isFrozen, 'GSM_ALREADY_UNFROZEN');
    }
    _isFrozen = enable;
    emit SwapFreeze(msg.sender, enable);
  }

  /// @inheritdoc IGsm
  function seize() external notSeized onlyRole(LIQUIDATOR_ROLE) returns (uint256) {
    _isSeized = true;
    _currentExposure = 0;
    _updateExposureCap(0);

    uint256 underlyingBalance = IERC20(UNDERLYING_ASSET).balanceOf(address(this));
    if (underlyingBalance > 0) {
      IERC20(UNDERLYING_ASSET).safeTransfer(_ghoTreasury, underlyingBalance);
    }

    emit Seized(msg.sender, _ghoTreasury, underlyingBalance, _ghoLiquidity);
    return underlyingBalance;
  }

  /// @inheritdoc IGsm
  function burnAfterSeize(uint256 amount) external onlyRole(LIQUIDATOR_ROLE) returns (uint256) {
    require(_isSeized, GsmNotSeized());
    require(amount > 0, InvalidAmount());

    if (amount > _ghoLiquidity) {
      amount = _ghoLiquidity;
    }

    IGhoToken(GHO_TOKEN).transferFrom(msg.sender, address(this), amount);
    IGhoToken(GHO_TOKEN).transfer(_liquidityProvider, amount);

    emit BurnAfterSeize(msg.sender, amount, (_ghoLiquidity - amount));
    return amount;
  }

  /// @inheritdoc IGsmL2
  function provideLiquidity(uint256 amount) external {
    require(msg.sender == _liquidityProvider, InvalidLiquidityProvider());

    _ghoLiquidity += amount.toUint128();
    IGhoToken(GHO_TOKEN).transferFrom(msg.sender, address(this), amount);
    emit LiquidityProvided(_liquidityProvider, amount);
  }

  /// @inheritdoc IGsm
  function updateFeeStrategy(address feeStrategy) external onlyRole(CONFIGURATOR_ROLE) {
    _updateFeeStrategy(feeStrategy);
  }

  /// @inheritdoc IGsm
  function updateExposureCap(uint128 exposureCap) external onlyRole(CONFIGURATOR_ROLE) {
    _updateExposureCap(exposureCap);
  }

  /// @inheritdoc IGsmL2
  function updateLiquidityProvider(address liquidityProvider) external onlyRole(CONFIGURATOR_ROLE) {
    _updateLiquidityProvider(liquidityProvider);
  }

  /// @inheritdoc IGhoFacilitator
  function distributeFeesToTreasury() public virtual override {
    uint256 accruedFees = _accruedFees;
    if (accruedFees > 0) {
      _accruedFees = 0;
      IERC20(GHO_TOKEN).transfer(_ghoTreasury, accruedFees);
      emit FeesDistributedToTreasury(_ghoTreasury, GHO_TOKEN, accruedFees);
    }
  }

  /// @inheritdoc IGhoFacilitator
  function updateGhoTreasury(address newGhoTreasury) external override onlyRole(CONFIGURATOR_ROLE) {
    _updateGhoTreasury(newGhoTreasury);
  }

  /// @inheritdoc IGsm
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparatorV4();
  }

  /// @inheritdoc IGsm
  function getGhoAmountForBuyAsset(
    uint256 minAssetAmount
  ) external view returns (uint256, uint256, uint256, uint256) {
    return _calculateGhoAmountForBuyAsset(minAssetAmount);
  }

  /// @inheritdoc IGsm
  function getGhoAmountForSellAsset(
    uint256 maxAssetAmount
  ) external view returns (uint256, uint256, uint256, uint256) {
    return _calculateGhoAmountForSellAsset(maxAssetAmount);
  }

  /// @inheritdoc IGsm
  function getAssetAmountForBuyAsset(
    uint256 maxGhoAmount
  ) external view returns (uint256, uint256, uint256, uint256) {
    bool withFee = _feeStrategy != address(0);
    uint256 grossAmount = withFee
      ? IGsmFeeStrategy(_feeStrategy).getGrossAmountFromTotalBought(maxGhoAmount)
      : maxGhoAmount;
    // round down so maxGhoAmount is guaranteed
    uint256 assetAmount = IGsmPriceStrategy(PRICE_STRATEGY).getGhoPriceInAsset(grossAmount, false);
    uint256 finalGrossAmount = IGsmPriceStrategy(PRICE_STRATEGY).getAssetPriceInGho(
      assetAmount,
      true
    );
    uint256 finalFee = withFee ? IGsmFeeStrategy(_feeStrategy).getBuyFee(finalGrossAmount) : 0;
    return (assetAmount, finalGrossAmount + finalFee, finalGrossAmount, finalFee);
  }

  /// @inheritdoc IGsm
  function getAssetAmountForSellAsset(
    uint256 minGhoAmount
  ) external view returns (uint256, uint256, uint256, uint256) {
    bool withFee = _feeStrategy != address(0);
    uint256 grossAmount = withFee
      ? IGsmFeeStrategy(_feeStrategy).getGrossAmountFromTotalSold(minGhoAmount)
      : minGhoAmount;
    // round up so minGhoAmount is guaranteed
    uint256 assetAmount = IGsmPriceStrategy(PRICE_STRATEGY).getGhoPriceInAsset(grossAmount, true);
    uint256 finalGrossAmount = IGsmPriceStrategy(PRICE_STRATEGY).getAssetPriceInGho(
      assetAmount,
      false
    );
    uint256 finalFee = withFee ? IGsmFeeStrategy(_feeStrategy).getSellFee(finalGrossAmount) : 0;
    return (assetAmount, finalGrossAmount - finalFee, finalGrossAmount, finalFee);
  }

  /// @inheritdoc IGsm
  function getAvailableUnderlyingExposure() external view returns (uint256) {
    return _exposureCap > _currentExposure ? _exposureCap - _currentExposure : 0;
  }

  /// @inheritdoc IGsm
  function getExposureCap() external view returns (uint128) {
    return _exposureCap;
  }

  /// @inheritdoc IGsm
  function getAvailableLiquidity() external view returns (uint256) {
    return _currentExposure;
  }

  /// @inheritdoc IGsm
  function getFeeStrategy() external view returns (address) {
    return _feeStrategy;
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

  /// @inheritdoc IGsm
  function canSwap() external view returns (bool) {
    return !_isFrozen && !_isSeized;
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
   * @dev Buys an underlying asset with GHO
   * @param originator The originator of the request
   * @param minAmount The minimum amount of the underlying asset desired for purchase
   * @param receiver The recipient address of the underlying asset being purchased
   * @return The amount of underlying asset bought
   * @return The amount of GHO sold by the user
   */
  function _buyAsset(
    address originator,
    uint256 minAmount,
    address receiver
  ) internal returns (uint256, uint256) {
    (
      uint256 assetAmount,
      uint256 ghoSold,
      uint256 grossAmount,
      uint256 fee
    ) = _calculateGhoAmountForBuyAsset(minAmount);

    _beforeBuyAsset(originator, assetAmount, receiver);

    require(assetAmount > 0, InvalidAmount());
    require(_currentExposure >= assetAmount, InsufficientAvailableExogenousLiquidity());

    _currentExposure -= assetAmount.toUint128();
    _ghoLiquidity += ghoSold.toUint128();
    _accruedFees += fee.toUint128();

    IGhoToken(GHO_TOKEN).transferFrom(originator, address(this), ghoSold);
    IERC20(UNDERLYING_ASSET).safeTransfer(receiver, assetAmount);

    emit BuyAsset(originator, receiver, assetAmount, ghoSold, fee);
    return (assetAmount, ghoSold);
  }

  /**
   * @dev Hook that is called before `buyAsset`.
   * @dev This can be used to add custom logic
   * @param originator Originator of the request
   * @param amount The amount of the underlying asset desired for purchase
   * @param receiver Recipient address of the underlying asset being purchased
   */
  function _beforeBuyAsset(address originator, uint256 amount, address receiver) internal virtual {}

  /**
   * @dev Sells an underlying asset for GHO
   * @param originator The originator of the request
   * @param maxAmount The maximum amount of the underlying asset desired to sell
   * @param receiver The recipient address of the GHO being purchased
   * @return The amount of underlying asset sold
   * @return The amount of GHO bought by the user
   */
  function _sellAsset(
    address originator,
    uint256 maxAmount,
    address receiver
  ) internal returns (uint256, uint256) {
    (
      uint256 assetAmount,
      uint256 ghoBought,
      uint256 grossAmount,
      uint256 fee
    ) = _calculateGhoAmountForSellAsset(maxAmount);

    _beforeSellAsset(originator, assetAmount, receiver);

    require(assetAmount > 0, InvalidAmount());
    require(_currentExposure + assetAmount <= _exposureCap, ExogenousAssetExposureTooHigh());

    _currentExposure += assetAmount.toUint128();
    _ghoLiquidity -= ghoBought.toUint128();
    _accruedFees += fee.toUint128();

    IERC20(UNDERLYING_ASSET).safeTransferFrom(originator, address(this), assetAmount);
    IGhoToken(GHO_TOKEN).transfer(receiver, ghoBought);

    emit SellAsset(originator, receiver, assetAmount, grossAmount, fee);
    return (assetAmount, ghoBought);
  }

  /**
   * @dev Hook that is called before `sellAsset`.
   * @dev This can be used to add custom logic
   * @param originator Originator of the request
   * @param amount The amount of the underlying asset desired to sell
   * @param receiver Recipient address of the GHO being purchased
   */
  function _beforeSellAsset(
    address originator,
    uint256 amount,
    address receiver
  ) internal virtual {}

  /**
   * @dev Returns the amount of GHO sold in exchange of buying underlying asset
   * @param assetAmount The amount of underlying asset to buy
   * @return The exact amount of asset the user purchases
   * @return The total amount of GHO the user sells (gross amount in GHO plus fee)
   * @return The gross amount of GHO
   * @return The fee amount in GHO, applied on top of gross amount of GHO
   */
  function _calculateGhoAmountForBuyAsset(
    uint256 assetAmount
  ) internal view returns (uint256, uint256, uint256, uint256) {
    bool withFee = _feeStrategy != address(0);
    // pick the highest GHO amount possible for given asset amount
    uint256 grossAmount = IGsmPriceStrategy(PRICE_STRATEGY).getAssetPriceInGho(assetAmount, true);
    uint256 fee = withFee ? IGsmFeeStrategy(_feeStrategy).getBuyFee(grossAmount) : 0;
    uint256 ghoSold = grossAmount + fee;
    uint256 finalGrossAmount = withFee
      ? IGsmFeeStrategy(_feeStrategy).getGrossAmountFromTotalBought(ghoSold)
      : ghoSold;
    // pick the lowest asset amount possible for given GHO amount
    uint256 finalAssetAmount = IGsmPriceStrategy(PRICE_STRATEGY).getGhoPriceInAsset(
      finalGrossAmount,
      false
    );
    uint256 finalFee = ghoSold - finalGrossAmount;
    return (finalAssetAmount, finalGrossAmount + finalFee, finalGrossAmount, finalFee);
  }

  /**
   * @dev Returns the amount of GHO bought in exchange of a given amount of underlying asset
   * @param assetAmount The amount of underlying asset to sell
   * @return The exact amount of asset the user sells
   * @return The total amount of GHO the user buys (gross amount in GHO minus fee)
   * @return The gross amount of GHO
   * @return The fee amount in GHO, applied to the gross amount of GHO
   */
  function _calculateGhoAmountForSellAsset(
    uint256 assetAmount
  ) internal view returns (uint256, uint256, uint256, uint256) {
    bool withFee = _feeStrategy != address(0);
    // pick the lowest GHO amount possible for given asset amount
    uint256 grossAmount = IGsmPriceStrategy(PRICE_STRATEGY).getAssetPriceInGho(assetAmount, false);
    uint256 fee = withFee ? IGsmFeeStrategy(_feeStrategy).getSellFee(grossAmount) : 0;
    uint256 ghoBought = grossAmount - fee;
    uint256 finalGrossAmount = withFee
      ? IGsmFeeStrategy(_feeStrategy).getGrossAmountFromTotalSold(ghoBought)
      : ghoBought;
    // pick the highest asset amount possible for given GHO amount
    uint256 finalAssetAmount = IGsmPriceStrategy(PRICE_STRATEGY).getGhoPriceInAsset(
      finalGrossAmount,
      true
    );
    uint256 finalFee = finalGrossAmount - ghoBought;
    return (finalAssetAmount, finalGrossAmount - finalFee, finalGrossAmount, finalFee);
  }

  /**
   * @dev Updates Fee Strategy
   * @param feeStrategy The address of the new Fee Strategy
   */
  function _updateFeeStrategy(address feeStrategy) internal {
    address oldFeeStrategy = _feeStrategy;
    _feeStrategy = feeStrategy;
    emit FeeStrategyUpdated(oldFeeStrategy, feeStrategy);
  }

  /**
   * @dev Updates Exposure Cap
   * @param exposureCap The value of the new Exposure Cap
   */
  function _updateExposureCap(uint128 exposureCap) internal {
    uint128 oldExposureCap = _exposureCap;
    _exposureCap = exposureCap;
    emit ExposureCapUpdated(oldExposureCap, exposureCap);
  }

  /**
   * @dev Updates Liquidity Provider
   * @param exposureCap The address of the liquidty provider for the GSM
   */
  function _updateLiquidityProvider(address liquidityProvider) internal {
    require(liquidityProvider != address(0), InvalidZeroAddress());
    address oldLiquidityProvider = _liquidityProvider;
    _liquidityProvider = liquidityProvider;
    emit LiquidityProviderUpdated(oldLiquidityProvider, liquidityProvider);
  }

  /**
   * @dev Updates GHO Treasury Address
   * @param newGhoTreasury The address of the new GHO Treasury
   */
  function _updateGhoTreasury(address newGhoTreasury) internal {
    require(newGhoTreasury != address(0), InvalidZeroAddress());
    address oldGhoTreasury = _ghoTreasury;
    _ghoTreasury = newGhoTreasury;
    emit GhoTreasuryUpdated(oldGhoTreasury, newGhoTreasury);
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return GSM_REVISION();
  }
}
