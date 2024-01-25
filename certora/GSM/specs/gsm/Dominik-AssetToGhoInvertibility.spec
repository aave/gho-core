import "../GsmMethods/methods_base.spec";




methods {
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal => mulDivSummary(x, y, denominator) expect (uint256); 
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal => mulDivSummaryWithRounding(x, y, denominator, rounding) expect (uint256); 
}

function mulDivSummary(uint256 x, uint256 y, uint256 denominator) returns uint256
{
    require denominator > 0;
    return require_uint256((x * y) / denominator);
}


function mulDivSummaryWithRounding(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) returns uint256
{
    require denominator > 0;
    if rounding == Math.Rounding.Up
    {
        return require_uint256((x * y + denominator - 1) / denominator);
    }
	else return require_uint256((x * y) / denominator);
}

// FULL REPORT AT: https://prover.certora.com/output/17512/c87a46588a694009988c74cd330e3451?anonymousKey=81afc1084fb6e444019f84f769cbce4cd06cdc11


// The view function getGhoAmountForBuyAsset is the inverse of getAssetAmountForBuyAsset


/**
    ********************************************************
    ***** BASIC PROPERTIES - SIMILAR TO OTAKAR's RULES *****
    ********************************************************
*/


// @title actual gho amount returned getAssetAmountForBuyAsset should be less than max gho amount specified by the user
// STATUS: PASS
// https://prover.certora.com/output/11775/e6a4acd004b6450bbc109f6dc30288ef?anonymousKey=57eb2fef7c06c14a84f14f4e2c1e206f4b884269
rule basicProperty_getAssetAmountForBuyAsset() {
    env e;

    require getPriceRatio(e) > 0;
    require _FixedFeeStrategy.getBuyFeeBP(e) <= 10000;

    uint256 maxGhoAmount;

    uint256 actualGhoAmount;

    _, actualGhoAmount, _, _ = getAssetAmountForBuyAsset(e, maxGhoAmount);
    assert actualGhoAmount <= maxGhoAmount;
}

// @title getAssetAmountForBuyAsset should return the same asset and gho amount for an amount of gho suggested as the selling amount 
// STATUS: PASS
// https://prover.certora.com/output/11775/e6a4acd004b6450bbc109f6dc30288ef?anonymousKey=57eb2fef7c06c14a84f14f4e2c1e206f4b884269
rule basicProperty2_getAssetAmountForBuyAsset() {
    env e;

    mathint priceRatio = getPriceRatio(e);
    require priceRatio == 9*10^17 || priceRatio == 10^18 || priceRatio == 5*10^18;

    mathint uau = _priceStrategy.getUnderlyingAssetUnits(e);
    uint8 underlyingAssetDecimals;
    require underlyingAssetDecimals < 25 && underlyingAssetDecimals > 5;
    require uau == 10^underlyingAssetDecimals;

    mathint buyFee = _FixedFeeStrategy.getBuyFeeBP(e);
    require buyFee == 0 || buyFee == 1000 || buyFee == 357 || buyFee == 9000 || buyFee == 10000;

    uint256 maxGhoAmount;

    uint256 assetsBought; uint256 assetsBought2;
    uint256 actualGhoAmount; uint256 actualGhoAmount2;
    uint256 grossAmount; uint256 grossAmount2;
    uint256 fee; uint256 fee2;

    assetsBought, actualGhoAmount, grossAmount, fee = getAssetAmountForBuyAsset(e, maxGhoAmount);
    assetsBought2, actualGhoAmount2, grossAmount2, fee2 = getAssetAmountForBuyAsset(e, actualGhoAmount);

    assert assetsBought == assetsBought2 && actualGhoAmount == actualGhoAmount2 && grossAmount == grossAmount2 && fee == fee2;
}

// @title actual gho amount returned getGhoAmountForBuyAsset should be more than the min amount specified by the user
// STATUS: PASS
// https://prover.certora.com/output/11775/e6a4acd004b6450bbc109f6dc30288ef?anonymousKey=57eb2fef7c06c14a84f14f4e2c1e206f4b884269
rule basicProperty_getGhoAmountForBuyAsset() {
    env e;

    require getPriceRatio(e) > 0;
    require _FixedFeeStrategy.getBuyFeeBP(e) < 10000;

    uint256 minAssetAmount;

    uint256 actualAssetAmount;

    actualAssetAmount, _, _, _ = getGhoAmountForBuyAsset(e, minAssetAmount);
    assert minAssetAmount <= actualAssetAmount;
}

// @title actual gho amount returned getAssetAmountForSellAsset should be more than the min amount specified by the user
// STATUS: PASS
// https://prover.certora.com/output/11775/e6a4acd004b6450bbc109f6dc30288ef?anonymousKey=57eb2fef7c06c14a84f14f4e2c1e206f4b884269
rule basicProperty_getAssetAmountForSellAsset() {
    env e;

    require getPriceRatio(e) > 0;
    require _FixedFeeStrategy.getSellFeeBP(e) < 10000;

    uint256 minGhoAmount;

    uint256 actualGhoAmount;

    _, actualGhoAmount, _, _ = getAssetAmountForSellAsset(e, minGhoAmount);
    assert minGhoAmount <= actualGhoAmount;
}

// @title actual asset amount returned getGhoAmountForSellAsset should be less than the max amount specified by the user
// STATUS: PASS
// https://prover.certora.com/output/11775/e6a4acd004b6450bbc109f6dc30288ef?anonymousKey=57eb2fef7c06c14a84f14f4e2c1e206f4b884269
rule basicProperty_getGhoAmountForSellAsset() {
    env e;

    require getPriceRatio(e) > 0;
    require _FixedFeeStrategy.getSellFeeBP(e) < 10000;

    uint256 maxAssetAmount;

    uint256 actualAssetAmount;

    actualAssetAmount, _, _, _ = getGhoAmountForSellAsset(e, maxAssetAmount);
    assert actualAssetAmount <= maxAssetAmount;
}

// @title getGhoAmountForBuyAsset should return the same amount for an asset amount suggested by it
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/ded636a7d0af4862b389cb8c0ae88914?anonymousKey=21e61bef920130667fb07d930f134cd1b4c5027a
// rule basicProperty2_getGhoAmountForBuyAsset() {
//     env e;

//     mathint priceRatio = getPriceRatio(e);
//     require priceRatio == 9*10^17 || priceRatio == 10^18 || priceRatio == 5*10^18;

//     mathint uau = _priceStrategy.getUnderlyingAssetUnits(e);
//     uint8 underlyingAssetDecimals;
//     require underlyingAssetDecimals < 25 && underlyingAssetDecimals > 5;
//     require uau == 10^underlyingAssetDecimals;

//     mathint buyFee = _FixedFeeStrategy.getBuyFeeBP(e);
//     require buyFee == 0 || buyFee == 1000 || buyFee == 357 || buyFee == 9000 || buyFee == 9999;

//     uint256 minAssetAmount;

//     uint256 assetsBought; uint256 assetsBought2;
//     uint256 actualGhoAmount; uint256 actualGhoAmount2;
//     uint256 grossAmount; uint256 grossAmount2;
//     uint256 fee; uint256 fee2;

//     assetsBought, actualGhoAmount, grossAmount, fee = getGhoAmountForBuyAsset(e, minAssetAmount);
//     assetsBought2, actualGhoAmount2, grossAmount2, fee2 = getGhoAmountForBuyAsset(e, assetsBought);

//     assert assetsBought == assetsBought2 && actualGhoAmount == actualGhoAmount2 && grossAmount == grossAmount2 && fee == fee2;
// }


/**
    ***********************************
    ***** BUY ASSET INVERSE RULE *****
    ***********************************
*/

// @title getAssetAmountForBuyAsset is inverse of getGhoAmountForBuyAsset
// STATUS: PASS
// https://prover.certora.com/output/11775/e6a4acd004b6450bbc109f6dc30288ef?anonymousKey=57eb2fef7c06c14a84f14f4e2c1e206f4b884269
rule buyAssetInverse_all() {
    env e;
    mathint priceRatio = getPriceRatio(e);
    require priceRatio > 0;

    mathint uau = _priceStrategy.getUnderlyingAssetUnits(e);
    uint8 underlyingAssetDecimals;
    require underlyingAssetDecimals <= 30 && underlyingAssetDecimals >= 1;
    require uau == 10^underlyingAssetDecimals;

    require _FixedFeeStrategy.getBuyFeeBP(e) < 5000;

    uint256 maxGhoAmount;

    uint256 assetAmount1; uint256 assetAmount2;
    uint256 gho1; uint256 gho2;
    uint256 gross1; uint256 gross2;
    uint256 fee1; uint256 fee2;

    assetAmount1, gho1, gross1, fee1 = getAssetAmountForBuyAsset(e, maxGhoAmount);
    assetAmount2, gho2, gross2, fee2 = getGhoAmountForBuyAsset(e, assetAmount1);

    assert assetAmount1 == assetAmount2, "asset amount";
    assert gho1 == gho2, "gho amount";
    assert gross1 == gross2, "gross amount";
    assert fee1 == fee2, "fee";
}


/**
    ************************************
    ***** SELL ASSET INVERSE RULES *****
    ************************************
*/


// @title getAssetAmountForSellAsset is inverse of getGhoAmountForSellAsset
// STATUS: VIOLATED
// Value from getGhoAmountForSellAsset can be smaller by 1.
// https://prover.certora.com/output/11775/e6a4acd004b6450bbc109f6dc30288ef?anonymousKey=57eb2fef7c06c14a84f14f4e2c1e206f4b884269
// rule sellAssetInverse_gross() {
//     env e;
//     require to_mathint(getPriceRatio(e)) > 0;

//     mathint uau = _priceStrategy.getUnderlyingAssetUnits(e);
//     uint8 underlyingAssetDecimals;
//     require underlyingAssetDecimals <= 30 && underlyingAssetDecimals >= 1;
//     require uau == 10^underlyingAssetDecimals;

//     require _FixedFeeStrategy.getSellFeeBP(e) < 5000; 

//     uint256 minGhoAmount;
//     uint256 assetAmount;

//     uint256 grossAmount;
//     uint256 grossAmount2;

//     assetAmount, _, grossAmount, _ = getAssetAmountForSellAsset(e, minGhoAmount);
//     _, _, grossAmount2, _ = getGhoAmountForSellAsset(e, assetAmount);

//     assert grossAmount == grossAmount2;
// }

// @title getAssetAmountForSellAsset is inverse of getGhoAmountForSellAsset
// STATUS: VIOLATED
// Value from getGhoAmountForSellAsset can be smaller by 1 (the difference is the same as for gross amount - their respecitve differences are equal to ghoAmount).
// https://prover.certora.com/output/11775/e6a4acd004b6450bbc109f6dc30288ef?anonymousKey=57eb2fef7c06c14a84f14f4e2c1e206f4b884269
// rule sellAssetInverse_fee() {
//     env e;
//     mathint randomCoefficient;
//     require randomCoefficient == 5 || randomCoefficient == 9 || randomCoefficient == 1 || randomCoefficient == 25 || randomCoefficient == 10;
//     require to_mathint(getPriceRatio(e)) == 10^17 * randomCoefficient;

//     mathint uau = _priceStrategy.getUnderlyingAssetUnits(e);
//     uint8 underlyingAssetDecimals;
//     require underlyingAssetDecimals < 25 && underlyingAssetDecimals > 5;
//     require uau == 10^underlyingAssetDecimals;

//     require _FixedFeeStrategy.getSellFeeBP(e) < 5000;

//     uint256 minGhoAmount;
//     uint256 assetAmount;

//     uint256 fee;
//     uint256 fee2;

//     assetAmount, _, _, fee = getAssetAmountForSellAsset(e, minGhoAmount);
//     _, _, _, fee2 = getGhoAmountForSellAsset(e, assetAmount);
    
//     assert fee == fee2;
// }

// @title getAssetAmountForSellAsset is inverse of getGhoAmountForSellAsset
// STATUS: PASS
// https://prover.certora.com/output/11775/d1d79caba11d4708a64c6273b914af83?anonymousKey=77944410212cb77cd8de01ce41b9f5a7f52780fd
rule sellAssetInverse_all() {
    env e;
    require 10^16 <= getPriceRatio(e) && getPriceRatio(e) <= 10^20;

    mathint uau = _priceStrategy.getUnderlyingAssetUnits(e);
    uint8 underlyingAssetDecimals;
    require underlyingAssetDecimals <= 30 && underlyingAssetDecimals >= 1;
    require uau == 10^underlyingAssetDecimals;

    require _FixedFeeStrategy.getSellFeeBP(e) < 5000;

    uint256 minGhoAmount;

    uint256 assetAmount; uint256 assetAmount2;
    uint256 ghoAmount; uint256 ghoAmount2;
    uint256 grossAmount; uint256 grossAmount2;
    uint256 fee; uint256 fee2;

    assetAmount, ghoAmount, grossAmount, fee = getAssetAmountForSellAsset(e, minGhoAmount);
    assetAmount2, ghoAmount2, grossAmount2, fee2 = getGhoAmountForSellAsset(e, assetAmount);

    assert assetAmount == assetAmount2, "asset amount";
    assert ghoAmount == ghoAmount2, "gho amount";
    assert grossAmount2 <= grossAmount && to_mathint(grossAmount) <= grossAmount2 + 1, "gross amount off by at most 1";
    assert fee2 <= fee && to_mathint(fee) <= fee2 + 1, "fee by at most 1";
    assert (fee == fee2) <=> (grossAmount == grossAmount2), "fee off by 1 iff gross amount off by 1";
}