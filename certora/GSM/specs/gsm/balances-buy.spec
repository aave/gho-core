import "../GsmMethods/erc20.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/aave_price_fee_limits.spec";

using DiffHelper as diffHelper;

// ========================= Buying ==============================
// The results are available in this run:
// https://prover.certora.com/output/40748/8433d4a7f3194f019a7ae98ddb872694/?anonymousKey=55effda6e5861528384a148b2b714a373ce5a637


// Issue: "Inconsistency in the amount of GHO user asks to sell and how much GHO is deducted from user account at the end."
// Rules broken: "R4_sellGhoUpdatesAssetBuyerGhoBalanceGe"
// Example property: """
// Case 1.
// Let GHO amount `g = 6`, price ratio `PR = 4`, underlying asset units
// `UAU = 1`, buy fee in BP `buyFeeBP = 0`.  The change in GHO balance
// is 8.
//
// Case 2.
// Let GHO amount `g = 3*10^36+5`, price ratio `PR = 1*10^36+2`,
// underlying asset units `UAU = 1`, buy fee in BP `buyFeeBP = 0.  The
// change in GHO balance is 2*10^36+4
// """
//
// Description: """
// GSM provides a way to swap an underlying asset against GHO.
// Technically this is implemented by providing the following API functions for
// swapping, where the argument `a` is in asset:
// - `buyAsset(a)`
// - `sellAsset(a)`
//
// In case the user wants to instead buy or sell GHO, there is no direct
// way to achieve this with the API.  When buying, respectively selling,
// GHO, the user needs to first call `getAssetAmountForSellAsset(g)`,
// respectively `getAssetAmountForSellAsset(g)`, to obtain the amount of
// asset `a` that, when provided to the correct swap function, executes
// the buy or sell based on the amount `g` in GHO.  It is not always
// possible to specify an amount of asset that will result in exactly
// `g` GHO being bought or sold.  For example, if the price of one asset
// is 10 GHO, and the number of decimals in GHO and asset are the same,
// it is not possible to sell exactly 1 GHO using the API: assuming no
// fees, one would presumably sell either 0 GHO or 10 GHO.  Depending on
// the properties of asset, the fees, and the amount `g` of GHO, the
// code might result in more or less than `g` GHO being sold.
// """
// Mitigation / Fix: """Refactor the API, fix rounding directions. Fix
// #168"""
// Severity: "High"
// Note: from https://github.com/Certora/gho-gsm/pull/10

// Issue:
// User may pay more GHO than the maximum they provided
// Description:
// The user may ask the amount of assets to provide for `buyAsset` by calling
// `getAssetAmountForBuyAsset(max)`, where `max` is the maximum amount of GHO
// user is willing to pay.  When the return value is provided to `buyAsset`, it
// is possible that the user is charged more than `max` GHO.
// Note: from https://github.com/Certora/gho-gsm/pull/12

// Issue:
// The exact amount of GHO returned by `getAssetAmountForBuyAsset(max)` can be higher than `max`
// Description:
// The user may ask the amount of assets to provide for `buyAsset` by calling
// `getAssetAmountForBuyAsset(max)`, where `max` is the maximum amount of GHO
// user is willing to pay.  One of the return values of
// `getAssetAmountForBuyAsset` is the exact amount of GHO that will be deducted.
// This value can be higher than `max`.
// Note: from https://github.com/Certora/gho-gsm/pull/12

// @Title The exact amount of GHO returned by `getAssetAmountForBuyAsset(maxGho)` is less than or equal to `maxGho`
// . -[getAssetAmountForBuyAsset(x)]-> .
// exactGHO <= goWithFee
// where exactGHO is the 2nd return value of getAssetAmountForBuyAsset
// Holds.
// (1)
rule R1_getAssetAmountForBuyAssetRV2 {
    env e;
    feeLimits(e);
    priceLimits(e);

    // Note: not required?
    require e.msg.sender != currentContract; // Otherwise the fee in GHO will come back to me, messing up the balance calculation
    require GHO_TOKEN(e) != UNDERLYING_ASSET(e); // This is inflation prevention (and also avoids an overflow)

    uint256 ghoWithFee;
    uint256 assetsToBuy;
    uint256 exactGHO;
    address receiver;

    // For debugging:
    uint256 priceRatio = getPriceRatio(e);
    uint256 underlyingAssetUnits = getUnderlyingAssetUnits(e);


    _, exactGHO, _, _ = getAssetAmountForBuyAsset(e, ghoWithFee);

    assert exactGHO <= ghoWithFee;
}

// @Title The exact amount of GHO returned by `getAssetAmountForBuyAsset(maxGho)` can be less than `maxGho`
// The second return value of `getAssetAmountForBuyAsset(x)` can be less
// than x.
// . -[getAssetAmountForBuyAsset(x)]-> .
// exactGHO <= goWithFee
// where exactGHO is the 2nd return value of getAssetAmountForBuyAsset
// Holds
// (1a)
rule R1a_getAssetAmountForBuyAssetRV2 {
    env e;
    feeLimits(e);
    priceLimits(e);

    // Note: not required?
    require e.msg.sender != currentContract; // Otherwise the fee in GHO will come back to me, messing up the balance calculation
    require GHO_TOKEN(e) != UNDERLYING_ASSET(e); // This is inflation prevention (and also avoids an overflow)

    uint256 ghoWithFee;
    uint256 assetsToBuy;
    uint256 exactGHO;
    address receiver;

    // For debugging:
    uint256 priceRatio = getPriceRatio(e);
    uint256 underlyingAssetUnits = getUnderlyingAssetUnits(e);


    _, exactGHO, _, _ = getAssetAmountForBuyAsset(e, ghoWithFee);

    satisfy exactGHO < ghoWithFee;
}


// @Title The difference in the exact amount of GHO returned by `getAssetAmountForBuyAsset(maxGho)` and `maxGho` can be greater than 10^13
// (1-UB)
rule R1UB_getAssetAmountForBuyAssetRV2_UB {
    env e;
    feeLimits(e);
    priceLimits(e);

    // Note: not required?
    require e.msg.sender != currentContract; // Otherwise the fee in GHO will come back to me, messing up the balance calculation
    require GHO_TOKEN(e) != UNDERLYING_ASSET(e); // This is inflation prevention (and also avoids an overflow)

    uint256 ghoWithFee;
    uint256 assetsToBuy;
    uint256 exactGHO;
    address receiver;

    // For debugging:
    uint256 priceRatio = getPriceRatio(e);
    uint256 underlyingAssetUnits = getUnderlyingAssetUnits(e);


    _, exactGHO, _, _ = getAssetAmountForBuyAsset(e, ghoWithFee);

    uint256 N = 10^13;
    satisfy !diffHelper.differsByAtMostN(e, exactGHO, ghoWithFee, N);
}

// @Title The exact amount of GHO returned by `getAssetAmountForBuyAsset(x)` matches the GHO amount deduced from user at `buyAsset`
// . -[getAssetAmountForBuyAsset(x)]-> . -[buyAsset(exactGHO)]-> .
// ghoBalance_1 - ghoBalance_2 = exactGHO
// where exactGHO is the 2nd return value of getAssetAmountForBuyAsset
// Holds.
// (2)
rule R2_getAssetAmountForBuyAssetRV_vs_GhoBalance {
    env e;
    feeLimits(e);
    priceLimits(e);

    require e.msg.sender != currentContract; // Otherwise the fee in GHO will come back to me, messing up the balance calculation
    require GHO_TOKEN(e) != UNDERLYING_ASSET(e); // This is inflation prevention (and also avoids an overflow)

    uint256 ghoWithFee;
    uint256 assetsToBuy;
    uint256 exactGHO;
    address receiver;

    // For debugging:
    uint256 priceRatio = getPriceRatio(e);
    uint256 underlyingAssetUnits = getUnderlyingAssetUnits(e);


    assetsToBuy, exactGHO, _, _ = getAssetAmountForBuyAsset(e, ghoWithFee);
    uint256 buyerGhoBalanceBefore = balanceOfGho(e, e.msg.sender);
    require assetsToBuy <= max_uint128;
    buyAsset(e, assert_uint128(assetsToBuy), receiver);
    uint256 buyerGhoBalanceAfter = balanceOfGho(e, e.msg.sender);

    mathint balanceDiff = buyerGhoBalanceBefore - buyerGhoBalanceAfter;
    assert to_mathint(exactGHO) == balanceDiff;
}

// @Title The asset amount deduced from user's account at `buyAsset(minAssets)` is at least `minAssets`
// -[buyAsset]->
// assetsToBuy <= |buyerAssetBalanceAfter - buyerAssetBalanceBefore|
// (3)
// Holds.
rule R3_buyAssetUpdatesAssetBuyerAssetBalanceLe {
    env e;
    feeLimits(e);
    priceLimits(e);

    require e.msg.sender != currentContract; // Otherwise the fee in GHO will come back to me, messing up the balance calculation
    require GHO_TOKEN(e) != UNDERLYING_ASSET(e); // This is inflation prevention (and also avoids an overflow)

    uint256 assetsToBuy;
    address receiver;
    require receiver != currentContract; // Otherwise GHO is burned but asset value doesn't increase.  (This is only a problem for my bookkeeping)

    // For debugging:
    uint256 priceRatio = getPriceRatio(e);
    uint256 underlyingAssetUnits = getUnderlyingAssetUnits(e);

    require assetsToBuy <= max_uint128;

    uint256 receiverAssetBalanceBefore = balanceOfUnderlying(e, receiver);
    buyAsset(e, assert_uint128(assetsToBuy), receiver);
    uint256 receiverAssetBalanceAfter = balanceOfUnderlying(e, receiver);

    uint256 balanceDiff = require_uint256(receiverAssetBalanceAfter - receiverAssetBalanceBefore);

    assert assetsToBuy <= balanceDiff;
}

// @Title The asset amount deduced from user's account at `buyAsset(minAssets)` can be more than `minAssets`
// -[buyAsset]->
// assetsToBuy < |buyerAssetBalanceAfter - buyerAssetBalanceBefore|
// (3a)
// Holds.
rule R3a_buyAssetUpdatesAssetBuyerAssetBalanceLt {
    env e;
    feeLimits(e);
    priceLimits(e);

    require e.msg.sender != currentContract; // Otherwise the fee in GHO will come back to me, messing up the balance calculation
    require GHO_TOKEN(e) != UNDERLYING_ASSET(e); // This is inflation prevention (and also avoids an overflow)

    uint256 assetsToBuy;
    address receiver;
    require receiver != currentContract; // Otherwise GHO is burned but asset value doesn't increase.  (This only a problem for my bookkeeping)

    // For debugging:
    uint256 priceRatio = getPriceRatio(e);
    uint256 underlyingAssetUnits = getUnderlyingAssetUnits(e);

    require assetsToBuy <= max_uint128;

    uint256 receiverAssetBalanceBefore = balanceOfUnderlying(e, receiver);
    buyAsset(e, assert_uint128(assetsToBuy), receiver);
    uint256 receiverAssetBalanceAfter = balanceOfUnderlying(e, receiver);

    uint256 balanceDiff = require_uint256(receiverAssetBalanceAfter - receiverAssetBalanceBefore);

    satisfy assetsToBuy < balanceDiff;
}

// @Title The difference between asset amount deduced from user's account at `buyAsset(minAssets)` and `minAssets` can be more than 10^10
// (3-UB)
// Holds.  I.e., the error can be at least 10^10
rule R3UB_buyAssetUpdatesAssetBuyerAssetBalanceUB {
    env e;
    feeLimits(e);
    priceLimits(e);

    require e.msg.sender != currentContract; // Otherwise the fee in GHO will come back to me, messing up the balance calculation
    require GHO_TOKEN(e) != UNDERLYING_ASSET(e); // This is inflation prevention (and also avoids an overflow)

    uint256 assetsToBuy;
    address receiver;
    require receiver != currentContract; // Otherwise GHO is burned but asset value doesn't increase.  (This is only a problem for my bookkeeping)

    // For debugging:
    uint256 priceRatio = getPriceRatio(e);
    uint256 underlyingAssetUnits = getUnderlyingAssetUnits(e);

    require assetsToBuy <= max_uint128;

    uint256 receiverAssetBalanceBefore = balanceOfUnderlying(e, receiver);
    buyAsset(e, assert_uint128(assetsToBuy), receiver);
    uint256 receiverAssetBalanceAfter = balanceOfUnderlying(e, receiver);

    uint256 balanceDiff = require_uint256(receiverAssetBalanceAfter - receiverAssetBalanceBefore);

    uint256 N = 10^10;
    satisfy !diffHelper.differsByAtMostN(e, assetsToBuy, balanceDiff, N);
}

// @Title The amount of GHO deduced from user's account at `buyAsset` is less than or equal to the value passed to `getAssetAmountForBuyAsset`
// . -[getAssetAmountForBuyAsset(x)]-> . -[buyAsset]-> .
// buyerGhoBalanceBefore - buyerGhoBalanceAfter <= goWithFee
// (4)
// Holds.
rule R4_sellGhoUpdatesAssetBuyerGhoBalanceGe {
    env e;
    feeLimits(e);
    priceLimits(e);

    require e.msg.sender != currentContract; // Otherwise the fee in GHO will come back to me, messing up the balance calculation
    require GHO_TOKEN(e) != UNDERLYING_ASSET(e); // This is inflation prevention (and also avoids an overflow)

    uint256 ghoWithFee;
    uint256 assetsToBuy;
    address receiver;

    // For debugging:
    uint256 priceRatio = getPriceRatio(e);
    uint256 underlyingAssetUnits = getUnderlyingAssetUnits(e);


    assetsToBuy, _, _, _ = getAssetAmountForBuyAsset(e, ghoWithFee);

    require assetsToBuy <= max_uint128;

    uint256 buyerGhoBalanceBefore = balanceOfGho(e, e.msg.sender);
    buyAsset(e, assert_uint128(assetsToBuy), receiver);
    uint256 buyerGhoBalanceAfter = balanceOfGho(e, e.msg.sender);

    mathint balanceDiff = buyerGhoBalanceBefore - buyerGhoBalanceAfter;
    assert to_mathint(ghoWithFee) >= balanceDiff;
}

// @Title The amount of GHO deduced from user's account at `buyAsset` can be less than the value passed to `getAssetAmountForBuyAsset`
// . -[getAssetAmountForBuyAsset(x)]-> . -[buyAsset]-> .
// \exists x . buyerGhoBalanceBefore - buyerGhoBalanceAfter < goWithFee
// (4a)
// Holds: https://prover.certora.com/output/40748/c44b117fccd94853a171b7d88ec93815/?anonymousKey=2ba26dfa6fbbde84014221222db1cbf0b8badc39
rule R4a_sellGhoUpdatesAssetBuyerGhoBalanceGt {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 ghoWithFee;
    uint256 assetsToBuy;
    address receiver;

    // For debugging:
    uint256 priceRatio = getPriceRatio(e);
    uint256 underlyingAssetUnits = getUnderlyingAssetUnits(e);

    require receiver != e.msg.sender; // Otherwise the sold GHO will just come back to me.

    assetsToBuy, _, _, _ = getAssetAmountForBuyAsset(e, ghoWithFee);

    require assetsToBuy <= max_uint128;

    uint256 buyerGhoBalanceBefore = balanceOfGho(e, e.msg.sender);
    buyAsset(e, assert_uint128(assetsToBuy), receiver);
    uint256 buyerGhoBalanceAfter = balanceOfGho(e, e.msg.sender);

    mathint balanceDiff = buyerGhoBalanceBefore - buyerGhoBalanceAfter;
    satisfy to_mathint(ghoWithFee) > balanceDiff;
}

// @Title The difference in the amount of GHO deduced from user's account at `buyAsset` and the value passed to `getAssetAmountForBuyAsset` can be more than 10^13
// . -[getAssetAmountForBuyAsset(x)]-> . -[buyAsset]-> .
// max |buyerGhoBalanceBefore - buyerGhoBalanceAfter - goWithFee|
// (4-UB)
rule R4UB_sellGhoUpdatesAssetBuyerGhoBalanceUB {
    env e;
    feeLimits(e);
    priceLimits(e);

    require e.msg.sender != currentContract; // Otherwise the fee in GHO will come back to me, messing up the balance calculation
    require GHO_TOKEN(e) != UNDERLYING_ASSET(e); // This is inflation prevention (and also avoids an overflow)

    uint256 ghoWithFee;
    uint256 assetsToBuy;
    address receiver;

    // For debugging:
    uint256 priceRatio = getPriceRatio(e);
    uint256 underlyingAssetUnits = getUnderlyingAssetUnits(e);


    assetsToBuy, _, _, _ = getAssetAmountForBuyAsset(e, ghoWithFee);

    require assetsToBuy <= max_uint128;

    uint256 buyerGhoBalanceBefore = balanceOfGho(e, e.msg.sender);
    buyAsset(e, assert_uint128(assetsToBuy), receiver);
    uint256 buyerGhoBalanceAfter = balanceOfGho(e, e.msg.sender);

    uint256 balanceDiff = require_uint256(buyerGhoBalanceBefore - buyerGhoBalanceAfter);
    uint256 N = 10^13;
    satisfy !diffHelper.differsByAtMostN(e, ghoWithFee, balanceDiff, N);
}

