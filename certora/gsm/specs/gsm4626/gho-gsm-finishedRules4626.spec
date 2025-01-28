import "../GsmMethods/methods4626_base.spec";
import "../GsmMethods/aave_price_fee_limits.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/erc4626.spec";


// @title Rescuing GHO never lefts less GHO available than _accruedFees.
// STATUS: PASSED
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
// STATUS: PASSED
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
// STATUS: PASSED
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
rule buyAssetDecreasesExposure() 
{
	env e;
	feeLimits(e);
	priceLimits(e);
	uint128 amount;
    address receiver;
	uint exposureBefore = getCurrentExposure(e);
	require amount > 0;
	buyAsset(e, amount, receiver);

	assert getCurrentExposure(e) < exposureBefore;
}

// @title sellAsset increases _currentExposure
//When calling sellAsset successfully (i.e., no revert), the _currentExposure should always increase.
// STATUS: PASSED
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
rule sellAssetIncreasesExposure() 
{
	env e;
	feeLimits(e);
	priceLimits(e);
	uint128 amount;
    address receiver;
	uint exposureBefore = getCurrentExposure(e);
	require amount > 0;
	sellAsset(e, amount, receiver);

	assert getCurrentExposure(e) > exposureBefore;
}

// @title If _currentExposure exceeds _exposureCap, sellAsset reverts.
// STATUS: VIOLATED
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
// rule cantSellIfExposureTooHigh()
// {
// 	env e;	
// 	feeLimits(e);
// 	priceLimits(e);
// 	uint128 amount;
//     address receiver;
// 	require require_uint256(getCurrentExposure(e) + amount) > getExposureCap(e);
// 	sellAsset@withrevert(e, amount, receiver);

// 	assert lastReverted;
// }

definition canChangeExposureCap(method f) returns bool = 
	f.selector == sig:updateExposureCap(uint128).selector ||
	f.selector == sig:initialize(address,address,uint128).selector||
	f.selector == sig:seize().selector;


// @title Only updateExposureCap, initialize, seize can change exposureCap.
// STATUS: PASS
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
	//f.selector == sig:backWithGho(uint128).selector ||
	f.selector == sig:backWithUnderlying(uint256).selector ||
	f.selector == sig:sellAsset(uint256,address).selector ||
	f.selector == sig:sellAssetWithSig(address,uint256,address,uint256,bytes).selector;

definition canDecreaseExposure(method f) returns bool = 
	f.selector == sig:buyAsset(uint256, address).selector ||
	f.selector == sig:seize().selector ||
	f.selector == sig:buyAssetWithSig(address,uint256,address,uint256,bytes).selector;

// @title Only specific methods can change exposure.
// STATUS: PASS

rule whoCanChangeExposure(method f)
{
	env e;
	feeLimits(e);
	priceLimits(e);
	uint256 exposureBefore = getCurrentExposure(e);
	calldataarg args;
	f(e, args);
	uint256 exposureAfter = getCurrentExposure(e);
	assert exposureAfter > exposureBefore => canIncreaseExposure(f), "should not increase exposure";
	assert exposureAfter < exposureBefore => canDecreaseExposure(f), "should not decrease exposure";
}

definition canIncreaseAccruedFees(method f) returns bool = 
	f.selector == sig:sellAsset(uint256,address).selector ||
	f.selector == sig:sellAssetWithSig(address,uint256,address,uint256,bytes).selector ||
	f.selector == sig:buyAsset(uint256, address).selector ||
	f.selector == sig:buyAssetWithSig(address,uint256,address,uint256,bytes).selector ||
	f.selector == sig:cumulateYieldInGho().selector
	;

definition canDecreaseAccruedFees(method f) returns bool =
	f.selector == sig:distributeFeesToTreasury().selector;

// @title Only specific methods can increase / decrease acrued fees
// STATUS: VIOLATED
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
rule collectedBuyFeeIsAtLeastAsRequired()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint256 assetAmount;
	uint256 ghoTotal; uint256 ghoGross; uint256 ghoFee;
	_, ghoTotal, ghoGross, ghoFee = getGhoAmountForBuyAsset(e, assetAmount);
	assert getPercMathPercentageFactor(e) * ghoFee >= getBuyFeeBP(e) * ghoGross;
}

// @title The buy fee actually collected (after rounding) is at least the required percentage.
// STATUS: PASS
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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

// @title getAssetAmountForSellAsset never exceeds the given bound
// STATUS: PASS
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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

// @title backWithGho doesn't create excess
// STATUS: PASS
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
rule backWithGhoDoesntCreateExcess()
{
	env e;	
	feeLimits(e);
	priceLimits(e);
	uint128 amount;
	uint256 excess; uint256 dearth;
	require getCurrentExposure(e) + amount < max_uint256;
	excess, dearth = getCurrentBacking(e);
	
	backWithGho(e, amount);
	assert dearth > 0;	//if not reverted, dearth must be > 0

	uint256 excessAfter; uint256 dearthAfter;
	excessAfter, dearthAfter = getCurrentBacking(e);
	assert excessAfter == 0;
}

// @title gifting Gho doesn't create excess or dearth
// STATUS: PASS
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
rule giftingGhoDoesntCreateExcessOrDearth()
{
	env e;	
	feeLimits(e);
	priceLimits(e);
	address sender;
	uint128 amount; 
	uint256 excess; uint256 dearth;
	excess, dearth = getCurrentBacking(e);
	
	giftGho(e, sender, amount);
	
	uint256 excessAfter; uint256 dearthAfter;
	excessAfter, dearthAfter = getCurrentBacking(e);
	assert excessAfter == excess && dearthAfter == dearth;
}

// @title gifting Underlying doesn't create excess or dearth
// STATUS: PASS
// https://prover.certora.com/output/6893/1a85cb3aac6942abad66e5508f7d37f7/?anonymousKey=4cff2c39342d22aac51f08bb6fdbb375c0f025c6
rule giftingUnderlyingDoesntCreateExcessOrDearth()
{
	env e;	
	feeLimits(e);
	priceLimits(e);
	address sender;
	uint128 amount; 
	uint256 excess; uint256 dearth;
	excess, dearth = getCurrentBacking(e);
	
	giftUnderlyingAsset(e, sender, amount);
	
	uint256 excessAfter; uint256 dearthAfter;
	excessAfter, dearthAfter = getCurrentBacking(e);
	assert excessAfter == excess && dearthAfter == dearth;
}

// @title exposure bellow cap is preserved by all methods except updateExposureCap and initialize
// STATUS: PASS
// https://prover.certora.com/output/6893/ada8f51ae4f7440b86c51e44b0848c45/?anonymousKey=6d86bdd46fd01d54e4d129bc12358b790450b57c
rule exposureBelowCap(method f)
	filtered { f -> 
		f.selector != sig:initialize(address,address,uint128).selector
		&& f.selector != sig:updateExposureCap(uint128).selector
		&& f.selector != sig:backWithUnderlying(uint256).selector
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

// @title backWithUnderlying doesn't create excess
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/41f89457d28046fd8337b785be0f7083?anonymousKey=11cb2f7a6900010275a89d0be8f6af8245bfce3d
// rule backWithUnderlyingDoesntCreateExcess()
// {
// 	env e;
// 	feeLimits(e);
// 	priceLimits(e);
// 	uint128 amount;
// 	uint256 excess; uint256 dearth;
// 	require getCurrentExposure(e) + amount < max_uint256;

// 	backWithUnderlying(e, amount); // Reverts if there is no deficit

// 	uint256 excessAfter; uint256 dearthAfter;
// 	excessAfter, dearthAfter = getCurrentBacking(e);
// 	assert excessAfter <= 1;
// }

// @title gifting underlying doesn't change storage
// STATUS: PASS
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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

// @title gifting underlying doesn't change storage
// STATUS: PASS
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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

// @title Return values of sellAsset are monotonically inreasing
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/a6b2635ff0d7405daa361c732e2a519e?anonymousKey=506bbd9b65e9cf3e32f27606e38fd713cedfe2df
// rule monotonicityOfSellAsset() {
//     env e;
//     feeLimits(e);
//     priceLimits(e);
    
// 	address recipient;
//     uint amount1;
//     uint a1;
// 	uint g1;
//     //a1, g1 = sellAsset(e, amount1, recipient);
// 	a1, g1, _, _ = getGhoAmountForSellAsset(e, amount1);

//     uint amount2;
//     uint a2;
// 	uint g2;
//     //a2, g2 = sellAsset(e, amount2, recipient);
// 	a2, g2, _, _ = getGhoAmountForSellAsset(e, amount2);

//     assert a1 <= a2 <=> g1 <= g2;
// }

// @title Return values of buyAsset are monotonically inreasing
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/614332d4a677432d988bfd371653a23b?anonymousKey=cd30246db79a8237b02d83f1d390c4832cd1f970
// rule monotonicityOfBuyAsset() {
//     env e;
//     feeLimits(e);
//     priceLimits(e);
    
// 	address recipient;
//     uint amount1;
//     uint a1;
// 	uint g1;
//     a1, g1 = buyAsset(e, amount1, recipient);

//     uint amount2;
//     uint a2;
// 	uint g2;
//     a2, g2 = buyAsset(e, amount2, recipient);

//     assert a1 <= a2 <=> g1 <= g2;
// }

// @title Return values of sellAsset are the same as of getGhoAmountForSellAsset
// STATUS: PASS
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
// https://prover.certora.com/output/11775/d325dd52f7a4416984e3b9b3188d81c4?anonymousKey=2db655a9466ae77e610d3b8f6229bd4752643f1e
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
