//import "erc20.spec"
import "VariableDebtToken.spec";
import "summarizations.spec";


using GhoDiscountRateStrategy as discStrategy;

methods{
    /********************;
     *	WadRayMath.sol	*;
     *********************/
    function _.rayMul(uint256 a,uint256 b) internal => rayMul_gst(a,b) expect uint256 ALL;
    function _.rayDiv(uint256 a,uint256 b) internal => rayDiv_gst(a,b) expect uint256 ALL;
    function getDiscountPercent(address user) external returns (uint256) envfree;
    function get_ghoAToken() external returns (address) envfree;
    
    /***********************************;
     *    PoolAddressesProvider.sol     *;
     ************************************/
    function _.getACLManager() external => CONSTANT;
    
    /************************;
     *    ACLManager.sol     *;
     *************************/
    function _.isPoolAdmin(address) external => CONSTANT;
    
    /******************************************************************;
     *	DummyERC20WithTimedBalanceOf.sol (linked to _discountToken)   *;
     *******************************************************************/
    function _._balanceOfWithBlockTimestamp(address user, uint256 ts) internal => balanceOfDiscountTokenAtTimestamp(user, ts) expect uint256;
    
    /************************************;
     *   DummyPool.sol (linked to POOL)  *;
     *************************************/
    function _._getReserveNormalizedVariableDebtWithBlockTimestamp(address asset, uint256 timestamp) internal => indexAtTimestamp(timestamp) expect uint256;
    
    /************************************;
     *	GhoVariableDebtTokenHarness.sol	*;
     *************************************/
    function discStrategy.calculateDiscountRate(uint256, uint256) external returns (uint256) envfree;
    
    /************************************;
     *	GhoVariableDebtTokenHarness.sol	*;
     *************************************/
    function getUserCurrentIndex(address) external returns (uint256) envfree;
    function getUserDiscountRate(address) external returns (uint256) envfree;
    function getUserAccumulatedDebtInterest(address) external returns (uint256) envfree;
    function getBalanceOfDiscountToken(address) external returns (uint256);

    /********************************;
     *	GhoVariableDebtToken.sol	*;
     *********************************/
    function totalSupply() external returns(uint256) envfree;
    function balanceOf(address) external returns (uint256);
    function mint(address, address, uint256, uint256) external returns (bool, uint256);
    function burn(address ,uint256 ,uint256) external returns (uint256);
    function scaledBalanceOf(address) external returns (uint256) envfree;
    function getBalanceFromInterest(address) external returns (uint256) envfree;
    function rebalanceUserDiscountPercent(address) external;
    function updateDiscountDistribution(address ,address ,uint256 ,uint256 ,uint256) external;
}

ghost rayMul_gst(mathint , mathint) returns uint256 {
    //axiom 1==1;
        axiom forall mathint x. forall mathint y. //rayMul_gst(x,y)+0 == x;
      (
       ((x==0||y==0) => rayMul_gst(x,y)==0)
       &&
       x <= to_mathint(rayMul_gst(x,y)) && to_mathint(rayMul_gst(x,y)) <= 2*x
      )    ;
}
ghost rayDiv_gst(mathint , mathint) returns uint256 {
    //    axiom 1==1;
        axiom forall mathint x. forall mathint y. //rayDiv_gst(x,y)+0 == x;
      (
       x/2 <= to_mathint(rayDiv_gst(x,y)) && to_mathint(rayDiv_gst(x,y)) <= x
      );
}


definition MAX_DISCOUNT() returns uint256 = 10000; // equals to 100% discount, in points

ghost mapping(address => mapping (uint256 => uint256)) discount_ghost;
ghost mapping(uint256 => uint256) index_ghost;

/**
* Query index_ghost for the index value at the input timestamp
**/
function indexAtTimestamp(uint256 timestamp) returns uint256 {
    require index_ghost[timestamp] >= ray();
    return index_ghost[timestamp];
}

/**
* Query discount_ghost for the [user]'s balance of discount token at [timestamp]
**/
function balanceOfDiscountTokenAtTimestamp(address user, uint256 timestamp) returns uint256 {
	return discount_ghost[user][timestamp];
}


function get_discount_scaled(env e, address user, uint256 current_index) returns uint256 {
    uint256 user_scaledBal_prev = scaledBalanceOf(user);
    
    //    assert (user_scaledBal_after <= user_scaledBal_prev);
    //    uint256 current_index = indexAtTimestamp(e.block.timestamp);
    uint256 user_index = getUserCurrentIndex(user);
    require user_index <= current_index;

    //uint256 bal_increase = (current_index-sender_index) * previousScaledBalance_of_sender;
    mathint bal_increase = rayMul_gst(user_scaledBal_prev, current_index) -
        rayMul_gst(user_scaledBal_prev, user_index);

    //uint256 discountScaled = bal_increase * sender_precentage / index;
    uint256 discountPercent = getDiscountPercent(e, user);
    uint256 discount = require_uint256(bal_increase * discountPercent / MAX_DISCOUNT());
    uint256 discountScaled = rayDiv_gst(discount, current_index);

    return discountScaled;
}



/*================================================================================
  Calling to mint(...amount) can't increase the scaled balance by more than scaled-amount.
  (This catches mutant 11)
  =================================================================================*/
rule mint_cant_increase_bal_by_more_than_amountScaled() {
    env e;
    address user; address onBehalfOf; uint256 amount; uint256 index;
    require getUserCurrentIndex(onBehalfOf) <= index;

    uint256 amountScaled = rayDiv_gst(amount,index);
    uint256 prev_bal = scaledBalanceOf(e, onBehalfOf);

    mint(e,user,onBehalfOf,amount,index);

    mathint after_bal = scaledBalanceOf(e, onBehalfOf);
    assert (after_bal <= prev_bal + amountScaled);
}

/*================================================================================
  When calling updateDiscountDistribution, if discountScaled>0 then the 
  balance of the sender must decrease.
  (This catches mutant 5)
  =================================================================================*/
rule discount_takes_place_in_updateDiscountDistribution__sender() {
    env e;
    address sender; address recipient; 
    uint256 senderDiscountTokenBalance; uint256 recipientDiscountTokenBalance; uint256 amount;

    uint256 sender_scaledBal_prev = scaledBalanceOf(sender);
    uint256 discountScaled = get_discount_scaled(e,sender,indexAtTimestamp(e.block.timestamp));
    updateDiscountDistribution(e, sender, recipient,
                               senderDiscountTokenBalance, recipientDiscountTokenBalance,
                               amount);
    uint256 sender_scaledBal_after = scaledBalanceOf(sender);

    if (sender != recipient){
        assert (discountScaled > 0 => sender_scaledBal_after<sender_scaledBal_prev);
    }
    else{
        assert (sender_scaledBal_after == sender_scaledBal_prev);
    }
    
}


/*================================================================================
  When calling updateDiscountDistribution, if discountScaled>0 then the 
  balance of the recipient must decrease.
  (This catches mutant 13)
  =================================================================================*/
rule discount_takes_place_in_updateDiscountDistribution__recipient() {
    env e;
    address sender; address recipient; 
    uint256 senderDiscountTokenBalance; uint256 recipientDiscountTokenBalance; uint256 amount;

    uint256 recipient_scaledBal_prev = scaledBalanceOf(recipient);   
    uint256 discountScaled = get_discount_scaled(e,recipient,indexAtTimestamp(e.block.timestamp));
    updateDiscountDistribution(e, sender, recipient,
                               senderDiscountTokenBalance, recipientDiscountTokenBalance,
                               amount);
    uint256 recipient_scaledBal_after = scaledBalanceOf(recipient);

    if (sender != recipient){
        assert (discountScaled > 0 => recipient_scaledBal_after<recipient_scaledBal_prev);
    }
    else{
        assert (recipient_scaledBal_after == recipient_scaledBal_prev);
    }
}



/*================================================================================
  When calling updateDiscountDistribution, the argument 'amount' has influence
  on the discountPercent of the sender.
  (This catches mutant 10)
  =================================================================================*/
rule in_updateDiscountDistribution_amount_affects_sender_discount() {
    env e;
    address sender; address recipient; 
    uint256 senderDiscountTokenBalance; uint256 recipientDiscountTokenBalance; uint256 amount_1;
    
    storage initState = lastStorage;

    updateDiscountDistribution(e, sender, recipient,
                               senderDiscountTokenBalance, recipientDiscountTokenBalance,
                               amount_1);
    uint256 discountPercent_1 = getDiscountPercent(e, sender);

    uint256 amount_2;
    updateDiscountDistribution(e, sender, recipient,
                               senderDiscountTokenBalance, recipientDiscountTokenBalance,
                               amount_2) at initState;
    uint256 discountPercent_2 = getDiscountPercent(e, sender);
        
    satisfy (discountPercent_1 != discountPercent_2);
}


/*================================================================================
  When calling updateDiscountDistribution, the argument 'amount' has influence
  on the discountPercent of the recipient.
  (This catches mutant 10)
  =================================================================================*/
rule in_updateDiscountDistribution_amount_affects_recpient_discount() {
    env e;
    address sender; address recipient; 
    uint256 senderDiscountTokenBalance; uint256 recipientDiscountTokenBalance; uint256 amount_1;
    
    storage initState = lastStorage;

    updateDiscountDistribution(e, sender, recipient,
                               senderDiscountTokenBalance, senderDiscountTokenBalance,
                               amount_1);
    uint256 discountPercent_1 = getDiscountPercent(e, recipient);

    uint256 amount_2;
    updateDiscountDistribution(e, sender, recipient,
                               senderDiscountTokenBalance, senderDiscountTokenBalance,
                               amount_2) at initState;
    uint256 discountPercent_2 = getDiscountPercent(e, recipient);
        
    satisfy (discountPercent_1 != discountPercent_2);
}




/*================================================================================
  After calling to setAToken, _ghoAToken!=0
  (This catches mutant 4)
  =================================================================================*/
rule _ghoAToken_cant_be_zero() {
    env e;
    address a;
    setAToken(e, a);

    assert get_ghoAToken() != 0;
}



rule discount_takes_place_in_burn() {
    env e;
    address user; uint256 amount; uint256 index;

    mathint _amountScaled = rayDiv(e,amount,index);
    mathint _prev_scaledBal = scaledBalanceOf(e, user);
    mathint _prev_bal = balanceOf(e, user);
    uint256 _discountScaled = get_discount_scaled(e,user,index);

    burn(e,user,amount,index);

    mathint _after_scaledBal = scaledBalanceOf(e, user);
    assert to_mathint(amount)==_prev_bal => _after_scaledBal==0;
    assert (to_mathint(amount)!=_prev_bal && _discountScaled>0) =>
        _after_scaledBal < _prev_scaledBal - _amountScaled;
}


