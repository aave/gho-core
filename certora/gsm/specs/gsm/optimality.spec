import "../GsmMethods/methods_base.spec";
import "../GsmMethods/aave_price_fee_limits.spec";
import "../GsmMethods/methods_divint_summary.spec";

// @Title For values given by `getAssetAmountForBuyAsset`, the user can only get more by paying more
// This rule proves the optimality of getAssetAmountForBuyAsset with respect to
// buyAsset in the following sense:
//
// User wants to buy as much asset as possible while paying at most maxGho.
// User asks how much they should provide to buyAsset:
//   - a, _, _, _ = getAssetAmountForBuyAsset(maxGho)
// This results in the user buying Da assets:
//   - Da, Dx = buyAsset(a)
// Is it possible that by not doing as `getAssetAmountForBuyAsset(maxGho)` says, the user would have
// gotten a better deal, i.e., paying still less than maxGho, but getting more assets.  If this is the
// case, then the following holds:
// There is a value `a'` such that
//   - Da', Dx' = buyAsset(a)
//   - Dx' <= Dx
//   - Da' > Da
// (1)
// STATUS: PASS
// https://prover.certora.com/output/11775/62c193bbbb484f3d9323986743fd368b?anonymousKey=982afbad05d5b144a84b530bbe8bb4c2f2b4b6af
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

// @Title User cannot buy more assets for same `maxGho` by providing a lower asset value than the one given by `getAssetAmountForBuyAsset(maxGho)`
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
// (2)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/29f5cb2aeb7f4937b70d5e013c5e0648?anonymousKey=6952c53b357275d706fed39ccd6509ffd73228bf
rule R2_optimalityOfBuyAsset_v2() {
    env e;
    feeLimits(e);
    priceLimits(e);
    address recipient;

    uint maxGho;
    uint a;
    a, _, _, _ = getAssetAmountForBuyAsset(e, maxGho);

    uint Da;
    Da, _ = buyAsset(e, a, recipient);

    uint ap;
    uint Dap;
    uint Dxp;
    Dap, Dxp = buyAsset(e, ap, recipient);
    require Dxp <= maxGho;
    assert Dap <= Da;
}

// @Title For values given by `getAssetAmountForSellAsset`, the user can only get more by paying more
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
//   - Da', Dx'= sellAsset(a')
//   - Dx' >= Dx
//   - Da' < Da
// (3)
// STATUS: PASS
// https://prover.certora.com/output/11775/62c193bbbb484f3d9323986743fd368b?anonymousKey=982afbad05d5b144a84b530bbe8bb4c2f2b4b6af
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

// @Title User cannot sell less assets for same `minGho` by providing a lower asset value than the one given by `getAssetAmountForSellAsset(minGho)`
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

// Solved for UAU = 13, 20, 21, 22, 23, 24, 25, 26, 27:
//   - https://prover.certora.com/output/40748/0cf26723d13f4a2aa084966deea053f8/?anonymousKey=221ab8180f66732e66c134e43e43d3876041b625
// Solved for UAU = 5, 6, 9, 14, 18:
//   - https://prover.certora.com/output/40748/c6bf16d3af2e4831a5421e8babb30474/?anonymousKey=41203cbc99be1097c60331f76c185c794ad89868
// Solved for UAU = 8, 19:
//   - https://prover.certora.com/output/40748/f8ee082aae5e46bda756ef9066569674/?anonymousKey=16e823180102505c4077e7941ff87ca97c1cf87e
// (4)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/be619ce4ffde4523acbbc6f3024f9edd?anonymousKey=77da7c4fe1ee9aed6e86e10ec1b0df360929bed4
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

// @Title The GHO received by selling asset using values from `getAssetAmountForSellAsset(minGho)` is upper bounded by `minGho` + oneAssetinGho - 1
// External optimality of sellAsset.  Shows that the received amount is as close as it can be to target
// (5)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/a651d5a5e6b24350ba0e0e5be743e2b7?anonymousKey=047a56cb5c6d3a738002371e7a1ae38b6caea6f3
// rule R5_externalOptimalityOfSellAsset {
//     env e;
//     feeLimits(e);
//     priceLimits(e);

//     uint256 minGhoToReceive;
//     uint256 ghoToReceive;

//     _, ghoToReceive, _, _ = getAssetAmountForSellAsset(e, minGhoToReceive);
//     uint256 oneAssetInGho = getAssetPriceInGho(e, 1, true);
// //    assert to_mathint(ghoToReceive) <= minGhoToReceive + oneAssetInGho; // holds: https://prover.certora.com/output/40748/03f0bd8a9323437195fc69871a573197/?anonymousKey=5453059e7056b0f7f5ee583bb0840ab448ec5ac7
//     assert to_mathint(ghoToReceive) < minGhoToReceive + oneAssetInGho; // times out: https://prover.certora.com/output/40748/20c45a372ff649c38ed2a728f0c5772a/?anonymousKey=1178900a97ca29ef45a37f981c5dd000227bb43d
// //    assert to_mathint(ghoToReceive) != minGhoToReceive + oneAssetInGho; // Holds with uau-trick: https://prover.certora.com/output/40748/691739be52a84a2f906f9e99d8a63bee/?anonymousKey=5f873a94d5f0fcf78365ebbee82fca1eff046b0c
// }

// @Title The GHO received by selling asset using values from `getAssetAmountForSellAsset(minGho)` can be equal to `minGho` + oneAssetInGho - 1
// External optimality of sellAsset.  Show the tightness of (5)
// (5a)
// STATUS: PASS
// https://prover.certora.com/output/11775/62c193bbbb484f3d9323986743fd368b?anonymousKey=982afbad05d5b144a84b530bbe8bb4c2f2b4b6af
// (The tightness is almost trivial: when oneAssetInGho == 1 and minGhoToReceive == ghoToReceive)
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

// @Title The GHO sold by buying asset using values from `getAssetAmountForBuyAsset(maxGho)` is at least `maxGho - 2*oneAssetInGho + 1
// External optimality of buyAsset.  Shows that the received amount is as close as it can be to target
// (6)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/23cdf5b0484f4068a9befce7ba094925?anonymousKey=90e8f8254d55e9496c321819d49607337015c877
// rule R6_externalOptimalityOfBuyAsset {
//     env e;
//     feeLimits(e);
//     priceLimits(e);

//     uint256 maxGhoToSpend;
//     uint256 ghoToSpend;

//     _, ghoToSpend, _, _ = getAssetAmountForBuyAsset(e, maxGhoToSpend);
//     uint256 oneAssetInGho = getAssetPriceInGho(e, 1, true);
//     assert to_mathint(maxGhoToSpend) <= ghoToSpend + 2*oneAssetInGho - 1; // Holds: https://prover.certora.com/output/40748/2790587d75684f88a232c5898aff9a10/?anonymousKey=893c32307119c35e8d6679db2a05ca1087b38e36
// }

// @Title The GHO sold by buying asset using values from `getAssetAmountForBuyAsset(maxGho)` can be equal to `maxGho - 2*oneAssetInGho + 1
// External optimality of buyAsset.  Show the tightness of (6)
// (6a)
// STATUS: PASS
// https://prover.certora.com/output/11775/62c193bbbb484f3d9323986743fd368b?anonymousKey=982afbad05d5b144a84b530bbe8bb4c2f2b4b6af
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