
/*===========================================================================
  This is a specification file for the contract GhoAaveSteward.
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

    function _.getSupplyCap(DataTypes.ReserveConfigurationMap memory) internal =>
        get_SUPPLY_CAP_cvl() expect uint256 ;
    function _.setSupplyCap(address token, uint256 newCap) external =>
        set_SUPPLY_CAP_cvl(token,newCap) expect void ALL;

    function _._getInterestRatesForAsset(address) internal =>
      get_INTEREST_RATE_cvl() expect (uint256,uint256,uint256,uint256);

    

    function getGhoTimelocks() external returns (IGhoAaveSteward.GhoDebounce) envfree;
    function MINIMUM_DELAY() external returns uint256 envfree;
    function RISK_COUNCIL() external returns address envfree;

    function owner() external returns address envfree;
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

ghost uint256 SUPPLY_CAP {
    axiom 1==1;
}
function get_SUPPLY_CAP_cvl() returns uint256 {
    return SUPPLY_CAP;
}
function set_SUPPLY_CAP_cvl(address token, uint256 newCap) {
    SUPPLY_CAP = newCap;
}


ghost uint16 OPTIMAL_USAGE_RATIO;
ghost uint32 BASE_VARIABLE_BORROW_RATE;
ghost uint32 VARIABLE_RATE_SLOPE1;
ghost uint32 VARIABLE_RATE_SLOPE2;

function get_INTEREST_RATE_cvl() returns (uint16, uint32, uint32, uint32) {
  return (OPTIMAL_USAGE_RATIO,BASE_VARIABLE_BORROW_RATE,VARIABLE_RATE_SLOPE1,VARIABLE_RATE_SLOPE2);
}





/* =================================================================================
   ================================================================================
   Part 1: validity of the timelocks
   =================================================================================
   ==============================================================================*/

// FUNCTION: updateGhoBorrowRate
rule ghoBorrowRateLastUpdate__updated_only_by_updateGhoBorrowRate(method f) {
    env e; calldataarg args;

    uint40 ghoBorrowRateLastUpdate_before = getGhoTimelocks().ghoBorrowRateLastUpdate;
    f(e,args);
    uint40 ghoBorrowRateLastUpdate_after = getGhoTimelocks().ghoBorrowRateLastUpdate;

    assert (ghoBorrowRateLastUpdate_after != ghoBorrowRateLastUpdate_before) =>
      f.selector == sig:updateGhoBorrowRate(uint16,uint32,uint32,uint32).selector;
}
rule updateGhoBorrowRate_update_correctly__ghoBorrowRateLastUpdate() {
    env e;  uint16 optimalUsageRatio; uint32 baseVariableBorrowRate;
    uint32 variableRateSlope1; uint32 variableRateSlope2;
    updateGhoBorrowRate(e,optimalUsageRatio, baseVariableBorrowRate,
                        variableRateSlope1, variableRateSlope2);
    assert getGhoTimelocks().ghoBorrowRateLastUpdate == require_uint40(e.block.timestamp);
}
rule updateGhoBorrowRate_timelock() {
    uint40 ghoBorrowRateLastUpdate_before = getGhoTimelocks().ghoBorrowRateLastUpdate;
    env e;  uint16 optimalUsageRatio; uint32 baseVariableBorrowRate;
    uint32 variableRateSlope1; uint32 variableRateSlope2;

    updateGhoBorrowRate(e,optimalUsageRatio, baseVariableBorrowRate,
                        variableRateSlope1, variableRateSlope2);

    assert to_mathint(e.block.timestamp) > ghoBorrowRateLastUpdate_before + MINIMUM_DELAY();
}


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


// FUNCTION: updateGhoSupplyCap
rule ghoSupplyCapLastUpdate__updated_only_by_updateGhoSupplyCap(method f) {
    env e; calldataarg args;

    uint40 ghoSupplyCapLastUpdate_before = getGhoTimelocks().ghoSupplyCapLastUpdate;
    f(e,args);
    uint40 ghoSupplyCapLastUpdate_after = getGhoTimelocks().ghoSupplyCapLastUpdate;

    assert (ghoSupplyCapLastUpdate_after != ghoSupplyCapLastUpdate_before) =>
        f.selector == sig:updateGhoSupplyCap(uint256).selector;
}
rule updateGhoSupplyCap_update_correctly__ghoSupplyCapLastUpdate() {
    env e;  uint256 newSupplyCap;
    updateGhoSupplyCap(e,newSupplyCap);
    assert getGhoTimelocks().ghoSupplyCapLastUpdate == require_uint40(e.block.timestamp);
}
rule updateGhoSupplyCap_timelock() {
    uint40 ghoSupplyCapLastUpdate_before = getGhoTimelocks().ghoSupplyCapLastUpdate;
    env e;  uint256 newSupplyCap;
    updateGhoSupplyCap(e,newSupplyCap);

    assert to_mathint(e.block.timestamp) > ghoSupplyCapLastUpdate_before + MINIMUM_DELAY();
}


/* =================================================================================
   ================================================================================
   Part 2: autorized message sender
   =================================================================================
   ==============================================================================*/
rule only_RISK_COUNCIL_can_call__updateGhoBorrowCap() {
    env e;  uint256 newBorrowCap;

    updateGhoBorrowCap(e,newBorrowCap);
    assert (e.msg.sender==RISK_COUNCIL());
}
rule only_RISK_COUNCIL_can_call__updateGhoBorrowRate() {
    env e;  uint16 optimalUsageRatio; uint32 baseVariableBorrowRate;
    uint32 variableRateSlope1; uint32 variableRateSlope2;

    updateGhoBorrowRate(e,optimalUsageRatio, baseVariableBorrowRate,
                        variableRateSlope1, variableRateSlope2);
    assert (e.msg.sender==RISK_COUNCIL());
}
rule only_RISK_COUNCIL_can_call__updateGhoSupplyCap() {
    env e;  uint256 newSupplyCap;

    updateGhoSupplyCap(e,newSupplyCap);
    assert (e.msg.sender==RISK_COUNCIL());
}
rule only_owner_can_call__setBorrowRateConfig() {
    env e;  
    uint16 optimalUsageRatioMaxChange;
    uint32 baseVariableBorrowRateMaxChange;
    uint32 variableRateSlope1MaxChange;
    uint32 variableRateSlope2MaxChange;

    setBorrowRateConfig(e,optimalUsageRatioMaxChange, baseVariableBorrowRateMaxChange, variableRateSlope1MaxChange, variableRateSlope2MaxChange);
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
    assert to_mathint(borrow_cap_after) <= 2*borrow_cap_before;
}

rule updateGhoSupplyCap__correctness() {
    env e;  uint256 newSupplyCap;
    uint256 supply_cap_before = SUPPLY_CAP;
    updateGhoSupplyCap(e,newSupplyCap);
    assert SUPPLY_CAP==newSupplyCap;

    uint256 supply_cap_after = SUPPLY_CAP;
    assert to_mathint(supply_cap_after) <= 2*supply_cap_before;
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
