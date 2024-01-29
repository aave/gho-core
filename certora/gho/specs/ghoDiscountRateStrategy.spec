methods {
    function calculateDiscountRate(uint256, uint256) external returns (uint256) envfree;
    function MIN_DISCOUNT_TOKEN_BALANCE() external returns (uint256) envfree;
    function MIN_DEBT_TOKEN_BALANCE() external returns (uint256) envfree;
    function DISCOUNT_RATE() external returns (uint256) envfree;
    function GHO_DISCOUNTED_PER_DISCOUNT_TOKEN() external returns (uint256) envfree;
    function wadMul(uint256, uint256) external returns (uint256) envfree;
}

function wad() returns uint256 {
    return 10^18;
}
function wadMulCVL(uint256 a, uint256 b) returns mathint {
	return ((a * b + (wad() / 2)) / wad());
}

/**
* @title sanity rule, checks that all contract functions are executables, should fail.
**/
// rule sanity(method f) {
//     env e;
//     calldataarg args;
//     f(e, args);
//     assert(false);
// }

/**
* @title prove the equivalence between wadMulCVL and the solidity implementation of wadMul
**/
rule equivalenceOfWadMulCVLAndWadMulSol() {
    uint256 x;
    uint256 y;
    mathint wadMulCvl = wadMulCVL(x, y);
    uint256 wadMulSol = wadMul(x, y);
    assert(wadMulCvl == to_mathint(wadMulSol));
}

/**
* @title proves that if the account's entitled balance for discount is above its current debt balance than the discount rate is the maximal rate
**/
rule maxDiscountForHighDiscountTokenBalance() {
    uint256 debtBalance;
    uint256 discountTokenBalance;
    mathint discountedBalance = wadMulCVL(GHO_DISCOUNTED_PER_DISCOUNT_TOKEN(), discountTokenBalance);
    uint256 rate = calculateDiscountRate(debtBalance, discountTokenBalance);
    // forcing the debt/discount token balance to be above the minimal value allowed in order to get a non-zero rate
    require(debtBalance >= MIN_DEBT_TOKEN_BALANCE() && discountTokenBalance >= MIN_DISCOUNT_TOKEN_BALANCE());
    assert(discountedBalance >= to_mathint(debtBalance) => rate == DISCOUNT_RATE());
}

/**
* @title proves that the discount balance below the threashold leads to zero discount rate
**/
rule zeroDiscountForSmallDiscountTokenBalance() {
    uint256 debtBalance;
    uint256 discountTokenBalance;
    uint256 rate = calculateDiscountRate(debtBalance, discountTokenBalance);
    mathint discountedBalance = wadMulCVL(GHO_DISCOUNTED_PER_DISCOUNT_TOKEN(), discountTokenBalance);
    // there are three conditions that can result in a zero rate:
    // 1,2 - if the debt balance or the discount token balance are below some threashold.
    // 3 - if debtBalance is much larger than discountBalance (since the return value is the max rate multiplied
    //     by the ratio between debtBalance and discountBalance)
    assert(
        (debtBalance < MIN_DEBT_TOKEN_BALANCE() || 
        discountTokenBalance < MIN_DISCOUNT_TOKEN_BALANCE() || 
        discountedBalance*DISCOUNT_RATE() < to_mathint(debtBalance)) 
        <=> rate == 0);
}

/**
* @title if the discounted blance is above the threashold and below the current debt, the discount rate will be according to the ratio
* between the debt balance and the discounted balance
**/
rule partialDiscountForIntermediateTokenBalance() {
    uint256 debtBalance;
    uint256 discountTokenBalance;
    mathint discountedBalance = wadMulCVL(GHO_DISCOUNTED_PER_DISCOUNT_TOKEN(), discountTokenBalance);
    uint256 rate = calculateDiscountRate(debtBalance, discountTokenBalance);
    require(debtBalance >= MIN_DEBT_TOKEN_BALANCE() && discountTokenBalance >= MIN_DISCOUNT_TOKEN_BALANCE());
    assert(discountedBalance < to_mathint(debtBalance) => (to_mathint(rate) == (discountedBalance * DISCOUNT_RATE()) / debtBalance));
}

/**
* @title proves that the discount rate is caped by the maximal discount rate value
**/
rule limitOnDiscountRate() {
    uint256 debtBalance;
    uint256 discountTokenBalance;
    uint256 discountRate = calculateDiscountRate(debtBalance, discountTokenBalance);
    assert(discountRate <= DISCOUNT_RATE());
}


rule sanity {
  env e;
  calldataarg arg;
  method f;
  f(e, arg);
  satisfy true;
}
