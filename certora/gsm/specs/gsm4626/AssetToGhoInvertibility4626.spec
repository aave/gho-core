import "../GsmMethods/methods4626_base.spec";
import "../GsmMethods/erc4626.spec";



methods {
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal => mulDivSummary(x, y, denominator) expect (uint256); 
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal => mulDivSummaryRounding(x, y, denominator, rounding) expect (uint256); 
}

function mulDivSummary(uint256 x, uint256 y, uint256 denominator) returns uint256
{
    require denominator > 0;
    return require_uint256((x * y) / denominator);
}


function mulDivSummaryRounding(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) returns uint256
{
    require denominator > 0;
    if (rounding == Math.Rounding.Up)
    {
        return require_uint256((x * y + denominator - 1) / denominator);
    }
	else return require_uint256((x * y) / denominator);
}


// // FULL REPORT AT: https://prover.certora.com/output/17512/a9aea9e11c56465d8714999a162bfdfa?anonymousKey=441316ec25aa2588abfca22582854f51dda2f339


// // @title actual gho amount returned getAssetAmountForBuyAsset should be less than max gho amount specified by the user
//  // STATUS: VIOLATED
// // https://prover.certora.com/output/11775/c75e493e2c494c2a8915efa5db311c6c?anonymousKey=04dc391cd1e3719c2302f38c2e045bcfa7907b76
// rule basicProperty_getAssetAmountForBuyAsset() {
//     env e;

//     require getPriceRatio(e) > 0;
//     require _FixedFeeStrategy.getBuyFeeBP(e) <= 10000;

//     uint256 maxGhoAmount;

//     uint256 actualGhoAmount;

//     _, actualGhoAmount, _, _ = getAssetAmountForBuyAsset(e, maxGhoAmount);
//     assert actualGhoAmount <= maxGhoAmount;
// }

// // @title getAssetAmountForBuyAsset should return the same asset and gho amount for an amount of gho suggested as the selling amount 
// // STATUS: VIOLATED
// // https://prover.certora.com/output/11775/c75e493e2c494c2a8915efa5db311c6c?anonymousKey=04dc391cd1e3719c2302f38c2e045bcfa7907b76
// rule basicProperty2_getAssetAmountForBuyAsset() {
//     env e;

//     mathint priceRatio = getPriceRatio(e);
//     require priceRatio == 9*10^17 || priceRatio == 10^18 || priceRatio == 5*10^18;

//     mathint uau = _priceStrategy.getUnderlyingAssetUnits(e);
//     uint8 underlyingAssetDecimals;
//     require underlyingAssetDecimals < 25 && underlyingAssetDecimals > 5;
//     require uau == 10^underlyingAssetDecimals;

//     mathint buyFee = _FixedFeeStrategy.getBuyFeeBP(e);
//     require buyFee == 0 || buyFee == 1000 || buyFee == 357 || buyFee == 9000 || buyFee == 10000;

//     uint256 maxGhoAmount;

//     uint256 assetsBought; uint256 assetsBought2;
//     uint256 actualGhoAmount; uint256 actualGhoAmount2;
//     uint256 grossAmount; uint256 grossAmount2;
//     uint256 fee; uint256 fee2;

//     assetsBought, actualGhoAmount, grossAmount, fee = getAssetAmountForBuyAsset(e, maxGhoAmount);
//     assetsBought2, actualGhoAmount2, grossAmount2, fee2 = getAssetAmountForBuyAsset(e, actualGhoAmount);

//     assert assetsBought == assetsBought2 && actualGhoAmount == actualGhoAmount2 && grossAmount == grossAmount2 && fee == fee2;
// }

// // @title actual gho amount returned getGhoAmountForBuyAsset should be more than the min amount specified by the user
// // STATUS: VIOLATED
// // https://prover.certora.com/output/11775/c75e493e2c494c2a8915efa5db311c6c?anonymousKey=04dc391cd1e3719c2302f38c2e045bcfa7907b76
// rule basicProperty_getGhoAmountForBuyAsset() {
//     env e;

//     require getPriceRatio(e) > 0;
//     require _FixedFeeStrategy.getBuyFeeBP(e) < 10000;

//     uint256 minAssetAmount;

//     uint256 actualAssetAmount;

//     actualAssetAmount, _, _, _ = getGhoAmountForBuyAsset(e, minAssetAmount);
//     assert minAssetAmount <= actualAssetAmount;
// }

// // @title actual gho amount returned getAssetAmountForSellAsset should be more than the min amount specified by the user
// // STATUS: VIOLATED
// // https://prover.certora.com/output/11775/c75e493e2c494c2a8915efa5db311c6c?anonymousKey=04dc391cd1e3719c2302f38c2e045bcfa7907b76
// rule basicProperty_getAssetAmountForSellAsset() {
//     env e;

//     require getPriceRatio(e) > 0;
//     require _FixedFeeStrategy.getSellFeeBP(e) < 10000;

//     uint256 minGhoAmount;

//     uint256 actualGhoAmount;

//     _, actualGhoAmount, _, _ = getAssetAmountForSellAsset(e, minGhoAmount);
//     assert minGhoAmount <= actualGhoAmount;
// }

// // @title actual asset amount returned getGhoAmountForSellAsset should be less than the max amount specified by the user
// // STATUS: VIOLATED
// // https://prover.certora.com/output/11775/c75e493e2c494c2a8915efa5db311c6c?anonymousKey=04dc391cd1e3719c2302f38c2e045bcfa7907b76
// rule basicProperty_getGhoAmountForSellAsset() {
//     env e;

//     require getPriceRatio(e) > 0;
//     require _FixedFeeStrategy.getSellFeeBP(e) < 10000;

//     uint256 maxAssetAmount;

//     uint256 actualAssetAmount;

//     actualAssetAmount, _, _, _ = getGhoAmountForSellAsset(e, maxAssetAmount);
//     assert actualAssetAmount <= maxAssetAmount;
// }

// // @title getGhoAmountForBuyAsset should return the same amount for an asset amount suggested by it
// // STATUS: VIOLATED
// // https://prover.certora.com/output/11775/c75e493e2c494c2a8915efa5db311c6c?anonymousKey=04dc391cd1e3719c2302f38c2e045bcfa7907b76
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


// /**
//     ***********************************
//     ***** BUY ASSET INVERSE RULES *****
//     ***********************************
// */

// // @title getAssetAmountForBuyAsset is inverse of getGhoAmountForBuyAsset
// // STATUS: VIOLATED
// // https://prover.certora.com/output/11775/c75e493e2c494c2a8915efa5db311c6c?anonymousKey=04dc391cd1e3719c2302f38c2e045bcfa7907b76
// rule buyAssetInverse_asset() {
//     env e;
//     mathint priceRatio = getPriceRatio(e);
//     require priceRatio >= 10^16 && priceRatio <= 10^20;

//     mathint uau = _priceStrategy.getUnderlyingAssetUnits(e);
//     uint8 underlyingAssetDecimals;
//     require underlyingAssetDecimals <= 27 && underlyingAssetDecimals >= 5;
//     require uau == 10^underlyingAssetDecimals;

//     require _FixedFeeStrategy.getBuyFeeBP(e) < 5000;

//     uint256 maxGhoAmount;
//     uint256 assetAmount;
//     uint256 assetAmount2;

//     assetAmount, _, _, _ = getAssetAmountForBuyAsset(e, maxGhoAmount);
//     assetAmount2, _, _, _ = getGhoAmountForBuyAsset(e, assetAmount);

//     assert assetAmount == assetAmount2; 
// }

// // @title getAssetAmountForSellAsset is inverse of getGhoAmountForSellAsset
// // STATUS: PASSING
// // https://prover.certora.com/output/11775/c75e493e2c494c2a8915efa5db311c6c?anonymousKey=04dc391cd1e3719c2302f38c2e045bcfa7907b76
rule buyAssetInverse_all() {
    env e;
    mathint priceRatio = getPriceRatio(e);
    require priceRatio >= 10^16 && priceRatio <= 10^20;

    mathint uau = _priceStrategy.getUnderlyingAssetUnits(e);
    uint8 underlyingAssetDecimals;
    require underlyingAssetDecimals <= 27 && underlyingAssetDecimals >= 5;
    require uau == 10^underlyingAssetDecimals;

    require _FixedFeeStrategy.getBuyFeeBP(e) < 5000;

    uint256 maxGhoAmount;

    uint256 assetAmount; uint256 assetAmount2;
    uint256 ghoAmount; uint256 ghoAmount2;
    uint256 grossAmount; uint256 grossAmount2;
    uint256 fee; uint256 fee2;

    assetAmount, ghoAmount, grossAmount, fee = getAssetAmountForBuyAsset(e, maxGhoAmount);
    assetAmount2, ghoAmount2, grossAmount2, fee2 = getGhoAmountForBuyAsset(e, assetAmount);

    mathint maxAssetError = (3*uau)/(5*getPriceRatio(e)) + 2;

    assert assetAmount <= assetAmount2 && to_mathint(assetAmount2) <= assetAmount + maxAssetError, "asset amount error bound";
    assert ghoAmount == ghoAmount2, "gho amount";
    assert grossAmount == grossAmount2, "gross amount";
    assert fee == fee2, "fee";
}



// /**
//     ************************************
//     ***** SELL ASSET INVERSE RULES *****
//     ************************************
// */

// // @title getAssetAmountForBuyAsset is inverse of getGhoAmountForBuyAsset
// // STATUS: VIOLATED
// // https://prover.certora.com/output/11775/c75e493e2c494c2a8915efa5db311c6c?anonymousKey=04dc391cd1e3719c2302f38c2e045bcfa7907b76
// rule sellAssetInverse_gross() {
//     env e;
//     mathint priceRatio = getPriceRatio(e);
//     require 10^16 <= priceRatio && priceRatio <= 10^20;

//     mathint uau = _priceStrategy.getUnderlyingAssetUnits(e);
//     uint8 underlyingAssetDecimals;
//     require underlyingAssetDecimals <= 27 && underlyingAssetDecimals >= 5;
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

// // @title getAssetAmountForSellAsset is inverse of getGhoAmountForSellAsset
// // STATUS: VIOLATED
// // https://prover.certora.com/output/11775/c75e493e2c494c2a8915efa5db311c6c?anonymousKey=04dc391cd1e3719c2302f38c2e045bcfa7907b76
// /* Takes 7000 seconds, the counterexample may be required directly
//     underlyingAssetDecimals = 11
//     sellFee = 1
//     minGhoAmount = 9
//     getAssetAmountForSellAsset(minGhoAmount=9) = (1, 0x1ada5, 0x1adb1, 12)
//     getGhoAmountForSellAsset(maxAssetAmount=1) = (1, 0x1ada5, 0x1adb0, 11)
// */
// rule sellAssetInverse_fee() {
//     env e;
//     mathint priceRatio = getPriceRatio(e);
//     require 10^16 <= priceRatio && priceRatio <= 10^20;

//     mathint uau = _priceStrategy.getUnderlyingAssetUnits(e);
//     uint8 underlyingAssetDecimals;
//     require underlyingAssetDecimals <= 27 && underlyingAssetDecimals >= 5;
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
// STATUS: PASSING
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