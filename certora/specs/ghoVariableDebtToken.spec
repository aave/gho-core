//import "erc20.spec"
import "VariableDebtToken.spec";
import "summarizations.spec";


using GhoDiscountRateStrategy as discStrategy;

methods{

	/********************;
	*	WadRayMath.sol	*;
	*********************/
	// function _.rayMul(uint256 x, uint256 y) internal => rayMulSummariztion(x, y) expect(uint256);
	function rayDiv(uint256 x, uint256 y) external returns uint256 envfree;
    function rayMul(uint256 x, uint256 y) external returns uint256 envfree;

  	/***********************************;
    *    PoolAddressesProvider.sol     *;
    ************************************/
	function _.getACLManager() external => CONSTANT;

	/************************;
    *    ACLManager.sol     *;
    *************************/
	function _.isPoolAdmin(address) external => CONSTANT;

	/******************************************************************;
	*	DummyERC20WithTimedBalanceOf.sol (linked to _discountToken)   *;
	*******************************************************************/
	// Internal function in DummyERC20WithTimedBalanceOf which exposes the block's timestamp and called by DummyERC20WithTimedBalanceOf::balanceOf
	function _._balanceOfWithBlockTimestamp(address user, uint256 ts) internal => balanceOfDiscountTokenAtTimestamp(user, ts) expect uint256;

  	/************************************;
    *   DummyPool.sol (linked to POOL)  *;
    *************************************/
	// Internal function in DummyPool which exposes the block's timestamp and called by Pool::getReserveNormalizedVariableDebt
	function _._getReserveNormalizedVariableDebtWithBlockTimestamp(address asset, uint256 timestamp) internal => indexAtTimestamp(timestamp) expect uint256;

	/************************************;
	*	GhoVariableDebtTokenHarness.sol	*;
	*************************************/
	function discStrategy.calculateDiscountRate(uint256, uint256) external returns (uint256) envfree;

	/************************************;
	*	GhoVariableDebtTokenHarness.sol	*;
	*************************************/
	function getUserCurrentIndex(address) external returns (uint256) envfree;
	function getUserDiscountRate(address) external returns (uint256) envfree;
	function getUserAccumulatedDebtInterest(address) external returns (uint256) envfree;
	function getBalanceOfDiscountToken(address) external returns (uint256);
	function getDiscountToken() external returns (address) envfree;

	/********************************;
	*	GhoVariableDebtToken.sol	*;
	*********************************/
	function totalSupply() external returns(uint256) envfree;
	function balanceOf(address) external returns (uint256);
	function mint(address, address, uint256, uint256) external returns (bool, uint256);
	function burn(address ,uint256 ,uint256) external returns (uint256);
	function scaledBalanceOf(address) external returns (uint256) envfree;
	function getBalanceFromInterest(address) external returns (uint256) envfree;
	function rebalanceUserDiscountPercent(address) external;
	function updateDiscountDistribution(address ,address ,uint256 ,uint256 ,uint256) external;

    /********************************;
	*	GhoDiscountRateStrategy.sol	*;
	*********************************/
    function discStrategy.DISCOUNT_RATE() external returns (uint256) envfree;
}

/**
* CVL implementation of rayMul
**/
function rayMulCVL(uint256 a, uint256 b) returns mathint {
	return ((a * b + (ray() / 2)) / ray());
}
function rayDivCVL(uint256 a, uint256 b) returns mathint {
	return ((a * ray() + (b / 2)) / b);
}

function getReserveNormalizedVariableDebt_1ray() returns mathint {
	return ray();
}

function getReserveNormalizedVariableDebt_1or2ray() returns uint256 {
	uint256 index;
	require (index==ray() || to_mathint(index)==2*ray());
	return index;
}
function getReserveNormalizedVariableDebt_7ray() returns uint256 {
	uint256 index;
	require (to_mathint(index)==7*ray());
	return index;
}

//todo: check balanceof after mint (stable index), burn after balanceof

definition MAX_DISCOUNT() returns uint256 = 10000; // equals to 100% discount, in points

ghost mapping(address => mapping (uint256 => uint256)) discount_ghost;
ghost mapping(uint256 => uint256) index_ghost;

/**
* Query index_ghost for the index value at the input timestamp
**/
function indexAtTimestamp(uint256 timestamp) returns uint256 {
    require index_ghost[timestamp] >= ray();
    return index_ghost[timestamp];
    // return 1001684385021630839436707910;//index_ghost[timestamp];
}

/**
* Query discount_ghost for the [user]'s balance of discount token at [timestamp]
**/
function balanceOfDiscountTokenAtTimestamp(address user, uint256 timestamp) returns uint256 {
	return discount_ghost[user][timestamp];
}

/**
* Returns an env instance with [ts] as the block timestamp
**/
function envAtTimestamp(uint256 ts) returns env {
	env e;
	require(e.block.timestamp == ts);
	return e;
}

/**
* @title at any point in time, the user's discount rate isn't larger than 100%
**/
invariant discountCantExceed100Percent(address user)
	getUserDiscountRate(user) <= MAX_DISCOUNT()
	{
		preserved updateDiscountDistribution(address sender,address recipient,uint256 senderDiscountTokenBalance,uint256 recipientDiscountTokenBalance,uint256 amount) with (env e) {
			require(indexAtTimestamp(e.block.timestamp) >= ray());
		}
	}
    
/**
* @title at any point in time, the user's discount rate isn't larger than DISCOUNT_RATE
**/
invariant discountCantExceedDiscountRate(address user)
	getUserDiscountRate(user) <= discStrategy.DISCOUNT_RATE()
	{
		preserved updateDiscountDistribution(address sender,address recipient,uint256 senderDiscountTokenBalance,uint256 recipientDiscountTokenBalance,uint256 amount) with (env e) {
			require(indexAtTimestamp(e.block.timestamp) >= ray());
		}
	}



// mutant 6
// A new discount token is not address zero
rule nonzeroNewDiscountToken{

	env e;
	address newDiscountToken; 
  	updateDiscountToken(e, newDiscountToken);
	assert newDiscountToken != 0;
}

// If a user's index has changed then it is assigned with the current pool index.
// Assuming that the Pool calls mint() and burn() with its current index.
invariant user_index_up_to_date(env e1, address user1)
		scaledBalanceOf(e1, user1) != 0 => 
		getUserCurrentIndex(user1) == indexAtTimestamp(e1.block.timestamp)
		{
        preserved mint(address user2, address onBehalfOf, uint256 amount, uint256 index) with (env e2)
        {
            require index == indexAtTimestamp(e2.block.timestamp); 
            require e1.block.timestamp == e2.block.timestamp;
        }
        preserved  burn(address from, uint256 amount, uint256 index) with (env e3)
        {
            require index == indexAtTimestamp(e3.block.timestamp);
            require e1.block.timestamp == e3.block.timestamp;
        }
		preserved with (env e4)
        {
            require e1.block.timestamp == e4.block.timestamp;
        }
    }

// check user index after mint()
rule user_index_after_mint
{
	env e; 
	address user;
    address onBehalfOf;
    uint256 amount;
    uint256 index;

	uint256 user_index_before = getUserCurrentIndex(onBehalfOf);
	mint(e, user, onBehalfOf, amount, index);
	uint256 user_index_after = getUserCurrentIndex(onBehalfOf);
	assert index > user_index_before =>  user_index_after > user_index_before;
	assert user_index_after == index;
}

// check accumulated interest after mint()
rule accumulated_interest_increase_after_mint
{
	env e; 
	address user;
    address onBehalfOf;
    uint256 amount;
    uint256 index;

	requireInvariant user_index_ge_one_ray(e, onBehalfOf);
	requireInvariant discountCantExceedDiscountRate(onBehalfOf);

	uint256 user_index_before = getUserCurrentIndex(onBehalfOf);
	uint256 balance_before = balanceOf(e, onBehalfOf);
	uint256 discount_before = getUserDiscountRate(onBehalfOf);
	uint256 accumulated_interest_before = getUserAccumulatedDebtInterest(onBehalfOf);
	mint(e, user, onBehalfOf, amount, index);
	uint256 accumulated_interest_after = getUserAccumulatedDebtInterest(onBehalfOf);


	assert balance_before > 0 && to_mathint(user_index_before + ray()) < to_mathint(index) 
			=> accumulated_interest_after > accumulated_interest_before;
}

// User index >= 1 ray for every user with positive balance 
invariant user_index_ge_one_ray(env e1, address user1)
		scaledBalanceOf(e1, user1) != 0 => ray() <=  getUserCurrentIndex(user1)
		{
        preserved mint(address user2, address onBehalfOf, uint256 amount, uint256 index) with (env e2)
        {
            require index >= ray(); //TODO: verify - the Pool calls mint() with index >= 1 ray
        }
        preserved  burn(address from, uint256 amount, uint256 index) with (env e3)
        {
            require index >= ray(); //TODO: verify - the Pool calls burn() with index >= 1 ray
        }
    }


/**
* Imported rules from VariableDebtToken.spec
**/
//pass
use rule disallowedFunctionalities;

/**
* @title proves that a user's discount rate can be updated only by calling rebalanceUserDiscountPercent
* This rule fails since updateDiscountDistribution, mint and burn can recalculate and update the user discount rate
**/
// rule onlyRebalanceCanUpdateUserDiscountRate(method f) {
// 	address user;
// 	uint256 discRateBefore = getUserDiscountRate(user);
// 	requireInvariant discountCantExceed100Percent(user);

// 	env e;
// 	calldataarg args;
// 	f(e,args);

// 	uint256 discRateAfter = getUserDiscountRate(user);

// 	assert(discRateAfter != discRateBefore => f.selector == sig:rebalanceUserDiscountPercent(address).selector);
// }

/**
* @title proves that the user's balance of debt token (as reported by GhoVariableDebtToken::balanceOf) can't increase by calling any external non-mint function.
**/
//pass
rule nonMintFunctionCantIncreaseBalance(method f) filtered { f-> f.selector != sig:mint(address, address, uint256, uint256).selector } {
	address user;
	uint256 ts1;
	uint256 ts2;
	require(ts2 >= ts1);
	// Forcing the index to be fixed (otherwise the rule times out). For non-fixed index replace `==` with `>=`
	require((indexAtTimestamp(ts1) >= ray()) && 
			(indexAtTimestamp(ts2) == indexAtTimestamp(ts1)));

	require(getUserCurrentIndex(user) == indexAtTimestamp(ts1));
	requireInvariant discountCantExceed100Percent(user);

	env e = envAtTimestamp(ts2);
	uint256 balanceBeforeOp = balanceOf(e, user);
	calldataarg args;
	f(e,args);
	mathint balanceAfterOp = balanceOf(e, user);
	mathint allowedDiff = indexAtTimestamp(ts2) / ray();
	// assert(balanceAfterOp != balanceBeforeOp + allowedDiff + 1);
	assert(balanceAfterOp <= balanceBeforeOp + allowedDiff);
}

/**
* @title proves that a call to a non-mint operation won't increase the user's balance of the actual debt tokens (i.e. it's scaled balance)
**/
// pass
rule nonMintFunctionCantIncreaseScaledBalance(method f) filtered { f-> f.selector != sig:mint(address, address, uint256, uint256).selector } {
	address user;
	uint256 ts1;
	uint256 ts2;
	require(ts2 >= ts1);
	require((indexAtTimestamp(ts1) >= ray()) && 
			(indexAtTimestamp(ts2) >= indexAtTimestamp(ts1)));

	require(getUserCurrentIndex(user) == indexAtTimestamp(ts1));
	requireInvariant discountCantExceed100Percent(user);
	uint256 balanceBeforeOp = scaledBalanceOf(user);
	env e = envAtTimestamp(ts2);
	calldataarg args;
	f(e,args);
	uint256 balanceAfterOp = scaledBalanceOf(user);
	assert(balanceAfterOp <= balanceBeforeOp);
}

/**
* @title proves that debt tokens aren't transferable
**/
// pass
rule debtTokenIsNotTransferable(method f) {
	address user1;
	address user2;
	require(user1 != user2);
	uint256 scaledBalanceBefore1 = scaledBalanceOf(user1);
	uint256 scaledBalanceBefore2 = scaledBalanceOf(user2);
	env e;
	calldataarg args;
	f(e,args);
	uint256 scaledBalanceAfter1 = scaledBalanceOf(user1);
	uint256 scaledBalanceAfter2 = scaledBalanceOf(user2);

	assert( scaledBalanceBefore1 + scaledBalanceBefore2 == scaledBalanceAfter1 + scaledBalanceAfter2 
	=> (scaledBalanceBefore1 == scaledBalanceAfter1 && scaledBalanceBefore2 == scaledBalanceAfter2));
}

/**
* @title proves that only burn/mint/rebalanceUserDiscountPercent/updateDiscountDistribution can modify user's scaled balance
**/
// pass
rule onlyCertainFunctionsCanModifyScaledBalance(method f) {
	address user;
	uint256 ts1;
	uint256 ts2;
	require(ts2 >= ts1);
	require((indexAtTimestamp(ts1) >= ray()) && 
			(indexAtTimestamp(ts2) >= indexAtTimestamp(ts1)));

	require(getUserCurrentIndex(user) == indexAtTimestamp(ts1));
	requireInvariant discountCantExceed100Percent(user);
	uint256 balanceBeforeOp = scaledBalanceOf(user);
	env e = envAtTimestamp(ts2);
	calldataarg args;
	f(e,args);
	uint256 balanceAfterOp = scaledBalanceOf(user);
	assert(balanceAfterOp != balanceBeforeOp => (
		(f.selector == sig:mint(address ,address ,uint256 ,uint256).selector) ||
		(f.selector == sig:burn(address ,uint256 ,uint256).selector) ||
		(f.selector == sig:updateDiscountDistribution(address ,address ,uint256 ,uint256 ,uint256).selector) ||
		(f.selector == sig:rebalanceUserDiscountPercent(address).selector)));
}

/**
* @title proves that only a call to decreaseBalanceFromInterest will decrease the user's accumulated interest listing.
**/
// pass
rule userAccumulatedDebtInterestWontDecrease(method f) {
	address user;
	uint256 ts1;
	uint256 ts2;
	require(ts2 >= ts1);
	require((indexAtTimestamp(ts1) >= ray()) && 
			(indexAtTimestamp(ts2) >= indexAtTimestamp(ts1)));

	require(getUserCurrentIndex(user) == indexAtTimestamp(ts1));
	requireInvariant discountCantExceed100Percent(user);
	uint256 initAccumulatedInterest = getUserAccumulatedDebtInterest(user);
	env e2 = envAtTimestamp(ts2);
	calldataarg args;
	f(e2,args);
	uint256 finAccumulatedInterest = getUserAccumulatedDebtInterest(user);
	assert(initAccumulatedInterest > finAccumulatedInterest => f.selector == sig:decreaseBalanceFromInterest(address, uint256).selector);
}

/**
* @title proves that a user can't nullify its debt without calling burn
**/
// pass
rule userCantNullifyItsDebt(method f) {
    address user;
    env e;
    env e2;
	require(getUserCurrentIndex(user) == indexAtTimestamp(e.block.timestamp));
	requireInvariant discountCantExceed100Percent(user);
	uint256 balanceBeforeOp = balanceOf(e, user);
	calldataarg args;
    require e2.block.timestamp == e.block.timestamp;
	f(e2,args);
	uint256 balanceAfterOp = balanceOf(e, user);
	assert((balanceBeforeOp > 0 && balanceAfterOp == 0) => (f.selector == sig:burn(address, uint256, uint256).selector));
}

/***************************************************************
* Integrity of Mint
***************************************************************/

/**
* @title proves that after calling mint, the user's discount rate is up to date
**/
rule integrityOfMint_updateDiscountRate() {
	address user1;
	address user2;
	env e;
	uint256 amount;
	uint256 index = indexAtTimestamp(e.block.timestamp);
	mint(e, user1, user2, amount, index);
	uint256 debtBalance = balanceOf(e, user2);
	uint256 discountBalance = getBalanceOfDiscountToken(e, user2);
	uint256 discountRate = getUserDiscountRate(user2);
	assert(discStrategy.calculateDiscountRate(debtBalance, discountBalance) == discountRate);
}

/**
* @title proves the after calling mint, the user's state is updated with the recent index value
**/
rule integrityOfMint_updateIndex() {
	address user1;
	address user2;
	env e;
	uint256 amount;
	uint256 index;
	mint(e, user1, user2, amount, index);
	assert(getUserCurrentIndex(user2) == index);
}

/**
* @title proves that on a fixed index calling mint(user, amount) will increase the user's scaled balance by amount. 
**/
// pass
rule integrityOfMint_updateScaledBalance_fixedIndex() {
	address user;
	env e;
	uint256 balanceBefore = balanceOf(e, user);
	uint256 scaledBalanceBefore = scaledBalanceOf(user);
	address caller;
	uint256 amount;
	uint256 index = indexAtTimestamp(e.block.timestamp);
	require(getUserCurrentIndex(user) == index);
	mint(e, caller, user, amount, index);

	uint256 balanceAfter = balanceOf(e, user);
	mathint scaledBalanceAfter = scaledBalanceOf(user);
	mathint scaledAmount = rayDivCVL(amount, index);

	assert(scaledBalanceAfter == scaledBalanceBefore + scaledAmount);
}

/**
* @title proves that mint can't effect other user's scaled balance
**/
// pass
rule integrityOfMint_userIsolation() {
	address otherUser;
	uint256 scaledBalanceBefore = scaledBalanceOf(otherUser);
	env e;
	uint256 amount;
	uint256 index;
	address targetUser;
	address caller;
	mint(e, caller, targetUser, amount, index);
	uint256 scaledBalanceAfter = scaledBalanceOf(otherUser);
	assert(scaledBalanceAfter != scaledBalanceBefore => otherUser == targetUser);
}

/**
* @title proves that when calling mint, the user's balance (as reported by GhoVariableDebtToken::balanceOf) will increase if the call is made on bahalf of the user.
**/
rule onlyMintForUserCanIncreaseUsersBalance() {
	address user1;
    env e;
	require(getUserCurrentIndex(user1) == indexAtTimestamp(e.block.timestamp));
	
	uint256 finBalanceBeforeMint = balanceOf(e, user1);
	uint256 amount;
	mint(e,user1, user1, amount, indexAtTimestamp(e.block.timestamp));
	uint256 finBalanceAfterMint = balanceOf(e, user1);

	assert(finBalanceAfterMint != finBalanceBeforeMint);
}

/**
* @title proves that a user can't decrease the ovelall interest of his position by taking more loans, compared to another user with the same initial position.
* This rule times out.
**/
// rule integrityOfMint_cantDecreaseInterestWithMint() {
// 	address user1;
// 	uint256 ts1;
// 	env e1 = envAtTimestamp(ts1);
// 	uint256 ts2;
// 	require(ts2 >= ts1);
// 	env e2 = envAtTimestamp(ts2);
// 	uint256 ts3;
// 	require(ts3 >= ts2);
// 	env e3 = envAtTimestamp(ts3);
// 	// Forcing the index to be fixed (otherwise the rule times out). For non-fixed index replace `==` with `>=`
// 	require((indexAtTimestamp(ts1) >= ray()) && 
// 			(indexAtTimestamp(ts2) >= indexAtTimestamp(ts1)) &&
// 			(indexAtTimestamp(ts3) >= indexAtTimestamp(ts2)));


// 	require(getUserCurrentIndex(user1) == indexAtTimestamp(ts1));
// 	uint256 amount;
// 	storage initialStorage = lastStorage;
// 	mint(e2, user1, user1, amount, indexAtTimestamp(ts2));

// 	rebalanceUserDiscountPercent(e3, user1);
// 	uint256 balanceFromInterestAfterMint = getBalanceFromInterest(user1);

// 	rebalanceUserDiscountPercent(e3, user1) at initialStorage;
// 	uint256 balanceFromInterestWithoutMint = getBalanceFromInterest(user1);

// 	assert(balanceFromInterestAfterMint >= balanceFromInterestWithoutMint);
// }

//pass
use rule integrityMint_atoken;

/***************************************************************
* Integrity of Burn
***************************************************************/

/**
* @title proves that after calling burn, the user's discount rate is up to date
**/
rule integrityOfBurn_updateDiscountRate() {
	address user;
	env e;
	uint256 amount;
	uint256 index = indexAtTimestamp(e.block.timestamp);
	burn(e, user, amount, index);
	uint256 debtBalance = balanceOf(e, user);
	uint256 discountBalance = getBalanceOfDiscountToken(e, user);
	uint256 discountRate = getUserDiscountRate(user);
	assert(discStrategy.calculateDiscountRate(debtBalance, discountBalance) == discountRate);
}

/**
* @title proves the after calling burn, the user's state is updated with the recent index value
**/
rule integrityOfBurn_updateIndex() {
	address user;
	env e;
	uint256 amount;
	uint256 index;
	burn(e, user, amount, index);
	assert(getUserCurrentIndex(user) == index);
}

/**
* @title proves that calling burn with 0 amount doesn't change the user's balance
**/
use rule burnZeroDoesntChangeBalance;

/**
* @title proves a concrete case of repaying the full debt that ends with a zero balance
**/
rule integrityOfBurn_fullRepay_concrete() {
	env e;
	address user;
	uint256 currentDebt = balanceOf(e, user);
	uint256 index = indexAtTimestamp(e.block.timestamp);
	require(getUserCurrentIndex(user) == ray());
	require(to_mathint(index) == 2*ray());
	require(to_mathint(scaledBalanceOf(user)) == 4*ray());
	burn(e, user, currentDebt, index);
	uint256 scaled = scaledBalanceOf(user);
	assert(scaled == 0);
}


/**
* @title proves that burn can't effect other user's scaled balance
**/
// pass
rule integrityOfBurn_userIsolation() {
	address otherUser;
	uint256 scaledBalanceBefore = scaledBalanceOf(otherUser);
	env e;
	uint256 amount;
	uint256 index;
	address targetUser;
	burn(e,targetUser, amount, index);
	uint256 scaledBalanceAfter = scaledBalanceOf(otherUser);
	assert(scaledBalanceAfter != scaledBalanceBefore => otherUser == targetUser);
}

/***************************************************************
* Integrity of updateDiscountDistribution
***************************************************************/

// /**
// * @title proves that the discount rate is calculated correctly when calling updateDiscountDistribution
// **/
// rule integrityOfUpdateDiscountDistribution_discountRate() {
// 	address sender;
//     address recipient;
//     uint256 senderDiscountTokenBalanceBefore;
//     uint256 recipientDiscountTokenBalanceBefore;
//     uint256 amount;
// 	uint256 senderDiscountTokenBalanceAfter = require_uint256(senderDiscountTokenBalanceBefore - amount);
//     uint256 recipientDiscountTokenBalanceAfter = require_uint256(recipientDiscountTokenBalanceBefore + amount);
// 	env e0;
// 	env e;
// 	require(e.block.timestamp > e0.block.timestamp);
// 	require(indexAtTimestamp(e.block.timestamp) >= indexAtTimestamp(e0.block.timestamp));
// 	require(indexAtTimestamp(e0.block.timestamp) == ray()); // reduces execution time
// 	require(getUserCurrentIndex(sender) == indexAtTimestamp(e0.block.timestamp));
// 	require(getUserCurrentIndex(recipient) == indexAtTimestamp(e0.block.timestamp));

// 	require(getBalanceOfDiscountToken(e0, sender) == senderDiscountTokenBalanceBefore);
// 	require(getBalanceOfDiscountToken(e0, recipient) == recipientDiscountTokenBalanceBefore);
// 	require(discStrategy.calculateDiscountRate(balanceOf(e0, sender), senderDiscountTokenBalanceBefore) == getUserDiscountRate(sender));
// 	require(discStrategy.calculateDiscountRate(balanceOf(e0, recipient), recipientDiscountTokenBalanceBefore) == getUserDiscountRate(recipient));

// 	require(getBalanceOfDiscountToken(e, sender) == senderDiscountTokenBalanceAfter);
// 	require(getBalanceOfDiscountToken(e, recipient) == recipientDiscountTokenBalanceAfter);

// 	updateDiscountDistribution(e, sender, recipient, senderDiscountTokenBalanceBefore, recipientDiscountTokenBalanceBefore, amount);
// 	uint256 senderBalance = balanceOf(e, sender);
// 	uint256 recipientBalance = balanceOf(e, recipient);
// 	assert(discStrategy.calculateDiscountRate(senderBalance, senderDiscountTokenBalanceAfter) == getUserDiscountRate(sender));
// 	assert(discStrategy.calculateDiscountRate(recipientBalance, recipientDiscountTokenBalanceAfter) == getUserDiscountRate(recipient));
// }

rule sendersDiscountPercentCannotIncrease(){
	env e1;
    address sender; address recipient; uint256 amount;

    uint256 _senderStkBalance = getBalanceOfDiscountToken(e1, sender);
    uint256 _recipientStkBalance = getBalanceOfDiscountToken(e1, recipient);
    uint256 indE1 = indexAtTimestamp(e1.block.timestamp);
    // require(indE1 >= ray()); // this is already enforced in the funciton's body
    require getUserCurrentIndex(sender) == indE1;
    uint256 _sender_debt = balanceOf(e1, sender);
    uint256 discount_sender = discStrategy.calculateDiscountRate(_sender_debt, _senderStkBalance);
    require(discount_sender == getDiscountPercent(e1, sender));
    require discount_sender != 0; // this can be violated due to discontinuity of calculateDiscountRate
    
    env e2;
	require e1.block.timestamp <= e2.block.timestamp;
    uint256 indE2 = indexAtTimestamp(e2.block.timestamp);
	require(indE2 >= indE1);
    require _senderStkBalance == getBalanceOfDiscountToken(e2, sender);
    require _recipientStkBalance == getBalanceOfDiscountToken(e2, recipient);

    updateDiscountDistribution(e2, sender, recipient, _senderStkBalance, _recipientStkBalance, amount);
    
    uint256 discountPercent_ = getDiscountPercent(e2, sender);
    assert (discountPercent_ <= discount_sender);
}

/**
* @title proves the after calling updateDiscountDistribution, the user's state is updated with the recent index value
**/
rule integrityOfUpdateDiscountDistribution_updateIndex() {
	address sender;
	address recipient;
	uint256 senderDiscountTokenBalance;
    uint256 recipientDiscountTokenBalance;
	env e;
	uint256 amount;
    uint256 _senderInd = getUserCurrentIndex(sender);
    uint256 _recipientInd = getUserCurrentIndex(recipient);
	uint256 index = indexAtTimestamp(e.block.timestamp);
	updateDiscountDistribution(e, sender, recipient, senderDiscountTokenBalance, recipientDiscountTokenBalance, amount);
	if (sender != recipient){
        assert(scaledBalanceOf(sender) > 0 => getUserCurrentIndex(sender) == index);
	    assert(scaledBalanceOf(recipient) > 0 => getUserCurrentIndex(recipient) == index);
    }
    else{
        assert(getUserCurrentIndex(sender) == _senderInd);
        assert(getUserCurrentIndex(recipient) == _recipientInd); // this is redundant, this is here for future changes in the code/rule
    }
}

/**
* @title proves that updateDiscountDistribution can't effect other user's scaled balance
**/
// pass
rule integrityOfUpdateDiscountDistribution_userIsolation() {
	address otherUser;
	uint256 scaledBalanceBefore = scaledBalanceOf(otherUser);
	env e;
	uint256 amount;
	uint256 senderDiscountTokenBalance;
	uint256 recipientDiscountTokenBalance;
	address sender;
	address recipient;
	updateDiscountDistribution(e, sender, recipient, senderDiscountTokenBalance, recipientDiscountTokenBalance, amount);
	uint256 scaledBalanceAfter = scaledBalanceOf(otherUser);
	assert(scaledBalanceAfter != scaledBalanceBefore => (otherUser == sender || otherUser == recipient));
}

/***************************************************************
* Integrity of rebalanceUserDiscountPercent
***************************************************************/

/**
* @title proves that after calling rebalanceUserDiscountPercent, the user's discount rate is up to date
**/
rule integrityOfRebalanceUserDiscountPercent_updateDiscountRate() {
	address user;
	env e;
	rebalanceUserDiscountPercent(e, user);
	assert(discStrategy.calculateDiscountRate(balanceOf(e, user), getBalanceOfDiscountToken(e, user)) == getUserDiscountRate(user));
}

/**
* @title proves the after calling rebalanceUserDiscountPercent, the user's state is updated with the recent index value
**/
rule integrityOfRebalanceUserDiscountPercent_updateIndex() {
	address user;
	env e;
	rebalanceUserDiscountPercent(e, user);
	uint256 index = indexAtTimestamp(e.block.timestamp);
	assert(getUserCurrentIndex(user) == index);
}

/**
* @title proves that rebalanceUserDiscountPercent can't effect other user's scaled balance
**/
// pass
rule integrityOfRebalanceUserDiscountPercent_userIsolation() {
	address otherUser;
	uint256 scaledBalanceBefore = scaledBalanceOf(otherUser);
	env e;
	address targetUser;
	rebalanceUserDiscountPercent(e, targetUser);
	uint256 scaledBalanceAfter = scaledBalanceOf(otherUser);
	assert(scaledBalanceAfter != scaledBalanceBefore => otherUser == targetUser);
}

/***************************************************************
* Integrity of balanceOf
***************************************************************/

/**
* @title proves that a user with 100% discounts has a fixed balance over time
**/
rule integrityOfBalanceOf_fullDiscount() {
	address user;
	uint256 fullDiscountRate = 10000; //100%
	require(getUserDiscountRate(user) == fullDiscountRate);
	env e1;
	env e2;
	uint256 index1 = indexAtTimestamp(e1.block.timestamp);
	uint256 index2 = indexAtTimestamp(e2.block.timestamp);
	assert(balanceOf(e1, user) == balanceOf(e2, user));
}

/**
* @title proves that a user's balance, with no discount, is equal to rayMul(scaledBalance, current index)
**/
rule integrityOfBalanceOf_noDiscount() {
	address user;
	require(getUserDiscountRate(user) == 0);
	env e;
	uint256 scaledBalance = scaledBalanceOf(user);
	uint256 currentIndex = indexAtTimestamp(e.block.timestamp);
	mathint expectedBalance = rayMulCVL(scaledBalance, currentIndex);
	assert(to_mathint(balanceOf(e, user)) == expectedBalance);
}

/**
* @title proves the a user with zero scaled balance has a zero balance
**/
rule integrityOfBalanceOf_zeroScaledBalance() {
	address user;
	env e;
	uint256 scaledBalance = scaledBalanceOf(user);
	require(scaledBalance == 0);
	assert(balanceOf(e, user) == 0);
}

/**
* @title burning amount of current debt nullifies the debt position
**/
rule burnAllDebtReturnsZeroDebt(address user) {
    env e;
	uint256 _variableDebt = balanceOf(e, user);
	burn(e, user, _variableDebt, indexAtTimestamp(e.block.timestamp));
	uint256 variableDebt_ = balanceOf(e, user);
    assert(variableDebt_ == 0);
}

/**
* @title discount strategy setter is setting the corresponding storage slot to the passed value 
**/
rule integrityOfUpdateDiscountRateStrategy(address newDiscountRateStrategy) {
	env e;
    updateDiscountRateStrategy(e, newDiscountRateStrategy );
    assert(getDiscountRateStrategy(e) == newDiscountRateStrategy);
}
