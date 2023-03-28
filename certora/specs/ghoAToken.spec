import "erc20.spec"

using GhoTokenHarness as _ghoTokenHarness

methods{

	totalSupply() returns (uint256) envfree
	RESERVE_TREASURY_ADDRESS() returns (address) envfree
	UNDERLYING_ASSET_ADDRESS() returns (address) envfree
	transferUnderlyingTo(address,uint256)
	handleRepayment(address,address,uint256) 
	distributeFeesToTreasury() envfree 
	rescueTokens(address,address,uint256) 
	setVariableDebtToken(address) 
	getVariableDebtToken() returns (address) envfree
	updateGhoTreasury(address) 
	getGhoTreasury() returns (address) envfree
	_ghoTokenHarness.getFacilitatorBucketCapacity(address) returns (uint256) envfree
	_ghoTokenHarness.getFacilitatorBucketLevel(address) returns (uint256) envfree
	_ghoTokenHarness.balanceOf(address) returns (uint256) envfree
	scaledBalanceOf(address) returns (uint256) envfree

  	/*******************
    *     Pool.sol     *
    ********************/
    getReserveNormalizedIncome(address) returns (uint256) => CONSTANT


  	/***********************************
    *    PoolAddressesProvider.sol     *
    ************************************/
	getACLManager() returns(address) => CONSTANT

	/************************
    *    ACLManager.sol     *
    *************************/
	isPoolAdmin(address) returns(bool) => CONSTANT


}

/**
* @title Proves that ghoAToken::mint always reverts
**/
rule noMint() {
	env e;
	calldataarg args;
	mint(e, args);
	assert(false);
}

/**
* @title Proves that ghoAToken::burn always reverts
**/
rule noBurn() {
	env e;
	calldataarg args;
	burn(e, args);
	assert(false);
}

/**
* @title Proves that ghoAToken::transfer always reverts
**/
rule noTransfer() {
	env e;
	calldataarg args;
	transfer(e, args);
	assert(false);
}

/** 
* @title Proves that calling ghoAToken::transferUnderlyingTo will revert if the amount exceeds the excess capacity  
* @notice A user can’t borrow more than the facilitator’s remaining capacity.
**/
rule transferUnderlyingToCantExceedCapacity() {
	address target;
	uint256 amount;
	env e;
	uint256 facilitatorLevel = _ghoTokenHarness.getFacilitatorBucketLevel(currentContract);
	uint256 facilitatorCapacity = _ghoTokenHarness.getFacilitatorBucketCapacity(currentContract);
	transferUnderlyingTo@withrevert(e, target, amount);
	assert(amount > (facilitatorCapacity - facilitatorLevel) => lastReverted);
}


/**
* @title Proves that the total supply of GhoAToken is always zero
**/
rule totalSupplyAlwaysZero() {
	assert(totalSupply() == 0);
}

/**
* @title Proves that any user's balance of GhoAToken is always zero
**/
invariant userBalanceAlwaysZero(address user)
	scaledBalanceOf(user) == 0



// /**
// * @title first handleRepayment(amount) after transferUnderlyingTo(amount) succeeds.
// * @dev assumption of sufficient balanceOf(msg.sender) is justified because BorrowLogic.executeRepay()
// * @dev executes: IERC20(params.asset).safeTransferFrom(msg.sender, reserveCache.aTokenAddress, paybackAmount);
// * @dev before invocation of handleRepayment()
// * OBSOLETE - GhoToken has other rules to validate the behavior of the facilitator level maintenance
// */
// rule handleRepayment_after_transferUnderlyingTo()
// {
// 	env e;
// 	calldataarg arg;
// 	uint256 amount;
// 	address target;
// 	address user;
//     address onBehalfOf;

// 	transferUnderlyingTo(e, target, amount);

// 	require _ghoTokenHarness.balanceOf(e.msg.sender) >= amount; //underlying asset
// 	require e.msg.sender == currentContract;

// 	handleRepayment@withrevert(e, user, onBehalfOf, amount);
// 	assert !lastReverted, "handleRepayment failed";

// }


/**
* @title BucketLevel decreases after transferUnderlyingTo() followed by handleRepayment()
* @dev repayment funds are, partially or fully, transferred to the treasury
*/
rule level_does_not_decrease_after_transferUnderlyingTo_followed_by_handleRepayment()
{
	env e;
	calldataarg arg;
	uint256 amount;
	address target;
	address user;
    address onBehalfOf;

	uint256 levelBefore = _ghoTokenHarness.getFacilitatorBucketLevel(currentContract);
	transferUnderlyingTo(e, target, amount);
	handleRepayment(e, user, onBehalfOf, amount);
	uint256 levelAfter = _ghoTokenHarness.getFacilitatorBucketLevel(currentContract);
	assert levelBefore <= levelAfter;

}





