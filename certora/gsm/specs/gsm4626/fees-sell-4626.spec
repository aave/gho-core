import "../GsmMethods/erc20.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/aave_price_fee_limits.spec";
import "../GsmMethods/erc4626.spec";

using DiffHelper as diffHelper;

// Study how well the estimated fees match the actual fees.

// ========================= Selling ==============================

// @Title 4626: The fee reported by `getAssetAmountForSellAsset` is greater than or equal to the fee reported by `getSellFee`
// getAssetAmountForSellAssetFee -(>=)-> getSellFee
// Shows >=
// (1)
// holds: https://prover.certora.com/output/40748/423580bb38c141b983906c061c39313a?anonymousKey=c1f615e893cdc4549b5b00138550cb8921d7703c
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

// @Title 4626: The fee reported by `getAssetAmountForSellAsset` can be greater than the fee reported by `getSellFee`
// getAssetAmountForSellAssetFee -(>=)-> getSellFee
// Shows !=
// (1a)
// Holds: https://prover.certora.com/output/40748/423580bb38c141b983906c061c39313a?anonymousKey=c1f615e893cdc4549b5b00138550cb8921d7703c
rule R1a_getAssetAmountForSellAssetFeeNeGetSellFee {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 estimatedFee;
    uint256 amountOfGhoToBuy;
    uint256 exactAmountOfGhoToReceive;

    _, exactAmountOfGhoToReceive, _, estimatedFee = getAssetAmountForSellAsset(e, amountOfGhoToBuy);

    uint256 fee = getSellFee(e, exactAmountOfGhoToReceive);

    satisfy fee != estimatedFee;
}

// @Title 4626: The fee reported by `getAssetAmountForSellAsset` can be greater than or equal to the fee deducted by `sellAsset`
// getAssetAmountForSellAsset -(>=)-> sellAsset
// Shows >=
// (2)
// holds: https://prover.certora.com/output/40748/423580bb38c141b983906c061c39313a?anonymousKey=c1f615e893cdc4549b5b00138550cb8921d7703c
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

// @Title 4626: The fee reported by `getAssetAmountForSellAsset` may differ from the fee deducted by `sellAsset`
// getAssetAmountForSellAsset -(>=)-> sellAsset
// Shows !=
// (2a)
// Holds: https://prover.certora.com/output/40748/423580bb38c141b983906c061c39313a?anonymousKey=c1f615e893cdc4549b5b00138550cb8921d7703c
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

    satisfy estimatedFee != actualFee;
}

// @Title 4626: The fee reported by `getSellFee` is less than or equal to the fee deduced by `sellAsset`
// getSellFee -(<=)-> sellAsset
// shows <=
// (3)
// Times out
// Solved for 6, 8, 9, 10, 11, 14, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27 in
// https://prover.certora.com/output/40748/0e599978d9a2421ab3bb9d8590136afb/?anonymousKey=0da77eb239ceb2c4c30b330b50e61769e5168644
// Solved for 5, 13, 15 in
// https://prover.certora.com/output/40748/a022ef5dd25d40aa9baecf9d14866007/?anonymousKey=a07d940634ade0c0004dc30cee0375ad5ac36759
// Solved for 16 in
// https://prover.certora.com/output/40748/f18e0f09d7044d4e847dffc601e08299/?anonymousKey=1c83f325ae45de355f204caed9b67cf99e18bc06
// Solved for 7, 12:
// https://prover.certora.com/output/40748/a79ba1aab3794e3a82f8671ab7a69f0e/?anonymousKey=dcb36001e071fd323ca66dcba6872b7102e301d0
// STATUS: TIMEOUT
// https://prover.certora.com/output/33050/e73527d566564185904c2359fc1c06ac?anonymousKey=9dbb56ece4c3d87b617bcabd9819a794c0bcacbf
// rule R3_estimatedSellFeeCanBeHigherThanActualSellFee {
//     env e;
//     feeLimits(e);
//     priceLimits(e);

//     uint128 ghoAmount;
//     address receiver;

//     uint256 preAccruedFees = currentContract._accruedFees;
//     uint256 estimatedSellFee = getSellFee(e, ghoAmount);

//     require ghoAmount <= max_uint128;
//     require estimatedSellFee <= max_uint128;

//     uint256 assetAmount;

//     assetAmount, _, _, _ = getAssetAmountForSellAsset(e, ghoAmount);

//     sellAsset(e, require_uint128(assetAmount), receiver);

//     uint256 postAccruedFees = currentContract._accruedFees;`

//     uint256 actualFee = require_uint256(postAccruedFees - preAccruedFees);

//     assert estimatedSellFee <= actualFee;
// }

// @Title 4626: The fee reported by `getSellFee` can be less than the fee deduced by `sellAsset`
// getSellFee -(<=)-> sellAsset
// shows <
// (3a)
// Holds: https://prover.certora.com/output/40748/423580bb38c141b983906c061c39313a?anonymousKey=c1f615e893cdc4549b5b00138550cb8921d7703c
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

// @Title 4626: The fee reported by `getSellFee` can be equal to the fee deduced by `sellAsset`
// getSellFee -(<=>)-> sellAsset
// shows ==
// (3b)
// Holds: https://prover.certora.com/output/40748/423580bb38c141b983906c061c39313a?anonymousKey=c1f615e893cdc4549b5b00138550cb8921d7703c
rule R3b_estimatedSellFeeEqActualSellFee {
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

    satisfy estimatedSellFee == actualFee;
}

// @Title 4626: the fee reported by `getSellFee` is less than or equal to the fee reported by `getAssetAmountForSellAsset`
// getSellFee -(<=)-> getAssetAmountForSellAsset
// (4)
// Holds: https://prover.certora.com/output/40748/423580bb38c141b983906c061c39313a?anonymousKey=c1f615e893cdc4549b5b00138550cb8921d7703c
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

// @Title 4626: the fee reported by `getSellFee` can be less than the fee reported by `getAssetAmountForSellAsset`
// getSellFee -(<=)-> getAssetAmountForSellAsset
// (4a)
// Shows <
// Holds: https://prover.certora.com/output/40748/423580bb38c141b983906c061c39313a?anonymousKey=c1f615e893cdc4549b5b00138550cb8921d7703c
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

// @Title 4626: the fee reeported by `getSellFee` can be equal to to the fee reported by `getAssetAmountForSellAsset`
// getSellFee -(<=)-> getAssetAmountForSellAsset
// (4b)
// Shows =
// Holds: https://prover.certora.com/output/40748/423580bb38c141b983906c061c39313a?anonymousKey=c1f615e893cdc4549b5b00138550cb8921d7703c
rule R4b_getSellFeeVsgetAssetAmountForSellAsset {
    env e;
    feeLimits(e);
    priceLimits(e);

    uint256 ghoAmount;
    uint256 estimatedSellFee;
    uint256 sellFee;

    estimatedSellFee  = getSellFee(e, ghoAmount);
    _, _, _, sellFee = getAssetAmountForSellAsset(e, ghoAmount);
    satisfy estimatedSellFee == sellFee;
}
