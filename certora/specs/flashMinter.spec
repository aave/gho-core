using GhoToken as gho
using GhoAToken as atoken
using MockFlashBorrower as flashBorrower

methods{
    isPoolAdmin(address user) returns (bool) => retreivePoolAdminFromGhost(user)
    isFlashBorrower(address user) returns (bool) => retreiveFlashBorrowerFromGhost(user)
    onFlashLoan(address, address, uint256, uint256, bytes) returns (bytes32) => DISPATCHER(true)
    getACLManager() returns (address) => NONDET

    // FlashBorrower
    flashBorrower.action() returns (uint8) envfree
    flashBorrower._transferTo() returns (address) envfree
    gho.allowance(address, address) returns (uint256) envfree
    burn(uint256) => DISPATCHER(true)
    mint(address, uint256) => DISPATCHER(true)
    transfer(address, uint256) returns (bool) => DISPATCHER(true)
    balanceOf(address) returns (uint256) => DISPATCHER(true)
    
    decreaseBalanceFromInterest(address, uint256) => NONDET
    getBalanceFromInterest(address) => NONDET
    gho.totalSupply() returns (uint256) envfree
    gho.balanceOf(address) returns (uint256) envfree

    atoken.getGhoTreasury() returns (address) envfree
}

// keeps track of users with pool admin permissions in order to return a consistent value per user
ghost mapping(address => bool) poolAdmin_ghost;
// keeps track of users with flash borrower permissions in order to return a consistent value per user
ghost mapping(address => bool) flashBorrower_ghost;

// returns whether the user is a pool admin
function retreivePoolAdminFromGhost(address user) returns bool{
    return poolAdmin_ghost[user];
}

// returns whether the user is a flash borrower
function retreiveFlashBorrowerFromGhost(address user) returns bool{
    return flashBorrower_ghost[user];
}

// a set of assumptions needed for rules that call flashloan
function flashLoanReqs(env e){
    require e.msg.sender != currentContract;
    require gho.allowance(currentContract, e.msg.sender) == 0;
}

// an assumption that demands the sum of balances of 3 given users is no more than the total supply
function ghoBalanceOfTwoUsersLETotalSupply(address user1, address user2, address user3){
    require gho.balanceOf(user1) + gho.balanceOf(user2) + gho.balanceOf(user3) <= gho.totalSupply();
}

/**
 * @title The GHO balance of the flash minter should grow when calling any function, excluding distributeFees
 */
rule balanceOfFlashMinterGrows(method f, env e, calldataarg args) 
    filtered { f -> f.selector != distributeFeesToTreasury().selector }{
    
    // No overflow of gho is possible
    ghoBalanceOfTwoUsersLETotalSupply(currentContract, e.msg.sender, atoken);
    flashLoanReqs(e);
    // excluding calls to distribute fees
    require flashBorrower.action() != 1; 

    uint256 _facilitatorBalance = gho.balanceOf(currentContract);

    f(e, args);

    uint256 facilitatorBalance_ = gho.balanceOf(currentContract);

    assert facilitatorBalance_ >= _facilitatorBalance;
}

/**
 * @title Checks the integrity of updateGhoTreasury - after update the given address is set
 */
rule integrityOfTreasurySet(address token){
    env e;
    updateGhoTreasury(e, token);
    address treasury_ = getGhoTreasury(e);
    assert treasury_ == token;
}

/**
 * @title Checks the integrity of updateFee - after update the given value is set
 */
rule integrityOfFeeSet(uint256 new_fee){
    env e;
    updateFee(e, new_fee);
    uint256 fee_ = getFee(e);
    assert fee_ == new_fee;
}

/**
 * @title Checks that the available liquidity, retreived by maxFlashLoan, stays the same after any action 
 */
rule availableLiquidityDoesntChange(method f, address token){
    env e; calldataarg args;
    uint256 _liquidity = maxFlashLoan(e, token);

    f(e, args);

    uint256 liquidity_ = maxFlashLoan(e, token);

    assert liquidity_ == _liquidity;
}

/**
 * @title Checks the integrity of distributeFees:
 *        1. As long as the treasury contract itself isn't acting as a flashloan minter, the flashloan facilitator's GHO balance should be empty after distribution
 *        2. The change in balances of the receiver (treasury) and the sender (flash minter) is the same. i.e. no money is being generated out of thin air
 */
rule integrityOfDistributeFeesToTreasury(){
    env e;
    address treasury = getGhoTreasury(e);
    uint256 _facilitatorBalance = gho.balanceOf(currentContract);
    uint256 _treasuryBalance = gho.balanceOf(treasury);

    // No overflow of gho is possible
    ghoBalanceOfTwoUsersLETotalSupply(currentContract, treasury, atoken);
    distributeFeesToTreasury(e);

    uint256 facilitatorBalance_ = gho.balanceOf(currentContract);
    uint256 treasuryBalance_ = gho.balanceOf(treasury);

    assert treasury != currentContract => facilitatorBalance_ == 0;
    assert treasuryBalance_ - _treasuryBalance == _facilitatorBalance - facilitatorBalance_;
}

/**
 * @title Checks that the fee amount reported by flashFee is the the same as the actual fee that is taken by flashloaning
 */
rule feeSimulationEqualsActualFee(address receiver, address token, uint256 amount, bytes data){
    env e;
    uint256 feeSimulationResult = flashFee(e, token, amount);
    uint256 _facilitatorBalance = gho.balanceOf(currentContract);
    
    flashLoanReqs(e);
    require atoken.getGhoTreasury() != currentContract;
    // No overflow of gho is possible
    ghoBalanceOfTwoUsersLETotalSupply(currentContract, e.msg.sender, atoken);
    // Excluding call to distributeFeesToTreasury & calling another flashloan (which will generate another fee in recursion)
    require flashBorrower.action() != 1 && flashBorrower.action() != 0;
    // Because we calculate the actual fee by balance difference of the minter, we assume no extra money is being sent to the minter.
    require flashBorrower._transferTo() != currentContract;
    
    flashLoan(e, receiver, token, amount, data);

    uint256 facilitatorBalance_ = gho.balanceOf(currentContract);

    uint256 actualFee = facilitatorBalance_ - _facilitatorBalance;

    assert feeSimulationResult == actualFee;
}
