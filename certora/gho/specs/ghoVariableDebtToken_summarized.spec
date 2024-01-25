import "ghoVariableDebtToken.spec";

methods{
	function GhoVariableDebtToken._accrueDebtOnAction(address user, uint256, uint256, uint256) internal returns (uint256, uint256) => flipAccrueCalled(user);
	function GhoVariableDebtToken._refreshDiscountPercent(address user, uint256, uint256, uint256) internal => flipRefreshCalled(user);
}

ghost mapping(address => mathint) accrue_called_counter {
    init_state axiom forall address user. accrue_called_counter[user] == 0;
}
ghost mapping(address => mathint) refresh_called_counter {
    init_state axiom forall address user. refresh_called_counter[user] == 0;
}

function flipAccrueCalled(address user) returns (uint256, uint256) {
    accrue_called_counter[user] = accrue_called_counter[user] + 1;
    return (0, 0);
}

function flipRefreshCalled(address user) {
    // before refreshing a user, accrue of the user should've been called exactly once
    // of course calling accrue twice is not a crucial mistake, but accruing the same user twice in a row before refreshing doesn't make sense, so a violation should be triggered
    assert(refresh_called_counter[user] + 1 == accrue_called_counter[user]);
    refresh_called_counter[user] = refresh_called_counter[user] + 1;
}

invariant allUsersRefreshAndAccrueCounterEqual()
    forall address user. accrue_called_counter[user] == refresh_called_counter[user];

// accrue is always called before refresh
rule accrueAlwaysCalleldBeforeRefresh(env e, method f) {
    address user1;
    requireInvariant allUsersRefreshAndAccrueCounterEqual();
    // require (forall address user. (accrue_called_counter[user] == refresh_called_counter[user]));

    calldataarg args;
    // see comment in flipRefreshCalled
    f(e, args);

    assert refresh_called_counter[user1] == accrue_called_counter[user1], "Remember, with great power comes great responsibility.";
}

// accrue is always called before refresh example
// should pass only on updateDiscountDistribution
rule accrueAlwaysCalledBeforeRefresh_witness(env e, method f) {
    address user1;
    mathint counter = accrue_called_counter[user1];
    require accrue_called_counter[user1] == refresh_called_counter[user1];

    calldataarg args;
    f(e, args);

    satisfy(refresh_called_counter[user1] == counter + 2);
}