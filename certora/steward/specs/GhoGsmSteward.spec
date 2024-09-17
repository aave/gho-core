using FixedFeeStrategyFactory as FAC;


/*===========================================================================
  This is a specification file for the contract GhoStewardV2.
  The rules were written base on the following:
  https://github.com/aave/gho-core/pull/388

  We check the following aspects:
  - Limitations due to timelocks.
  - For the relevant functions, only autorized sender can call them.
  - When setting new paramethers they are in the correct range.
  - The new paramethers are indeed set.
  =============================================================================*/

methods {
    function _.getPool() external => NONDET;
    function _.getConfiguration(address) external => NONDET;
    function _.getPoolConfigurator() external => NONDET;

    function _.getExposureCap() external => get_EXPOSURE_CAP_cvl() expect uint256 ;
    function _.updateExposureCap(uint128 newCap) external =>
        set_EXPOSURE_CAP_cvl(newCap) expect void ALL;

    function _.getBuyFee(uint256) external => get_BUY_FEE_cvl() expect uint256;
    function _.getSellFee(uint256) external => get_SELL_FEE_cvl() expect uint256;
    function _.updateFeeStrategy(address strategy) external =>
      set_FEE_STRATEGY(strategy) expect void ALL;
    

    function getGsmTimelocks(address) external returns (IGhoGsmSteward.GsmDebounce) envfree;
    function GSM_FEE_RATE_CHANGE_MAX() external returns uint256 envfree;
    function MINIMUM_DELAY() external returns uint256 envfree;
    function RISK_COUNCIL() external returns address envfree;
    function FAC.getFixedFeeStrategy(uint256 buyFee, uint256 sellFee) external returns (address) envfree;
}



ghost uint128 EXPOSURE_CAP {
    axiom 1==1;
}
function get_EXPOSURE_CAP_cvl() returns uint128 {
    return EXPOSURE_CAP;
}
function set_EXPOSURE_CAP_cvl(uint128 newCap) {
    EXPOSURE_CAP = newCap;
}


ghost uint128 BUY_FEE {
    axiom 1==1;
}
function get_BUY_FEE_cvl() returns uint128 {
    return BUY_FEE;
}
ghost uint128 SELL_FEE {
    axiom 1==1;
}
function get_SELL_FEE_cvl() returns uint128 {
    return SELL_FEE;
}
ghost address FEE_STRATEGY {
    axiom 1==1;
}
function set_FEE_STRATEGY(address strategy) {
    FEE_STRATEGY = strategy;
}



/* =================================================================================
   ================================================================================
   Part 1: validity of the timelocks
   =================================================================================
   ==============================================================================*/

// FUNCTION: updateGsmExposureCap
rule gsmExposureCapLastUpdated__updated_only_by_updateGsmExposureCap(method f) {
    env e; calldataarg args;
    address gsm;

    uint40 gsmExposureCapLastUpdated_before = getGsmTimelocks(gsm).gsmExposureCapLastUpdated;
    f(e,args);
    uint40 gsmExposureCapLastUpdated_after = getGsmTimelocks(gsm).gsmExposureCapLastUpdated;

    assert (gsmExposureCapLastUpdated_after != gsmExposureCapLastUpdated_before) =>
        f.selector == sig:updateGsmExposureCap(address,uint128).selector;
}

rule updateGsmExposureCap_update_correctly__gsmExposureCapLastUpdated() {
    env e;  address gsm;   uint128 newExposureCap;
    updateGsmExposureCap(e,gsm, newExposureCap);
    assert getGsmTimelocks(gsm).gsmExposureCapLastUpdated == require_uint40(e.block.timestamp);
}

rule updateGsmExposureCap_timelock() {
    env e;  address gsm;   uint128 newExposureCap;
    uint40 gsmExposureCapLastUpdated_before = getGsmTimelocks(gsm).gsmExposureCapLastUpdated;
    updateGsmExposureCap(e,gsm, newExposureCap);

    assert to_mathint(e.block.timestamp) > gsmExposureCapLastUpdated_before + MINIMUM_DELAY();
}



// FUNCTION: updateGsmBuySellFees
rule gsmFeeStrategyLastUpdated__updated_only_by_updateGsmBuySellFees(method f) {
    env e; calldataarg args;
    address gsm;

    uint40 gsmFeeStrategyLastUpdated_before = getGsmTimelocks(gsm).gsmFeeStrategyLastUpdated;
    f(e,args);
    uint40 gsmFeeStrategyLastUpdated_after = getGsmTimelocks(gsm).gsmFeeStrategyLastUpdated;

    assert (gsmFeeStrategyLastUpdated_after != gsmFeeStrategyLastUpdated_before) =>
        f.selector == sig:updateGsmBuySellFees(address,uint256,uint256).selector;
}

rule updateGsmBuySellFees_update_correctly__gsmFeeStrategyLastUpdated() {
    env e;  address gsm;  uint256 buyFee;  uint256 sellFee;
    updateGsmBuySellFees(e,gsm, buyFee, sellFee);
    assert getGsmTimelocks(gsm).gsmFeeStrategyLastUpdated == require_uint40(e.block.timestamp);
}

rule updateGsmBuySellFees_timelock() {
    env e;  address gsm;  uint256 buyFee;  uint256 sellFee;
    uint40 gsmFeeStrategyLastUpdated_before = getGsmTimelocks(gsm).gsmFeeStrategyLastUpdated;
    updateGsmBuySellFees(e,gsm, buyFee, sellFee);

    assert to_mathint(e.block.timestamp) > gsmFeeStrategyLastUpdated_before + MINIMUM_DELAY();
}




/* =================================================================================
   ================================================================================
   Part 2: autorized message sender
   =================================================================================
   ==============================================================================*/
rule only_RISK_COUNCIL_can_call__updateGsmExposureCap() {
    env e;  address gsm;  uint128 newExposureCap;

    updateGsmExposureCap(e,gsm,newExposureCap);
    assert (e.msg.sender==RISK_COUNCIL());
}
rule only_RISK_COUNCIL_can_call__updateGsmBuySellFees() {
    env e;  address gsm;  uint256 buyFee;  uint256 sellFee;

    updateGsmBuySellFees(e,gsm,buyFee,sellFee);
    assert (e.msg.sender==RISK_COUNCIL());
}



/* =================================================================================
   ================================================================================
   Part 3: correctness of the main functions. 
   We check the validity of the new paramethers values, and that are indeed set.
   =================================================================================
   ==============================================================================*/
rule updateGsmExposureCap__correctness() {
    env e;  address gsm;  uint128 newExposureCap;
    uint128 exposure_cap_before = EXPOSURE_CAP;
    updateGsmExposureCap(e,gsm,newExposureCap);
    assert EXPOSURE_CAP==newExposureCap;
    
    uint128 exposure_cap_after = EXPOSURE_CAP;
    assert to_mathint(exposure_cap_after) <= 2*exposure_cap_before;
}


rule updateGsmBuySellFees__correctness() {
    env e;  address gsm;  uint256 buyFee;  uint256 sellFee;
    uint256 buyFee_before = BUY_FEE;
    uint256 sellFee_before = SELL_FEE;
    updateGsmBuySellFees(e,gsm,buyFee,sellFee);
    assert FAC.getFixedFeeStrategy(buyFee,sellFee)==FEE_STRATEGY;

    assert to_mathint(buyFee) <= buyFee_before + GSM_FEE_RATE_CHANGE_MAX();
    assert to_mathint(sellFee) <= sellFee_before + GSM_FEE_RATE_CHANGE_MAX();
}







/* =================================================================================
   Rule: sanity.
   Status: PASS.
   ================================================================================*/
rule sanity(method f) {
    env e;
    calldataarg args;
    f(e,args);
    satisfy true;
}
