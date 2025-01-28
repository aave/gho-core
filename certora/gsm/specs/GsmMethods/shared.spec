import "../GsmMethods/methods_base-Martin.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/aave_price_fee_limits.spec";

/**
 *
 * SHARED RULES
 *
 */
/**
 *
 * SHARED FUNCTIONALITY
 *
 */
// Computes sum of assets of the addresses passed as parameters taking into account that the
// some of the addresses may be the same.
function assetOfUsers(env e, address sender, address receiver, address originator, mathint ghoDecimals, mathint underlyingAssetUnits) returns mathint {
	mathint result = getTotalAsset(e, sender, ghoDecimals, underlyingAssetUnits);
	mathint result1;
	mathint result2;

	if (sender != receiver) {
		result1 = result + getTotalAsset(e, receiver, ghoDecimals, underlyingAssetUnits);
	} else {
		result1 = result;
	}
	if (sender != originator && receiver != originator) {
		result2 = result1 + getTotalAsset(e, originator, ghoDecimals, underlyingAssetUnits);
	} else {
		result2 = result1;
	}

	return result2;
}

// Returns sum of all assets of the given address
function getTotalAsset(env e, address a, mathint ghoDecimals, mathint underlyingAssetUnits) returns mathint {
	return ghoDecimals*balanceOfUnderlying(e,a) + underlyingAssetUnits*balanceOfGho(e,a);
}

function functionDispatcher(method f, env e, address receiver, address originator, uint256 amount) {
	uint256 deadline;
	bytes signature;
	calldataarg args;

	if (f.selector == sig:sellAsset(uint256,address).selector) {
        sellAsset(e, amount, receiver);
	} else if (f.selector == sig:buyAssetWithSig(address,uint256,address,uint256,bytes).selector) {
		buyAssetWithSig(e, originator, amount, receiver, deadline, signature);
	} else if (f.selector == sig:sellAssetWithSig(address,uint256,address,uint256,bytes).selector) {
		sellAssetWithSig(e, originator, amount, receiver, deadline, signature);
	} else if (f.selector == sig:buyAsset(uint256,address).selector) {
		buyAsset(e, amount, receiver);
	} else if (f.selector == sig:giftUnderlyingAsset(address, uint).selector) {
		giftUnderlyingAsset(e, originator, amount);
	} else if (f.selector == sig:giftGho(address, uint).selector) {
		giftGho(e, originator, amount);
	} else {
		f(e,args);
	}
}