import "../GsmMethods/shared.spec";
import "../GsmMethods/erc4626.spec";

using GhoToken as _ghoTokenHook;
using DummyERC20B as UNDERLYING_ASSET;

using FixedPriceStrategy4626Harness as _priceStrategy;
using FixedFeeStrategyHarness as _FixedFeeStrategy;

methods {
   // priceStrategy
    function _priceStrategy.getAssetPriceInGho(uint256, bool) external returns(uint256) envfree;
    function _priceStrategy.getUnderlyingAssetUnits() external returns(uint256) envfree;

    // feeStrategy
    function _FixedFeeStrategy.getBuyFeeBP() external returns(uint256) envfree;
    function _FixedFeeStrategy.getSellFeeBP() external returns(uint256) envfree;
}

// @title Rule checks that In the event the underlying asset increases in value relative
// to the amount of GHO minted, excess yield harvesting should never result
// in previously-minted GHO having less backing (i.e., as new GHO is minted backed
// by the excess, it should not result in the GSM becoming under-backed in the same block).
// STATUS: VIOLATED
// Run: https://prover.certora.com/output/11775/de602da1d4cc426bb067f9a0aa4a9a05?anonymousKey=a6365b8a651e118c4ccdfb59df46c26a4d3d32b4
rule yieldNeverDecreasesBacking() {
	env e;
	require(getExceed(e) > 0);
	cumulateYieldInGho(e);
	assert getDearth(e) == 0;
}

// @title Rule checks that _accruedFees should be <= ghotoken.balanceof(this) with an exception of the function distributeFeesToTreasury().
// STATUS: PASS
// Run: https://prover.certora.com/output/11775/d3603bd8c03942df80d02a2043b171ca?anonymousKey=0d708c3d21d302cfad1eba8deac83f6eb919cbe2
rule accruedFeesLEGhoBalanceOfThis(method f) {
    env e;
    calldataarg args;

    require(getAccruedFee(e) <= getGhoBalanceOfThis(e));
    require(e.msg.sender != currentContract);
	require(UNDERLYING_ASSET(e) != GHO_TOKEN(e));

    if (f.selector == sig:buyAssetWithSig(address,uint256,address,uint256,bytes).selector) {
	    address originator;
	    uint256 amount;
	    address receiver;
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
// Run: https://prover.certora.com/output/31688/1c8ec1e853e849c5aa4fd26914d0acf3?anonymousKey=30813ba939a055af5f0a09f097782c9805b980a8 
rule accruedFeesNeverDecrease(method f) filtered {f -> f.selector != sig:distributeFeesToTreasury().selector} {
    env e;
    calldataarg args;
    uint256 feesBefore = getAccruedFee(e);

    f(e,args);

    assert feesBefore <= getAccruedFee(e);
}

// @title For price ratio == 1, the total assets of a user should not increase.
// STATUS: VIOLATED
// https://prover.certora.com/output/11775/8448c89e18e94cb9a9ba21eb95b2efb0?anonymousKey=6f9f80c71040f75b35dece32a73442f84140e6ce
//  https://prover.certora.com/output/31688/4f70640081d6419fa999271d91a4ba89?anonymousKey=877a8c262875da9a8c04bda11d0c36facf5aa390
// Passing with Antti's model of 4626 (with some timeouts) https://prover.certora.com/output/31688/7c83d14232934b349d17569688a741fe?anonymousKey=0b7f3177ea39762c6d9fa1be1f7b969bda29f233
//
// For price ratio == 1, the total assets of a user should not increase
rule totalAssetsNotIncrease(method f) filtered {f -> f.selector != sig:seize().selector
    && f.selector != sig:rescueTokens(address, address, uint256).selector &&
	f.selector != sig:distributeFeesToTreasury().selector &&
	f.selector != sig:giftGho(address, uint256).selector &&
	f.selector != sig:giftUnderlyingAsset(address, uint256).selector &&
	f.selector != sig:buyAssetWithSig(address, uint256, address, uint256, bytes).selector &&
	f.selector != sig:sellAssetWithSig(address, uint256, address, uint256, bytes).selector} {
	env e;

	// we focuse on a user so remove address of contracts
	require e.msg.sender != currentContract;

	require(getPriceRatio() == 10^18);
	// uint8 underlyingAssetDecimals;
	// require underlyingAssetDecimals <= 36;
	// require to_mathint(_priceStrategy.getUnderlyingAssetUnits()) == 10^underlyingAssetDecimals;
	feeLimits(e);
	priceLimits(e);
	mathint underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits();

	address other;
	address receiver;
	uint256 amount;
	address originator;

	// This is here due to FixedPriceStrategy4626 since we need
	// to say that previewRedeem respects price ratio == 1, i.e.,
	// you still buy same amount of shares for the given gho.
	require(getAssetPriceInGho(e, amount, false) * underlyingAssetUnits/getPriceRatio() == to_mathint(amount));

	require receiver != currentContract; // && receiver != originator &&  receiver != e.msg.sender;
	require originator != currentContract; // && originator != e.msg.sender;
	require other != e.msg.sender && other != receiver && other != originator && other != currentContract;
	mathint totalAssetOtherBefore = getTotalAsset(e, other, getPriceRatio(), underlyingAssetUnits);

	mathint totalAssetBefore = assetOfUsers(e, e.msg.sender, receiver, originator, getPriceRatio(), underlyingAssetUnits);

	functionDispatcher(f, e, receiver, originator, amount);

	mathint totalAssetAfter = assetOfUsers(e, e.msg.sender, receiver, originator, getPriceRatio(), underlyingAssetUnits);

	assert totalAssetBefore >= totalAssetAfter;
	assert totalAssetOtherBefore == getTotalAsset(e, other, getPriceRatio(), underlyingAssetUnits);
}


// @title Rule checks that an overall asset of the system (UA - minted gho) stays same.
// STATUS: VIOLATED
// https://prover.certora.com/output/11775/de602da1d4cc426bb067f9a0aa4a9a05?anonymousKey=a6365b8a651e118c4ccdfb59df46c26a4d3d32b4
// The attempts to solve the timeout:
// For the general condition:
//   - general limits + standard timeout - https://prover.certora.com/output/31688/a49f76f4578b4b4ab70b72576bbb0189?anonymousKey=bc3a2e3aae14596c9ba1adc5c566b718c4d02e96
//   - 1000 fees && fixed price ratio + standard timeout - https://prover.certora.com/output/31688/08d21e1c60a546cda151d762d3e6acf2?anonymousKey=50f50e1fc767bae84a3b44c9d4a92aad03cdcc4e
//   - 1000 fees && fixed price ratio + 10000 smt solving timeout - https://prover.certora.com/output/31688/0f520b4cf02e4770a804a94bc49120ec?anonymousKey=5581daad6a74234f25bc80a170fd92ace68f4f4c
//   - Rule is split to individual ones with fixed UA decimal units https://prover.certora.com/output/31688/5b6cd5108e544841bb30c48852827007?anonymousKey=0a0aa495023d36ecceeb386fe5b170392da2627b
// Provd that no underbacking happes, i.e. diff >= 0
//   - general limits + standard timeout https://prover.certora.com/output/31688/caa6714046234cd18e4f09c397dfeec4?anonymousKey=00dc26cf5a0b355c09092650aae7e1f1adf48136
rule systemBalanceStabilitySell() {
	uint256 amount;
	address receiver;
	env e;
	require currentContract != e.msg.sender;
	require currentContract != receiver;

	feeLimits(e);
	priceLimits(e);
	require(getAssetPriceInGho(e, amount, false) * _priceStrategy.getUnderlyingAssetUnits()/getPriceRatio() == to_mathint(amount));

	mathint ghoMintedBefore = getGhoMinted(e);
	mathint balanceBefore = balanceOfUnderlyingDirect(e, currentContract);

	sellAsset(e, amount, receiver);

	mathint ghoMintedAfter = getGhoMinted(e);
	mathint balanceAfter = balanceOfUnderlyingDirect(e, currentContract);

	mathint diff = getAssetPriceInGho(e, assert_uint256(balanceAfter - balanceBefore), false) - ghoMintedAfter + ghoMintedBefore;
	//assert diff >= 0; // no underbacking
	assert diff >= 0 && diff <= 1;
}


// @title Rule checks that an overall asset of the system (UA - minted gho) stays same.
// STATUS: TIMEOUT
// https://prover.certora.com/output/31688/905f225066a04f9394d8ea5adee5274d?anonymousKey=5c95ad70db18bf9b3dcdc74f7f781e01e50d0550
// No underbacking happens, i.e. diff <= 1 - proved https://prover.certora.com/output/31688/16161fec79664619a9a72c52a58cb36a/?anonymousKey=80739ecd169b7e28964092556cb66c0e9aa42ebc
rule systemBalanceStabilityBuy() {
	uint256 amount;
	address receiver;
	env e;
	require currentContract != e.msg.sender;
	require currentContract != receiver;

	feeLimits(e);
	priceLimits(e);
	require(getAssetPriceInGho(e, amount, false) * _priceStrategy.getUnderlyingAssetUnits()/getPriceRatio() == to_mathint(amount));

	uint256 ghoBucketCapacity;
	uint256 ghoMintedBefore;
	ghoBucketCapacity, ghoMintedBefore = getFacilitatorBucket(e);
	mathint balanceBefore = balanceOfUnderlyingDirect(e, currentContract);
	mathint ghoExceedBefore = getExceed(e);
	require ghoBucketCapacity - ghoMintedBefore > ghoExceedBefore;

	buyAsset(e, amount, receiver);

	mathint ghoMintedAfter = getGhoMinted(e);
	mathint balanceAfter = balanceOfUnderlyingDirect(e, currentContract);


	mathint diff = getAssetPriceInGho(e, assert_uint256(balanceBefore - balanceAfter), true) - ghoMintedBefore + ghoMintedAfter - ghoExceedBefore;
	// assert diff <= 1; // No underbacking happens.
	assert -1 <= diff && diff <= 1;
}

