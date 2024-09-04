// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {GPv2SafeERC20} from '@aave/core-v3/contracts/dependencies/gnosis/contracts/GPv2SafeERC20.sol';
// import {EIP712} from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
// import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
// import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
// import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
// import {IGhoFacilitator} from '../../gho/interfaces/IGhoFacilitator.sol';
import {IGhoToken} from '../../gho/interfaces/IGhoToken.sol';
// import {IGsmPriceStrategy} from './priceStrategy/interfaces/IGsmPriceStrategy.sol';
// import {IGsmFeeStrategy} from './feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {IGsm} from './interfaces/IGsm.sol';
import {IRedemption} from './dependencies/circle/interfaces/IRedemption.sol';

/**
 * @title GsmConverter
 * @author Aave
 * @notice GHO Stability Module. It provides buy/sell facilities to go to/from an underlying asset to/from GHO.
 * @dev To be covered by a proxy contract.
 */
contract GsmConverter {
  using GPv2SafeERC20 for IERC20;

  address public immutable GSM;
  // address public immutable GHO_TOKEN;
  address public immutable REDEEMABLE_ASSET;
  address public immutable REDEEMED_ASSET;
  address public immutable REDEMPTION_CONTRACT;

  event BuyAssetThroughRedemption(
    address indexed originator,
    address indexed receiver,
    uint256 redemptionAssetAmount,
    uint256 ghoSold
  );

  /**
   * @dev Constructor
   * @param gsm The address of the GSM contract associated with conversion
   * @param redemptionContract The address of the
   * @param redeemableAsset The address of the
   * @param redeemedAsset The address of the
   */
  constructor(
    address gsm,
    address redemptionContract,
    address redeemableAsset,
    address redeemedAsset
  ) {
    require(gsm != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(redemptionContract != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(redeemableAsset != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(redeemedAsset != address(0), 'ZERO_ADDRESS_NOT_VALID');

    GSM = gsm;
    REDEMPTION_CONTRACT = redemptionContract;
    REDEEMABLE_ASSET = redeemableAsset;
    REDEEMED_ASSET = redeemedAsset;
  }

  // TODO:
  // 1) implement buyAsset (sell GHO -> get USDC)
  // - GHO transferFrom user to converter
  // - call buyAsset on GSM, get the BUIDL
  // - offramp BUIDL to USDC, send USDC to user
  // - call redeem on offramp to get BUIDL
  // - send USDC to user, safeTransfer
  // - do we need to use multicall? https://docs.openzeppelin.com/contracts/4.x/utilities#multicall

  /**
   * @dev
   */
  function buyAssetThroughRedemption(
    uint256 minAmount,
    address receiver
  ) external returns (uint256, uint256) {
    IGhoToken(IGsm(GSM).GHO_TOKEN()).transferFrom(msg.sender, address(this), minAmount);
    (uint256 redemptionAssetAmount, uint256 ghoSold) = IGsm(GSM).buyAsset(minAmount, receiver);
    IRedemption(REDEMPTION_CONTRACT).redeem(redemptionAssetAmount);
    IERC20(REDEEMED_ASSET).safeTransfer(receiver, redemptionAssetAmount);

    emit BuyAssetThroughRedemption(msg.sender, receiver, redemptionAssetAmount, ghoSold);
  }

  // TODO:
  // 2) implement sellAsset (sell USDC -> get GHO)
  // - onramp USDC to BUIDL, get BUIDL - unknown how to onramp USDC to BUIDL currently
  // - send BUIDL to GSM, get GHO from GSM
  // - send GHO to user, safeTransfer
}
