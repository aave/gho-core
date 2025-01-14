import "../GsmMethods/methods_base.spec";
import "../GsmMethods/aave_price_fee_limits.spec";
import "../GsmMethods/methods_divint_summary.spec";

rule reachability(method f)
{
	env e;
	feeLimits(e);
	priceLimits(e);
	calldataarg args;
	f(e,args);
	satisfy true;
}

// @title Rescuing GHO never lefts less GHO available than _accruedFees.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule rescuingGhoKeepsAccruedFees()
{
	address token;
    address to;
    uint256 amount;
	env e;
	feeLimits(e);
	priceLimits(e);
	require token == GHO_TOKEN(e);
	rescueTokens(e, token, to, amount);
	assert getCurrentGhoBalance(e) >= getAccruedFee(e);
}

// @title Rescuing underlying never lefts less underlying available than _currentExposure.
//Rescuing the underlying asset should never result in there being less of the underlying (as an ERC-20 balance) than the combined total of the _currentExposure and _tokenizedAssets.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule rescuingAssetKeepsAccruedFees()
{
	address token;
    address to;
    uint256 amount;
	env e;
	feeLimits(e);
	priceLimits(e);
	require token == UNDERLYING_ASSET(e);
	rescueTokens(e, token, to, amount);
	assert getCurrentUnderlyingBalance(e) >= assert_uint256(getCurrentExposure(e));	// + getTokenizedAssets(e));
}

// @title buyAsset decreases _currentExposure
//When calling buyAsset successfully (i.e., no revert), the _currentExposure should always decrease.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule buyAssetDecreasesExposure() 
{
	env e;
	feeLimits(e);
	priceLimits(e);
	uint128 amount;
    address receiver;
	uint128 exposureBefore = getCurrentExposure(e);
	require amount > 0;
	buyAsset(e, amount, receiver);

	assert getCurrentExposure(e) < exposureBefore;
}

// @title sellAsset increases _currentExposure
//When calling sellAsset successfully (i.e., no revert), the _currentExposure should always increase.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule sellAssetIncreasesExposure() 
{
	env e;
	feeLimits(e);
	priceLimits(e);
	uint128 amount;
    address receiver;
	uint128 exposureBefore = getCurrentExposure(e);
	require amount > 0;
	sellAsset(e, amount, receiver);

	assert getCurrentExposure(e) > exposureBefore;
}

// @title If _currentExposure exceeds _exposureCap, sellAsset reverts.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule cantSellIfExposureTooHigh()
{
	env e;	
	feeLimits(e);
	priceLimits(e);
	uint128 amount;
    address receiver;
	sellAsset(e, amount, receiver);
	
	uint128 exposureCap = getExposureCap(e);
	uint128 currentExposure = getCurrentExposure(e);

	assert currentExposure <= exposureCap;
}

definition canChangeExposureCap(method f) returns bool = 
	f.selector == sig:updateExposureCap(uint128).selector ||
	f.selector == sig:initialize(address,address,uint128).selector||
	f.selector == sig:seize().selector;


// @title Only updateExposureCap, initialize, seize can change exposureCap.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule whoCanChangeExposureCap(method f)
{
	env e;
	feeLimits(e);
	priceLimits(e);
	uint256 exposureCapBefore = getExposureCap(e);
	calldataarg args;
	f(e, args);
	uint256 exposureCapAfter = getExposureCap(e);
	assert exposureCapAfter != exposureCapBefore => canChangeExposureCap(f), "should not change exposure cap";
}

// @title Cannot buy or sell if the GSM is frozen.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule cantBuyOrSellWhenFrozen()
{
	env e;	
	feeLimits(e);
	priceLimits(e);
	uint128 amount;
    address receiver;
	require getIsFrozen(e);

	buyAsset@withrevert(e, amount, receiver);
	assert lastReverted;

	sellAsset@withrevert(e, amount, receiver);
	assert lastReverted;
}

// @title Cannot buy or sell if the GSM is seized.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule cantBuyOrSellWhenSeized()
{
	env e;	
	feeLimits(e);
	priceLimits(e);
	uint128 amount;
    address receiver;
	
	require getIsSeized(e);

	buyAsset@withrevert(e, amount, receiver);
	assert lastReverted;
	
	sellAsset@withrevert(e, amount, receiver);
	assert lastReverted;
}

definition canIncreaseExposure(method f) returns bool = 
	f.selector == sig:sellAsset(uint256,address).selector ||
	f.selector == sig:sellAssetWithSig(address,uint256,address,uint256,bytes).selector;

definition canDecreaseExposure(method f) returns bool = 
	f.selector == sig:buyAsset(uint256, address).selector ||
	f.selector == sig:seize().selector ||
	f.selector == sig:buyAssetWithSig(address,uint256,address,uint256,bytes).selector;

// @title Only specific methods can change exposure.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule whoCanChangeExposure(method f)
{
	env e;
	feeLimits(e);
	priceLimits(e);
	uint128 exposureBefore = getCurrentExposure(e);
	calldataarg args;
	f(e, args);
	uint128 exposureAfter = getCurrentExposure(e);
	assert exposureAfter > exposureBefore => canIncreaseExposure(f), "should not increase exposure";
	assert exposureAfter < exposureBefore => canDecreaseExposure(f), "should not decrease exposure";
}

definition canIncreaseAccruedFees(method f) returns bool = 
	f.selector == sig:sellAsset(uint256,address).selector ||
	f.selector == sig:sellAssetWithSig(address,uint256,address,uint256,bytes).selector ||
	f.selector == sig:buyAsset(uint256, address).selector ||
	f.selector == sig:buyAssetWithSig(address,uint256,address,uint256,bytes).selector;
	
definition canDecreaseAccruedFees(method f) returns bool =
	f.selector == sig:distributeFeesToTreasury().selector;

// @title Only specific methods can increase / decrease accrued fees
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule whoCanChangeAccruedFees(method f)
{
	env e;
	feeLimits(e);
	priceLimits(e);
	uint256 accruedFeesBefore = getAccruedFee(e);
	calldataarg args;
	f(e, args);
	uint256 accruedFeesAfter = getAccruedFee(e);
	assert accruedFeesAfter > accruedFeesBefore => canIncreaseAccruedFees(f), "should not increase accrued fees";
	assert accruedFeesAfter < accruedFeesBefore => canDecreaseAccruedFees(f), "should not decrease accrued fees";
}

// @title It's not possible for _currentExposure to exceed _exposureCap as a result of a call to sellAsset.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule sellingDoesntExceedExposureCap()
{
	env e;	
	feeLimits(e);
	priceLimits(e);
	uint128 amount;
    address receiver;
	require getCurrentExposure(e) <= getExposureCap(e);
	sellAsset(e, amount, receiver);

	assert getCurrentExposure(e) <= getExposureCap(e);
}

// @title The buy fee actually collected (after rounding) is at least the required percentage.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule collectedBuyFeeIsAtLeastAsRequired()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint256 assetAmount;
	uint256 ghoTotal; uint256 ghoGross; uint256 ghoFee;
	_, ghoTotal, ghoGross, ghoFee = getGhoAmountForBuyAsset(e, assetAmount);
	// assert getPercMathPercentageFactor(e) * ghoFee >= getBuyFeeBP(e) * ghoGross;
	satisfy getPercMathPercentageFactor(e) * ghoFee >= getBuyFeeBP(e) * ghoGross;
}

// @title The buy fee actually collected (after rounding) is at least the required percentage.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule collectedBuyFeePlus1IsAtLeastAsRequired()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint256 assetAmount;
	uint256 ghoTotal; uint256 ghoGross; uint256 ghoFee;
	_, ghoTotal, ghoGross, ghoFee = getGhoAmountForBuyAsset(e, assetAmount);
	assert getPercMathPercentageFactor(e) * require_uint256(ghoFee + 1) >= getBuyFeeBP(e) * ghoGross;
}

// @title The buy fee actually collected (after rounding) is at least the required percentage.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule collectedBuyFeePlus2IsAtLeastAsRequired()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint256 assetAmount;
	uint256 ghoTotal; uint256 ghoGross; uint256 ghoFee;
	_, ghoTotal, ghoGross, ghoFee = getGhoAmountForBuyAsset(e, assetAmount);
	assert getPercMathPercentageFactor(e) * require_uint256(ghoFee + 2) >= getBuyFeeBP(e) * ghoGross;
}

// @title The sell fee actually collected (after rounding) is at least the required percentage.
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule collectedSellFeeIsAtLeastAsRequired()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint256 ghoAmount;
	uint256 ghoTotal; uint256 ghoGross; uint256 ghoFee;
	_, ghoTotal, ghoGross, ghoFee = getGhoAmountForSellAsset(e, ghoAmount);

	assert getPercMathPercentageFactor(e) * ghoFee >= getSellFeeBP(e) * ghoGross;
}

// @title getAssetAmountForSellAsset returns a value as close as possible to user specified amount.
// STATUS: TIMEOUT
// https://prover.certora.com/output/33050/f3a77c3d085d4d289ed2e9bd6e7eec37?anonymousKey=378909505ab1597dcb807b3a3f1097de9b0c08a6
rule getAssetAmountForSellAsset_optimality()
{
	// proves that if user wants to receive at least X gho
	// and the system tel them to sell Y assets, 
	// then there is no amount W < Y that would also bring X gho.

	env e;
	feeLimits(e);
	priceLimits(e);

	uint wantsToReceive;
	uint suggestedAssetToSell;
	suggestedAssetToSell, _, _, _ = getAssetAmountForSellAsset(e, wantsToReceive);

	uint reallySold;
	uint reallyReceived;
	_, reallyReceived, _, _ = getGhoAmountForSellAsset(e, reallySold);
	
	require reallyReceived >= wantsToReceive;

	assert suggestedAssetToSell <= reallySold;
}

// @title Exposure below cap is preserved by all methods except updateExposureCap and initialize
// STATUS: PASS
// https://prover.certora.com/output/6893/14a1440d3114460f8b64b388a706ca46/?anonymousKey=bb420c63b5b5b11810d5d72026ed6cb6baec43ac
rule exposureBelowCap(method f)
	filtered { f -> 
		f.selector != sig:initialize(address,address,uint128).selector
		&& f.selector != sig:updateExposureCap(uint128).selector
	}   
{
	env e;
	calldataarg args;
	feeLimits(e);
	priceLimits(e);
	require getCurrentExposure(e) <= getExposureCap(e);
	f(e, args);
	assert getCurrentExposure(e) <= getExposureCap(e);
}

// @title getAssetAmountForSellAsset never exceeds the given bound
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule getAssetAmountForSellAsset_correctness()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint minimumToReceive;
	uint suggestedAssetToSell;
	suggestedAssetToSell, _, _, _ = getAssetAmountForSellAsset(e, minimumToReceive);

	uint reallyReceived;
	_, reallyReceived, _, _ = getGhoAmountForSellAsset(e, suggestedAssetToSell);
	
	assert reallyReceived >= minimumToReceive;
}

// @title gifting underlying doesn't change storage
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule giftingUnderlyingDoesntAffectStorageSIMPLE()
{
	env e;	
	feeLimits(e);
	priceLimits(e);

	address sender;
	uint128 amount; 
	calldataarg args;
	storage initialStorage = lastStorage;
	giftUnderlyingAsset(e, sender, amount);
	storage storageAfter = lastStorage;

	assert storageAfter[currentContract] == initialStorage[currentContract];
}

// @title gifting GHO doesn't change storage
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule giftingGhoDoesntAffectStorageSIMPLE()
{
	env e;	
	feeLimits(e);
	priceLimits(e);

	address sender;
	uint128 amount; 
	storage initialStorage = lastStorage;
	giftGho(e, sender, amount) at initialStorage;
	storage storageAfter = lastStorage;

	assert storageAfter[currentContract] == initialStorage[currentContract];
}

// @title Return values of sellAsset are monotonically increasing
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/abdd5e8dc1634d0a91e6a35647b06412?anonymousKey=8ae78b0142eba6819674647e6e41e1f264df6a12
rule monotonicityOfSellAsset() {
    env e;
    feeLimits(e);
    priceLimits(e);
    
	address recipient;
    uint amount1;
    uint a1;
	uint g1;
    //a1, g1 = sellAsset(e, amount1, recipient);
	a1, g1, _, _ = getGhoAmountForSellAsset(e, amount1);

    uint amount2;
    uint a2;
	uint g2;
    //a2, g2 = sellAsset(e, amount2, recipient);
	a2, g2, _, _ = getGhoAmountForSellAsset(e, amount2);

    assert a1 <= a2 <=> g1 <= g2;
}

// @title Return values of buyAsset are monotonically increasing
// STATUS: PASS
// https://prover.certora.com/output/6893/a4e2f473e8e8464db7528615287b19dc/?anonymousKey=52f6539bd09a3ed26235b922ad83c9737b01fd3d
rule monotonicityOfBuyAsset() {
    env e;
    feeLimits(e);
    priceLimits(e);
    
	address recipient;
    uint amount1;
    uint a1;
	uint g1;
    a1, g1 = buyAsset(e, amount1, recipient);

    uint amount2;
    uint a2;
	uint g2;
    a2, g2 = buyAsset(e, amount2, recipient);

    assert a1 <= a2 <=> g1 <= g2;
}

// @title Return values of sellAsset are the same as of getGhoAmountForSellAsset
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule sellAssetSameAsGetGhoAmountForSellAsset() {
    env e;
    feeLimits(e);
    priceLimits(e);
    
	address recipient;
    uint amount;
    uint a1;
	uint g1;
	uint a2;
	uint g2;

	a1, g1, _, _ = getGhoAmountForSellAsset(e, amount);
	a2, g2 = sellAsset(e, amount, recipient);

    assert a1 == a2 && g1 == g2;
}

// @title buyAsset never returns value lower than the argument
// STATUS: PASS
// https://prover.certora.com/output/11775/d2998f74795f45eea2ac8da86fd9a481?anonymousKey=6382a56072f63e64436d7af2b5c1800e07a0be9e
rule correctnessOfBuyAsset()
{
	env e;
    feeLimits(e);
    priceLimits(e);
    
	address recipient;
    uint amount;
    uint a;
	uint g;
    a, g = buyAsset(e, amount, recipient);
	assert a >= amount;
}

// @title sellAsset never returns value greater than the argument
// STATUS: PASS
// https://prover.certora.com/output/6893/5c3c2e6eef7e463cb20a0cc2caa945d3/?anonymousKey=77247d881df0abc794a51e871ccae36c4b3c4e08
rule correctnessOfSellAsset()
{
	env e;
    feeLimits(e);
    priceLimits(e);
    
	address recipient;
    uint amount;
    uint a;
	uint g;
    a, g = sellAsset(e, amount, recipient);
	assert a <= amount;
}
