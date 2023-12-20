import "ghoVariableDebtToken.spec";

methods{
}


// check a scenario that function _accrueDebtOnAction() returns non zero balance increase 
rule positive_balanceIncrease {
	env e;
	address user;
    uint256 previousScaledBalance; uint256 discountPercent; uint256 index;
	uint256 balanceIncrease; uint256 discountScaled;
	uint256 user_index_before = getUserCurrentIndex(user);
	uint256 accumulated_interest_before = getUserAccumulatedDebtInterest(user);
	balanceIncrease, discountScaled = accrueDebtOnAction(e, user,previousScaledBalance,discountPercent,index);
	uint256 accumulated_interest_after = getUserAccumulatedDebtInterest(user);
	uint256 user_index_after = getUserCurrentIndex(user);
	
	assert 	ray() <= user_index_before
			&& to_mathint(user_index_before + ray()) < to_mathint(index) // user index increase by more than 1 ray
			&& 0 < previousScaledBalance
			&& discountPercent < discStrategy.DISCOUNT_RATE() // discount rate is less than 30% 
			//(if user index increases by 1 ray discount percent could be as high as 50%) 
					=> balanceIncrease > 0;

	assert 	balanceIncrease > 0 => accumulated_interest_after > accumulated_interest_before;

	assert user_index_after == index;
}


