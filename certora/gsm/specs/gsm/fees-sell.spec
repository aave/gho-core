import "../GsmMethods/erc20.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/aave_price_fee_limits.spec";

using DiffHelper as diffHelper;

// Study how well the estimated fees match the actual fees.

// Issue: "Inconsistency in the reported and accrued fees when selling asset"
// Rules broken: "R3_estimatedSellFeeCanBeHigherThanActualSellFee"
// Example property: """"""
//
// Description: """
// When a swap takes place in GSM, the contract may collect a fee.  The
// fee is represented in basic points.  When a concrete transaction
// takes place the fee in basic points is used to obtain a concrete fee
// in GHO.
// The API exposes the fee in three different ways.  Directly based on BP
// through `getSellFee(x)`, as the fee reported by
// `getAssetAmountForSellAsset(x)`, and as the fee accrued through
// `sellAsset(a)`.  The fee reported by `getSellFee(x)` can be less than,
// greater than, or equal to the fee accrued by `sellAsset(a)`.
// """
// Mitigation / Fix: """TODO"""
// Severity: "Medium"
// Note: from https://github.com/Certora/gho-gsm/pull/10



// ========================= Selling ==============================
// The results are available in this run:
// https://prover.certora.com/output/40748/de214c37fe2549d0b11461087d191d9f?anonymousKey=2711135cf621015f610eabd5a685b8f82e47ff67

// @Title The fee reported by `getAssetAmountForSellAsset` is greater than or equal to the fee reported by `getSellFee`
// getAssetAmountForSellAssetFee -(>=)-> getSellFee
// Shows >=
// (1)
//
rule R1_getAssetAmountForSellAssetFeeGeGetSellFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 estimatedFee;
    uint256 amountOfGhoToBuy;
    uint256 exactAmountOfGhoToReceive;

    _, exactAmountOfGhoToReceive, _, estimatedFee = getAssetAmountForSellAsset(e, amountOfGhoToBuy);

    uint256 fee = getSellFee(e, amountOfGhoToBuy);

    assert estimatedFee >= fee;
}

// @Title The fee reported by `getAssetAmountForSellAsset` can be greater than the fee reported by `getSellFee`
// getAssetAmountForSellAssetFee -(>=)-> getSellFee
// Shows >
// (1a)
//
rule R1a_getAssetAmountForSellAssetFeeGeGetSellFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 estimatedFee;
    uint256 amountOfGhoToBuy;
    uint256 exactAmountOfGhoToReceive;

    _, exactAmountOfGhoToReceive, _, estimatedFee = getAssetAmountForSellAsset(e, amountOfGhoToBuy);

    uint256 fee = getSellFee(e, amountOfGhoToBuy);

    satisfy estimatedFee > fee;
}

// @Title The fee reported by `getAssetAmountForSellAsset` can be greater than or equal to the fee accrued by `sellAsset`
// getAssetAmountForSellAsset -(>=)-> sellAsset
// Shows >=
// (2)
rule R2_getAssetAmountForSellAssetVsActualSellFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 assetAmount;
    uint256 estimatedFee;
    uint256 amountOfGhoToBuy;

    address receiver;

    uint256 preAccruedFees = currentContract._accruedFees;

    assetAmount, _, _, estimatedFee = getAssetAmountForSellAsset(e, amountOfGhoToBuy);
    sellAsset(e, require_uint128(assetAmount), receiver);
    uint256 postAccruedFees = currentContract._accruedFees;

    uint256 actualFee = require_uint256(postAccruedFees - preAccruedFees);

    assert estimatedFee >= actualFee;
}

// @Title The fee reported by `getAssetAmountForSellAsset` may differ from the fee accrued by `sellAsset`
// getAssetAmountForSellAsset -(>=)-> sellAsset
// Shows >
// (2a)
rule R2a_getAssetAmountForSellAssetNeActualSellFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 assetAmount;
    uint256 estimatedFee;
    uint256 amountOfGhoToBuy;

    address receiver;

    uint256 preAccruedFees = currentContract._accruedFees;

    assetAmount, _, _, estimatedFee = getAssetAmountForSellAsset(e, amountOfGhoToBuy);
    sellAsset(e, require_uint128(assetAmount), receiver);
    uint256 postAccruedFees = currentContract._accruedFees;

    uint256 actualFee = require_uint128(postAccruedFees - preAccruedFees);

    satisfy estimatedFee > actualFee;
}

// @Title The fee reported by `getSellFee` is less than or equal to the fee accrued by `sellAsset`
// getSellFee -(<=)-> sellAsset
// shows <=
// (3)
//
rule R3_estimatedSellFeeCanBeHigherThanActualSellFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint128 ghoAmount;
    address receiver;

    uint256 preAccruedFees = currentContract._accruedFees;
    uint256 estimatedSellFee = getSellFee(e, ghoAmount);

    require ghoAmount <= max_uint128;
    require estimatedSellFee <= max_uint128;

    uint256 assetAmount;

    assetAmount, _, _, _ = getAssetAmountForSellAsset(e, ghoAmount);

    sellAsset(e, require_uint128(assetAmount), receiver);

    uint256 postAccruedFees = currentContract._accruedFees;

    uint256 actualFee = require_uint256(postAccruedFees - preAccruedFees);

    assert estimatedSellFee <= actualFee;
}

// @Title The fee reported by `getSellFee` can be less than the fee deduced by `sellAsset`
// getSellFee -(<=)-> sellAsset
// shows <
// (3a)
//
rule R3a_estimatedSellFeeCanBeLowerThanActualSellFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint128 ghoAmount;
    address receiver;

    uint256 preAccruedFees = currentContract._accruedFees;
    uint256 estimatedSellFee = getSellFee(e, ghoAmount);

    require ghoAmount <= max_uint128;
    require estimatedSellFee <= max_uint128;

    uint256 assetAmount;

    assetAmount, _, _, _ = getAssetAmountForSellAsset(e, ghoAmount);

    sellAsset(e, require_uint128(assetAmount), receiver);

    uint256 postAccruedFees = currentContract._accruedFees;

    uint256 actualFee = require_uint256(postAccruedFees - preAccruedFees);

    satisfy estimatedSellFee < actualFee;
}

// @Title The fee reported by `getSellFee` is less than or equal to the fee reported by `getAssetAmountForSellAsset`
// getSellFee -(<=)-> getAssetAmountForSellAsset
// (4)
rule R4_getSellFeeVsgetAssetAmountForSellAsset {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 ghoAmount;
    uint256 estimatedSellFee;
    uint256 sellFee;

    estimatedSellFee  = getSellFee(e, ghoAmount);
    _, _, _, sellFee = getAssetAmountForSellAsset(e, ghoAmount);
    assert estimatedSellFee <= sellFee;
}

// @Title The fee reported by `getSellFee` can be less than the fee reported by `getAssetAmountForSellAsset`
// getSellFee -(<=)-> getAssetAmountForSellAsset
// (4a)
// Shows <
rule R4a_getSellFeeVsgetAssetAmountForSellAsset {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 ghoAmount;
    uint256 estimatedSellFee;
    uint256 sellFee;

    estimatedSellFee  = getSellFee(e, ghoAmount);
    _, _, _, sellFee = getAssetAmountForSellAsset(e, ghoAmount);
    satisfy estimatedSellFee < sellFee;
}
