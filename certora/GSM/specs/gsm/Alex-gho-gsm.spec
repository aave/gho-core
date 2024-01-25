import "../GsmMethods/methods_base.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/aave_price_fee_limits_strict.spec";


// @title solvency rule: (ghoBacked + 1>= ghoMinted) – (insolvency, rescue more funds than should, allocate more funds to allocator) - buyAsset Function
// STATUS: PASSED
// https://prover.certora.com/output/11775/23a09796cb7442679f790c6760b303e1?anonymousKey=c672c1acf218250e313b3d165820544582ce366a
rule enoughULtoBackGhoBuyAsset()
{
	uint256 _currentExposure = getAvailableLiquidity();
	uint256 _ghoMinted = getGhoMinted();
	uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
	uint8 underlyingAssetDecimals;
	require underlyingAssetDecimals <78;
	require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

	// rounding up to check for the stricter case where the starting _currentExposure is possibly slightly less than ideal
    uint256 _ghoBacked = _priceStrategy.getAssetPriceInGho(_currentExposure, true);
    require _ghoBacked >= _ghoMinted;

	uint256 amount;
	address receiver;
	
	env e;
	buyAsset(e, amount, receiver);

	uint256 ghoMinted_ = getGhoMinted();
	uint256 currentExposure_ = getAvailableLiquidity();
	
    uint256 ghoBacked_ = _priceStrategy.getAssetPriceInGho(currentExposure_, false);
    
    assert to_mathint(ghoBacked_ + 1)>= to_mathint(ghoMinted_)
    ,"not enough currentExposure to back the ghoMinted";
}

// @title solvency rule: (ghoBacked + 1>= ghoMinted) – (insolvency, rescue more funds than should, allocate more funds to allocator) - buyAsset Function
// STATUS: PASSED
// https://prover.certora.com/output/11775/23a09796cb7442679f790c6760b303e1?anonymousKey=c672c1acf218250e313b3d165820544582ce366a
rule enoughUnderlyingToBackGhoRuleSellAsset()
{
	uint256 _currentExposure = getAvailableLiquidity();
	uint256 _ghoMinted = getGhoMinted();
	uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
	uint8 underlyingAssetDecimals;
	require underlyingAssetDecimals <78;
	require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;
	// rounding up to check for the stricter case where the starting _currentExposure is possibly slightly less than ideal
    uint256 _ghoBacked = _priceStrategy.getAssetPriceInGho(_currentExposure,true);
    require _ghoBacked >= _ghoMinted;//TRY with backed >= is no TO

	uint128 amount;
	address receiver;
	
	env e;
	sellAsset(e, amount, receiver);

	uint256 ghoMinted_ = getGhoMinted();
	uint256 currentExposure_ = getAvailableLiquidity();
	
    uint256 ghoBacked_ = _priceStrategy.getAssetPriceInGho(currentExposure_, false);

    assert to_mathint(ghoBacked_ + 1)>= to_mathint(ghoMinted_) ,"not enough currentExposure to back the ghoMinted";
}


// @title solvency rule: (ghoBacked + 1>= ghoMinted) – (insolvency, rescue more funds than should, allocate more funds to allocator) - buyAsset Function
// STATUS: PASSED
// https://prover.certora.com/output/11775/23a09796cb7442679f790c6760b303e1?anonymousKey=c672c1acf218250e313b3d165820544582ce366a
rule enoughULtoBackGhoNonBuySell(method f)
filtered {
    f -> !f.isView &&
	!harnessOnlyMethods(f) &&
    !buySellAssetsFunctions(f)
}{
	uint256 _currentExposure = getAvailableLiquidity();
	uint256 _ghoMinted = getGhoMinted();
    uint256 _ghoBacked = _priceStrategy.getAssetPriceInGho(_currentExposure,false);
    require _ghoBacked >= _ghoMinted;

    env e;
    calldataarg args;

    f(e, args);
	
	uint256 ghoMinted_ = getGhoMinted();
	uint256 currentExposure_ = getAvailableLiquidity();
	
    uint256 ghoBacked_ = _priceStrategy.getAssetPriceInGho(_currentExposure,false);
    assert ghoBacked_ >= ghoMinted_,"not enough currentExposure to back the ghoMinted";
}


// // @title property#2 If feePercentage > 0  – (Fees are being charged) )
// if fee > 0:
// 1. gho received by user is less than assetPriceInGho(underlying amount) in sell asset function
// 2. gho paid by user is more than assetPriceInGho(underlying amount received)
// 3. gho balance of contract goes up

// STATUS: PASSED
// https://prover.certora.com/output/11775/23a09796cb7442679f790c6760b303e1?anonymousKey=c672c1acf218250e313b3d165820544582ce366a
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


// @title property#2 If feePercentage > 0  – (Fees are being charged) )
// for buyAsset function
// STATUS: PASSED
// https://prover.certora.com/output/11775/23a09796cb7442679f790c6760b303e1?anonymousKey=c672c1acf218250e313b3d165820544582ce366a
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
