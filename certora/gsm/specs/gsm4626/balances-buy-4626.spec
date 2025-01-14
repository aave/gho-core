import "../GsmMethods/erc20.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/aave_price_fee_limits.spec";
import "../GsmMethods/erc4626.spec";

using DiffHelper as diffHelper;

methods {
    function distributeFeesToTreasury() external;
}

// Issue:
// The exact GHO return by `getAssetAmountForBuyAsset(max)` can be greater than `max` in 4626
// Description:
// The user may ask the amount of assets to provide for `buyAsset` by calling
// `getAssetAmountForBuyAsset(max)`, where `max` is the maximum amount of GHO
// user is willing to pay.  One of the return values of
// `getAssetAmountForBuyAsset` is the exact amount of GHO that will be deducted.
// This value can be higher than `max`.
// Note: From https://github.com/Certora/gho-gsm/pull/18

// ========================= Buying ==============================
//

// @title 4626: The exact amount of GHO returned by `getAssetAmountForBuyAsset(maxGho)` is less than or equal to `maxGho`
// . -[getAssetAmountForBuyAsset(x)]-> .
// exactGHO <= goWithFee
// where exactGHO is the 2nd return value of getAssetAmountForBuyAsset
// Holds: https://prover.certora.com/output/40748/0146aff66f2a492886c6dd89724b92ba?anonymousKey=32b3789b362a27460edce2d9bc86870646e65c52
// (1)
rule R1_getAssetAmountForBuyAssetRV2 {
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


    _, exactGHO, _, _ = getAssetAmountForBuyAsset(e, ghoWithFee);

    assert exactGHO <= ghoWithFee;
}

// @title 4626: The exact amount of GHO returned by `getAssetAmountForBuyAsset(maxGho)` can be less than `maxGho`
// (1a)
// Holds: https://prover.certora.com/output/40748/0146aff66f2a492886c6dd89724b92ba?anonymousKey=32b3789b362a27460edce2d9bc86870646e65c52
rule R1a_getAssetAmountForBuyAssetRV2_LT {
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


    _, exactGHO, _, _ = getAssetAmountForBuyAsset(e, ghoWithFee);

    satisfy exactGHO < ghoWithFee;
}

// @title 4626: The exact amount of GHO returned by `getAssetAmountForBuyAsset(x)` matches the GHO amount deduced from user at `buyAsset`
// . -[getAssetAmountForBuyAsset(x)]-> . -[buyAsset(exactGHO)]-> .
// ghoBalance_1 - ghoBalance_2 = exactGHO
// where exactGHO is the 2nd return value of getAssetAmountForBuyAsset
// Holds: https://prover.certora.com/output/40748/0146aff66f2a492886c6dd89724b92ba?anonymousKey=32b3789b362a27460edce2d9bc86870646e65c52
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

// @title 4626: The asset amount deduced from user's account at `buyAsset(minAssets)` is at least `minAssets`
// -[buyAsset]->
// assetsToBuy <= |buyerAssetBalanceAfter - buyerAssetBalanceBefore|
// (3)
// STATUS: TIMEOUT
// https://prover.certora.com/output/33050/56571f50dd3f4f5ead1c1ee7520b7619?anonymousKey=9b0e61ce85c892c5bf093508ee8a03d6d91fda53
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

// @title 4626: The asset amount deduced from user's account at `buyAsset(minAssets)` can be more than `minAssets`
// -[buyAsset]->
// assetsToBuy < |buyerAssetBalanceAfter - buyerAssetBalanceBefore|
// (3a)
// Holds: https://prover.certora.com/output/40748/0146aff66f2a492886c6dd89724b92ba?anonymousKey=32b3789b362a27460edce2d9bc86870646e65c52
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

// @title 4626: The amount of GHO deduced from user's account at `buyAsset` is less than or equal to the value passed to `getAssetAmountForBuyAsset`
// . -[getAssetAmountForBuyAsset(x)]-> . -[buyAsset]-> .
// buyerGhoBalanceBefore - buyerGhoBalanceAfter <= goWithFee
// (4)
// Holds: https://prover.certora.com/output/40748/0146aff66f2a492886c6dd89724b92ba?anonymousKey=32b3789b362a27460edce2d9bc86870646e65c52
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
    satisfy to_mathint(ghoWithFee) >= balanceDiff;
}

// @title 4626: The amount of GHO deduced from user's account at `buyAsset` can be less than the value passed to `getAssetAmountForBuyAsset`
// . -[getAssetAmountForBuyAsset(x)]-> . -[buyAsset]-> .
// buyerGhoBalanceBefore - buyerGhoBalanceAfter < goWithFee
// Expected to hold in current implementation
// (4a)
// Holds: https://prover.certora.com/output/40748/0146aff66f2a492886c6dd89724b92ba?anonymousKey=32b3789b362a27460edce2d9bc86870646e65c52

rule R4a_sellGhoUpdatesAssetBuyerGhoBalanceGt {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 ghoWithFee;
    uint256 assetsToBuy;
    address receiver;

    require receiver != e.msg.sender; // Otherwise the sold GHO will just come back to me.

    assetsToBuy, _, _, _ = getAssetAmountForBuyAsset(e, ghoWithFee);

    require assetsToBuy <= max_uint128;

    uint256 buyerGhoBalanceBefore = balanceOfGho(e, e.msg.sender);
    buyAsset(e, assert_uint128(assetsToBuy), receiver);
    uint256 buyerGhoBalanceAfter = balanceOfGho(e, e.msg.sender);

    mathint balanceDiff = buyerGhoBalanceBefore - buyerGhoBalanceAfter;
    satisfy to_mathint(ghoWithFee) > balanceDiff;
}
