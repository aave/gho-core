//using FixedRateStrategyFactory as FAC;


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

    function _.getFacilitatorBucket(address facilitator) external =>
      get_BUCKET_CAPACITY_cvl() expect (uint256,uint256);
    function _.setFacilitatorBucketCapacity(address,uint128 newBucketCapacity) external =>
      set_BUCKET_CAPACITY_cvl(newBucketCapacity) expect void;

    function owner() external returns (address) envfree;
    function getFacilitatorBucketCapacityTimelock(address) external returns (uint40) envfree;
    function MINIMUM_DELAY() external returns uint256 envfree;
    function RISK_COUNCIL() external returns address envfree;
}



ghost uint128 BUCKET_CAPACITY;
function get_BUCKET_CAPACITY_cvl() returns (uint256,uint256) {
  uint256 ret;
  return (BUCKET_CAPACITY,ret);
}
function set_BUCKET_CAPACITY_cvl(uint128 newBucketCapacity) {
  BUCKET_CAPACITY = newBucketCapacity;
}




/* =================================================================================
   ================================================================================
   Part 1: validity of the timelocks
   =================================================================================
   ==============================================================================*/

// FUNCTION: updateFacilitatorBucketCapacity
rule timestamp__updated_only_by_updateFacilitatorBucketCapacity(method f) {
    env e; calldataarg args;
    address facilitator;

    uint40 timestamp_before = getFacilitatorBucketCapacityTimelock(facilitator);
    f(e,args);
    uint40 timestamp_after = getFacilitatorBucketCapacityTimelock(facilitator);

    assert (timestamp_before != timestamp_after) =>
        f.selector == sig:updateFacilitatorBucketCapacity(address,uint128).selector;
}

rule updateFacilitatorBucketCapacity_update_correctly__timestamp() {
    env e;  address facilitator;   uint128 newBucketCapacity;
    updateFacilitatorBucketCapacity(e,facilitator,newBucketCapacity);
    assert getFacilitatorBucketCapacityTimelock(facilitator) == require_uint40(e.block.timestamp);
}

rule updateFacilitatorBucketCapacity_timelock() {
    env e;  address facilitator;   uint128 newBucketCapacity;
    uint40 timestamp_before = getFacilitatorBucketCapacityTimelock(facilitator);
    updateFacilitatorBucketCapacity(e,facilitator, newBucketCapacity);

    assert to_mathint(e.block.timestamp) > timestamp_before + MINIMUM_DELAY();
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

rule updateFacilitatorBucketCapacity__correctness() {
  env e;  address facilitator; uint128 newBucketCapacity;

  uint256 bucket_capacity_before = BUCKET_CAPACITY;
  updateFacilitatorBucketCapacity(e,facilitator,newBucketCapacity);
  assert BUCKET_CAPACITY==newBucketCapacity;
  
  assert to_mathint(BUCKET_CAPACITY) <= 2*bucket_capacity_before;
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
