import "set.spec";

using GhoToken as GHOTOKEN;
methods{
	function mint(address,uint256) external;
	function burn(uint256) external;
	function removeFacilitator(address) external;
	function setFacilitatorBucketCapacity(address,uint128) external;
	
	function totalSupply() external returns uint256 envfree;
	function balanceOf(address) external returns (uint256) envfree;
	function getFacilitatorBucketLevel(address) external returns uint256 envfree;
	function getFacilitatorBucketCapacity(address) external returns uint256 envfree;
	
	function is_in_facilitator_mapping(address) external returns bool envfree;
	function is_in_facilitator_set_map(address) external returns bool envfree;
	function is_in_facilitator_set_array(address) external returns bool envfree;
	//function to_bytes32(address) external returns (bytes32) envfree;
}

ghost sumAllBalance() returns mathint {
    init_state axiom sumAllBalance() == 0;
}

hook Sstore balanceOf[KEY address a] uint256 balance (uint256 old_balance) STORAGE {
  havoc sumAllBalance assuming sumAllBalance@new() == sumAllBalance@old() + balance - old_balance;
}

hook Sload uint256 balance balanceOf[KEY address a] STORAGE {
    require to_mathint(balance) <= sumAllBalance();
} 


ghost sumAllLevel() returns mathint {
    init_state axiom sumAllLevel() == 0;
}


/**
 * @title Sum of facilitators' bucket levels 
 * @dev Sample stores to  _facilitators[*].bucketLevel
 * @dev first field of struct Facilitator is uint128 so offset 16 is used  
 **/
hook Sstore _facilitators[KEY address a].(offset 16) uint128 level (uint128 old_level)   STORAGE {
  havoc sumAllLevel assuming sumAllLevel@new() == sumAllLevel@old() + level - old_level;
}

//
// Invariants
//

// INV #1
/**
* @title Length of AddressSet is less than 2^160
* @dev the assumption is safe because there are at most 2^160 unique addresses
* @dev the proof of the assumption is vacuous because length > loop_iter
*/
invariant length_leq_max_uint160()
	getFacilitatorsListLen() < TWO_TO_160();

// INV #2
/**
* @title User's balance not greater than totalSupply()
*/
invariant inv_balanceOf_leq_totalSupply(address user)
	balanceOf(user) <= totalSupply()
	{
		preserved {
			requireInvariant sumAllBalance_eq_totalSupply();
		}
	}

// INV #3
/**
 * @title Sum of bucket levels is equals to GhoToken::totalSupply()
 **/
invariant total_supply_eq_sumAllLevel()
		sumAllLevel() == to_mathint(totalSupply()) 
	{
	  preserved burn(uint256 amount) with (env e){
			requireInvariant inv_balanceOf_leq_totalSupply(e.msg.sender);
		}
	}


// INV #4
/**
 * @title Sum of balances is GhoToke::totalSupply()
 * @dev EITHER requireInvariant sumAllLevel_eq_sumAllBalance() OR requireInvariant total_supply_eq_sumAllLevel() suffices.
 **/
//todo: replace preserve
invariant sumAllBalance_eq_totalSupply()
	sumAllBalance() == to_mathint(totalSupply())
	{
		preserved {
			requireInvariant sumAllLevel_eq_sumAllBalance();
		}
	}

// INV #5
/**
 * @title The sum of bucket level is equal to the sum of GhoToken balances
 * @dev This invariant can be deduced from sumAllBalance_eq_totalSupply and total_supply_eq_sumAllLevel
 * @dev requireInvariant of EITHER sumAllBalance_eq_totalSupply() OR total_supply_eq_sumAllLevel() suffuces for the proof
 **/
invariant sumAllLevel_eq_sumAllBalance()
	sumAllLevel() == sumAllBalance()
	  	{
			preserved {
			requireInvariant sumAllBalance_eq_totalSupply();
		}
	}



// INV #6
/**
* @title A facilitator with a positive bucket capacity exists in the _facilitators mapping
*/
invariant inv_valid_capacity(address facilitator)
	((getFacilitatorBucketCapacity(facilitator)>0) => is_in_facilitator_mapping(facilitator) );

// INV #7
/**
* @title A facilitator with a positive bucket level exists in the _facilitators mapping
*/
invariant inv_valid_level(address facilitator)
	((getFacilitatorBucketLevel(facilitator)>0) => is_in_facilitator_mapping(facilitator) )
	{
		preserved{
			requireInvariant inv_valid_capacity(facilitator);
		}
	}

// INV #8
/**
* @title AddressSet internal coherency
* @dev A facilitator address exists in AddressSet list (GhoToken._facilitatorsList._values)
* @dev if and only if it exists in AddressSet mapping (GhoToken._facilitatorsList._indexes)
*/
invariant address_in_set_values_iff_in_set_indexes(address facilitator)
	is_in_facilitator_set_array(facilitator) <=> is_in_facilitator_set_map(facilitator)
	{preserved{
		requireInvariant addressSetInvariant();
		requireInvariant length_leq_max_uint160();
		}
	}

// INV #9
/**
* @title GhoToken mapping-AddressSet coherency (1)
* @dev A facilitator address that exists in GhoToken Facilitator mapping (GhoToken._facilitators)
* @dev if and only if it exists in GhoToken  AddressSet (GhoToken._facilitatorsList._indexes)
*/
invariant addr_in_set_iff_in_map(address facilitator)
	is_in_facilitator_mapping(facilitator) <=> is_in_facilitator_set_map(facilitator)
	{preserved{
 		requireInvariant addressSetInvariant();

	}
	}

// INV #10
/**
* @title GhoToken mapping-AddressSet coherency (2)
* @dev A facilitator address exists in GhoToken Facilitator mapping (GhoToken._facilitators)
* @dev iff it exists in GhoToken AddressSet list (GhoToken._facilitatorsList._values)
*/
invariant addr_in_set_list_iff_in_map(address facilitator)
	is_in_facilitator_mapping(facilitator) <=> is_in_facilitator_set_array(facilitator)
	{preserved{
		requireInvariant addressSetInvariant();
		requireInvariant length_leq_max_uint160();
		}
	}



//
// Rules
//

/**
* @title Bucket level <= bucket capacity unless setFacilitatorBucketCapacity() lowered it
*/
rule level_leq_capacity(address facilitator, method f) filtered {f -> !f.isView}{

	env e;
	calldataarg arg;
	requireInvariant inv_valid_capacity(facilitator);
	require getFacilitatorBucketLevel(facilitator) <= getFacilitatorBucketCapacity(facilitator); 
	f(e, arg);
	assert ((f.selector != sig:setFacilitatorBucketCapacity(address,uint128).selector)
		=>	(getFacilitatorBucketLevel(facilitator) <= getFacilitatorBucketCapacity(facilitator)));
		
}

/**
* @notice If Bucket level < bucket capacity then the first invocation of mint() succeeds after burn
* @notice unless setFacilitatorBucketCapacity() lowered bucket capacity or removeFacilitator() was called
*/
rule mint_after_burn(method f) filtered {f -> !f.isView}
{
	env e;
	calldataarg arg;
	uint256 amount_burn;
	uint256 amount_mint;
	address account;
	
	require getFacilitatorBucketLevel(e.msg.sender) <= getFacilitatorBucketCapacity(e.msg.sender);
	require amount_mint > 0;
	requireInvariant addressSetInvariant();

	requireInvariant inv_balanceOf_leq_totalSupply(e.msg.sender);
	requireInvariant inv_valid_capacity(e.msg.sender);

	burn(e, amount_burn);
	f(e, arg);
	mint@withrevert(e, account, amount_mint);
	assert (((amount_mint <= amount_burn)
			&& f.selector != sig:mint(address,uint256).selector
			&& f.selector != sig:setFacilitatorBucketCapacity(address,uint128).selector
			&& f.selector != sig:removeFacilitator(address).selector
			)	=> !lastReverted), "mint failed";
}

/**
* @title Burn after mint succeeds
* @dev BorrowLogic::executeRepa() executes the following code before invocation of handleRepayment()
* @dev safeTransferFrom(msg.sender, reserveCache.aTokenAddress, paybackAmount);
*/
rule burn_after_mint(method f) filtered {f -> !f.isView}
{
	env e;
	uint256 amount;
	address account;

	requireInvariant inv_balanceOf_leq_totalSupply(e.msg.sender);
	require e.msg.value == 0; 
	require amount > 0;

	mint(e, account, amount);
	transferFrom(e, account, e.msg.sender, amount);
	burn@withrevert(e, amount);
	assert !lastReverted, "burn failed";

}

/**
* @title BucketLevel remains unchanged after mint() followed by burn()
*/
rule level_unchanged_after_mint_followed_by_burn()
{
	env e;
	calldataarg arg;
	uint256 amount;
	address account;

	uint256 levelBefore = getFacilitatorBucketLevel(e.msg.sender);
	mint(e, account, amount);
	burn(e, amount);
	uint256 leveAfter = getFacilitatorBucketLevel(e.msg.sender);
	assert levelBefore == leveAfter;

}

rule level_after_mint()
{
	env e;
	calldataarg arg;
	uint256 amount;
	address account;

	uint256 levelBefore = getFacilitatorBucketLevel(e.msg.sender);
	mint(e, account, amount);
	uint256 leveAfter = getFacilitatorBucketLevel(e.msg.sender);
	assert levelBefore + amount == to_mathint(leveAfter);

}

rule level_after_burn()
{
	env e;
	calldataarg arg;
	uint256 amount;

	uint256 levelBefore = getFacilitatorBucketLevel(e.msg.sender);
	burn(e, amount);
	uint256 leveAfter = getFacilitatorBucketLevel(e.msg.sender);
	assert to_mathint(levelBefore) == leveAfter + amount;

}


/**
* @title Facilitator is valid after successful call to setFacilitatorBucketCapacity()
*/
rule facilitator_in_list_after_setFacilitatorBucketCapacity(){

	env e;
	address facilitator;
	uint128 newCapacity;

	requireInvariant addr_in_set_iff_in_map(facilitator);
	requireInvariant addr_in_set_list_iff_in_map(facilitator);

	setFacilitatorBucketCapacity(e, facilitator, newCapacity);
	
	assert is_in_facilitator_set_map(facilitator);
	assert is_in_facilitator_set_array(facilitator);
}

/**
* @title getFacilitatorBucketCapacity() called after setFacilitatorBucketCapacity() retrun the assign bucket capacity
*/
rule getFacilitatorBucketCapacity_after_setFacilitatorBucketCapacity(){

	env e;
	address facilitator;
	uint128 newCapacity;

	setFacilitatorBucketCapacity(e, facilitator, newCapacity);
	assert getFacilitatorBucketCapacity(facilitator) == require_uint256(newCapacity);
}

/**
* @title Facilitator is valid after successful call to addFacilitator()
*/
rule facilitator_in_list_after_addFacilitator(){

	env e;
	address facilitator;
	string label;
	uint128 capacity;

	requireInvariant addr_in_set_iff_in_map(facilitator);
	
	addFacilitator(e,facilitator, label, capacity);
	
	assert is_in_facilitator_set_map(facilitator);
	assert is_in_facilitator_set_array(facilitator);
}

/**
* @title Facilitator is valid after successful call to mint() or burn()
*/
rule facilitator_in_list_after_mint_and_burn(method f){

	env e;
	calldataarg args;
	requireInvariant inv_valid_capacity(e.msg.sender);
	requireInvariant inv_valid_level(e.msg.sender);
	requireInvariant addr_in_set_iff_in_map(e.msg.sender);
	requireInvariant addr_in_set_list_iff_in_map(e.msg.sender);

	f(e,args);
	assert (((f.selector == sig:mint(address,uint256).selector) || (f.selector == sig:burn(uint256).selector)) => is_in_facilitator_mapping(e.msg.sender));
	assert (((f.selector == sig:mint(address,uint256).selector) || (f.selector == sig:burn(uint256).selector)) => is_in_facilitator_set_map(e.msg.sender));
	assert (((f.selector == sig:mint(address,uint256).selector) || (f.selector == sig:burn(uint256).selector)) => is_in_facilitator_set_array(e.msg.sender));
}

/**
* @title Facilitator address is removed from list  (GhoToken._facilitatorsList._values) after calling removeFacilitator()
**/
rule address_not_in_list_after_removeFacilitator(address facilitator){
	env e;
	requireInvariant addressSetInvariant();
	requireInvariant length_leq_max_uint160();
	requireInvariant addr_in_set_iff_in_map(facilitator);
	removeFacilitator(e, facilitator);
	assert !is_in_facilitator_set_array(facilitator);
}


/**
* @title Proves that mint(a + b) == mint(a) + mint(b)
**/
// rule mintIsAdditive() {
// 	address user1;
// 	address user2;
// 	require (user1 != user2);
// 	uint256 initBalance1 = balanceOf(user1);
// 	uint256 initBalance2 = balanceOf(user2);
// 	require (sumAllBalance() >= initBalance1 + initBalance2);
// 	requireInvariant sumAllBalance_eq_totalSupply();

// 	uint256 amount1;
// 	uint256 amount2;
// 	uint256 sum = amount1 + amount2;
// 	env e;
// 	mint(e, user1, amount1);
// 	mint(e, user1, amount2);
// 	mint(e, user2, sum);

// 	uint256 finBalance1 = balanceOf(user1);
// 	uint256 finBalance2 = balanceOf(user2);
// 	mathint diff1 = finBalance1 - initBalance1;
// 	mathint diff2 = finBalance2 - initBalance2;

// 	assert diff1 == diff2;
// }

rule balance_after_mint() {
	
	env e;
	address user;
	uint256 initBalance = balanceOf(user);
	uint256 initSupply = totalSupply();
	uint256 amount;
	requireInvariant sumAllBalance_eq_totalSupply();
	mint(e, user, amount);
	uint256 finBalance = balanceOf(user);
	uint256 finSupply = totalSupply();
	assert initBalance + amount == to_mathint(finBalance);
	assert initSupply + amount == to_mathint(finSupply);
}

rule balance_after_burn() {
	
	env e;
	requireInvariant inv_balanceOf_leq_totalSupply(e.msg.sender);
	uint256 initBalance = balanceOf(e.msg.sender);
	uint256 initSupply = totalSupply();
	uint256 amount;
	burn(e, amount);
	uint256 finBalance = balanceOf(e.msg.sender);
	uint256 finSupply = totalSupply();
	assert to_mathint(initBalance) == finBalance + amount;
	assert to_mathint(initSupply) == finSupply + amount ;
}

/**
* @title Proves that burn(a + b) == burn(a) + burn(b)
**/
// rule burnIsAdditive() {
// 	env e;
// 	uint256 senderBalance = balanceOf(e.msg.sender);
// 	require(senderBalance <= sumAllBalance());
// 	requireInvariant sumAllBalance_eq_totalSupply();

// 	uint256 amount1;
// 	uint256 amount2;
// 	uint256 sum = amount1 + amount2;

// 	uint256 initSupply = totalSupply();
// 	burn(e, amount1);
// 	burn(e, amount2);
// 	uint256 midSupply = totalSupply();
// 	burn(e, sum);
// 	uint256 finSupply = totalSupply();
// 	mathint diff1 = finSupply - midSupply;
// 	mathint diff2 = midSupply - initSupply;

// 	assert diff1 == diff2;
// }

/**
* @title Proves that you can't mint more than the facilitator's remaining capacity
**/
rule mintLimitedByFacilitatorRemainingCapacity() {
	env e;
	require(getFacilitatorBucketCapacity(e.msg.sender) > getFacilitatorBucketLevel(e.msg.sender));

	uint256 amount;
	require(to_mathint(amount) > (getFacilitatorBucketCapacity(e.msg.sender) - getFacilitatorBucketLevel(e.msg.sender)));
	address user;
	mint@withrevert(e, user, amount);
	assert lastReverted;
}

/**
* @title Proves that you can't burn more than the facilitator's current level
**/
rule burnLimitedByFacilitatorLevel() {
	env e;
	require(getFacilitatorBucketCapacity(e.msg.sender) > getFacilitatorBucketLevel(e.msg.sender));

	uint256 amount;
	require(amount > getFacilitatorBucketLevel(e.msg.sender));
	burn@withrevert(e, amount);
	assert lastReverted;
}



//
// Additional rules
//

//keep these rules for development team - resolve timeouts, fix bugs


//pass with workaround for https://certora.atlassian.net/browse/CERT-1060
invariant ARRAY_IS_INVERSE_OF_MAP_Invariant()
    ARRAY_IS_INVERSE_OF_MAP()
	{
		preserved{
			require ADDRESS_SET_INVARIANT();
			requireInvariant length_leq_max_uint160();
		}
	}

//pass with workaround for https://certora.atlassian.net/browse/CERT-1060
invariant addressSetInvariant()
    ADDRESS_SET_INVARIANT()
	{
		preserved{
			requireInvariant length_leq_max_uint160();
		}
	}

//Debugging  https://certora.atlassian.net/browse/CERT-1060 
//timeout with staging
//fail with yoav/grounding
//pass with  axiom mirrorArrayLen < TWO_TO_160() - 1 
rule address_not_in_list_after_removeFacilitator_CASE_SPLIT_zero_address(address facilitator){
	env e;
	requireInvariant addressSetInvariant();
	require facilitator == 0;
	
	requireInvariant addr_in_set_iff_in_map(facilitator);
	removeFacilitator(e, facilitator);
	assert !is_in_facilitator_set_array(facilitator);
}






