import "../GsmMethods/methods4626_base.spec";
import "../GsmMethods/aave_price_fee_limits.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/erc4626.spec";

// @title The amount of asset returned is less than or equal to given param
// STATUS: PASS
// https://prover.certora.com/output/11775/66c7c0a501d04b7e815fcd13680c087d?anonymousKey=6c44ce466f01c24f3e7d5432b4ddd2b8170da571
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

// @title the amount given should be at most 1 more than the max amount specified
// STATUS: PASS
// https://prover.certora.com/output/11775/66c7c0a501d04b7e815fcd13680c087d?anonymousKey=6c44ce466f01c24f3e7d5432b4ddd2b8170da571
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

// @title the amount given should be at most 1 more than the max amount specified
// STATUS: PASS
// https://prover.certora.com/output/11775/66c7c0a501d04b7e815fcd13680c087d?anonymousKey=6c44ce466f01c24f3e7d5432b4ddd2b8170da571
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

// @title The amount of gho returned is greater than or equal to given param
// STATUS: PASS
// https://prover.certora.com/output/6893/9b3b580e82f8497f87ab1f7f169715b8/?anonymousKey=e6c627441f4110e51467815149500a78d8f3765a
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


// @title suggested asset amount is upto 1 less than the miss asset amount 
// STATUS: PASS
// https://prover.certora.com/output/11775/66c7c0a501d04b7e815fcd13680c087d?anonymousKey=6c44ce466f01c24f3e7d5432b4ddd2b8170da571
rule getGhoAmountForBuyAsset_correctness_bound1()
{
	env e;
	feeLimits(e);
	priceLimits(e);

    uint256 minAssetAmount;
	uint suggestedAssetToBuy;
	suggestedAssetToBuy, _, _, _ = getGhoAmountForBuyAsset(e, minAssetAmount);

	assert require_uint256(suggestedAssetToBuy + 1) >= minAssetAmount;
}


// @title The amount of asset returned is greater than or equal to given param.
// STATUS: PASS
// // https://prover.certora.com/output/11775/66c7c0a501d04b7e815fcd13680c087d?anonymousKey=6c44ce466f01c24f3e7d5432b4ddd2b8170da571
rule getAssetAmountForSellAsset_correctness()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint minimumToReceive;
	require minimumToReceive > 0;
	uint suggestedAssetToSell;
	suggestedAssetToSell, _, _, _ = getAssetAmountForSellAsset(e, minimumToReceive);

	uint reallyReceived;
	_, reallyReceived, _, _ = getGhoAmountForSellAsset(e, suggestedAssetToSell);
	
	assert reallyReceived >= minimumToReceive;
}


// @title The amount of gho returned is less than or equal to given param.
// STATUS: PASS
// https://prover.certora.com/output/11775/66c7c0a501d04b7e815fcd13680c087d?anonymousKey=6c44ce466f01c24f3e7d5432b4ddd2b8170da571
rule getGhoAmountForSellAsset_correctness()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint maxAssetAmount;
	uint suggestedAssetToSell;
	suggestedAssetToSell, _, _, _ = getGhoAmountForSellAsset(e, maxAssetAmount);

	assert suggestedAssetToSell <= maxAssetAmount;
}

// @title getAssetAmountForBuyAsset returns value that is as close as possible to user specified amount.
// STATUS: PASS
// https://prover.certora.com/output/11775/66c7c0a501d04b7e815fcd13680c087d?anonymousKey=6c44ce466f01c24f3e7d5432b4ddd2b8170da571
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

// @title getGhoAmountForBuyAsset returns value that is as close as possible to user specified amount.
// STATUS: PASS
// https://prover.certora.com/output/11775/c3036f0fb1c344e2ab8c3f38bf9438af?anonymousKey=f0fd891d0add2cf779b3473b67296b97dd769a8a
rule getGhoAmountForBuyAsset_optimality()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint minAssetToBuy;			
	uint suggestedAssetToBuy;	
	uint suggestedGhoToSpend;
	suggestedAssetToBuy, suggestedGhoToSpend, _, _ = getGhoAmountForBuyAsset(e, minAssetToBuy);

	uint min2AssetsToBuy;		
	uint couldBuy;				
	uint couldPay;				
	couldBuy, couldPay, _, _ = getGhoAmountForBuyAsset(e, min2AssetsToBuy);
	
	require couldBuy >= minAssetToBuy;
	//require couldPay >= suggestedGhoToPay;

	assert couldPay >= suggestedGhoToSpend;
}

// @title getGhoAmountForSellAsset returns value that is as close as possible to user specified amount.
// STATUS: PASS
// https://prover.certora.com/output/6893/9b3b580e82f8497f87ab1f7f169715b8/?anonymousKey=e6c627441f4110e51467815149500a78d8f3765a
rule getGhoAmountForSellAsset_optimality()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint maxAssetToSell;	
	uint suggestedAssetToSell;
	uint suggestedGhoToGain;
	suggestedAssetToSell, suggestedGhoToGain, _, _ = getGhoAmountForSellAsset(e, maxAssetToSell);

	uint maxAssetToSell2;
	uint couldSell;	
	uint couldGain;				
	couldSell, couldGain, _, _ = getGhoAmountForSellAsset(e, maxAssetToSell2);
	
	require couldSell <= maxAssetToSell;
	//require couldPay >= suggestedGhoToPay;

	assert suggestedGhoToGain >= couldGain;
}

// @title getAssetAmountForSellAsset returns value that is as close as possible to user specified amount.
// STATUS: PASS
// https://prover.certora.com/output/11775/1c7f7d0151f04b2c9a68f12f161a7a3f?anonymousKey=7efd045107e4779246295b692ecaf169c5b2c280
rule getAssetAmountForSellAsset_optimality()
{
	// proves that if user wants to receive at least X gho
	// and the system tells them to sell Y assets, 
	// then there is no amount W < Y that would already provide X gho.

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


// @title getAssetAmountForBuyAsset returns value that is as close as possible to user specified amount.
// STATUS: PASS
// https://prover.certora.com/output/33050/f360ab36c2564a069784bc859d6d4c7e?anonymousKey=e0c9610f8e7d6c2e1c78d70708b8fec9b04ee505
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

// @title The first two return values of getGhoAmountForBuyAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/740d89f59d5b4bd689d5e71742b9014e?anonymousKey=fdd7be2db7b1db552afc7fa7bcbbd89983bd6bd1
// rule getGhoAmountForBuyAsset_funcProperty()
// {
// 	// if (A, B, _, _) = getGhoAmountForBuyAsset(X) then B is function of A
// 	env e;
// 	feeLimits(e);
// 	priceLimits(e);

//     uint256 amount1;
// 	uint suggestedAssetToBuy1;
// 	uint totalPay1;
// 	suggestedAssetToBuy1, totalPay1, _, _ = getGhoAmountForBuyAsset(e, amount1);

// 	uint256 amount2;
// 	uint suggestedAssetToBuy2;
// 	uint totalPay2;
// 	suggestedAssetToBuy2, totalPay2, _, _ = getGhoAmountForBuyAsset(e, amount2);

// 	assert (suggestedAssetToBuy1 == suggestedAssetToBuy2) ==
// 		(totalPay1 == totalPay2);
// }

// @title The first two return values of getAssetAmountForSellAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/bde7981ff4f64a04b995ddff49b4b153?anonymousKey=cf1b5e409d9d9e37dc6320d5382c562bc4144664
// rule getAssetAmountForSellAsset_funcProperty()
// {
// 	// if (A, B, _, _) = getAssetAmountForSellAsset(X) then B is function of A
// 	env e;
// 	feeLimits(e);
// 	priceLimits(e);

//     uint256 amount1;
// 	uint suggestedAsset1;
// 	uint totalPay1;
// 	suggestedAsset1, totalPay1, _, _ = getAssetAmountForSellAsset(e, amount1);

// 	uint256 amount2;
// 	uint suggestedAsset2;
// 	uint totalPay2;
// 	suggestedAsset2, totalPay2, _, _ = getAssetAmountForSellAsset(e, amount2);

// 	assert (suggestedAsset1 == suggestedAsset2) ==
// 		(totalPay1 == totalPay2);
// }

// @title The first two return values of getGhoAmountForSellAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/291150d123e04ee29541a3cd0763eb9c?anonymousKey=cee781030122979f034823769c6705c26869f5b8
// rule getGhoAmountForSellAsset_funcProperty()
// {
// 	// if (A, B, _, _) = getGhoAmountForSellAsset(X) then B is function of A
// 	env e;
// 	feeLimits(e);
// 	priceLimits(e);

//     uint256 amount1;
// 	uint suggestedAsset1;
// 	uint totalPay1;
// 	suggestedAsset1, totalPay1, _, _ = getGhoAmountForSellAsset(e, amount1);

// 	uint256 amount2;
// 	uint suggestedAsset2;
// 	uint totalPay2;
// 	suggestedAsset2, totalPay2, _, _ = getGhoAmountForSellAsset(e, amount2);

// 	assert (suggestedAsset1 == suggestedAsset2) ==
// 		(totalPay1 == totalPay2);
// }

// @title getGhoAmountForBuyAsset is additive. Making two small transactions x1, x2, is less favourable for the user than making (x1+x2)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/ebb8f639ebb74796802fe08c55ddfd6c?anonymousKey=be2f94647809d3c634f1e653f572385902452b07
// rule getGhoAmountForBuyAsset_aditivity()
// {
// 	env e;
// 	feeLimits(e);
// 	priceLimits(e);

//     uint256 minAssetAmount1;
// 	uint bought1;
// 	uint paid1;
// 	bought1, paid1, _, _ = getGhoAmountForBuyAsset(e, minAssetAmount1);

// 	uint256 minAssetAmount2;
// 	uint bought2;
// 	uint paid2;
// 	bought2, paid2, _, _ = getGhoAmountForBuyAsset(e, minAssetAmount2);
// 	require require_uint256(bought1 + bought2) > 0;

// 	uint256 minAssetAmount3;
// 	uint bought3;
// 	uint paid3;
// 	bought3, paid3, _, _ = getGhoAmountForBuyAsset(e, minAssetAmount3);

// 	assert require_uint256(bought1 + bought2) >= bought3 => 
// 		require_uint256(paid1 + paid2) >= paid3;
// }


// @title getAssetAmountForBuyAsset is additive. Making two small transactions x1, x2, is less favourable for the user than making (x1+x2)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/c5216b2a5ae54598a471c536f368501f?anonymousKey=1bfd46b0d930b3860ddf12f3f2450eadecd6d482
// rule getAssetAmountForBuyAsset_aditivity()
// {
// 	env e;
// 	feeLimits(e);
// 	priceLimits(e);

//     uint256 maxGhoAmount1;
// 	uint bought1;
// 	uint paid1;
// 	bought1, paid1, _, _ = getAssetAmountForBuyAsset(e, maxGhoAmount1);

// 	uint256 maxGhoAmount2;
// 	uint bought2;
// 	uint paid2;
// 	bought2, paid2, _, _ = getAssetAmountForBuyAsset(e, maxGhoAmount2);
// 	require require_uint256(bought1 + bought2) > 0;

// 	uint256 maxGhoAmount3;
// 	uint bought3;
// 	uint paid3;
// 	bought3, paid3, _, _ = getAssetAmountForBuyAsset(e, maxGhoAmount3);

// 	assert require_uint256(bought1 + bought2) >= bought3 => 
// 		require_uint256(paid1 + paid2) >= paid3;
// }

// @title getGhoAmountForSellAsset is additive. Making two small transactions x1, x2, is less favourable for the user than making (x1+x2)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/4eb683e5162640f599f80f5afb59fdb9?anonymousKey=da8944168ada87b4d556dccb77f240a62f481ece
// rule getGhoAmountForSellAsset_aditivity()
// {
// 	env e;
// 	feeLimits(e);
// 	priceLimits(e);

// 	uint256 amount1;
// 	uint suggestedAsset1;
// 	uint totalGained1;
// 	suggestedAsset1, totalGained1, _, _ = getGhoAmountForSellAsset(e, amount1);

// 	uint256 amount2;
// 	uint suggestedAsset2;
// 	uint totalGained2;
// 	suggestedAsset2, totalGained2, _, _ = getGhoAmountForSellAsset(e, amount2);
// 	require require_uint256(suggestedAsset1 + suggestedAsset2) > 0;

// 	uint256 amount3;
// 	uint suggestedAsset3;
// 	uint totalGained3;
// 	suggestedAsset3, totalGained3, _, _ = getGhoAmountForSellAsset(e, amount3);

// 	assert require_uint256(suggestedAsset1 + suggestedAsset2) <= suggestedAsset3 => 
// 		require_uint256(totalGained1 + totalGained2) <= totalGained3;
// }

// @title getAssetAmountForSellAsset is additive. Making two small transactions x1, x2, is less favourable for the user than making (x1+x2)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/8ee8e360d1c64478961c9ba80565c5cd?anonymousKey=4ed0353a58d71ae7f863097cbb25884ace721234
// rule getAssetAmountForSellAsset_aditivity()
// {
// 	env e;
// 	feeLimits(e);
// 	priceLimits(e);

//     uint256 amount1;
// 	uint suggestedAsset1;
// 	uint totalGained1;
// 	suggestedAsset1, totalGained1, _, _ = getAssetAmountForSellAsset(e, amount1);

// 	uint256 amount2;
// 	uint suggestedAsset2;
// 	uint totalGained2;
// 	suggestedAsset2, totalGained2, _, _ = getAssetAmountForSellAsset(e, amount2);
// 	require require_uint256(suggestedAsset1 + suggestedAsset2) > 0;

// 	uint256 amount3;
// 	uint suggestedAsset3;
// 	uint totalGained3;
// 	suggestedAsset3, totalGained3, _, _ = getAssetAmountForSellAsset(e, amount3);

// 	assert require_uint256(suggestedAsset1 + suggestedAsset2) <= suggestedAsset3 => 
// 		require_uint256(totalGained1 + totalGained2) <= totalGained3;
// }





