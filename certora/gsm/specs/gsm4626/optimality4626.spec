import "../GsmMethods/methods4626_base.spec";
import "../GsmMethods/aave_price_fee_limits.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/erc4626.spec";

// @Title 4626: For values given by `getAssetAmountForBuyAsset`, the user can only get more by paying more
// STATUS: https://prover.certora.com/output/11775/e8e6630d5b58425d8c0b6a251ff080be?anonymousKey=900815aac4f3703ba08d4a8c64402ac6cc9979bf
// This rule proves the optimality of getAssetAmountForBuyAsset with respect to
// buyAsset in the following sense:
//
// User wants to buy as much asset as possible while paying at most maxGho.
// User asks how much they should provide to buyAsset:
//   - a, _, _, _ = getAssetAmountForBuyAsset(maxGho)
// This results in the user buying DaT assets:
//   - Da, Dx = buyAsset(a)
// Is it possible that by not doing as `getAssetAmountForBuyAsset(maxGho)` says, the user would have
// gotten a better deal, i.e., paying still less than maxGho, but getting more assets.  If this is the
// case, then the following holds:
// There is a value `a'` such that
//   - Da', Dx' = buyAsset(a)
//   - Dx' <= Dx
//   - Da' > Da
// Solved: https://prover.certora.com/output/40748/b6ded393db3441649a6969f207037e79?anonymousKey=840fde79dad71cfc241479f2856eb27c0aa446b9
// (1)

rule R1_optimalityOfBuyAsset_v1() {
    env e;
    feeLimits(e);
    priceLimits(e);
    address recipient;

    uint maxGho;
    uint a;
    a, _, _, _ = getAssetAmountForBuyAsset(e, maxGho);

    uint Da;
    uint Dx;
    Da, Dx = buyAsset(e, a, recipient);

    uint ap;
    uint Dap;
    uint Dxp;
    Dap, Dxp = buyAsset(e, ap, recipient);
    require Dxp <= Dx;
    assert Dap <= Da;
}

// @Title 4626: User cannot buy more assets for same `maxGho` by providing a lower asset value than the one given by `getAssetAmountForBuyAsset(maxGho)`
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/2270a93b48984d0583c1334442bb11a5?anonymousKey=1655942848f2863b7612cbe27aa433868432fe8b
// This rule proves the optimality of getAssetAmountForBuyAsset with respect to
// buyAsset in the following sense:
//
// User wants to buy as much asset as possible while paying at most maxGho.
// User asks how much they should provide to buyAsset:
//   - a, _, _, _ = getAssetAmountForBuyAsset(maxGho)
// This results in the user buying Da assets:
//   - Da, _ = buyAsset(a)
// Is it possible that by not doing as `getAssetAmountForBuyAsset(maxGho)` says, the user would have
// gotten a better deal, i.e., paying still less than maxGho, but getting more assets.  If this is the
// case, then the following holds:
// There is a value `a'` such that
//   - Da', Dx' = buyAsset(a)
//   - Dx' <= maxGho
//   - Da' > Da
// Times out: https://prover.certora.com/output/40748/b6ded393db3441649a6969f207037e79?anonymousKey=840fde79dad71cfc241479f2856eb27c0aa446b9
// (2)

// rule R2_optimalityOfBuyAsset_v2() {
//     env e;
//     feeLimits(e);
//     priceLimits(e);
//     address recipient;

//     uint maxGho;
//     uint a;
//     a, _, _, _ = getAssetAmountForBuyAsset(e, maxGho);

//     uint Da;
//     Da, _ = buyAsset(e, a, recipient);

//     uint ap;
//     uint Dap;
//     uint Dxp;
//     Dap, Dxp = buyAsset(e, ap, recipient);
//     require Dxp <= maxGho;
//     assert Dap <= Da;
// }

// @Title 4626: For values given by `getAssetAmountForSellAsset`, the user can only get more by paying more
// STATUS: https://prover.certora.com/output/11775/f7389a715d5c4e8d88ad6f9666704adf?anonymousKey=cf8fa7dda6e2b9dedece7d13afae0f2ddc509258
// This rule proves the optimality of getAssetAmountForSellAsset with respect to
// sellAsset in the following sense:
//
// User wants to sell as little assets as possible while receiving at least `minGho`.
// User asks how much should they provide to sellAsset:
//   - a, _, _, _ = getAssetAmountForSellAsset(minGho)
// This results in the user selling Da assets and receiving Dx GHO:
//   - Da, Dx = sellAsset(a)
// Is it possible that by not doing as `getAssetAmountForSellAsset(minGho)` says, the user would have
// gotten a better deal, i.e., receiving at least Dx GHO, but selling less assets.  If this is the
// case, then the following holds:
// There is a value `a'` such that
//   - Da', Dx' = sellAsset(a')
//   - Dx' >= Dx
//   - Da' < Da
// Solved: https://prover.certora.com/output/40748/b6ded393db3441649a6969f207037e79?anonymousKey=840fde79dad71cfc241479f2856eb27c0aa446b9
// (3)

rule R3_optimalityOfSellAsset_v1 {
    env e;
    feeLimits(e);
    priceLimits(e);
    address recipient;

    uint minGho;
    uint a;
    a, _, _, _ = getAssetAmountForSellAsset(e, minGho);

    uint Da;
    uint Dx;
    Da, Dx = sellAsset(e, a, recipient);

    uint ap;
    uint Dap;
    uint Dxp;
    Dap, Dxp = sellAsset(e, ap, recipient);
    require Dxp >= Dx;
    assert Dap >= Da;
}

// @Title 4626: User cannot sell less assets for same `minGho` by providing a lower asset value than the one given by `getAssetAmountForSellAsset(minGho)`
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/f6ba80137c2e45458ec7c7f3fd54a5c3?anonymousKey=f21ea27b70d5c54e405794b70e5f6221466718f7
// This rule proves the optimality of getAssetAmountForSellAsset with respect to
// sellAsset in the following sense:
//
// User wants to sell as little assets as possible while receiving at least `minGho`.
// User asks how much should they provide to sellAsset:
//   - a, _, _, _ = getAssetAmountForSellAsset(minGho)
// This results in the user selling DaT assets:
//   - Da, _ = sellAsset(a)
// Is it possible that by not doing as `getAssetAmountForSellAsset(minGho)` says, the user would have
// gotten a better deal, i.e., receiving still at least minGho, but selling less assets.  If this is the
// case, then the following holds:
// There is a value `a'` such that
//   - Da', Dx' = sellAsset(a')
//   - Dx' >= minGho
//   - Da' < Da
// Times out: https://prover.certora.com/output/40748/b6ded393db3441649a6969f207037e79?anonymousKey=840fde79dad71cfc241479f2856eb27c0aa446b9
// (4)
// rule R4_optimalityOfSellAsset_v2() {
//     env e;
//     feeLimits(e);
//     priceLimits(e);
//     address recipient;

//     uint minGho;
//     uint a;
//     a, _, _, _ = getAssetAmountForSellAsset(e, minGho);

//     uint Da;
//     Da, _ = sellAsset(e, a, recipient);

//     uint ap;
//     uint Dap;
//     uint Dxp;
//     Dap, Dxp = sellAsset(e, ap, recipient);
//     require Dxp >= minGho;
//     assert Dap >= Da;
// }

// @Title 4626: The GHO received by selling asset using values from `getAssetAmountForSellAsset(minGho)` is upper bounded by `minGho` + oneAssetinGho - 1
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/f4ebd94360be4faab6988ae46c11a488?anonymousKey=4a045705983f7d61295d79023c49d981793c1a36
// External optimality of sellAsset.  Shows that the received amount is as close as it can be to target
// Times out: https://prover.certora.com/output/40748/b6ded393db3441649a6969f207037e79?anonymousKey=840fde79dad71cfc241479f2856eb27c0aa446b9
// (5)
// rule R5_externalOptimalityOfSellAsset {
//     env e;
//     feeLimits(e);
//     priceLimits(e);

//     uint256 minGhoToReceive;
//     uint256 ghoToReceive;

//     _, ghoToReceive, _, _ = getAssetAmountForSellAsset(e, minGhoToReceive);
//     uint256 oneAssetInGho = getAssetPriceInGho(e, 1, true);
// //    assert to_mathint(ghoToReceive) <= minGhoToReceive + oneAssetInGho;
//     assert to_mathint(ghoToReceive) < minGhoToReceive + oneAssetInGho;
// //    assert to_mathint(ghoToReceive) != minGhoToReceive + oneAssetInGho;
// }

// @Title 4626: The GHO received by selling asset using values from `getAssetAmountForSellAsset(minGho)` can be equal to `minGho` + oneAssetInGho - 1
// STATUS: PASS
// https://prover.certora.com/output/11775/944a0631a18846e39fe519d7e0f631b8?anonymousKey=613fae239e703cd94f7b6c2c9081bfaca941bf0a
// External optimality of sellAsset.  Show the tightness of (5)
// Holds: https://prover.certora.com/output/40748/b6ded393db3441649a6969f207037e79?anonymousKey=840fde79dad71cfc241479f2856eb27c0aa446b9
// (5a)
//
//
rule R5a_externalOptimalityOfSellAsset {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 minGhoToReceive;
    uint256 ghoToReceive;

    _, ghoToReceive, _, _ = getAssetAmountForSellAsset(e, minGhoToReceive);
    uint256 oneAssetInGho = getAssetPriceInGho(e, 1, true);
    satisfy to_mathint(ghoToReceive) == minGhoToReceive + oneAssetInGho - 1;
}

// @Title 4626: The GHO sold by buying asset using values from `getAssetAmountForBuyAsset(maxGho)` is at least `maxGho - 2*oneAssetInGho + 1
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/d98963a792454a949ab81f99419bbb9b?anonymousKey=c9f93b1edf28e9c693c1adc0aeafef6cce912a1b
// External optimality of buyAsset.  Shows that the received amount is as close as it can be to target
// Times out: https://prover.certora.com/output/40748/b6ded393db3441649a6969f207037e79?anonymousKey=840fde79dad71cfc241479f2856eb27c0aa446b9
// (6)
// rule R6_externalOptimalityOfBuyAsset {
//     env e;
//     feeLimits(e);
//     priceLimits(e);

//     uint256 maxGhoToSpend;
//     uint256 ghoToSpend;

//     _, ghoToSpend, _, _ = getAssetAmountForBuyAsset(e, maxGhoToSpend);
//     uint256 oneAssetInGho = getAssetPriceInGho(e, 1, true);
//     assert to_mathint(maxGhoToSpend) <= ghoToSpend + 2*oneAssetInGho - 1;
// }

// @Title 4626: The GHO sold by buying asset using values from `getAssetAmountForBuyAsset(maxGho)` can be equal to `maxGho - 2*oneAssetInGho + 1
// STATUS: PASS
// https://prover.certora.com/output/11775/944a0631a18846e39fe519d7e0f631b8?anonymousKey=613fae239e703cd94f7b6c2c9081bfaca941bf0a
// External optimality of buyAsset.  Show the tightness of (6)
// (6a)
// Holds: https://prover.certora.com/output/40748/b6ded393db3441649a6969f207037e79?anonymousKey=840fde79dad71cfc241479f2856eb27c0aa446b9
// Counterexample is buy fee = 1 BP, maxGhoToSpend = 1, oneAssetInGho = 1, ghoToSpend = 0
rule R6a_externalOptimalityOfBuyAsset {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 maxGhoToSpend;
    uint256 ghoToSpend;

    _, ghoToSpend, _, _ = getAssetAmountForBuyAsset(e, maxGhoToSpend);
    uint256 oneAssetInGho = getAssetPriceInGho(e, 1, true);
    satisfy to_mathint(maxGhoToSpend) == ghoToSpend + 2*oneAssetInGho - 1;
}
