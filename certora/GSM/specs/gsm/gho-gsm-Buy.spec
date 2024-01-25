import "../GsmMethods/methods_base.spec";
import "../GsmMethods/aave_price_fee_limits.spec";

// patch2: violated by at most 2
// https://prover.certora.com/output/6893/cb83daf2e5cf4a929b95833e7e3e818e?anonymousKey=6adb07ee65ae6366f535ccad8379bce3784e21ca
rule getAssetAmountForBuyAsset_correctness_bound1()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint maxToGive;
	uint suggestedAssetToBuy;
	suggestedAssetToBuy, _, _, _ = getAssetAmountForBuyAsset(e, maxToGive);

	uint reallyPaid;
	_, reallyPaid, _, _ = getGhoAmountForBuyAsset(e, suggestedAssetToBuy);
	
	assert reallyPaid <= require_uint256(maxToGive + 1);
}

// patch2: holds
// https://prover.certora.com/output/6893/cb83daf2e5cf4a929b95833e7e3e818e?anonymousKey=6adb07ee65ae6366f535ccad8379bce3784e21ca
rule getAssetAmountForBuyAsset_correctness_bound2()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint maxToGive;
	uint suggestedAssetToBuy;
	suggestedAssetToBuy, _, _, _ = getAssetAmountForBuyAsset(e, maxToGive);

	uint reallyPaid;
	_, reallyPaid, _, _ = getGhoAmountForBuyAsset(e, suggestedAssetToBuy);
	
	assert reallyPaid <= require_uint256(maxToGive + 2);
}

// patch2: holds
// https://prover.certora.com/output/6893/9752152c77704030aea9dbef2f410423?anonymousKey=d01df80162910000c5aaa7cc4516add5ad7e1739
rule getAssetAmountForBuyAsset_optimality()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint maxToGive;
	uint suggestedAssetToBuy;
	suggestedAssetToBuy, _, _, _ = getAssetAmountForBuyAsset(e, maxToGive);
	uint suggestedGhoToPay;
	_, suggestedGhoToPay, _, _ = getGhoAmountForBuyAsset(e, suggestedAssetToBuy);

	uint maxCouldBuy;
	uint couldBuy;
	uint couldPay;
	couldBuy, couldPay, _, _ = getGhoAmountForBuyAsset(e, maxCouldBuy);
	
	require couldPay <= maxToGive;
	require couldPay >= suggestedGhoToPay;

	assert couldBuy <= suggestedAssetToBuy;
}

// patch3: holds
rule getGhoAmountForBuyAsset_optimality()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint minAssetToBuy;			// 2
	uint suggestedAssetToBuy;	// 3
	uint suggestedGhoToSpend;	// 3
	suggestedAssetToBuy, suggestedGhoToSpend, _, _ = getGhoAmountForBuyAsset(e, minAssetToBuy);

	uint min2AssetsToBuy;		// 1
	uint couldBuy;				// 2
	uint couldPay;				// 2
	couldBuy, couldPay, _, _ = getGhoAmountForBuyAsset(e, min2AssetsToBuy);
	
	require couldBuy >= minAssetToBuy;
	//require couldPay >= suggestedGhoToPay;

	assert couldPay >= suggestedGhoToSpend;
}


rule getGhoAmountForBuyAsset_correctness()
{
	env e;
	feeLimits(e);
	priceLimits(e);

    uint256 minAssetAmount;
	uint suggestedAssetToBuy;
	suggestedAssetToBuy, _, _, _ = getGhoAmountForBuyAsset(e, minAssetAmount);

	assert suggestedAssetToBuy >= minAssetAmount;
}

rule getGhoAmountForBuyAsset_correctness1()
{
	env e;
	feeLimits(e);
	priceLimits(e);

    uint256 minAssetAmount;
	uint suggestedAssetToBuy;
	suggestedAssetToBuy, _, _, _ = getGhoAmountForBuyAsset(e, minAssetAmount);

	assert require_uint256(suggestedAssetToBuy + 1) >= minAssetAmount;
}

rule getAssetAmountForBuyAsset_funcProperty()
{
	// if (A, B, _, _) = getAssetAmountForBuyAsset(X) then B is function of A
	env e;
	feeLimits(e);
	priceLimits(e);

    uint256 amount1;
	uint suggestedAssetToBuy1;
	uint totalPay1;
	suggestedAssetToBuy1, totalPay1, _, _ = getAssetAmountForBuyAsset(e, amount1);

	uint256 amount2;
	uint suggestedAssetToBuy2;
	uint totalPay2;
	suggestedAssetToBuy2, totalPay2, _, _ = getAssetAmountForBuyAsset(e, amount2);

	assert (suggestedAssetToBuy1 == suggestedAssetToBuy2) ==
		(totalPay1 == totalPay2);
}

rule getGhoAmountForBuyAsset_funcProperty()
{
	// if (A, B, _, _) = getGhoAmountForBuyAsset(X) then B is function of A
	env e;
	feeLimits(e);
	priceLimits(e);

    uint256 amount1;
	uint suggestedAssetToBuy1;
	uint totalPay1;
	suggestedAssetToBuy1, totalPay1, _, _ = getGhoAmountForBuyAsset(e, amount1);

	uint256 amount2;
	uint suggestedAssetToBuy2;
	uint totalPay2;
	suggestedAssetToBuy2, totalPay2, _, _ = getGhoAmountForBuyAsset(e, amount2);

	assert (suggestedAssetToBuy1 == suggestedAssetToBuy2) ==
		(totalPay1 == totalPay2);
}

rule getAssetAmountForSellAsset_funcProperty()
{
	// if (A, B, _, _) = getAssetAmountForSellAsset(X) then B is function of A
	env e;
	feeLimits(e);
	priceLimits(e);

    uint256 amount1;
	uint suggestedAsset1;
	uint totalPay1;
	suggestedAsset1, totalPay1, _, _ = getAssetAmountForSellAsset(e, amount1);

	uint256 amount2;
	uint suggestedAsset2;
	uint totalPay2;
	suggestedAsset2, totalPay2, _, _ = getAssetAmountForSellAsset(e, amount2);

	assert (suggestedAsset1 == suggestedAsset2) ==
		(totalPay1 == totalPay2);
}

rule getGhoAmountForSellAsset_funcProperty()
{
	// if (A, B, _, _) = getGhoAmountForSellAsset(X) then B is function of A
	env e;
	feeLimits(e);
	priceLimits(e);

    uint256 amount1;
	uint suggestedAsset1;
	uint totalPay1;
	suggestedAsset1, totalPay1, _, _ = getGhoAmountForSellAsset(e, amount1);

	uint256 amount2;
	uint suggestedAsset2;
	uint totalPay2;
	suggestedAsset2, totalPay2, _, _ = getGhoAmountForSellAsset(e, amount2);

	assert (suggestedAsset1 == suggestedAsset2) ==
		(totalPay1 == totalPay2);
}

rule getGhoAmountForBuyAsset_aditivity()
{
	env e;
	feeLimits(e);
	priceLimits(e);

    uint256 minAssetAmount1;
	uint bought1;
	uint paid1;
	bought1, paid1, _, _ = getGhoAmountForBuyAsset(e, minAssetAmount1);

	uint256 minAssetAmount2;
	uint bought2;
	uint paid2;
	bought2, paid2, _, _ = getGhoAmountForBuyAsset(e, minAssetAmount2);
	require require_uint256(bought1 + bought2) > 0;

	uint256 minAssetAmount3;
	uint bought3;
	uint paid3;
	bought3, paid3, _, _ = getGhoAmountForBuyAsset(e, minAssetAmount3);

	assert require_uint256(bought1 + bought2) >= bought3 => 
		require_uint256(paid1 + paid2) >= paid3;
}

rule getAssetAmountForBuyAsset_aditivity()
{
	env e;
	feeLimits(e);
	priceLimits(e);

    uint256 maxGhoAmount1;
	uint bought1;
	uint paid1;
	bought1, paid1, _, _ = getAssetAmountForBuyAsset(e, maxGhoAmount1);

	uint256 maxGhoAmount2;
	uint bought2;
	uint paid2;
	bought2, paid2, _, _ = getAssetAmountForBuyAsset(e, maxGhoAmount2);
	require require_uint256(bought1 + bought2) > 0;

	uint256 maxGhoAmount3;
	uint bought3;
	uint paid3;
	bought3, paid3, _, _ = getAssetAmountForBuyAsset(e, maxGhoAmount3);

	assert require_uint256(bought1 + bought2) >= bought3 => 
		require_uint256(paid1 + paid2) >= paid3;
}

// patch2: violated by at most 2
// https://prover.certora.com/output/6893/cb83daf2e5cf4a929b95833e7e3e818e?anonymousKey=6adb07ee65ae6366f535ccad8379bce3784e21ca
rule getAssetAmountForBuyAsset_correctness()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint maxToGive;
	require maxToGive > 0;
	uint suggestedAssetToBuy;
	suggestedAssetToBuy, _, _, _ = getAssetAmountForBuyAsset(e, maxToGive);

	uint reallyPaid;
	_, reallyPaid, _, _ = getGhoAmountForBuyAsset(e, suggestedAssetToBuy);
	
	assert reallyPaid <= maxToGive;
}



