// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {GPv2SafeERC20} from '@aave/core-v3/contracts/dependencies/gnosis/contracts/GPv2SafeERC20.sol';
import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {EIP712} from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IGhoToken} from '../../../gho/interfaces/IGhoToken.sol';
import {IGsm} from '../interfaces/IGsm.sol';
import {IGsmConverter} from './interfaces/IGsmConverter.sol';
// TODO: replace with proper issuance implementation/interface later from USTB
import {ISubscriptionRedemption} from '../dependencies/USTB/ISubscriptionRedemption.sol';
import {MockBUIDLSubscription} from '../../../../test/mocks/MockBUIDLSubscription.sol';

import 'forge-std/console2.sol';

/**
 * @title USTBGsmConverter
 * @author Aave
 * @notice Converter that facilitates conversions/redemptions of underlying assets. Integrates with GSM to buy/sell to go to/from an underlying asset to/from GHO.
 */
contract USTBGsmConverter is Ownable, EIP712, IGsmConverter {
  using GPv2SafeERC20 for IERC20;

  /// @inheritdoc IGsmConverter
  bytes32 public constant BUY_ASSET_WITH_SIG_TYPEHASH =
    keccak256(
      'BuyAssetWithSig(address originator,uint256 minAmount,address receiver,uint256 nonce,uint256 deadline)'
    );

  /// @inheritdoc IGsmConverter
  bytes32 public constant SELL_ASSET_WITH_SIG_TYPEHASH =
    keccak256(
      'SellAssetWithSig(address originator,uint256 maxAmount,address receiver,uint256 nonce,uint256 deadline)'
    );

  /// @inheritdoc IGsmConverter
  address public immutable GHO_TOKEN;

  /// @inheritdoc IGsmConverter
  address public immutable GSM;

  /// @inheritdoc IGsmConverter
  address public immutable ISSUED_ASSET;

  /// @inheritdoc IGsmConverter
  address public immutable REDEEMED_ASSET;

  /// @inheritdoc IGsmConverter
  address public immutable REDEMPTION_CONTRACT;

  /// @inheritdoc IGsmConverter
  address public immutable SUBSCRIPTION_CONTRACT;

  /// @inheritdoc IGsmConverter
  mapping(address => uint256) public nonces;

  /**
   * @dev Constructor
   * @param gsm The address of the associated GSM contract
   * @param redemptionContract The address of the redemption contract associated with the asset conversion
   * @param issuanceReceiverContract The address of the contract receiving the payment associated with the asset conversion
   * @param issuedAsset The address of the asset being redeemed
   * @param redeemedAsset The address of the asset being received from redemption
   */
  constructor(
    address admin,
    address gsm,
    address redemptionContract,
    address issuanceReceiverContract,
    address issuedAsset,
    address redeemedAsset
  ) EIP712('GSMConverter', '1') {
    require(admin != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(gsm != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(redemptionContract != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(issuanceReceiverContract != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(issuedAsset != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(redeemedAsset != address(0), 'ZERO_ADDRESS_NOT_VALID');

    GSM = gsm;
    REDEMPTION_CONTRACT = redemptionContract;
    SUBSCRIPTION_CONTRACT = issuanceReceiverContract;
    ISSUED_ASSET = issuedAsset; // BUIDL
    REDEEMED_ASSET = redeemedAsset; // USDC
    GHO_TOKEN = IGsm(GSM).GHO_TOKEN();

    transferOwnership(admin);
  }

  /// @inheritdoc IGsmConverter
  // TODO: maxAmount should be the amount of GHO to be received, NOT the amount of asset to be sold
  function sellAsset(uint256 maxAmount, address receiver) external returns (uint256, uint256) {
    require(maxAmount > 0, 'INVALID_MAX_AMOUNT');

    return _sellAsset(msg.sender, maxAmount, receiver);
  }

  /// @inheritdoc IGsmConverter
  // TODO: minAmount should be the amount of USDC to be returned to user, NOT the amount of asset to buy
  function buyAsset(uint256 minAmount, address receiver) external returns (uint256, uint256) {
    require(minAmount > 0, 'INVALID_MIN_AMOUNT');

    return _buyAsset(msg.sender, minAmount, receiver);
  }

  /// @inheritdoc IGsmConverter
  function buyAssetWithSig(
    address originator,
    uint256 minAmount,
    address receiver,
    uint256 deadline,
    bytes calldata signature
  ) external returns (uint256, uint256) {
    require(deadline >= block.timestamp, 'SIGNATURE_DEADLINE_EXPIRED');
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
      'SIGNATURE_INVALID'
    );

    return _buyAsset(originator, minAmount, receiver);
  }

  /// @inheritdoc IGsmConverter
  function sellAssetWithSig(
    address originator,
    uint256 maxAmount,
    address receiver,
    uint256 deadline,
    bytes calldata signature
  ) external returns (uint256, uint256) {
    require(deadline >= block.timestamp, 'SIGNATURE_DEADLINE_EXPIRED');
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
      'SIGNATURE_INVALID'
    );

    return _sellAsset(originator, maxAmount, receiver);
  }

  /// @inheritdoc IGsmConverter
  function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
    require(amount > 0, 'INVALID_AMOUNT');
    IERC20(token).safeTransfer(to, amount);
    emit TokensRescued(token, to, amount);
  }

  /// @inheritdoc IGsmConverter
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparatorV4();
  }

  /**
   * @notice Buys the GSM underlying asset in exchange for selling GHO, after asset redemption
   * @param minAmount The minimum amount of the underlying asset to buy via USTB redemption (USDC)
   * @param receiver Recipient address of the underlying asset being purchased
   * @return The amount of underlying asset bought, after asset redemption
   * @return The amount of GHO sold by the user
   */
  function _buyAsset(
    address originator,
    uint256 minAmount,
    address receiver
  ) internal returns (uint256, uint256) {
    uint256 initialGhoBalance = IGhoToken(GHO_TOKEN).balanceOf(address(this));
    uint256 initialIssuedAssetBalance = IERC20(ISSUED_ASSET).balanceOf(address(this));
    uint256 initialRedeemedAssetBalance = IERC20(REDEEMED_ASSET).balanceOf(address(this));

    uint256 minUSTBAmount = ISubscriptionRedemption(REDEMPTION_CONTRACT).calculateUstbIn(minAmount);

    (, uint256 ghoAmount, , ) = IGsm(GSM).getGhoAmountForBuyAsset(minUSTBAmount);

    IGhoToken(GHO_TOKEN).transferFrom(originator, address(this), ghoAmount);
    IGhoToken(GHO_TOKEN).approve(address(GSM), ghoAmount);
    (uint256 boughtAssetAmount, uint256 ghoSold) = IGsm(GSM).buyAsset(minUSTBAmount, address(this));
    require(ghoAmount == ghoSold, 'INVALID_GHO_SOLD');
    IGhoToken(GHO_TOKEN).approve(address(GSM), 0);

    IERC20(ISSUED_ASSET).approve(address(REDEMPTION_CONTRACT), boughtAssetAmount);
    IRedemption(REDEMPTION_CONTRACT).redeem(boughtAssetAmount);
    IERC20(ISSUED_ASSET).approve(address(REDEMPTION_CONTRACT), 0);
    IERC20(REDEEMED_ASSET).safeTransfer(receiver, minAmount);

    require(
      IGhoToken(GHO_TOKEN).balanceOf(address(this)) == initialGhoBalance,
      'INVALID_REMAINING_GHO_BALANCE'
    );
    require(
      IERC20(ISSUED_ASSET).balanceOf(address(this)) == initialIssuedAssetBalance,
      'INVALID_REMAINING_ISSUED_ASSET_BALANCE'
    );

    emit BuyAssetThroughRedemption(originator, receiver, boughtAssetAmount, ghoSold);
    return (boughtAssetAmount, ghoSold);
  }

  /**
   * @notice Sells the GSM underlying asset in exchange for buying GHO, after asset conversion
   * @param originator The originator of the request
   * @param maxAmount The maximum amount of the underlying asset to sell
   * @param receiver Recipient address of the GHO being purchased
   * @return The amount of underlying asset sold, after asset conversion
   * @return The amount of GHO bought by the user
   */
  function _sellAsset(
    address originator,
    uint256 maxAmount,
    address receiver
  ) internal returns (uint256, uint256) {
    uint256 initialGhoBalance = IGhoToken(GHO_TOKEN).balanceOf(address(this));
    uint256 initialIssuedAssetBalance = IERC20(ISSUED_ASSET).balanceOf(address(this));
    uint256 initialRedeemedAssetBalance = IERC20(REDEEMED_ASSET).balanceOf(address(this));

    (uint256 assetAmount, , , ) = IGsm(GSM).getGhoAmountForSellAsset(maxAmount); // asset is BUIDL
    IERC20(REDEEMED_ASSET).transferFrom(originator, address(this), assetAmount);
    IERC20(REDEEMED_ASSET).approve(SUBSCRIPTION_CONTRACT, assetAmount);
    //TODO: replace with proper issuance implementation later
    MockBUIDLSubscription(SUBSCRIPTION_CONTRACT).issuance(assetAmount);
    uint256 subscribedAssetAmount = IERC20(ISSUED_ASSET).balanceOf(address(this)) -
      initialIssuedAssetBalance;
    // TODO: probably will be fees from issuance, so need to adjust the logic
    // only use this require only if preview of issuance is possible, otherwise it is redundant
    require(
      IERC20(ISSUED_ASSET).balanceOf(address(this)) ==
        initialIssuedAssetBalance + subscribedAssetAmount,
      'INVALID_ISSUANCE'
    );
    // reset approval after issuance
    IERC20(REDEEMED_ASSET).approve(SUBSCRIPTION_CONTRACT, 0);

    // TODO: account for fees for sellAsset amount param
    (assetAmount, , , ) = IGsm(GSM).getGhoAmountForSellAsset(subscribedAssetAmount); // recalculate based on actual issuance amount, < maxAmount
    IERC20(ISSUED_ASSET).approve(GSM, assetAmount);
    (uint256 soldAssetAmount, uint256 ghoBought) = IGsm(GSM).sellAsset(
      subscribedAssetAmount,
      receiver
    );
    // reset approval after sellAsset
    IERC20(ISSUED_ASSET).approve(GSM, 0);

    // by the end of the transaction, this contract should not retain any of the assets
    require(
      IGhoToken(GHO_TOKEN).balanceOf(address(this)) == initialGhoBalance,
      'INVALID_REMAINING_GHO_BALANCE'
    );
    require(
      IERC20(REDEEMED_ASSET).balanceOf(address(this)) == initialRedeemedAssetBalance,
      'INVALID_REMAINING_REDEEMED_ASSET_BALANCE'
    );
    require(
      IERC20(ISSUED_ASSET).balanceOf(address(this)) == initialIssuedAssetBalance,
      'INVALID_REMAINING_ISSUED_ASSET_BALANCE'
    );

    emit SellAssetThroughSubscription(originator, receiver, soldAssetAmount, ghoBought);
    return (soldAssetAmount, ghoBought);
  }
}
