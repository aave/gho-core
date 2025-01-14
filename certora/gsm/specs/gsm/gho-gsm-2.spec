import "../GsmMethods/shared.spec";

using GhoToken as _ghoTokenHook;
using DummyERC20B as UNDERLYING_ASSET;

using FixedPriceStrategyHarness as _priceStrategy;
using FixedFeeStrategyHarness as _FixedFeeStrategy;


methods {
   // priceStrategy

    function _priceStrategy.getAssetPriceInGho(uint256, bool) external returns(uint256) envfree;
    function _priceStrategy.getUnderlyingAssetUnits() external returns(uint256) envfree;
	function _priceStrategy.getUnderlyingAssetDecimals() external returns(uint256) envfree;

    // feeStrategy

    function _FixedFeeStrategy.getBuyFeeBP() external returns(uint256) envfree;
    function _FixedFeeStrategy.getSellFeeBP() external returns(uint256) envfree;
}

// @title Rule checks that _accruedFees should be <= ghotoken.balanceof(this) with an exception of the function distributeFeesToTreasury().
// STATUS: PASS
// https://prover.certora.com/output/11775/281e0b05ac0345edb1d398dcbc329c19?anonymousKey=376f01ddc0cf54741e33c334e83547bb12adba23
rule accruedFeesLEGhoBalanceOfThis(method f) filtered {
    f -> !f.isView &&
	!harnessOnlyMethods(f)
} {
    env e;
    calldataarg args;

    require(getAccruedFee(e) <= getGhoBalanceOfThis(e));
    require(e.msg.sender != currentContract);
	require(UNDERLYING_ASSET(e) != GHO_TOKEN(e));

    if (f.selector == sig:buyAssetWithSig(address,uint256,address,uint256,bytes).selector) {
	    address receiver;
	    uint256 amount;
	    address originator;
	    uint256 deadline;
	    bytes signature;
        require(originator != currentContract);
        buyAssetWithSig(e, originator, amount, receiver, deadline, signature);
    } else {
        f(e,args);
    }

    assert getAccruedFee(e) <= getGhoBalanceOfThis(e);
}

// @title _accruedFees should never decrease, unless fees are being harvested by Treasury
// STATUS: PASS
// https://prover.certora.com/output/11775/281e0b05ac0345edb1d398dcbc329c19?anonymousKey=376f01ddc0cf54741e33c334e83547bb12adba23
rule accruedFeesNeverDecrease(method f) filtered {f -> f.selector != sig:distributeFeesToTreasury().selector &&
	!harnessOnlyMethods(f)} {
    env e;
    calldataarg args;
    uint256 feesBefore = getAccruedFee(e);

    f(e,args);

    assert feesBefore <= getAccruedFee(e);
}

// @title For price ratio == 1, the total assets of a user should not increase
// STATUS: PASS
// https://prover.certora.com/output/31688/5c6b516ac67c4417a37e00d4bbc7f0d4/?anonymousKey=9d2c66dfc469003c10961d645f398ae3f8cdf1d8
rule totalAssetsNotIncrease(method f) filtered {f -> f.selector != sig:seize().selector
    && f.selector != sig:rescueTokens(address, address, uint256).selector &&
	f.selector != sig:distributeFeesToTreasury().selector  &&
	f.selector != sig:buyAssetWithSig(address, uint256, address, uint256, bytes).selector &&
	f.selector != sig:sellAssetWithSig(address, uint256, address, uint256, bytes).selector &&
	!harnessOnlyMethods(f)} {
	env e;

	// we focus on a user so remove address of contracts
	require e.msg.sender != currentContract;

	require(getPriceRatio() == 10^18);
	// uint8 underlyingAssetDecimals;
	// require underlyingAssetDecimals <= 36;
	feeLimits(e);
	priceLimits(e);
	// require to_mathint(_priceStrategy.getUnderlyingAssetUnits()) == 10^underlyingAssetDecimals;
	mathint underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits();

	address other;
	address receiver;
	uint256 amount;
	address originator;

	require(getAssetPriceInGho(e, amount, false) * underlyingAssetUnits/getPriceRatio() == to_mathint(amount));

	require receiver != currentContract;
	require originator != currentContract;
	require other != e.msg.sender && other != receiver && other != originator && other != currentContract;
	mathint totalAssetOtherBefore = getTotalAsset(e, other, getPriceRatio(), underlyingAssetUnits);

	mathint totalAssetBefore = assetOfUsers(e, e.msg.sender, receiver, originator, getPriceRatio(), underlyingAssetUnits);

	functionDispatcher(f, e, receiver, originator, amount);

	mathint totalAssetAfter = assetOfUsers(e, e.msg.sender, receiver, originator, getPriceRatio(), underlyingAssetUnits);

	assert totalAssetBefore >= totalAssetAfter;
	assert totalAssetOtherBefore == getTotalAsset(e, other, getPriceRatio(), underlyingAssetUnits);
}

// @title Rule checks that an overall asset of the system (UA - minted gho) stays same.
// STATUS: PASS
// https://prover.certora.com/output/31688/92138d4951324b81893fdfb04177dd6a/?anonymousKey=8fadc4e00f7004dfe3525dba321d29a8a9c31424
rule systemBalanceStabilityBuy() {
	uint256 amount;
	address receiver;
	env e;
	require currentContract != e.msg.sender;
	require currentContract != receiver;

	// require(getPriceRatio() == 10^18);
	// uint8 underlyingAssetDecimals;
	// require underlyingAssetDecimals <= 25;
	// require to_mathint(_priceStrategy.getUnderlyingAssetUnits()) == 10^underlyingAssetDecimals;
	// require _priceStrategy.getUnderlyingAssetDecimals() <= 25;
	// require to_mathint(_priceStrategy.getUnderlyingAssetUnits()) == 10^_priceStrategy.getUnderlyingAssetDecimals();
	feeLimits(e);
	priceLimits(e);

	mathint ghoMintedBefore = getGhoMinted(e);
	mathint balanceBefore = getAssetPriceInGho(e, balanceOfUnderlying(e, currentContract), false) - ghoMintedBefore;

	buyAsset(e, amount, receiver);

	mathint ghoMintedAfter = getGhoMinted(e);
	mathint balanceAfter = getAssetPriceInGho(e, balanceOfUnderlying(e, currentContract), false) - ghoMintedAfter;

	assert(balanceAfter + 1 >= balanceBefore && balanceAfter <= balanceBefore + 1);
	// assert balanceAfter + 1 >= balanceBefore;
}

// @title Rule checks that an overall asset of the system (UA - minted gho) stays same.
// STATUS: PASS
// https://prover.certora.com/output/11775/281e0b05ac0345edb1d398dcbc329c19?anonymousKey=376f01ddc0cf54741e33c334e83547bb12adba23
rule systemBalanceStabilitySell() {
	uint256 amount;
	address receiver;
	env e;
	require currentContract != e.msg.sender;
	require currentContract != receiver;

	// uint8 underlyingAssetDecimals;
	// require underlyingAssetDecimals <= 25;
	// mathint underlyingAssetUnits = 10^underlyingAssetDecimals;
	// require to_mathint(_priceStrategy.getUnderlyingAssetUnits()) == underlyingAssetUnits;
	// require(getPriceRatio() == 10^18);
	feeLimits(e);
	priceLimits(e);

	mathint ghoMintedBefore = getGhoMinted(e);
	mathint balanceBefore = getPriceRatio()*balanceOfUnderlying(e, currentContract)/_priceStrategy.getUnderlyingAssetUnits() - ghoMintedBefore;

	sellAsset(e, amount, receiver);

	mathint ghoMintedAfter = getGhoMinted(e);
	mathint balanceAfter = getPriceRatio()*balanceOfUnderlying(e, currentContract)/_priceStrategy.getUnderlyingAssetUnits() - ghoMintedAfter;

	// assert(balanceAfter + 1 >= balanceBefore && balanceAfter <= balanceBefore + 1);
	assert balanceAfter + 1 >= balanceBefore;
}

