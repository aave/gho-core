//using FixedFeeStrategyFactory as FAC;


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


    function _.getCurrentOutboundRateLimiterState(uint64 remoteCS) external
      => OutboundRate(remoteCS) expect RateLimiter.TokenBucket;
    
    function _.getCurrentInboundRateLimiterState(uint64 remoteCS) external
      => InboundRate(remoteCS) expect RateLimiter.TokenBucket;

    function _.setChainRateLimiterConfig(uint64,RateLimiter.Config,RateLimiter.Config)
      external => NONDET;

    function getCcipTimelocks() external returns (IGhoCcipSteward.CcipDebounce) envfree;
    function MINIMUM_DELAY() external returns uint256 envfree;
    function RISK_COUNCIL() external returns address envfree;
}


ghost uint128 CAPACITY_OUT;
ghost uint128 RATE_OUT;
function OutboundRate(uint64 remoteCS) returns RateLimiter.TokenBucket {
  RateLimiter.TokenBucket ret;
  
  require ret.capacity == CAPACITY_OUT;
  require ret.rate == RATE_OUT;

  return ret;
}

ghost uint128 CAPACITY_IN;
ghost uint128 RATE_IN;
function InboundRate(uint64 remoteCS) returns RateLimiter.TokenBucket {
  RateLimiter.TokenBucket ret;
  
  require ret.capacity == CAPACITY_IN;
  require ret.rate == RATE_IN;

  return ret;
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

// FUNCTION: updateBridgeLimit
rule bridgeLimitLastUpdate__updated_only_by_updateBridgeLimit(method f) {
    env e; calldataarg args;

    uint40 bridgeLimitLastUpdate_before = getCcipTimelocks().bridgeLimitLastUpdate;
    f(e,args);
    uint40 bridgeLimitLastUpdate_after = getCcipTimelocks().bridgeLimitLastUpdate;

    assert (bridgeLimitLastUpdate_before != bridgeLimitLastUpdate_after) =>
        f.selector == sig:updateBridgeLimit(uint256).selector;
}

rule updateBridgeLimit_update_correctly__bridgeLimitLastUpdate() {
    env e;  uint256 newBridgeLimit;
    updateBridgeLimit(e,newBridgeLimit);
    assert getCcipTimelocks().bridgeLimitLastUpdate == require_uint40(e.block.timestamp);
}

rule updateBridgeLimit_timelock() {
    env e;  uint128 newBridgeLimit;
    uint40 before = getCcipTimelocks().bridgeLimitLastUpdate;
    updateBridgeLimit(e,newBridgeLimit);

    assert to_mathint(e.block.timestamp) > before + MINIMUM_DELAY();
}



// FUNCTION: updateRateLimit
rule rateLimitLastUpdate__updated_only_by_updateRateLimit(method f) {
    env e; calldataarg args;

    uint40 before = getCcipTimelocks().rateLimitLastUpdate;
    f(e,args);
    uint40 after = getCcipTimelocks().rateLimitLastUpdate;

    assert (before != after) =>
        f.selector == sig:updateRateLimit(uint64,bool,uint128,uint128,bool,uint128,uint128).selector;
}

rule updateRateLimit_update_correctly__rateLimitLastUpdate() {
    env e;  calldataarg args;
    updateRateLimit(e,args);
    assert getCcipTimelocks().rateLimitLastUpdate == require_uint40(e.block.timestamp);
}

rule updateRateLimit_timelock() {
    env e;  calldataarg args;
    uint40 before = getCcipTimelocks().rateLimitLastUpdate;
    updateRateLimit(e,args);

    assert to_mathint(e.block.timestamp) > before + MINIMUM_DELAY();
}





/* =================================================================================
   ================================================================================
   Part 2: autorized message sender
   =================================================================================
   ==============================================================================*/

rule only_RISK_COUNCIL_can_call__updateBridgeLimit() {
  env e;  calldataarg args;

  updateBridgeLimit(e,args);
  assert (e.msg.sender==RISK_COUNCIL());
}

rule only_RISK_COUNCIL_can_call__updateRateLimit() {
  env e;  calldataarg args;

  updateRateLimit(e,args);
  assert (e.msg.sender==RISK_COUNCIL());
}



/* =================================================================================
   ================================================================================
   Part 3: correctness of the main functions. 
   We check the validity of the new paramethers values.
   =================================================================================
   ==============================================================================*/

rule updateBridgeLimit__correctness() {
    env e;  

    uint64 remoteChainSelector;
    bool outboundEnabled;
    uint128 outboundCapacity;
    uint128 outboundRate;
    bool inboundEnabled;
    uint128 inboundCapacity;
    uint128 inboundRate;

    updateRateLimit(e, remoteChainSelector,
                    outboundEnabled, outboundCapacity, outboundRate,
                    inboundEnabled,  inboundCapacity, inboundRate);

    assert to_mathint(outboundCapacity) <= 2*CAPACITY_OUT;
    assert to_mathint(outboundRate) <= 2*RATE_OUT;

    assert to_mathint(inboundCapacity) <= 2*CAPACITY_IN;
    assert to_mathint(inboundRate) <= 2*RATE_IN;
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
