import "../GsmMethods/erc20.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/aave_price_fee_limits.spec";
import "../GsmMethods/erc4626.spec";
using DiffHelper as diffHelper;

// ========================= Buying ==============================

// @Title 4626: The fee reported by `getBuyFee` is greater than or equal to the fee reported by `getAssetAmountForBuyAsset`
// getBuyFee -(>=)-> getAssetAmountForBuyAsset
// Shows >=
// Holds: https://prover.certora.com/output/40748/b8b526129e114ca9b3e7dcdcdf3d2fd4?anonymousKey=d1a47509f71c924af60b0b38ec1b3dcd9fe0ae63
// (1)
rule R1_getBuyFeeGeGetAssetAmountForBuyAsset {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint128 ghoAmount;
    uint256 estimatedBuyFee = getBuyFee(e, ghoAmount);

    require estimatedBuyFee + ghoAmount <= max_uint256;
    uint256 amountOfGhoToSell = assert_uint256(estimatedBuyFee + ghoAmount);

    uint256 fee;
    _, _, _, fee = getAssetAmountForBuyAsset(e, amountOfGhoToSell);

    assert fee <= estimatedBuyFee;
}

// @Title 4626: The fee reported by `getBuyFee` can be greater than the fee reported by `getAssetAmountForBuyAsset`
// getBuyFee -(>=)-> getAssetAmountForBuyAsset
// Shows >
// Holds: https://prover.certora.com/output/40748/b8b526129e114ca9b3e7dcdcdf3d2fd4?anonymousKey=d1a47509f71c924af60b0b38ec1b3dcd9fe0ae63
// (1a)
// Expected to hold in the current implementation

rule R1a_getBuyFeeNeGetAssetAmountForBuyAsset {
    env e;
    feeLimits(e);
    priceLimits(e);

    require e.msg.sender != currentContract; // Otherwise the fee in GHO will come back to me, messing up the balance calculation

    uint128 ghoAmount;
    uint256 estimatedBuyFee = getBuyFee(e, ghoAmount);

    require estimatedBuyFee + ghoAmount <= max_uint256;
    uint256 amountOfGhoToSell = assert_uint256(estimatedBuyFee + ghoAmount);

    uint256 fee;
    _, _, _, fee = getAssetAmountForBuyAsset(e, amountOfGhoToSell);

    satisfy fee < estimatedBuyFee;
}

// @Title 4626: The fee reported by `getAssetAmountForBuyAsset` is equal to the fee accrued by `buyAsset`
// getAssetAmountForBuyAsset -(==)-> buyAsset
// Show ==
// (2)
// holds: https://prover.certora.com/output/40748/b8b526129e114ca9b3e7dcdcdf3d2fd4?anonymousKey=d1a47509f71c924af60b0b38ec1b3dcd9fe0ae63
rule R2_getAssetAmountForBuyAssetNeBuyAssetFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    address receiver;

    uint256 preAccruedFees = currentContract._accruedFees;

    uint256 amountOfGhoToSell;
    uint256 estimatedFee;

    uint256 assetAmount;

    assetAmount, _, _, estimatedFee = getAssetAmountForBuyAsset(e, amountOfGhoToSell);

    require assetAmount <= max_uint128; // No overflow
    require getExcess(e) == 0; // Are we blocking important executions?

    buyAsset(e, assert_uint128(assetAmount), receiver);

    uint256 postAccruedFees = currentContract._accruedFees;

    uint256 actualFee = assert_uint256(postAccruedFees - preAccruedFees);

    assert estimatedFee == actualFee;
}

// @Title 4626: The fee reported by `getAssetAmountForBuyAsset` is equal to the fee accrued by `getBuyFee`
// getAssetAmountForBuyAssetFee -(==)-> getBuyFee
// Shows ==
// Holds. https://prover.certora.com/output/40748/b8b526129e114ca9b3e7dcdcdf3d2fd4?anonymousKey=d1a47509f71c924af60b0b38ec1b3dcd9fe0ae63
// (3)
rule R3_getAssetAmountForBuyAssetFeeEqGetBuyFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 estimatedFee;
    uint256 grossGho;
    uint256 amountOfGhoToSellWithFee;

    _, _, grossGho, estimatedFee = getAssetAmountForBuyAsset(e, amountOfGhoToSellWithFee);

    uint256 fee = getBuyFee(e, grossGho);

    assert fee == estimatedFee;
}

// @Title 4626: The fee reported by `getBuyFee` is greater than or equal to the fee accrued by `buyAsset`
// getBuyFee -(>=)-> buyAsset
// shows that estimatedBuyFee >= actualFee.
// Holds: https://prover.certora.com/output/40748/b8b526129e114ca9b3e7dcdcdf3d2fd4?anonymousKey=d1a47509f71c924af60b0b38ec1b3dcd9fe0ae63
// (4)
rule R4_estimatedBuyFeeLtActualBuyFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint128 ghoAmount;
    address receiver;

    uint256 preAccruedFees = currentContract._accruedFees;
    uint256 estimatedBuyFee = getBuyFee(e, ghoAmount);

    require estimatedBuyFee + ghoAmount <= max_uint256;
    uint256 amountOfGhoToSell = assert_uint256(estimatedBuyFee + ghoAmount);

    uint256 assetAmount;

    assetAmount, _, _, _ = getAssetAmountForBuyAsset(e, amountOfGhoToSell);

    require assetAmount <= max_uint128; // No overflow
    require getExcess(e) == 0; // Are we blocking important executions?

    buyAsset(e, assert_uint128(assetAmount), receiver);

    uint256 postAccruedFees = currentContract._accruedFees;

    uint256 actualFee = assert_uint256(postAccruedFees - preAccruedFees);

    assert estimatedBuyFee >= actualFee;
}

// @Title 4626: The fee reported by `getBuyFee` can be greater than the fee deduced by `buyAsset`
// getBuyFee -(>=)-> buyAsset
// shows that the estimated fee can be > than actual fee (but isn't necessarily always)
// Holds: https://prover.certora.com/output/40748/b8b526129e114ca9b3e7dcdcdf3d2fd4?anonymousKey=d1a47509f71c924af60b0b38ec1b3dcd9fe0ae63
// (4a)
rule R4a_estimatedBuyFeeGtActualBuyFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 priceRatio = getPriceRatio(e);

    uint128 ghoAmount;
    address receiver;

    uint256 preAccruedFees = currentContract._accruedFees;
    uint256 estimatedBuyFee = getBuyFee(e, ghoAmount);

    require estimatedBuyFee + ghoAmount <= max_uint256;
    uint256 amountOfGhoToSell = assert_uint256(estimatedBuyFee + ghoAmount);

    uint256 assetAmount;

    assetAmount, _, _, _ = getAssetAmountForBuyAsset(e, amountOfGhoToSell);

    require assetAmount <= max_uint128; // No overflow
    require getExcess(e) == 0; // Are we blocking important executions?

    buyAsset(e, assert_uint128(assetAmount), receiver);

    uint256 postAccruedFees = currentContract._accruedFees;

    uint256 actualFee = assert_uint256(postAccruedFees - preAccruedFees);

    satisfy estimatedBuyFee > actualFee;
}

// @Title 4626: The fee reported by `getBuyFee` can be equal to the fee reported by `buyAsset`
// getBuyFee -(>=)-> buyAsset
// shows that the fee can be correct (but isn't necessarily always)
// (4b)
// Holds: https://prover.certora.com/output/40748/b8b526129e114ca9b3e7dcdcdf3d2fd4?anonymousKey=d1a47509f71c924af60b0b38ec1b3dcd9fe0ae63
rule R4b_estimatedBuyFeeEqActualBuyFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint128 ghoAmount;
    address receiver;

    uint256 preAccruedFees = currentContract._accruedFees;
    uint256 estimatedBuyFee = getBuyFee(e, ghoAmount);

    require estimatedBuyFee + ghoAmount <= max_uint256;
    uint256 amountOfGhoToSell = assert_uint256(estimatedBuyFee + ghoAmount);

    uint256 assetAmount;

    assetAmount, _, _, _ = getAssetAmountForBuyAsset(e, amountOfGhoToSell);

    require assetAmount <= max_uint128; // No overflow
    require getExcess(e) == 0; // Are we blocking important executions?

    buyAsset(e, assert_uint128(assetAmount), receiver);

    uint256 postAccruedFees = currentContract._accruedFees;

    uint256 actualFee = assert_uint256(postAccruedFees - preAccruedFees);

    satisfy estimatedBuyFee == actualFee;
}