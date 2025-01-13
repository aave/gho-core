import "../GsmMethods/methods4626_base.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/aave_price_fee_limits.spec";
import "../GsmMethods/erc4626.spec";

// @title solvency rule - buyAsset Function
// STATUS: VIOLATED
// https://prover.certora.com/output/11775/0b04906c237b4a1e8ac5b7ffc1e9f449?anonymousKey=cf620b132aaadb33116c93025269fbbe5258070c

// rule enoughULtoBackGhoBuyAsset()
// {
// 	uint256 _currentExposure = getAvailableLiquidity();
// 	uint256 _ghoMinted = getGhoMinted();
// 	uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
// 	uint8 underlyingAssetDecimals;
// 	// require underlyingAssetDecimals == 18;
// 	require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

// 	// uint256 priceRatio = _priceStrategy.PRICE_RATIO();
// 	// require priceRatio >= 10^16 && priceRatio <= 10^20;
// 	// uint256 buyFeeBP = getBuyFeeBP();
// 	// require buyFeeBP == 4000;
// 	// rounding up for over-approximation
//     uint256 _ghoBacked = _priceStrategy.getAssetPriceInGho(_currentExposure, true);
//     require _ghoBacked >= _ghoMinted;
// 	env e;
// 	feeLimits(e);
// 	priceLimits(e);

// 	uint256 amount;
// 	address receiver;
	
// 	buyAsset(e, amount, receiver);

// 	uint256 ghoMinted_ = getGhoMinted();
// 	uint256 currentExposure_ = getAvailableLiquidity();
	
// 	// rounding down for over-approximation
//     uint256 ghoBacked_ = _priceStrategy.getAssetPriceInGho(currentExposure_, false);
    
//     assert to_mathint(ghoBacked_+1)>= to_mathint(ghoMinted_)
//     ,"not enough currentExposure to back the ghoMinted";
// }

// @title solvency rule - sellAsset function
// STATUS: TIMEOUT
// https://prover.certora.com/output/11775/bfafe4ddbb6947a8ae86635dd14a6eb8?anonymousKey=4e0a75d10aaadeba18ea4d3a9ecfcfdb0c1f2188
// rule enoughUnderlyingToBackGhoRuleSellAsset()
// {
// 	uint256 _currentExposure = getAvailableLiquidity();
// 	uint256 _ghoMinted = getGhoMinted();
// 	// uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
// 	// uint8 underlyingAssetDecimals;
// 	// require underlyingAssetDecimals == 18;
// 	// require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

// 	// uint256 priceRatio = _priceStrategy.PRICE_RATIO();
// 	// require priceRatio >= 10^16 && priceRatio <= 10^20;
// 	// uint256 sellFeeBP = getSellFeeBP();
// 	// require sellFeeBP == 5000;
//     uint256 _ghoBacked = _priceStrategy.getAssetPriceInGho(_currentExposure,false);
//     require _ghoBacked >= _ghoMinted;

// 	uint128 amount;
// 	address receiver;
	
// 	env e;
// 	feeLimits(e);
// 	priceLimits(e);

// 	sellAsset(e, amount, receiver);

// 	uint256 ghoMinted_ = getGhoMinted();
// 	uint256 currentExposure_ = getAvailableLiquidity();
	
//     uint256 ghoBacked_ = _priceStrategy.getAssetPriceInGho(currentExposure_, false);

//     assert to_mathint(ghoBacked_+1)>= to_mathint(ghoMinted_) ,"not enough currentExposure to back the ghoMinted";
// }


// @title solvency rule for non buy sell functions
// STATUS: PASSED
// https://prover.certora.com/output/11775/434fcceaf67349e19568b66d7457a35f?anonymousKey=6570aa08aa061ffe7bcf4328ff64714d08764215
rule enoughULtoBackGhoNonBuySell(method f)
filtered {
    f -> !f.isView &&
	!harnessOnlyMethods(f) &&
    !buySellAssetsFunctions(f)
}{
	uint256 _currentExposure = getAvailableLiquidity();
	uint256 _ghoMinted = getGhoMinted();
    uint256 _ghoBacked = _priceStrategy.getAssetPriceInGho(_currentExposure,true);
    require _ghoBacked >= _ghoMinted;

    env e;
    calldataarg args;

    f(e, args);
	
	uint256 ghoMinted_ = getGhoMinted();
	uint256 currentExposure_ = getAvailableLiquidity();
	
    uint256 ghoBacked_ = _priceStrategy.getAssetPriceInGho(_currentExposure,true);
    assert ghoBacked_ >= ghoMinted_,"not enough currentExposure to back the ghoMinted";
}


// @title if fee > 0:
// 1. gho received by user is less than assetPriceInGho(underlying amount) in sell asset function
// 2. gho paid by user is more than assetPriceInGho(underlying amount received)
// 3. gho balance of contract goes up

// STATUS: PASSED
// https://prover.certora.com/output/11775/434fcceaf67349e19568b66d7457a35f?anonymousKey=6570aa08aa061ffe7bcf4328ff64714d08764215



rule NonZeroFeeCheckSellAsset(){
	uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
	uint8 underlyingAssetDecimals;
	require underlyingAssetDecimals <78;
	require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;
    address receiver;
    uint256 _receiverGhoBalance = _ghoToken.balanceOf(receiver);
    uint256 _GSMGhoBalance = _ghoToken.balanceOf(currentContract);
	uint256 _accruedFee = getAccruedFees();
    uint256 amount;
    uint256 amountInGho = _priceStrategy.getAssetPriceInGho(amount, false);
	require _FixedFeeStrategy.getSellFee(amountInGho) > 0;
    env e;
	basicBuySellSetup(e, receiver);


    sellAsset(e, amount, receiver);

    uint256 receiverGhoBalance_ = _ghoToken.balanceOf(receiver);
    uint256 GSMGhoBalance_ = _ghoToken.balanceOf(currentContract);
	mathint GSMGhoBalanceIncrease = GSMGhoBalance_ - _GSMGhoBalance;
	uint256 accruedFee_ = getAccruedFees();
	mathint accruedFeeIncrease = accruedFee_ - _accruedFee;
	mathint ghoReceived = receiverGhoBalance_ - _receiverGhoBalance;

	assert ghoReceived < to_mathint(amountInGho),"fee not deducted from gho minted for the given UL amount";
	assert GSMGhoBalance_ > _GSMGhoBalance ,"GMS gho balance should increase on account of fee collected";
	assert accruedFee_ > _accruedFee,"accruedFee should increase in a sell asset transaction";
	assert accruedFeeIncrease == GSMGhoBalanceIncrease,"accrued fee should increase by the same amount as the GSM gho balance";
}


// STATUS: PASSED
// https://prover.certora.com/output/11775/434fcceaf67349e19568b66d7457a35f?anonymousKey=6570aa08aa061ffe7bcf4328ff64714d08764215
rule NonZeroFeeCheckBuyAsset(){
    
	uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
	uint8 underlyingAssetDecimals;
	require underlyingAssetDecimals <78;
	require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;
    address receiver;
    uint256 _receiverGhoBalance = _ghoToken.balanceOf(receiver);
    uint256 _GSMGhoBalance = _ghoToken.balanceOf(currentContract);
	uint256 _accruedFee = getAccruedFees();
    uint256 amount;
    uint256 amountInGho = _priceStrategy.getAssetPriceInGho(amount, true);
	uint256 fee = _FixedFeeStrategy.getBuyFee(amountInGho);
	require  fee > 0;
    env e;
	basicBuySellSetup(e, receiver);


    buyAsset(e, amount, receiver);

    uint256 receiverGhoBalance_ = _ghoToken.balanceOf(receiver);
    uint256 GSMGhoBalance_ = _ghoToken.balanceOf(currentContract);
	mathint GSMGhoBalanceIncrease = GSMGhoBalance_ - _GSMGhoBalance;
	uint256 accruedFee_ = getAccruedFees();
	mathint accruedFeeIncrease = accruedFee_ - _accruedFee;
	mathint ghoReceived = receiverGhoBalance_ - _receiverGhoBalance;

	assert ghoReceived < to_mathint(amountInGho),"fee not deducted from gho minted for the given UL amount";
	assert GSMGhoBalance_ > _GSMGhoBalance ,"GMS gho balance should increase on account of fee collected";
	assert accruedFee_ > _accruedFee,"accruedFee should increase in a sell asset transaction";
	assert accruedFeeIncrease == GSMGhoBalanceIncrease,"accrued fee should increase by the same amount as the GSM gho balance";
}