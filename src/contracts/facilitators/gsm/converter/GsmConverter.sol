// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {GPv2SafeERC20} from '@aave/core-v3/contracts/dependencies/gnosis/contracts/GPv2SafeERC20.sol';
import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IGhoToken} from '../../../gho/interfaces/IGhoToken.sol';
import {IGsm} from '../interfaces/IGsm.sol';
import {IGsmConverter} from './interfaces/IGsmConverter.sol';
import {IRedemption} from '../dependencies/circle/IRedemption.sol';

/**
 * @title GsmConverter
 * @author Aave
 * @notice Converter that facilitates conversions/redemptions of underlying assets. Integrates with GSM to buy/sell to go to/from an underlying asset to/from GHO.
 */
contract GsmConverter is Ownable, IGsmConverter {
  using GPv2SafeERC20 for IERC20;

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

  /**
   * @dev Constructor
   * @param gsm The address of the associated GSM contract
   * @param redemptionContract The address of the redemption contract associated with the redemption/conversion
   * @param redeemableAsset The address of the asset being redeemed
   * @param redeemedAsset The address of the asset being received from redemption
   */
  constructor(
    address admin,
    address gsm,
    address redemptionContract,
    address redeemableAsset,
    address redeemedAsset
  ) {
    require(admin != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(gsm != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(redemptionContract != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(redeemableAsset != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(redeemedAsset != address(0), 'ZERO_ADDRESS_NOT_VALID');

    GSM = gsm;
    REDEMPTION_CONTRACT = redemptionContract;
    REDEEMABLE_ASSET = redeemableAsset; // BUIDL
    REDEEMED_ASSET = redeemedAsset; // USDC
    GHO_TOKEN = IGsm(GSM).GHO_TOKEN();

    transferOwnership(admin);
  }

  /// @inheritdoc IGsmConverter
  function buyAsset(uint256 minAmount, address receiver) external returns (uint256, uint256) {
    require(minAmount > 0, 'INVALID_MIN_AMOUNT');

    uint256 initialGhoBalance = IGhoToken(GHO_TOKEN).balanceOf(address(this));
    uint256 initialRedeemableAssetBalance = IERC20(REDEEMABLE_ASSET).balanceOf(address(this));
    uint256 initialRedeemedAssetBalance = IERC20(REDEEMED_ASSET).balanceOf(address(this));

    (, uint256 ghoAmount, , ) = IGsm(GSM).getGhoAmountForBuyAsset(minAmount);

    IGhoToken(GHO_TOKEN).transferFrom(msg.sender, address(this), ghoAmount);
    IGhoToken(GHO_TOKEN).approve(address(GSM), ghoAmount);

    (uint256 redeemableAssetAmount, uint256 ghoSold) = IGsm(GSM).buyAsset(minAmount, address(this));
    require(ghoAmount == ghoSold, 'INVALID_GHO_SOLD');

    IGhoToken(GHO_TOKEN).approve(address(GSM), 0);
    IERC20(REDEEMABLE_ASSET).approve(address(REDEMPTION_CONTRACT), redeemableAssetAmount);
    IRedemption(REDEMPTION_CONTRACT).redeem(redeemableAssetAmount);
    IERC20(REDEEMABLE_ASSET).approve(address(REDEMPTION_CONTRACT), 0);
    // redeemableAssetAmount matches redeemedAssetAmount because Redemption exchanges in 1:1 ratio
    IERC20(REDEEMED_ASSET).safeTransfer(receiver, redeemableAssetAmount);

    require(
      IGhoToken(GHO_TOKEN).balanceOf(address(this)) == initialGhoBalance,
      'INVALID_REMAINING_GHO_BALANCE'
    );
    require(
      IERC20(REDEEMABLE_ASSET).balanceOf(address(this)) == initialRedeemableAssetBalance,
      'INVALID_REMAINING_REDEEMABLE_ASSET_BALANCE'
    );
    require(
      IERC20(REDEEMED_ASSET).balanceOf(address(this)) == initialRedeemedAssetBalance,
      'INVALID_REMAINING_REDEEMED_ASSET_BALANCE'
    );

    emit BuyAssetThroughRedemption(msg.sender, receiver, redeemableAssetAmount, ghoSold);
    return (redeemableAssetAmount, ghoSold);
  }

  // TODO:
  // 2) implement sellAsset (sell USDC -> get GHO)
  // - onramp USDC to BUIDL, get BUIDL - unknown how to onramp USDC to BUIDL currently
  // - send BUIDL to GSM, get GHO from GSM
  // - send GHO to user, safeTransfer

  /// @inheritdoc IGsmConverter
  function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
    require(amount > 0, 'INVALID_AMOUNT');
    IERC20(token).safeTransfer(to, amount);
    emit TokensRescued(token, to, amount);
  }
}
