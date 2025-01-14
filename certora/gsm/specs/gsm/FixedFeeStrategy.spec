// verifies properties of FixedFeestrategy

import "../GsmMethods/aave_fee_limits.spec";
import "../GsmMethods/methods_divint_summary.spec";

methods {
	function getBuyFeeBP() external returns uint256 envfree;
	function getSellFeeBP() external returns uint256 envfree;
	function getPercMathPercentageFactor() external returns uint256 envfree;
	
    function getBuyFee(uint256) external returns uint256 envfree;
	function getSellFee(uint256) external returns uint256 envfree;

	function getGrossAmountFromTotalBought(uint256) external returns (uint256)envfree;
	function getGrossAmountFromTotalSold(uint256) external returns (uint256)envfree;

}

// @title get{Buy|Sell}Fee(x) <= x
// STATUS: PASS
// https://prover.certora.com/output/11775/2daedeb4c01a4354bc7889ffd9f4ec25?anonymousKey=eee3f23fb4011ab65bf9a0096bc855dcfb58a780
rule feeIsLowerThanGrossAmount()
{
	env e;
	feeLimits(e);
	uint amount;
	uint buyFee = getBuyFee(amount);
	assert buyFee <= amount;

	uint sellFee = getSellFee(amount);
	assert sellFee <= amount;
}

// @title get{Buy|Sell}Fee is monotone. x1 <= x2 -> get{Buy|Sell}Fee(x1) <= get{Buy|Sell}Fee(x2)
// STATUS: PASS
// https://prover.certora.com/output/11775/2daedeb4c01a4354bc7889ffd9f4ec25?anonymousKey=eee3f23fb4011ab65bf9a0096bc855dcfb58a780
rule getFeeIsMonotone()
{
	env e;
	feeLimits(e);
	uint amount1; uint amount2;
	require amount1 < amount2;
	assert getBuyFee(amount1) <= getBuyFee(amount2);
	assert getSellFee(amount1) <= getSellFee(amount2);
}

// @title getGrossAmountFromTotalBought is monotone.
// STATUS: PASS
// https://prover.certora.com/output/11775/2daedeb4c01a4354bc7889ffd9f4ec25?anonymousKey=eee3f23fb4011ab65bf9a0096bc855dcfb58a780
rule getGrossAmountFromTotalBought_isMonotoneInTotalAmount()
{
	env e;
	feeLimits(e);
	uint amount1; uint amount2;
	require amount1 < amount2;
	assert getGrossAmountFromTotalBought(amount1) <= getGrossAmountFromTotalBought(amount2);
}

// @title getGrossAmountFromTotalSold is monotone.
// STATUS: PASS
// https://prover.certora.com/output/11775/2daedeb4c01a4354bc7889ffd9f4ec25?anonymousKey=eee3f23fb4011ab65bf9a0096bc855dcfb58a780
rule getGrossAmountFromTotalSold_isMonotoneInTotalAmount()
{
	env e;
	feeLimits(e);
	uint amount1; uint amount2;
	//require amount1 * getPercMathPercentageFactor() < max_uint256;	//otherwise the result of the function overflows. 
	//require amount2 * getPercMathPercentageFactor() < max_uint256; 

	require amount1 < amount2;
	assert getGrossAmountFromTotalSold(amount1) <= getGrossAmountFromTotalSold(amount2);
}

function differsByAtMostOne(mathint x, mathint y) returns bool
{
	mathint diff = x - y;
	return -1 <= diff && diff <= 1;
}

// @title getGrossAmountFromTotalBought function calculates gross amount correctly
// STATUS: PASS
// https://prover.certora.com/output/11775/2daedeb4c01a4354bc7889ffd9f4ec25?anonymousKey=eee3f23fb4011ab65bf9a0096bc855dcfb58a780
rule byuFeeAndInverse0()
{
	env e;
	feeLimits(e);
	uint amount;
	uint buyFee = getBuyFee(amount);
	mathint sum = amount + buyFee;
	require sum < max_uint256;

	uint amount2 = getGrossAmountFromTotalBought(assert_uint256(sum));

	//assert differsByAtMostOne(amount, amount2);
	assert amount == amount2;
}

// @title getGrossAmountFromTotalBought is inverse to getBuyFee.
// STATUS: PASS
// https://prover.certora.com/output/11775/2daedeb4c01a4354bc7889ffd9f4ec25?anonymousKey=eee3f23fb4011ab65bf9a0096bc855dcfb58a780
rule byuFeeAndInverse1()
{
	env e;
	feeLimits(e);
	uint amount;
	uint buyFee = getBuyFee(amount);
	mathint sum = amount + buyFee;
	require sum < max_uint256;

	uint amount2 = getGrossAmountFromTotalBought(assert_uint256(sum));

	assert differsByAtMostOne(amount, amount2);
	//assert amount == amount2;
}

// @title getGrossAmountFromTotalBought is inverse to getBuyFee.
// STATUS: PASS
// https://prover.certora.com/output/11775/2daedeb4c01a4354bc7889ffd9f4ec25?anonymousKey=eee3f23fb4011ab65bf9a0096bc855dcfb58a780
rule getGrossAmountFromTotalBought_isCorrect()
{
	env e;
	feeLimits(e);
	uint GhoAmount;
	uint grossAmount = getGrossAmountFromTotalBought(GhoAmount);
	uint buyFee = getBuyFee(grossAmount);
	mathint reallySold = grossAmount + buyFee;	
	assert differsByAtMostOne(reallySold, GhoAmount);
}

// @title getGrossAmountFromTotalSold is inverse to getSellFee.
// STATUS: PASS
// https://prover.certora.com/output/11775/2daedeb4c01a4354bc7889ffd9f4ec25?anonymousKey=eee3f23fb4011ab65bf9a0096bc855dcfb58a780
rule getGrossAmountFromTotalSold_isCorrect()
{
	env e;
	feeLimits(e);
	uint ghoToReceive;
	uint grossAmount = getGrossAmountFromTotalSold(ghoToReceive);
	uint sellFee = getSellFee(grossAmount);
	mathint reallyReceived = grossAmount - sellFee;	
	assert assert_uint256(reallyReceived) == ghoToReceive;
}


// @title getSellFee never reverts.
// STATUS: PASS
// https://prover.certora.com/output/40748/1b5b658d0a4b49c3844cff4efd397cf0?anonymousKey=cab52c3a200bf976702ffb1c232760ab249e3e2e
rule GetSellFeeNeverReverts()
{
	env e;
	feeLimits(e);
	uint amount;
	uint sellFee = getSellFee@withrevert(amount);
	assert !lastReverted;
}

// @title getBuyFee never reverts.
// STATUS: PASS
// https://prover.certora.com/output/40748/18c697324f4c4c858a7aaa966f0eed79?anonymousKey=7724c74905fb397687da58d101235307fa1b7109
//
rule GetBuyFeeNeverReverts()
{
	env e;
	feeLimits(e);
	uint amount;
	uint buyFee = getBuyFee@withrevert(amount);
	assert !lastReverted;
}

// // @title No method can change fees.
// // STATUS: PASS
// // https://prover.certora.com/output/11775/2daedeb4c01a4354bc7889ffd9f4ec25?anonymousKey=eee3f23fb4011ab65bf9a0096bc855dcfb58a780
// rule noMethodCanChangeFees(method f)
// {
// 	env e;
// 	calldataarg args;
// 	uint sellFeeBefore = getSellFeeBP();
// 	uint buyFeeBefore = getBuyFeeBP();
// 	f(e,args);
// 	assert getSellFeeBP() == sellFeeBefore;
// 	assert getBuyFeeBP() == buyFeeBefore;
// }
