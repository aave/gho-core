import "erc20.spec";

using GhoTokenHarness as _ghoTokenHarness;

methods{

	function totalSupply() external returns (uint256) envfree;
	function RESERVE_TREASURY_ADDRESS() external returns (address) envfree;
	function UNDERLYING_ASSET_ADDRESS() external returns (address) envfree;
	function transferUnderlyingTo(address,uint256) external;
	function handleRepayment(address,address,uint256) external; 
	function distributeFeesToTreasury() external envfree ;
	function rescueTokens(address,address,uint256) external; 
	function setVariableDebtToken(address)  external;
	function getVariableDebtToken() external returns (address) envfree;
	function updateGhoTreasury(address) external ;
	function getGhoTreasury() external returns (address) envfree;
	function _ghoTokenHarness.getFacilitatorBucketCapacity(address) external returns (uint256) envfree;
	function _ghoTokenHarness.getFacilitatorBucketLevel(address) external returns (uint256) envfree;
	function _ghoTokenHarness.balanceOf(address) external returns (uint256) envfree;
	function scaledBalanceOf(address) external returns (uint256) envfree;

  	/*******************
    *     Pool.sol     *
    ********************/
    function _.getReserveNormalizedIncome(address) external => CONSTANT;


  	/***********************************
    *    PoolAddressesProvider.sol     *
    ************************************/
	function _.getACLManager() external => CONSTANT;

	/************************
    *    ACLManager.sol     *
    *************************/
	function _.isPoolAdmin(address) external => CONSTANT;


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
	mathint facilitatorLevel = _ghoTokenHarness.getFacilitatorBucketLevel(currentContract);
	mathint facilitatorCapacity = _ghoTokenHarness.getFacilitatorBucketCapacity(currentContract);
	transferUnderlyingTo@withrevert(e, target, amount);
	assert(to_mathint(amount) > (facilitatorCapacity - facilitatorLevel) => lastReverted);
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
	scaledBalanceOf(user) == 0;



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


