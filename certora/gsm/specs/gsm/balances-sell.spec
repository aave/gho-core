import "../GsmMethods/erc20.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/aave_price_fee_limits.spec";

using DiffHelper as diffHelper;

// ========================= Selling ==============================
// The user wants to buy GHO and asks how much asset should be sold.  Fees are
// not included in user's GHO buying order.
//
// https://prover.certora.com/output/40748/82b017e6272940189f89a69de371f386/?anonymousKey=f4acb19d25cf33db1c2473eab71b6a8f1e53181d

// @Title The exact amount of GHO returned by `getAssetAmountForSellAsset(minGho)` is at least `minGho`
// Check that recipient's GHO balance is updated correctly
// User wants to buy `minGhoToSend` GHO.
// User asks for the assets required: `(assetsToSpend, ghoToReceive, ghoToSpend, fee) := getAssetAmountForSellAsset(minGhoToReceive)`
// Let balance difference of the recipient be balanceDiff.
// (1): minGhoToReceive <= ghoToReceive
// Holds.

rule R1_getAssetAmountForSellAsset_arg_vs_return {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 minGhoToReceive;
    uint256 ghoToReceive;

    _, ghoToReceive, _, _ = getAssetAmountForSellAsset(e, minGhoToReceive);
    assert minGhoToReceive <= ghoToReceive;
}

// @Title The exact amount of GHO returned by `getAssetAmountForSellAsset(minGho)` can be greater than `minGho`
// Shows <
// (1a)
// Holds.
rule R1a_buyGhoUpdatesGhoBalanceCorrectly1 {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 minGhoToReceive;
    uint256 ghoToReceive;

    _, _, ghoToReceive, _ = getAssetAmountForSellAsset(e, minGhoToReceive);
    satisfy minGhoToReceive < ghoToReceive;
}

// @Title The exact amount of GHO returned by `getAssetAmountForSellAsset` is equal to the amount obtained after `sellAsset`
// getAssetAmountForSellAsset returns exactGhoToReceive.  Does this match the exact GHO received after the corresponding sellAsset?
// Holds.
// (2)
rule R2_getAssetAmountForSellAsset_sellAsset_eq {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 minGhoToReceive;
    uint256 ghoToReceive;
    uint256 assetsToSell;

    require currentContract.UNDERLYING_ASSET(e) != currentContract.GHO_TOKEN(e); // Otherwise we only measure the fee.

    address recipient;
    require recipient != currentContract; // Otherwise the balance grows because of the fees.

    assetsToSell, ghoToReceive, _, _ = getAssetAmountForSellAsset(e, minGhoToReceive);

    uint256 ghoBalanceBefore = balanceOfGho(e, recipient);
    sellAsset(e, assetsToSell, recipient);
    uint256 ghoBalanceAfter = balanceOfGho(e, recipient);

    uint256 balanceDiff = require_uint256(ghoBalanceAfter - ghoBalanceBefore);
    assert balanceDiff == ghoToReceive;
}

// @Title The asset amount deduced from the user's account at `sellAsset(_, maxAsset, _)` is at most `maxAsset`
// Check that user's asset balance is
// decreased correctly.  Shows >=
// (3)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/9e60de94fefe4aa5b20bd4ae1342dfcb?anonymousKey=a94125580ee2a1b2d268bb476ff90664f53b30e4
rule R3_sellAssetUpdatesAssetBalanceCorrectly {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint128 assets;
    address seller = e.msg.sender;
    address recipient;

    require e.msg.sender != currentContract;
    require currentContract.UNDERLYING_ASSET(e) != currentContract.GHO_TOKEN(e); // Inflation prevention!

    uint256 balanceBefore = balanceOfUnderlying(e, seller);
    sellAsset(e, assets, recipient);
    uint256 balanceAfter = balanceOfUnderlying(e, seller);
    mathint balanceDiff = balanceBefore - balanceAfter;
    assert to_mathint(assets) >= balanceDiff;
}

// @Title The asset amount deduced from the user's account at `sellAsset(_, maxAsset, _)` can be less than `maxAsset`
// Check that user's asset balance is
// decreased correctly.  Shows >
// (3a)
rule R3a_sellAssetUpdatesAssetBalanceCorrectly {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint128 assets;
    address seller = e.msg.sender;
    address recipient;

    require e.msg.sender != currentContract;
    require currentContract.UNDERLYING_ASSET(e) != currentContract.GHO_TOKEN(e); // Inflation prevention!

    uint256 balanceBefore = balanceOfUnderlying(e, seller);
    sellAsset(e, assets, recipient);
    uint256 balanceAfter = balanceOfUnderlying(e, seller);
    mathint balanceDiff = balanceBefore - balanceAfter;
    satisfy to_mathint(assets) > balanceDiff;
}

// @Title The GHO amount added to the user's account at `sellAsset` is at least the value `x` passed to `getAssetAmountForSellAsset(x)`
// (4)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/04f9aa998c0045839ed5e0fa8f17465d?anonymousKey=ba48d972104e53d04391136fa6e98e2eaeaf7d56
rule R4_buyGhoUpdatesGhoBalanceCorrectly {
    env e;
    feeLimits(e);
    priceLimits(e);

    require e.msg.sender != currentContract;
    require currentContract.UNDERLYING_ASSET(e) != currentContract.GHO_TOKEN(e); // Inflation prevention

    address seller = e.msg.sender;
    address recipient;
    require recipient != currentContract; // Otherwise the balance grows because of the fees.

    uint256 minGhoToSend;
    uint256 assetsToSpend;

    assetsToSpend, _, _, _ = getAssetAmountForSellAsset(e, minGhoToSend);
    require assetsToSpend < max_uint128;

    uint256 balanceBefore = balanceOfGho(e, recipient);
    sellAsset(e, assert_uint128(assetsToSpend), recipient);
    uint256 balanceAfter = balanceOfGho(e, recipient);
    require balanceAfter >= balanceBefore; // No overflow
    uint256 balanceDiff = require_uint256(balanceAfter - balanceBefore);
    assert minGhoToSend <= balanceDiff;
}

// @Title The GHO amount added to the user's account at `sellAsset` can be greater than the value `x` passed to `getAssetAmountForSellAsset(x)`
// Show that the GHO amount requested by the user to be transferred to the
// recipient can be less than what the recipient receives, even when fees are considered.
// (4a)
rule R4a_buyGhoAmountGtGhoBalanceChange {
    env e;
    feeLimits(e);
    priceLimits(e);

    require e.msg.sender != currentContract;
    require currentContract.UNDERLYING_ASSET(e) != currentContract.GHO_TOKEN(e); // Inflation prevention

    address seller = e.msg.sender;
    address recipient;
    require recipient != currentContract; // Otherwise the balance grows because of the fees.

    uint256 minGhoToSend;
    uint256 assetsToSpend;

    assetsToSpend, _, _, _ = getAssetAmountForSellAsset(e, minGhoToSend);
    require assetsToSpend < max_uint128;

    uint256 balanceBefore = balanceOfGho(e, recipient);
    sellAsset(e, assert_uint128(assetsToSpend), recipient);
    uint256 balanceAfter = balanceOfGho(e, recipient);
    require balanceAfter >= balanceBefore; // No overflow
    uint256 balanceDiff = require_uint256(balanceAfter - balanceBefore);
    satisfy minGhoToSend < balanceDiff;
}
