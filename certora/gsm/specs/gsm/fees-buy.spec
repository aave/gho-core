import "../GsmMethods/erc20.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/aave_price_fee_limits.spec";

using DiffHelper as diffHelper;

// Issue:
// Inconsistency in the reported and accrued fees when buying asset
// Description:
// When a swap takes place in GSM, the contract may collect a fee.  The fee is
// represented in basic points.  When a concrete transaction takes place the fee in
// basic points is used to obtain a concrete fee in GHO.  The API exposes the fee
// in three different ways.  Directly based on BP through `getBuyFee(x)`, as the fee
// reported by `getAssetAmountForBuyAsset(x)`, and as the fee accrued through
// `buyAsset(a)`.  The fee reported by `getBuyFee(x)` can be less than, greater
// than, or equal to the fee accrued by `buyAsset(a)`.  Similarly, the fee
// reported by `getAssetAmountForBuyAsset(x)` can be less than, greater than, or
// equal to the fee accrued by `buyAsset`
// Mitigation/Fix:
// TODO
// Note: from https://github.com/Certora/gho-gsm/pull/10


// ========================= Buying ==============================
// A successful run:
// https://prover.certora.com/output/40748/c6f0cc0e2d794e2c997ce7ec2f37ca48/?anonymousKey=5af25f5d1ed5c68b6b1db47fdc5e04bc673752b6

// @title The fee reported by `getBuyFee` is greater than or equal to the fee reported by `getAssetAmountForBuyAsset`
// getBuyFee -(>=)-> getAssetAmountForBuyAsset
// Shows >=
// Holds
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

    assert estimatedBuyFee >= fee;
}

// @title The fee reported by `getBuyFee` can be greater than the fee reported by `getAssetAmountForBuyAsset`
// getBuyFee -(>=)-> getAssetAmountForBuyAsset.
// Shows >
// (1a)
// Holds.
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

    satisfy estimatedBuyFee > fee;
}

// @title The fee reported by `getBuyFee` can differ from the fee reported by `getAssetAmountForBuyAsset` by at least 10^3
// getBuyFee -(>=, ?)-> getAssetAmountForBuyAsset
// (1-UB)
// Holds.
rule R1UB_getBuyFeeGeGetAssetAmountForBuyAssetUB {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint128 ghoAmount;
    uint256 estimatedBuyFee = getBuyFee(e, ghoAmount);

    require estimatedBuyFee + ghoAmount <= max_uint256;
    uint256 amountOfGhoToSell = assert_uint256(estimatedBuyFee + ghoAmount);

    uint256 fee;
    _, _, _, fee = getAssetAmountForBuyAsset(e, amountOfGhoToSell);

    uint N = 10^3;
    satisfy !diffHelper.differsByAtMostN(e, fee, estimatedBuyFee, N);
}

// @title The fee reported by `getAssetAmountForBuyAsset` is equal to the fee accrued by `buyAsset`
// getAssetAmountForBuyAsset -(==)-> buyAsset
// Show ==
// (2)
// Holds.
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

    buyAsset(e, assert_uint128(assetAmount), receiver);

    uint256 postAccruedFees = currentContract._accruedFees;

    uint256 actualFee = assert_uint256(postAccruedFees - preAccruedFees);

    assert estimatedFee == actualFee;
}

// @title The fee reported by `getAssetAmountForBuyAsset` is equal to the fee accrued by `getBuyFee`
// getAssetAmountForBuyAssetFee -(==)-> getBuyFee
// Shows ==
// Holds.
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

// @title The fee reported by `getBuyFee` is greater than or equal to the fee accrued by `buyAsset`
// getBuyFee -(>=)-> buyAsset
// shows that the estimated fee >= actual fee
// Holds.
// (4)
rule R4_estimatedBuyFeeGeActualBuyFee {
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

    buyAsset(e, assert_uint128(assetAmount), receiver);

    uint256 postAccruedFees = currentContract._accruedFees;

    uint256 actualFee = assert_uint256(postAccruedFees - preAccruedFees);

    assert estimatedBuyFee >= actualFee;
}

// @title The fee reported by `getBuyFee` can be greater than the fee deduced by `buyAsset`
// getBuyFee -(>=)-> buyAsset
// shows that the estimated fee can be > than actual fee (but isn't necessarily always)
// Holds.
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

    buyAsset(e, assert_uint128(assetAmount), receiver);

    uint256 postAccruedFees = currentContract._accruedFees;

    uint256 actualFee = assert_uint256(postAccruedFees - preAccruedFees);

    satisfy estimatedBuyFee > actualFee;
}