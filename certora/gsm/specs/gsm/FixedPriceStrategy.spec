// import "../GsmMethods/methods_base.spec";


methods {
    function getAssetPriceInGho(uint256, bool) external returns (uint256) envfree;
    function getGhoPriceInAsset(uint256, bool) external returns (uint256) envfree;
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
    if (rounding == Math.Rounding.Up)
    {
        return require_uint256((x * y + denominator - 1) / denominator);
    }
	else return require_uint256((x * y) / denominator);
}

// Full report at https://prover.certora.com/output/17512/ed7722cf57e54d228e6f3487bd15661e?anonymousKey=4bf315b7502b8c338c4b4cd8bcfe7ae9eb858782

// @title getAssetPirce is monotonic
// STATUS: PASS
// https://prover.certora.com/output/11775/924ac54bf2c645cfb2509898c5893163?anonymousKey=ffc27e798c9c5333b00dc04acbc527dccd3c11d5
rule getAssetPriceIsMonotone() {
    env e;
    uint256 amount1;
    uint256 amount2;

    assert amount1 > amount2 => getAssetPriceInGho(amount1, false) >= getAssetPriceInGho(amount2, false);
    assert amount1 > amount2 => getAssetPriceInGho(amount1, true) >= getAssetPriceInGho(amount2, true);
}


// @title getGhoPirce is monotonic
// STATUS: PASS
// https://prover.certora.com/output/11775/924ac54bf2c645cfb2509898c5893163?anonymousKey=ffc27e798c9c5333b00dc04acbc527dccd3c11d5
rule getGhoPriceIsMonotone() {
    env e;
    uint256 amount1;
    uint256 amount2;

    assert amount1 > amount2 => getGhoPriceInAsset(amount1, false) >= getGhoPriceInAsset(amount2, false);
    assert amount1 > amount2 => getGhoPriceInAsset(amount1, true) >= getGhoPriceInAsset(amount2, true);
}

// ******************** //
// *** ERROR BOUNDS *** //
// ******************** //


/* 
    assetAmount - _underlyingAssetUnits/PRICE_RATIO - 1 <= getGhoPriceInAsset(getAssetPriceInGho(assetAmount, false), -) <= assetAmount
    assetAmount <= getGhoPriceInAsset(getAssetPriceInGho(assetAmount, true), -) <= assetAmount + _underlyingAssetUnits/PRICE_RATIO + 1
*/
// @title getGhoPriceInAsset and getAssetPriceInGho are inverse of each other
// STATUS: PASS
// https://prover.certora.com/output/11775/924ac54bf2c645cfb2509898c5893163?anonymousKey=ffc27e798c9c5333b00dc04acbc527dccd3c11d5
rule assetToGhoAndBackErrorBounds() {
    env e;
    uint256 originalAssetAmount;

    mathint underlyingAssetUnits = getUnderlyingAssetUnits(e);
    require underlyingAssetUnits > 0; // safe as this number should be equal to 10 ** underlyingAssetDecimals
    uint256 priceRatio = getPriceRatio(e);
    require priceRatio > 0;

    mathint maxError = underlyingAssetUnits/priceRatio +1;
    mathint newAssetAmountDD = getGhoPriceInAsset(getAssetPriceInGho(originalAssetAmount, false), false);
    mathint newAssetAmountDU = getGhoPriceInAsset(getAssetPriceInGho(originalAssetAmount, false), true);
    mathint newAssetAmountUD = getGhoPriceInAsset(getAssetPriceInGho(originalAssetAmount, true), false);
    mathint newAssetAmountUU = getGhoPriceInAsset(getAssetPriceInGho(originalAssetAmount, true), true);

    assert originalAssetAmount - maxError <= newAssetAmountDD && newAssetAmountDD <= to_mathint(originalAssetAmount), "rounding down then down";
    assert originalAssetAmount - maxError <= newAssetAmountDU && newAssetAmountDU <= to_mathint(originalAssetAmount), "rounding down then up";
    assert to_mathint(originalAssetAmount) <= newAssetAmountUD && newAssetAmountUD <= originalAssetAmount + maxError, "rounding up then down";
    assert to_mathint(originalAssetAmount) <= newAssetAmountUU && newAssetAmountUU <= originalAssetAmount + maxError, "rounding up then up";
}

/* 
    ghoAmount - PRICE_RATIO / _underlyingAssetUnits - 1 <= getAssetPriceInGho(getGhoPriceInAsset(ghoAmount,false),-) <= ghoAmount
    ghoAmount <= getAssetPriceInGho(getGhoPriceInAsset(ghoAmount,false),-) <= ghoAmount + PRICE_RATIO / _underlyingAssetUnits + 1 
*/
// @title getGhoPriceInAsset and getAssetPriceInGho are inverse of each other
// STATUS: PASS
// https://prover.certora.com/output/11775/924ac54bf2c645cfb2509898c5893163?anonymousKey=ffc27e798c9c5333b00dc04acbc527dccd3c11d5
rule ghoToAssetAndBackErrorBounds() {
    env e;
    uint256 originalAmountOfGho;

    mathint underlyingAssetUnits = getUnderlyingAssetUnits(e);
    require underlyingAssetUnits > 0; // safe as this number should be equal to 10 ** underlyingAssetDecimals
    uint256 priceRatio = getPriceRatio(e);
    require priceRatio > 0;

    mathint maxError = priceRatio/underlyingAssetUnits +1;
    mathint newGhoAmountDD = getAssetPriceInGho(getGhoPriceInAsset(originalAmountOfGho, false), false);
    mathint newGhoAmountDU = getAssetPriceInGho(getGhoPriceInAsset(originalAmountOfGho, false), true);
    mathint newGhoAmountUD = getAssetPriceInGho(getGhoPriceInAsset(originalAmountOfGho, true), false);
    mathint newGhoAmountUU = getAssetPriceInGho(getGhoPriceInAsset(originalAmountOfGho, true), true);

    assert originalAmountOfGho - maxError <= newGhoAmountDD && newGhoAmountDD <= to_mathint(originalAmountOfGho), "rounding down then down";
    assert originalAmountOfGho - maxError <= newGhoAmountDU && newGhoAmountDU <= to_mathint(originalAmountOfGho), "rounding down then up";
    assert to_mathint(originalAmountOfGho) <= newGhoAmountUD && newGhoAmountUD <= originalAmountOfGho + maxError, "rounding up then down";
    assert to_mathint(originalAmountOfGho) <= newGhoAmountUU && newGhoAmountUU <= originalAmountOfGho + maxError, "rounding up then up";
}
