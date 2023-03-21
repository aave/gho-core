methods {
	// summarization for elimination the raymul operation in balance of and totalSupply.
	//getReserveNormalizedVariableDebt(address asset) returns (uint256) => indexAtTimestamp(e.block.timestamp)
	//setAdditionalData(address user, uint128 data) envfree
    handleAction(address, uint256, uint256) => NONDET
	scaledBalanceOfToBalanceOf(uint256) returns (uint256) envfree
    //balanceOf(address) returns (uint256) envfree
}

definition ray() returns uint = 1000000000000000000000000000; // 10^27
definition wad() returns uint = 1000000000000000000; // 10^18
definition bound(uint256 index) returns uint = ((index / ray()) + 1 ) / 2;
// summerization for scaledBlanaceOf -> regularBalanceOf + 0.5 (canceling the rayMul)
// ghost gRNVB() returns uint256 {
// 	axiom gRNVB() == 7 * ray();
// }
/*
Due to rayDiv and RayMul Rounding (+ 0.5) - blance could increase by (gRNI() / Ray() + 1) / 2.
*/
definition bounded_error_eq(uint x, uint y, uint scale, uint256 index) returns bool = x <= y + (bound(index) * scale) && x + (bound(index) * scale) >= y;



definition disAllowedFunctions(method f) returns bool = 
            f.selector == transfer(address, uint256).selector ||
            f.selector == allowance(address, address).selector ||
            f.selector == approve(address, uint256).selector ||
            f.selector == transferFrom(address, address, uint256).selector ||
            f.selector == increaseAllowance(address, uint256).selector ||
            f.selector == decreaseAllowance(address, uint256).selector;


ghost sumAllBalance() returns uint256 {
    init_state axiom sumAllBalance() == 0;
}

hook Sstore _userState[KEY address a].balance uint128 balance (uint128 old_balance) STORAGE {
  havoc sumAllBalance assuming sumAllBalance@new() == sumAllBalance@old() + balance - old_balance;
}

invariant totalSupplyEqualsSumAllBalance(env e)
    totalSupply() == scaledBalanceOfToBalanceOf(sumAllBalance())
    filtered { f -> !f.isView && !disAllowedFunctions(f) }
    {
        preserved mint(address user, address onBehalfOf, uint256 amount, uint256 index) with (env e2) {
            require index == indexAtTimestamp(e.block.timestamp);
        }
        preserved burn(address from, uint256 amount, uint256 index) with (env e3) {
            require index == indexAtTimestamp(e.block.timestamp);
        }
    }


// Only the pool with burn or mint operation can change the total supply. (assuming the getReserveNormalizedVariableDebt is not changed)
rule whoChangeTotalSupply(method f) 
    filtered { f ->  !f.isView && !disAllowedFunctions(f) } 
{
    env e;
    uint256 oldTotalSupply = totalSupply();
    calldataarg args;
    f(e, args);
    uint256 newTotalSupply = totalSupply();
    assert oldTotalSupply != newTotalSupply => 
           (e.msg.sender == POOL(e) && 
           (f.selector == burn(address, uint256, uint256).selector || 
            f.selector == mint(address, address, uint256, uint256).selector));
}

/*
Each operation of Variable Debt Token can change at most one user's balance.
*/
rule balanceOfChange(address a, address b, method f) 
    filtered { f ->  !f.isView && !disAllowedFunctions(f) }
{
	env e;
	require a != b;
	uint256 balanceABefore = balanceOf(e, a);
	uint256 balanceBBefore = balanceOf(e, b);
	 
	calldataarg arg;
    f(e, arg); 

	uint256 balanceAAfter = balanceOf(e, a);
	uint256 balanceBAfter = balanceOf(e, b);
	
	assert (balanceABefore == balanceAAfter || balanceBBefore == balanceBAfter);
}

/*
Each operation of Variable Debt Token can change at most two user's balance.
*/
rule balanceOfAtMost3Change(address a, address b, address c, method f) 
    filtered { f ->  !f.isView && !disAllowedFunctions(f) }
{
	env e;
	require a != b;
	require a != c;
	require b != c;
	uint256 balanceABefore = balanceOf(e, a);
	uint256 balanceBBefore = balanceOf(e, b);
	uint256 balanceCBefore = balanceOf(e, c);
	 
	calldataarg arg;
    f(e, arg); 

	uint256 balanceAAfter = balanceOf(e, a);
	uint256 balanceBAfter = balanceOf(e, b);
	uint256 balanceCAfter = balanceOf(e, c);
	
	assert !(balanceABefore != balanceAAfter && balanceBBefore != balanceBAfter && balanceCBefore != balanceCAfter);
}


// only delegationWithSig operation can change the nonce.
rule nonceChangePermits(method f) 
    filtered { f ->  !f.isView && !disAllowedFunctions(f) } 
{
    env e;
    address user;
    uint256 oldNonce = nonces(e, user);
    calldataarg args;
    f(e, args);
    uint256 newNonce = nonces(e, user);
    assert oldNonce != newNonce => f.selector == delegationWithSig(address, address, uint256, uint256, uint8, bytes32, bytes32).selector;
}

// minting and then buring Variable Debt Token should have no effect on the users balance
rule inverseMintBurn(address a, address delegatedUser, uint256 amount, uint256 index) {
	env e;
	uint256 balancebefore = balanceOf(e, a);
	requireInvariant discountCantExceed100Percent(a);
	mint(e, delegatedUser, a, amount, index);
	burn(e, a, amount, index);
	uint256 balanceAfter = balanceOf(e, a);
	assert balancebefore == balanceAfter, "burn is not the inverse of mint";
}

rule integrityDelegationWithSig(address delegator, address delegatee, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) {
    env e;
    uint256 oldNonce = nonces(e, delegator);
    delegationWithSig(e, delegator, delegatee, value, deadline, v, r, s);
    assert nonces(e, delegator) == oldNonce + 1 && borrowAllowance(e, delegator, delegatee) == value;
}

/**
Burning user u amount of amount tokens, decreases his balanceOf the user by amount. 
(balance is decreased by amount and not scaled amount because of the summarization to one ray)
*/
rule integrityOfBurn(address u, uint256 amount) {
	env e;
	uint256 index = indexAtTimestamp(e.block.timestamp);
	uint256 balanceBeforeUser = balanceOf(e, u);
	uint256 totalSupplyBefore = totalSupply(); 

	burn(e, u, amount, index);
	
	uint256 balanceAfterUser = balanceOf(e, u);
	uint256 totalSupplyAfter = totalSupply();

    assert bounded_error_eq(totalSupplyAfter, totalSupplyBefore - amount, 1, index), "total supply integrity"; // total supply reduced
    assert bounded_error_eq(balanceAfterUser, balanceBeforeUser - amount, 1, index), "integrity break";  // user burns ATokens to recieve underlying
}

rule integrityOfBurn_exact_suply_should_fail(address u, uint256 amount) {
	env e;
	uint256 index = indexAtTimestamp(e.block.timestamp);
	uint256 balanceBeforeUser = balanceOf(e, u);
	uint256 totalSupplyBefore = totalSupply(); 

	burn(e, u, amount, index);
	
	uint256 balanceAfterUser = balanceOf(e, u);
	uint256 totalSupplyAfter = totalSupply();

    assert totalSupplyAfter == totalSupplyBefore - amount, "total supply integrity"; // total supply reduced
}

rule integrityOfBurn_exact_balance_should_fail(address u, uint256 amount) {
	env e;
	uint256 index = indexAtTimestamp(e.block.timestamp);
	uint256 balanceBeforeUser = balanceOf(e, u);
	uint256 totalSupplyBefore = totalSupply(); 

	burn(e, u, amount, index);
	
	uint256 balanceAfterUser = balanceOf(e, u);
	uint256 totalSupplyAfter = totalSupply();

    assert totalSupplyAfter == totalSupplyBefore - amount, "total supply integrity"; // total supply reduced
}

/*
Burn is additive, can performed either all at once or gradually
burn(from,to,x,index); burn(from,to,y,index) ~ burn(from,to,x+y,index) at the same initial state
*/
rule additiveBurn(address user1, address user2, uint256 x, uint256 y) {
	env e;
	uint256 index = indexAtTimestamp(e.block.timestamp);
    require (user1 != user2  && balanceOf(e, user1) == balanceOf(e, user2));
	require user1 != currentContract && user2 != currentContract;

    burn(e, user1, x, index);
	burn(e, user1, y, index);
	uint256 balanceScenario1 = balanceOf(e, user1);

	burn(e, user2, x+y, index);
	uint256 balanceScenario2 = balanceOf(e, user2);

    assert bounded_error_eq(balanceScenario1, balanceScenario2, 3, index), "burn is not additive";
	// assert balanceScenario1 == balanceScenario2, "burn is not additive";
}

// using too tight bound
rule additiveBurn_should_fail(address user1, address user2, uint256 x, uint256 y) {
	env e;
	uint256 index = indexAtTimestamp(e.block.timestamp);
    require (user1 != user2  && balanceOf(e, user1) == balanceOf(e, user2));
	require user1 != currentContract && user2 != currentContract;

    burn(e, user1, x, index);
	burn(e, user1, y, index);
	uint256 balanceScenario1 = balanceOf(e, user1);

	burn(e, user2, x+y, index);
	uint256 balanceScenario2 = balanceOf(e, user2);

    assert bounded_error_eq(balanceScenario1, balanceScenario2, 2, index), "burn is not additive";
	//assert balanceScenario1 == balanceScenario2, "burn is not additive";
}

/*
Mint is additive, can performed either all at once or gradually
mint(from,to,x,index); mint(from,to,y,index) ~ mint(from,to,x+y,index) at the same initial state
*/
rule additiveMint(address user1, address user2, address user3, uint256 x, uint256 y) {
	env e;
	uint256 index = indexAtTimestamp(e.block.timestamp);
    require (user1 != user2  && balanceOf(e, user1) == balanceOf(e, user2));

    mint(e, user3, user1, x, index);
	mint(e, user3, user1, y, index);
	uint256 balanceScenario1 = balanceOf(e, user1);

	mint(e, user3, user2, x+y, index);
	uint256 balanceScenario2 = balanceOf(e, user2);

    assert bounded_error_eq(balanceScenario1, balanceScenario2, 3, index), "burn is not additive";
	// assert balanceScenario1 == balanceScenario2, "burn is not additive";
}

//using exact comparison
rule additiveMint_excact_should_fail(address user1, address user2, address user3, uint256 x, uint256 y) {
	env e;
	uint256 index = indexAtTimestamp(e.block.timestamp);
    require (user1 != user2  && balanceOf(e, user1) == balanceOf(e, user2));

    mint(e, user3, user1, x, index);
	mint(e, user3, user1, y, index);
	uint256 balanceScenario1 = balanceOf(e, user1);

	mint(e, user3, user2, x+y, index);
	uint256 balanceScenario2 = balanceOf(e, user2);

    //assert bounded_error_eq(balanceScenario1, balanceScenario2, 3, index), "burn is not additive";
	assert balanceScenario1 == balanceScenario2, "burn is not additive";
}

/**
Mint to user u amount of x tokens, increases his balanceOf the user by x. 
(balance is increased by x and not scaled x because of the summarization to one ray)
*/
rule integrityMint(address a, uint256 x) {
	env e;
	address delegatedUser;
	uint256 index = indexAtTimestamp(e.block.timestamp);
	uint256 underlyingBalanceBefore = balanceOf(e, a);
	uint256 atokenBlanceBefore = scaledBalanceOf(a);
	uint256 totalATokenSupplyBefore = scaledTotalSupply(e);
	mint(e, delegatedUser, a, x, index);
	
	uint256 underlyingBalanceAfter = balanceOf(e, a);
	uint256 atokenBlanceAfter = scaledBalanceOf(a);
	uint256 totalATokenSupplyAfter = scaledTotalSupply(e);

	assert atokenBlanceAfter - atokenBlanceBefore == totalATokenSupplyAfter - totalATokenSupplyBefore;
	assert totalATokenSupplyAfter > totalATokenSupplyBefore;
    assert bounded_error_eq(underlyingBalanceAfter, underlyingBalanceBefore+x, 1, index);
    // assert balanceAfter == balancebefore+x;
}

//split rule to three - checking underlying alone
rule integrityMint_underlying(address a, uint256 x) {
	env e;
	address delegatedUser;
	uint256 index = indexAtTimestamp(e.block.timestamp);
	uint256 underlyingBalanceBefore = balanceOf(e, a);
	uint256 atokenBlanceBefore = scaledBalanceOf(a);
	uint256 totalATokenSupplyBefore = scaledTotalSupply(e);
	mint(e, delegatedUser, a, x, index);
	
	uint256 underlyingBalanceAfter = balanceOf(e, a);
	uint256 atokenBlanceAfter = scaledBalanceOf(a);
	uint256 totalATokenSupplyAfter = scaledTotalSupply(e);

	//assert atokenBlanceAfter - atokenBlanceBefore == totalATokenSupplyAfter - totalATokenSupplyBefore;
	//assert totalATokenSupplyAfter > totalATokenSupplyBefore;
    assert bounded_error_eq(underlyingBalanceAfter, underlyingBalanceBefore+x, 1, index);
    // assert balanceAfter == balancebefore+x;
}
//checking atoken alone
rule integrityMint_atoken(address a, uint256 x) {
	env e;
	address delegatedUser;
	uint256 index = indexAtTimestamp(e.block.timestamp);
	uint256 underlyingBalanceBefore = balanceOf(e, a);
	uint256 atokenBlanceBefore = scaledBalanceOf(a);
	uint256 totalATokenSupplyBefore = scaledTotalSupply(e);
	mint(e, delegatedUser, a, x, index);
	
	uint256 underlyingBalanceAfter = balanceOf(e, a);
	uint256 atokenBlanceAfter = scaledBalanceOf(a);
	uint256 totalATokenSupplyAfter = scaledTotalSupply(e);

	assert atokenBlanceAfter - atokenBlanceBefore == totalATokenSupplyAfter - totalATokenSupplyBefore;
	//assert totalATokenSupplyAfter > totalATokenSupplyBefore;
    //assert bounded_error_eq(underlyingBalanceAfter, underlyingBalanceBefore+x, 1, index);
    // assert balanceAfter == balancebefore+x;
}


rule integrityMint_exact_should_fail(address a, uint256 x) {
	env e; 
	address delegatedUser;
	uint256 index = indexAtTimestamp(e.block.timestamp);
	uint256 underlyingBalanceBefore = balanceOf(e, a);
	uint256 atokenBlanceBefore = scaledBalanceOf(a);
	uint256 totalATokenSupplyBefore = scaledTotalSupply(e);
	mint(e, delegatedUser, a, x, index);
	
	uint256 underlyingBalanceAfter = balanceOf(e, a);
	uint256 atokenBlanceAfter = scaledBalanceOf(a);
	uint256 totalATokenSupplyAfter = scaledTotalSupply(e);

	assert atokenBlanceAfter - atokenBlanceBefore == totalATokenSupplyAfter - totalATokenSupplyBefore;
	assert totalATokenSupplyAfter > totalATokenSupplyBefore;
    assert underlyingBalanceAfter == underlyingBalanceBefore+x;
    
}

// Buring zero amount of tokens should have no effect.
rule burnZeroDoesntChangeBalance(address u, uint256 index) {
	env e;
	uint256 balanceBefore = balanceOf(e, u);
	invoke burn(e, u, 0, index);
	uint256 balanceAfter = balanceOf(e, u);
	assert balanceBefore == balanceAfter;
}

/*
Burning one user atokens should have no effect on other users that are not involved in the action.
*/
rule burnNoChangeToOther(address user, uint256 amount, uint256 index, address other) {
  
	require other != user;
	
	env e;
	uint256 otherBalanceBefore = balanceOf(e, other);
	
	burn(e, user, amount, index);
	
	uint256 otherBalanceAfter = balanceOf(e, other);

	assert otherBalanceBefore == otherBalanceAfter;
}

/*
Minting ATokens for a user should have no effect on other users that are not involved in the action.
*/
rule mintNoChangeToOther(address user, address onBehalfOf, uint256 amount, uint256 index, address other) {
	require other != user && other != onBehalfOf;

	env e;
	uint256 userBalanceBefore = balanceOf(e, user);
	uint256 otherBalanceBefore = balanceOf(e, other);

	mint(e, user, onBehalfOf, amount, index);

  	uint256 userBalanceAfter = balanceOf(e, user);
	uint256 otherBalanceAfter = balanceOf(e, other);

	if (user != onBehalfOf) {
		assert userBalanceBefore == userBalanceAfter ; 
	}

	assert otherBalanceBefore == otherBalanceAfter ;
}

/*
Ensuring that the defined disallowed functions revert in any case.
*/
rule disallowedFunctionalities(method f)
    filtered { f -> disAllowedFunctions(f) }
{
    env e; calldataarg args;
    f@withrevert(e, args);
    assert lastReverted;
}