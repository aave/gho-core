import "../GsmMethods/erc20.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/aave_price_fee_limits.spec";
import "../GsmMethods/erc4626.spec";

using DiffHelper as diffHelper;

methods {
    function distributeFeesToTreasury() external;
}

// ========================= Selling ==============================

// The user wants to buy GHO and asks how much asset should be sold.  Fees are
// not included in user's GHO buying order.

// @Title 4626: The exact amount of GHO returned by `getAssetAmountForSellAsset(minGho)` is at least `minGho`
// Check that recipient's GHO balance is updated correctly
// User wants to buy `minGhoToSend` GHO.
// User asks for the assets required: `(assetsToSpend, ghoToReceive, ghoToSpend, fee) := getAssetAmountForSellAsset(minGhoToReceive)`
// Let balance difference of the recipient be balanceDiff.
// (1): ghoToReceive >= minGhoToReceive Expected to hold.
// User wants to receive at least minGhoAmount.  Is the amount of GHO reported by getAssetAmountForSellAsset at least minGhoAmount
// (1)
// Holds: https://prover.certora.com/output/40748/c4b0691393f4416dbe328f383093ffad?anonymousKey=83439124b153fd20f61457ff3c63da877c6770c3

rule R1_getAssetAmountForSellAsset_arg_vs_return {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 minGhoToReceive;
    uint256 ghoToReceive;

    _, ghoToReceive, _, _ = getAssetAmountForSellAsset(e, minGhoToReceive);

    assert minGhoToReceive <= ghoToReceive;
}

// @Title 4626: The exact amount of GHO returned by `getAssetAmountForSellAsset(minGho)` can be greater than `minGho`
// Shows !=
// (1a)
// Holds: https://prover.certora.com/output/40748/c4b0691393f4416dbe328f383093ffad?anonymousKey=83439124b153fd20f61457ff3c63da877c6770c3
rule R1a_buyGhoUpdatesGhoBalanceCorrectly1 {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 minGhoToReceive;
    uint256 ghoToReceive;

    _, _, ghoToReceive, _ = getAssetAmountForSellAsset(e, minGhoToReceive);
    satisfy minGhoToReceive != ghoToReceive;
}

// @Title 4626: The exact amount of GHO returned by `getAssetAmountForSellAsset` is equal to the amount obtained after `sellAsset`
// getAssetAmountForSellAsset returns exactGhoToReceive.  Does this match the exact GHO received after the corresponding sellAsset?
// Holds: https://prover.certora.com/output/40748/c4b0691393f4416dbe328f383093ffad?anonymousKey=83439124b153fd20f61457ff3c63da877c6770c3
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

// @Title 4626: The asset amount deduced from the user's account at `sellAsset(_, maxAsset, _)` is at most `maxAsset`
// Check that user's asset balance is decreased correctly.
// assets >= balanceDiff
// Expected to hold in current implementation.
// STATUS: TIMEOUT
// https://prover.certora.com/output/33050/9ef597b1a6424528ae96871f69b5d735?anonymousKey=97dcbde8fc3a574d6a23635dfc6ca227d4e145fc
rule R3_sellAssetUpdatesAssetBalanceCorrectlyGe {
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
    require balanceBefore >= balanceAfter; // To avoid overflows
    mathint balanceDiff = balanceBefore - balanceAfter;
    assert to_mathint(assets) >= balanceDiff;
}

// @Title 4626: The asset amount deduced from the user's account at `sellAsset(_, maxAsset, _)` can be less than `maxAsset`
// Check that user's asset balance difference can differ from the assets provided
// holds: https://prover.certora.com/output/40748/c4b0691393f4416dbe328f383093ffad?anonymousKey=83439124b153fd20f61457ff3c63da877c6770c3
// (3a)
//
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
    require balanceBefore >= balanceAfter; // To avoid overflows
    mathint balanceDiff = balanceBefore - balanceAfter;
    satisfy balanceDiff != to_mathint(assets);
}

// // @Title 4626: The GHO amount added to the user's account at `sellAsset` is at least the value `x` passed to `getAssetAmountForSellAsset(x)`
// // (4)
// // Timeout: https://prover.certora.com/output/11775/b2a7e3687b504f3dbe03457b4b5ed3be?anonymousKey=0e6938a302b565c3d5e7b158d4b20a23d2605db1
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

// @Title 4626: The GHO amount added to the user's account at `sellAsset` can be greater than the value `x` passed to `getAssetAmountForSellAsset(x)`
// Show that the GHO amount requested by the user to be transferred to the
// recipient can be less than what the recipient receives, even when fees are considered.
// Holds: https://prover.certora.com/output/40748/c4b0691393f4416dbe328f383093ffad?anonymousKey=83439124b153fd20f61457ff3c63da877c6770c3
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
