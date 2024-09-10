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
import {IRedemption} from '../dependencies/circle/IRedemption.sol';
import {MockIssuanceReceiver} from 'mocks/MockIssuanceReceiver.sol';

import 'forge-std/console2.sol';

/**
 * @title GsmConverter
 * @author Aave
 * @notice Converter that facilitates conversions/redemptions of underlying assets. Integrates with GSM to buy/sell to go to/from an underlying asset to/from GHO.
 */
contract GsmConverter is Ownable, EIP712, IGsmConverter {
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
  address public immutable REDEEMABLE_ASSET;

  /// @inheritdoc IGsmConverter
  address public immutable REDEEMED_ASSET;

  /// @inheritdoc IGsmConverter
  address public immutable REDEMPTION_CONTRACT;

  /// @inheritdoc IGsmConverter
  address public immutable ISSUANCE_RECEIVER_CONTRACT;

  /// @inheritdoc IGsmConverter
  mapping(address => uint256) public nonces;

  /**
   * @dev Constructor
   * @param gsm The address of the associated GSM contract
   * @param redemptionContract The address of the redemption contract associated with the asset conversion
   * @param issuanceReceiverContract The address of the contract receiving the payment associated with the asset conversion
   * @param redeemableAsset The address of the asset being redeemed
   * @param redeemedAsset The address of the asset being received from redemption
   */
  constructor(
    address admin,
    address gsm,
    address redemptionContract,
    address issuanceReceiverContract,
    address redeemableAsset,
    address redeemedAsset
  ) EIP712('GSMConverter', '1') {
    require(admin != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(gsm != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(redemptionContract != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(issuanceReceiverContract != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(redeemableAsset != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(redeemedAsset != address(0), 'ZERO_ADDRESS_NOT_VALID');

    GSM = gsm;
    REDEMPTION_CONTRACT = redemptionContract;
    ISSUANCE_RECEIVER_CONTRACT = issuanceReceiverContract;
    REDEEMABLE_ASSET = redeemableAsset; // BUIDL
    REDEEMED_ASSET = redeemedAsset; // USDC
    GHO_TOKEN = IGsm(GSM).GHO_TOKEN();

    transferOwnership(admin);
  }

  /// @inheritdoc IGsmConverter
  function sellAsset(uint256 maxAmount, address receiver) external returns (uint256, uint256) {
    require(maxAmount > 0, 'INVALID_MAX_AMOUNT');

    return _sellAsset(msg.sender, maxAmount, receiver);
  }

  /// @inheritdoc IGsmConverter
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
   * @param minAmount The minimum amount of the underlying asset to buy (ie BUIDL)
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
    uint256 initialRedeemableAssetBalance = IERC20(REDEEMABLE_ASSET).balanceOf(address(this));
    uint256 initialRedeemedAssetBalance = IERC20(REDEEMED_ASSET).balanceOf(address(this));

    (, uint256 ghoAmount, , ) = IGsm(GSM).getGhoAmountForBuyAsset(minAmount);

    IGhoToken(GHO_TOKEN).transferFrom(originator, address(this), ghoAmount);
    IGhoToken(GHO_TOKEN).approve(address(GSM), ghoAmount);
    (uint256 redeemableAssetAmount, uint256 ghoSold) = IGsm(GSM).buyAsset(minAmount, address(this));
    require(ghoAmount == ghoSold, 'INVALID_GHO_SOLD');
    IGhoToken(GHO_TOKEN).approve(address(GSM), 0);

    IERC20(REDEEMABLE_ASSET).approve(address(REDEMPTION_CONTRACT), redeemableAssetAmount);
    IRedemption(REDEMPTION_CONTRACT).redeem(redeemableAssetAmount);
    // redeemedAssetAmount matches redeemableAssetAmount because Redemption exchanges in 1:1 ratio
    require(
      IERC20(REDEEMED_ASSET).balanceOf(address(this)) ==
        initialRedeemedAssetBalance + redeemableAssetAmount,
      'INVALID_REDEMPTION'
    );
    IERC20(REDEEMABLE_ASSET).approve(address(REDEMPTION_CONTRACT), 0);

    IERC20(REDEEMED_ASSET).safeTransfer(receiver, redeemableAssetAmount);

    require(
      IGhoToken(GHO_TOKEN).balanceOf(address(this)) == initialGhoBalance,
      'INVALID_REMAINING_GHO_BALANCE'
    );
    require(
      IERC20(REDEEMABLE_ASSET).balanceOf(address(this)) == initialRedeemableAssetBalance,
      'INVALID_REMAINING_REDEEMABLE_ASSET_BALANCE'
    );

    emit BuyAssetThroughRedemption(originator, receiver, redeemableAssetAmount, ghoSold);
    return (redeemableAssetAmount, ghoSold);
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
    uint256 initialRedeemableAssetBalance = IERC20(REDEEMABLE_ASSET).balanceOf(address(this));
    uint256 initialRedeemedAssetBalance = IERC20(REDEEMED_ASSET).balanceOf(address(this));

    (uint256 redeemedAssetAmount, , , ) = IGsm(GSM).getGhoAmountForSellAsset(maxAmount);
    IERC20(REDEEMED_ASSET).transferFrom(originator, address(this), redeemedAssetAmount);
    IERC20(REDEEMED_ASSET).approve(ISSUANCE_RECEIVER_CONTRACT, redeemedAssetAmount);
    //TODO: replace with proper issuance implementation later
    MockIssuanceReceiver(ISSUANCE_RECEIVER_CONTRACT).issuance(redeemedAssetAmount);
    require(
      IERC20(REDEEMABLE_ASSET).balanceOf(address(this)) ==
        initialRedeemedAssetBalance + redeemedAssetAmount,
      'INVALID_ISSUANCE'
    );
    // reset approval after issuance
    IERC20(REDEEMED_ASSET).approve(ISSUANCE_RECEIVER_CONTRACT, 0);

    IERC20(REDEEMABLE_ASSET).approve(GSM, redeemedAssetAmount);
    (uint256 assetAmount, uint256 ghoBought) = IGsm(GSM).sellAsset(maxAmount, receiver);
    // reset approval after sellAsset
    IERC20(REDEEMABLE_ASSET).approve(GSM, 0);

    require(
      IGhoToken(GHO_TOKEN).balanceOf(address(this)) == initialGhoBalance,
      'INVALID_REMAINING_GHO_BALANCE'
    );
    require(
      IERC20(REDEEMED_ASSET).balanceOf(address(this)) == initialRedeemedAssetBalance,
      'INVALID_REMAINING_REDEEMED_ASSET_BALANCE'
    );

    emit SellAssetThroughIssuance(originator, receiver, redeemedAssetAmount, ghoBought);
    return (assetAmount, ghoBought);
  }
}
