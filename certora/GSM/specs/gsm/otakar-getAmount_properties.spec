import "../GsmMethods/methods_base.spec";
import "../GsmMethods/aave_price_fee_limits.spec";
import "../GsmMethods/methods_divint_summary.spec";


// @title The amount of asset returned is less than or equal to given param
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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

// @title The amount of gho returned is greater than or equal to given param
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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

// @title The amount of gho returned is greater than or equal to given param within bound of 1
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
rule getAssetAmountForBuyAsset_optimality()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint maxGhoToGive;
	uint suggestedAssetToBuy;
	suggestedAssetToBuy, _, _, _ = getAssetAmountForBuyAsset(e, maxGhoToGive);
	uint suggestedGhoToPay;
	_, suggestedGhoToPay, _, _ = getGhoAmountForBuyAsset(e, suggestedAssetToBuy);

	uint maxAssetCouldBuy;
	uint couldBuyAsset;
	uint couldPayGho;
	couldBuyAsset, couldPayGho, _, _ = getGhoAmountForBuyAsset(e, maxAssetCouldBuy);
	
	require couldPayGho <= maxGhoToGive;
	require couldPayGho >= suggestedGhoToPay;

	assert couldBuyAsset <= suggestedAssetToBuy;
}

// @title getGhoAmountForBuyAsset returns value that is as close as possible to user specified amount.
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
rule getAssetAmountForSellAsset_optimality()
{
	// proves that if user wants to receive at least X gho
	// and the system tells them to sell Y assets, 
	// then there is no amount W < Y that would already provide X gho.

	env e;
	feeLimits(e);
	priceLimits(e);

	uint wantsToReceive; //6
	uint suggestedAssetToSell;
	suggestedAssetToSell, _, _, _ = getAssetAmountForSellAsset(e, wantsToReceive); //2

	uint reallySold; //1
	uint reallyReceived;
	_, reallyReceived, _, _ = getGhoAmountForSellAsset(e, reallySold);
	
	require reallyReceived >= wantsToReceive;

	assert suggestedAssetToSell <= reallySold;
}

// @title The first two return values of getAssetAmountForBuyAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
rule getAssetAmountForBuyAsset_funcProperty_LR()
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

	require suggestedAssetToBuy1 == suggestedAssetToBuy2;
	assert totalPay1 == totalPay2;
}

// @title The first two return values of getAssetAmountForBuyAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/ca6d0e522361477cb6a74761b7ff087f?anonymousKey=c514848ed2a5ef6b6762574f2f9f0a30a3f5f57f
rule getAssetAmountForBuyAsset_funcProperty_RL()
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

	require totalPay1 == totalPay2;
	assert suggestedAssetToBuy1 == suggestedAssetToBuy2;
}

// @title The first two return values of getGhoAmountForBuyAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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

// @title The first two return values of getGhoAmountForBuyAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
rule getGhoAmountForBuyAsset_funcProperty_LR()
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

	require suggestedAssetToBuy1 == suggestedAssetToBuy2;
	assert totalPay1 == totalPay2;
}

// @title The first two return values of getGhoAmountForBuyAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
rule getGhoAmountForBuyAsset_funcProperty_RL()
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

	require totalPay1 == totalPay2;
	assert suggestedAssetToBuy1 == suggestedAssetToBuy2;
}

// @title The first two return values of getAssetAmountForSellAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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

// @title The first two return values of getAssetAmountForSellAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
rule getAssetAmountForSellAsset_funcProperty_LR()
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

	require suggestedAsset1 == suggestedAsset2;
	assert totalPay1 == totalPay2;
}

// @title The first two return values of getAssetAmountForSellAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
rule getAssetAmountForSellAsset_funcProperty_RL()
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

	require totalPay1 == totalPay2;
	assert suggestedAsset1 == suggestedAsset2;
}

// @title The first two return values of getGhoAmountForSellAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
rule getGhoAmountForSellAsset_funcProperty_LR()
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

	require suggestedAsset1 == suggestedAsset2;
	assert totalPay1 == totalPay2;
}

// @title The first two return values of getGhoAmountForSellAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
rule getGhoAmountForSellAsset_funcProperty_RL()
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

	require totalPay1 == totalPay2;
	assert suggestedAsset1 == suggestedAsset2;
}

// @title The first two return values of getGhoAmountForSellAsset are univalent (https://en.wikipedia.org/wiki/Binary_relation#Specific_types_of_binary_relations)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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

// @title getGhoAmountForBuyAsset is additive. Making two small transactions x1, x2, is less favourable for the user than making (x1+x2)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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

	require require_uint256(bought1 + bought2) >= bought3;
	assert require_uint256(paid1 + paid2) >= paid3;
}

// @title getAssetAmountForBuyAsset is additive. Making two small transactions x1, x2, is less favourable for the user than making (x1+x2)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
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

	require require_uint256(bought1 + bought2) == bought3;

	assert require_uint256(paid1 + paid2) >= paid3;
}

// @title getGhoAmountForSellAsset is additive. Making two small transactions x1, x2, is less favourable for the user than making (x1+x2)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
rule getGhoAmountForSellAsset_aditivity()
{
	env e;
	feeLimits(e);
	priceLimits(e);

	uint256 amount1;
	uint suggestedAsset1;
	uint totalGained1;
	suggestedAsset1, totalGained1, _, _ = getGhoAmountForSellAsset(e, amount1);

	uint256 amount2;
	uint suggestedAsset2;
	uint totalGained2;
	suggestedAsset2, totalGained2, _, _ = getGhoAmountForSellAsset(e, amount2);
	require require_uint256(suggestedAsset1 + suggestedAsset2) > 0;

	uint256 amount3;
	uint suggestedAsset3;
	uint totalGained3;
	suggestedAsset3, totalGained3, _, _ = getGhoAmountForSellAsset(e, amount3);

	require require_uint256(suggestedAsset1 + suggestedAsset2) <= suggestedAsset3;
	assert require_uint256(totalGained1 + totalGained2) <= totalGained3;
}

// @title getAssetAmountForSellAsset is additive. Making two small transactions x1, x2, is less favourable for the user than making (x1+x2)
// STATUS: PASS
// https://prover.certora.com/output/11775/414e746701a349e2bbacc696e0fb5446?anonymousKey=1ee0516abf9c3e609824cfac3893e3a34033f15e
rule getAssetAmountForSellAsset_aditivity()
{
	env e;
	feeLimits(e);
	priceLimits(e);

    uint256 amount1;
	uint suggestedAsset1;
	uint totalGained1;
	suggestedAsset1, totalGained1, _, _ = getAssetAmountForSellAsset(e, amount1);

	uint256 amount2;
	uint suggestedAsset2;
	uint totalGained2;
	suggestedAsset2, totalGained2, _, _ = getAssetAmountForSellAsset(e, amount2);
	require require_uint256(suggestedAsset1 + suggestedAsset2) > 0;

	uint256 amount3;
	uint suggestedAsset3;
	uint totalGained3;
	suggestedAsset3, totalGained3, _, _ = getAssetAmountForSellAsset(e, amount3);

	require require_uint256(suggestedAsset1 + suggestedAsset2) <= suggestedAsset3;
	assert require_uint256(totalGained1 + totalGained2) <= totalGained3;
}





