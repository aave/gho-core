using FixedRateStrategyFactory as FAC;


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

    function _.getBorrowCap(DataTypes.ReserveConfigurationMap memory) internal =>
        get_BORROW_CAP_cvl() expect uint256 ;
    function _.setBorrowCap(address token, uint256 newCap) external =>
        set_BORROW_CAP_cvl(token,newCap) expect void ALL;

    function _.getBaseVariableBorrowRate() external =>
        get_BORROW_RATE_cvl() expect uint256;
    function _.setReserveInterestRateStrategyAddress(address,address strategy) external =>
        set_STRATEGY(strategy) expect void ALL;

    function _.getExposureCap() external => get_EXPOSURE_CAP_cvl() expect uint256 ;
    function _.updateExposureCap(uint128 newCap) external =>
        set_EXPOSURE_CAP_cvl(newCap) expect void ALL;

    function _.getBuyFee(uint256) external => get_BUY_FEE_cvl() expect uint256;
    function _.getSellFee(uint256) external => get_SELL_FEE_cvl() expect uint256;
    function _.updateFeeStrategy(address strategy) external =>
        set_FEE_STRATEGY(strategy) expect void ALL;
    

    function owner() external returns (address) envfree;
    function getGhoTimelocks() external returns (IGhoStewardV2.GhoDebounce) envfree;
    function getGsmTimelocks(address) external returns (IGhoStewardV2.GsmDebounce) envfree;
    function GHO_BORROW_RATE_CHANGE_MAX() external returns uint256 envfree;
    function GSM_FEE_RATE_CHANGE_MAX() external returns uint256 envfree;
    function GHO_BORROW_RATE_MAX() external returns uint256 envfree;
    function MINIMUM_DELAY() external returns uint256 envfree;
    function RISK_COUNCIL() external returns address envfree;
    function FAC.getStrategyByRate(uint256) external returns (address) envfree;
    function get_gsmFeeStrategiesByRates(uint256,uint256) external returns(address) envfree;
}


ghost uint256 BORROW_CAP {
    axiom 1==1;
}
function get_BORROW_CAP_cvl() returns uint256 {
    return BORROW_CAP;
}
function set_BORROW_CAP_cvl(address token, uint256 newCap) {
    BORROW_CAP = newCap;
}

ghost uint256 BORROW_RATE {
    axiom BORROW_RATE <= 10^27;
}
function get_BORROW_RATE_cvl() returns uint256 {
    return BORROW_RATE;
}

ghost address STRATEGY {
    axiom 1==1;
}
function set_STRATEGY(address strategy) {
    STRATEGY = strategy;
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

// FUNCTION: updateGhoBorrowCap
rule ghoBorrowCapLastUpdate__updated_only_by_updateGhoBorrowCap(method f) {
    env e; calldataarg args;

    uint40 ghoBorrowCapLastUpdate_before = getGhoTimelocks().ghoBorrowCapLastUpdate;
    f(e,args);
    uint40 ghoBorrowCapLastUpdate_after = getGhoTimelocks().ghoBorrowCapLastUpdate;

    assert (ghoBorrowCapLastUpdate_after != ghoBorrowCapLastUpdate_before) =>
        f.selector == sig:updateGhoBorrowCap(uint256).selector;
}

rule updateGhoBorrowCap_update_correctly__ghoBorrowCapLastUpdate() {
    env e;  uint256 newBorrowCap;
    updateGhoBorrowCap(e,newBorrowCap);
    assert getGhoTimelocks().ghoBorrowCapLastUpdate == require_uint40(e.block.timestamp);
}

rule updateGhoBorrowCap_timelock() {
    uint40 ghoBorrowCapLastUpdate_before = getGhoTimelocks().ghoBorrowCapLastUpdate;
    env e;  uint256 newBorrowCap;
    updateGhoBorrowCap(e,newBorrowCap);

    assert to_mathint(e.block.timestamp) > ghoBorrowCapLastUpdate_before + MINIMUM_DELAY();
}


// FUNCTION: updateGhoBorrowRate
rule ghoBorrowRateLastUpdate__updated_only_by_updateGhoBorrowRate(method f) {
    env e; calldataarg args;

    uint40 ghoBorrowRateLastUpdate_before = getGhoTimelocks().ghoBorrowRateLastUpdate;
    f(e,args);
    uint40 ghoBorrowRateLastUpdate_after = getGhoTimelocks().ghoBorrowRateLastUpdate;

    assert (ghoBorrowRateLastUpdate_after != ghoBorrowRateLastUpdate_before) =>
        f.selector == sig:updateGhoBorrowRate(uint256).selector;
}

rule updateGhoBorrowRate_update_correctly__ghoBorrowRateLastUpdate() {
    env e;  uint256 newBorrowRate;
    updateGhoBorrowRate(e,newBorrowRate);
    assert getGhoTimelocks().ghoBorrowRateLastUpdate == require_uint40(e.block.timestamp);
}

rule updateGhoBorrowRate_timelock() {
    uint40 ghoBorrowRateLastUpdate_before = getGhoTimelocks().ghoBorrowRateLastUpdate;
    env e;  uint256 newBorrowRate;
    updateGhoBorrowRate(e,newBorrowRate);

    assert to_mathint(e.block.timestamp) > ghoBorrowRateLastUpdate_before + MINIMUM_DELAY();
}



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
rule only_RISK_COUNCIL_can_call__updateFacilitatorBucketCapacity() {
    env e;  address facilitator;  uint128 newBucketCapacity;

    updateFacilitatorBucketCapacity(e,facilitator,newBucketCapacity);
    assert (e.msg.sender==RISK_COUNCIL());
}
rule only_RISK_COUNCIL_can_call__updateGhoBorrowCap() {
    env e;  uint256 newBorrowCap;

    updateGhoBorrowCap(e,newBorrowCap);
    assert (e.msg.sender==RISK_COUNCIL());
}
rule only_RISK_COUNCIL_can_call__updateGhoBorrowRate() {
    env e;  uint256 newBorrowRate;

    updateGhoBorrowRate(e,newBorrowRate);
    assert (e.msg.sender==RISK_COUNCIL());
}
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
rule only_owner_can_call__setControlledFacilitator() {
    env e;
    address[] facilitatorList;
    bool approve;

    setControlledFacilitator(e,facilitatorList,approve);
    assert (e.msg.sender==owner());
}



/* =================================================================================
   ================================================================================
   Part 3: correctness of the main functions. 
   We check the validity of the new paramethers values, and that are indeed set.
   =================================================================================
   ==============================================================================*/
rule updateGhoBorrowCap__correctness() {
    env e;  uint256 newBorrowCap;
    uint256 borrow_cap_before = BORROW_CAP;
    updateGhoBorrowCap(e,newBorrowCap);
    assert BORROW_CAP==newBorrowCap;

    uint256 borrow_cap_after = BORROW_CAP;
    assert 0 <= to_mathint(borrow_cap_after) && to_mathint(borrow_cap_after) <= 2*borrow_cap_before;
}


rule updateGhoBorrowRate__correctness() {
    env e;  uint256 newBorrowRate;
    uint256 borrow_rate_before = BORROW_RATE;
    updateGhoBorrowRate(e,newBorrowRate);
    assert FAC.getStrategyByRate(newBorrowRate) == STRATEGY;

    assert (borrow_rate_before-GHO_BORROW_RATE_CHANGE_MAX() <= to_mathint(newBorrowRate)
            &&
            to_mathint(newBorrowRate) <= borrow_rate_before+GHO_BORROW_RATE_CHANGE_MAX());
    assert (newBorrowRate <= GHO_BORROW_RATE_MAX());
}


rule updateGsmExposureCap__correctness() {
    env e;  address gsm;  uint128 newExposureCap;
    uint128 exposure_cap_before = EXPOSURE_CAP;
    updateGsmExposureCap(e,gsm,newExposureCap);
    assert EXPOSURE_CAP==newExposureCap;
    
    uint128 exposure_cap_after = EXPOSURE_CAP;
    assert 0 <= to_mathint(exposure_cap_after) &&
        to_mathint(exposure_cap_after) <= 2*exposure_cap_before;
}


rule updateGsmBuySellFees__correctness() {
    env e;  address gsm;  uint256 buyFee;  uint256 sellFee;
    uint256 buyFee_before = BUY_FEE;
    uint256 sellFee_before = SELL_FEE;
    updateGsmBuySellFees(e,gsm,buyFee,sellFee);
    assert get_gsmFeeStrategiesByRates(buyFee,sellFee)==FEE_STRATEGY;

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
