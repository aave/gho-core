
// verifies properties of OracleSwapFreezer

methods {
	function getFreezeBound() external returns (uint128, uint128) envfree;
	function getUnfreezeBound() external returns (uint128, uint128) envfree;
	function validateBounds(uint128,uint128,uint128,uint128,bool) external returns bool envfree;
    function _.hasRole(bytes32, address) external => hasRole expect bool;
	function _.getAssetPrice(address) external => CONSTANT;
	function _.getPriceOracle() external => CONSTANT;
	function _.getIsSeized() external => CONSTANT;
	function _.SWAP_FREEZER_ROLE() external => CONSTANT;
	function _.getIsFrozen() external => CONSTANT;
}

function boundsAreValid() returns bool 
{
	uint128 freezeLower; uint128 freezeUpper; uint128 unFreezeLower; uint128 unFreezeUpper;
	freezeLower, freezeUpper = getFreezeBound();
	unFreezeLower, unFreezeUpper = getUnfreezeBound();
	return validateBounds(freezeLower, freezeUpper, unFreezeLower, unFreezeUpper, true);
}

ghost bool hasRole;

// @title Freeze action is executable under specified conditions
// Freeze action is executable if GSM is not seized, not frozen and price is outside of the freeze bounds
// STATUS: PASS
// https://prover.certora.com/output/40748/9802a015eadc415ab6e449384f60e944?anonymousKey=e43bbc0fc9409b164be311adbadaa6d473db1a00
rule freezeExecutable()
{
	env e;
	uint256 price = getPrice(e);
    require hasRole == true;
	require !isFrozen(e) && !isSeized(e);
	uint128 freezeLower; uint128 freezeUpper;
	freezeLower, freezeUpper = getFreezeBound();
	require price < require_uint256(freezeLower) || price > require_uint256(freezeUpper);
	assert price != 0 => getAction(e) == 1;	//represents the freeze action
}

// @title Unfreeze action is executable under specified conditions
//Unfreeze action is executable if GSM is not seized, frozen, unfreezing is allowed and price is inside the unfreeze bounds
// STATUS: PASS
// https://prover.certora.com/output/11775/184ae7de9b56415088118d8e6d027ff3?anonymousKey=4f8fcda010d0dbba62ed4fd5663650233a3f7969
rule unfreezeExecutable()
{
	env e;
	uint256 price = getPrice(e);
    require hasRole == true;
	require boundsAreValid();
	require isFrozen(e) && !isSeized(e);
	uint128 unFreezeLower; uint128 unFreezeUpper;
	unFreezeLower, unFreezeUpper = getUnfreezeBound();
	require price >= require_uint256(unFreezeLower) && price <= require_uint256(unFreezeUpper);
	assert getCanUnfreeze(e) => getAction(e) == 2;	//represents the unfreeze action
}

// @title Unfreeze boundaries are contained in freeze boundaries
//Unfreeze boundaries are "contained" in freeze boundaries, where freezeLowerBound < unfreezeLowerBound and unfreezeUpperBound < freezeUpperBound
// STATUS: PASS
// https://prover.certora.com/output/11775/184ae7de9b56415088118d8e6d027ff3?anonymousKey=4f8fcda010d0dbba62ed4fd5663650233a3f7969
rule boundsAreContained()
{
	env e;
	require boundsAreValid();
	uint128 freezeLower; uint128 freezeUpper;
	freezeLower, freezeUpper = getFreezeBound();

	uint128 unfreezeLower; uint128 unfreezeUpper;
	unfreezeLower, unfreezeUpper = getUnfreezeBound();

	assert freezeLower < unfreezeLower && unfreezeUpper < freezeUpper;
}

// @title freeze and unfreeze are never executable at the same time.
//there should never be an oracle price that could allow both freeze and unfreeze
// STATUS: PASS
// https://prover.certora.com/output/11775/184ae7de9b56415088118d8e6d027ff3?anonymousKey=4f8fcda010d0dbba62ed4fd5663650233a3f7969
rule freezeAndUnfreezeAreExclusive()
{
	env e;
	require boundsAreValid();
	assert !(isFreezeAllowed(e) && isUnfreezeAllowed(e));
}
