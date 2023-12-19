// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoVariableDebtToken is TestGhoBase {
  function setUp() public {
    mintAndStakeDiscountToken(BOB, 10_000e18);
  }

  function testConstructor() public {
    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));
    assertEq(debtToken.name(), 'GHO_VARIABLE_DEBT_TOKEN_IMPL', 'Wrong default ERC20 name');
    assertEq(debtToken.symbol(), 'GHO_VARIABLE_DEBT_TOKEN_IMPL', 'Wrong default ERC20 symbol');
    assertEq(debtToken.decimals(), 0, 'Wrong default ERC20 decimals');
  }

  function testInitialize() public {
    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));
    string memory tokenName = 'Aave Variable Debt GHO';
    string memory tokenSymbol = 'variableDebtGHO';
    bytes memory empty;
    debtToken.initialize(
      IPool(address(POOL)),
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      tokenName,
      tokenSymbol,
      empty
    );

    assertEq(debtToken.name(), tokenName, 'Wrong initialized name');
    assertEq(debtToken.symbol(), tokenSymbol, 'Wrong initialized symbol');
    assertEq(debtToken.decimals(), 18, 'Wrong ERC20 decimals');
  }

  function testInitializePoolRevert() public {
    string memory tokenName = 'Aave Variable Debt GHO';
    string memory tokenSymbol = 'variableDebtGHO';
    bytes memory empty;

    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));
    vm.expectRevert(bytes(Errors.POOL_ADDRESSES_DO_NOT_MATCH));
    debtToken.initialize(
      IPool(address(0)),
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      tokenName,
      tokenSymbol,
      empty
    );
  }

  function testReInitRevert() public {
    string memory tokenName = 'Aave Variable Debt GHO';
    string memory tokenSymbol = 'variableDebtGHO';
    bytes memory empty;

    vm.expectRevert(bytes('Contract instance has already been initialized'));
    GHO_DEBT_TOKEN.initialize(
      IPool(address(POOL)),
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      tokenName,
      tokenSymbol,
      empty
    );
  }

  function testBorrowFixed() public {
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);
  }

  function testBorrowOnBehalf() public {
    vm.prank(BOB);
    GHO_DEBT_TOKEN.approveDelegation(ALICE, DEFAULT_BORROW_AMOUNT);

    borrowActionOnBehalf(ALICE, BOB, DEFAULT_BORROW_AMOUNT);
  }

  function testBorrowFuzz(uint256 fuzzAmount) public {
    vm.assume(fuzzAmount < 100000000000000000000000001);
    vm.assume(fuzzAmount > 0);
    borrowAction(ALICE, fuzzAmount);
    assertEq(
      GHO_DEBT_TOKEN.getBalanceFromInterest(ALICE),
      0,
      'Accumulated interest should be zero'
    );
  }

  function testBorrowFixedWithDiscount() public {
    borrowAction(BOB, DEFAULT_BORROW_AMOUNT);
  }

  function testMultipleBorrowFixedWithDiscount() public {
    borrowAction(BOB, DEFAULT_BORROW_AMOUNT);
    vm.warp(block.timestamp + 100000000);
    borrowAction(BOB, 1e16);
  }

  function testBorrowMultiple() public {
    for (uint x; x < 100; ++x) {
      borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);
      vm.warp(block.timestamp + 2628000);
    }
  }

  function testBorrowMultipleWithDiscount() public {
    for (uint x; x < 100; ++x) {
      borrowAction(BOB, DEFAULT_BORROW_AMOUNT);
      vm.warp(block.timestamp + 2628000);
    }
  }

  function testBorrowMultipleFuzz(uint256 fuzzAmount) public {
    vm.assume(fuzzAmount < 1000000000000000000000000);
    vm.assume(fuzzAmount > 0);

    for (uint x; x < 10; ++x) {
      borrowAction(ALICE, fuzzAmount);
      vm.warp(block.timestamp + 2628000);
    }
  }

  function testPartialMinorRepay() public {
    uint256 partialRepayAmount = 1e7;

    // Perform borrow
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);

    vm.warp(block.timestamp + 2628000);

    // Perform repayment
    repayAction(ALICE, partialRepayAmount);
  }

  function testPartialRepay() public {
    uint256 partialRepayAmount = 50e18;

    // Perform borrow
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);

    vm.warp(block.timestamp + 2628000);

    // Perform repayment
    repayAction(ALICE, partialRepayAmount);
  }

  function testPartialRepayDiscount() public {
    uint256 partialRepayAmount = 50e18;

    // Perform borrow
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);

    vm.warp(block.timestamp + 2628000);

    repayAction(ALICE, partialRepayAmount);

    mintAndStakeDiscountToken(ALICE, 10_000e18);
    vm.warp(block.timestamp + 2628000);

    repayAction(ALICE, partialRepayAmount);
  }

  function testFullRepay() public {
    vm.prank(ALICE);

    // Perform borrow
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);

    vm.warp(block.timestamp + 2628000);

    uint256 allDebt = GHO_DEBT_TOKEN.balanceOf(ALICE);

    ghoFaucet(ALICE, 1e18);

    repayAction(ALICE, allDebt);
  }

  function testMultipleMinorRepay() public {
    uint256 partialRepayAmount = 1e7;

    // Perform borrow
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);

    vm.warp(block.timestamp + 2628000);

    for (uint x; x < 100; ++x) {
      repayAction(ALICE, partialRepayAmount);
      vm.warp(block.timestamp + 2628000);
    }
  }

  function testMultipleRepay() public {
    uint256 partialRepayAmount = 50e18;

    // Perform borrow
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);

    vm.warp(block.timestamp + 2628000);

    for (uint x; x < 4; ++x) {
      repayAction(ALICE, partialRepayAmount);
      vm.warp(block.timestamp + 2628000);
    }
  }

  function testDiscountRebalance() public {
    mintAndStakeDiscountToken(ALICE, 10e18);
    borrowAction(ALICE, 1000e18);
    vm.warp(block.timestamp + 10000000000);

    rebalanceDiscountAction(ALICE);
  }

  function testUnderlying() public {
    assertEq(
      GHO_DEBT_TOKEN.UNDERLYING_ASSET_ADDRESS(),
      address(GHO_TOKEN),
      'Underlying should match token'
    );
  }

  function testGetAToken() public {
    assertEq(
      GHO_DEBT_TOKEN.getAToken(),
      address(GHO_ATOKEN),
      'AToken getter should match Gho AToken'
    );
  }

  function testBalanceOfSameIndex() public {
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);
    uint256 balanceOne = GHO_DEBT_TOKEN.balanceOf(ALICE);
    uint256 balanceTwo = GHO_DEBT_TOKEN.balanceOf(ALICE);
    assertEq(balanceOne, balanceTwo, 'Balance should be equal if index does not increase');
  }

  function testTransferRevert() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.transfer(CHARLES, 1);
  }

  function testTransferFromRevert() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.transferFrom(ALICE, CHARLES, 1);
  }

  function testApproveRevert() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.approve(CHARLES, 1);
  }

  function testIncreaseAllowanceRevert() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.increaseAllowance(CHARLES, 1);
  }

  function testDecreaseAllowanceRevert() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.decreaseAllowance(CHARLES, 1);
  }

  function testAllowanceRevert() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.allowance(CHARLES, ALICE);
  }

  function testUnauthorizedUpdateDiscount() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes('CALLER_NOT_DISCOUNT_TOKEN'));
    GHO_DEBT_TOKEN.updateDiscountDistribution(ALICE, ALICE, 0, 0, 0);
  }

  function testUpdateDiscount() public {
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);
    borrowAction(BOB, DEFAULT_BORROW_AMOUNT);
    vm.warp(block.timestamp + 1000);

    vm.prank(address(STK_TOKEN));
    GHO_DEBT_TOKEN.updateDiscountDistribution(ALICE, BOB, 0, 0, 0);
  }

  function testUpdateDiscountSkipComputation() public {
    vm.record();
    vm.prank(address(STK_TOKEN));
    GHO_DEBT_TOKEN.updateDiscountDistribution(ALICE, BOB, 0, 0, 0);
    (bytes32[] memory reads, ) = vm.accesses(address(GHO_DEBT_TOKEN.POOL()));
    assertEq(reads.length, 0, 'Unexpected read of index from Pool');
  }

  function testUpdateDiscountSelfTransfer() public {
    // Top up Alice with discount tokens
    mintAndStakeDiscountToken(ALICE, 1e18);

    // Alice mints some GHO
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);
    uint256 discountPercentBefore = GHO_DEBT_TOKEN.getDiscountPercent(ALICE);
    address discountRateStrategyBefore = GHO_DEBT_TOKEN.getDiscountRateStrategy();
    assertTrue(discountPercentBefore > 0);
    assertTrue(discountPercentBefore < GHO_DISCOUNT_STRATEGY.DISCOUNT_RATE());

    // Alice self-transfers discount tokens
    vm.record();
    vm.prank(ALICE);
    IERC20(address(STK_TOKEN)).transfer(ALICE, 1e18);
    (, bytes32[] memory writes) = vm.accesses(address(GHO_DEBT_TOKEN));
    assertEq(writes.length, 0);

    assertEq(discountPercentBefore, GHO_DEBT_TOKEN.getDiscountPercent(ALICE));
    assertEq(discountRateStrategyBefore, GHO_DEBT_TOKEN.getDiscountRateStrategy());
  }

  function testUpdateDiscountSelfTransferZeroAmount() public {
    // Top up Alice with discount tokens
    mintAndStakeDiscountToken(ALICE, 1e18);

    // Alice mints some GHO
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);
    uint256 discountPercentBefore = GHO_DEBT_TOKEN.getDiscountPercent(ALICE);
    address discountRateStrategyBefore = GHO_DEBT_TOKEN.getDiscountRateStrategy();
    assertTrue(discountPercentBefore > 0);
    assertTrue(discountPercentBefore < GHO_DISCOUNT_STRATEGY.DISCOUNT_RATE());

    // Alice self-transfers 0 discount tokens
    vm.record();
    vm.prank(ALICE);
    IERC20(address(STK_TOKEN)).transfer(ALICE, 0);
    (, bytes32[] memory writes) = vm.accesses(address(GHO_DEBT_TOKEN));
    assertEq(writes.length, 0);

    assertEq(discountPercentBefore, GHO_DEBT_TOKEN.getDiscountPercent(ALICE));
    assertEq(discountRateStrategyBefore, GHO_DEBT_TOKEN.getDiscountRateStrategy());
  }

  function testUpdateDiscountTransferZeroAmount() public {
    // Top up Alice with discount tokens
    mintAndStakeDiscountToken(ALICE, 1e18);

    // Alice mints some GHO
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);
    uint256 discountPercentBefore = GHO_DEBT_TOKEN.getDiscountPercent(ALICE);
    address discountRateStrategyBefore = GHO_DEBT_TOKEN.getDiscountRateStrategy();
    assertTrue(discountPercentBefore > 0);
    assertTrue(discountPercentBefore < GHO_DISCOUNT_STRATEGY.DISCOUNT_RATE());

    // Alice transfers 0 discount tokens to BOB
    vm.prank(ALICE);
    IERC20(address(STK_TOKEN)).transfer(BOB, 0);

    assertEq(discountPercentBefore, GHO_DEBT_TOKEN.getDiscountPercent(ALICE));
    assertEq(discountRateStrategyBefore, GHO_DEBT_TOKEN.getDiscountRateStrategy());
  }

  function testUpdateDiscountSelfTransferFuzz(
    uint256 debtBalance,
    uint256 discountTokenBalance,
    uint256 amount
  ) public {
    discountTokenBalance = bound(discountTokenBalance, 0, type(uint128).max);
    debtBalance = bound(debtBalance, 1, DEFAULT_CAPACITY);
    vm.assume(amount < discountTokenBalance);
    // Top up Alice with discount tokens
    mintAndStakeDiscountToken(ALICE, discountTokenBalance);

    // Alice mints some GHO
    borrowAction(ALICE, debtBalance);
    uint256 discountPercentBefore = GHO_DEBT_TOKEN.getDiscountPercent(ALICE);
    address discountRateStrategyBefore = GHO_DEBT_TOKEN.getDiscountRateStrategy();
    assertTrue(discountPercentBefore <= GHO_DISCOUNT_STRATEGY.DISCOUNT_RATE());

    // Alice self-transfers discount tokens
    vm.record();
    vm.prank(ALICE);
    IERC20(address(STK_TOKEN)).transfer(ALICE, discountTokenBalance);
    (, bytes32[] memory writes) = vm.accesses(address(GHO_DEBT_TOKEN));
    assertEq(writes.length, 0);

    assertEq(discountPercentBefore, GHO_DEBT_TOKEN.getDiscountPercent(ALICE));
    assertEq(
      discountPercentBefore,
      GHO_DISCOUNT_STRATEGY.calculateDiscountRate(debtBalance, discountTokenBalance)
    );
    assertEq(discountRateStrategyBefore, GHO_DEBT_TOKEN.getDiscountRateStrategy());
    assertTrue(GHO_DEBT_TOKEN.getDiscountPercent(ALICE) <= GHO_DISCOUNT_STRATEGY.DISCOUNT_RATE());
  }

  function testUpdateDiscountTransferBackAndForthFuzz(
    uint256 aliceDebtBalance,
    uint256 charlesDebtBalance,
    uint256 aliceDiscountTokenBalance,
    uint256 charlesDiscountTokenBalance,
    uint256 transferAmount
  ) public {
    aliceDebtBalance = bound(aliceDebtBalance, 0, DEFAULT_CAPACITY);
    charlesDebtBalance = bound(charlesDebtBalance, 0, DEFAULT_CAPACITY - aliceDebtBalance);
    aliceDiscountTokenBalance = bound(aliceDiscountTokenBalance, 0, type(uint128).max);
    charlesDiscountTokenBalance = bound(
      charlesDiscountTokenBalance,
      0,
      type(uint128).max - aliceDiscountTokenBalance
    );
    vm.assume(transferAmount < aliceDiscountTokenBalance);

    // Top up with discount tokens
    if (aliceDiscountTokenBalance > 0) {
      mintAndStakeDiscountToken(ALICE, aliceDiscountTokenBalance);
    }
    if (charlesDiscountTokenBalance > 0) {
      mintAndStakeDiscountToken(CHARLES, charlesDiscountTokenBalance);
    }

    // Users borrow GHO
    if (aliceDebtBalance > 0) {
      borrowAction(ALICE, aliceDebtBalance);
    }
    if (charlesDebtBalance > 0) {
      borrowAction(CHARLES, charlesDebtBalance);
    }
    uint256 aliceDiscountPercentBefore = GHO_DEBT_TOKEN.getDiscountPercent(ALICE);
    uint256 charlesDiscountPercentBefore = GHO_DEBT_TOKEN.getDiscountPercent(CHARLES);
    console2.log(
      'balance',
      GHO_DEBT_TOKEN.balanceOf(CHARLES),
      IERC20(address(STK_TOKEN)).balanceOf(CHARLES),
      GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
        GHO_DEBT_TOKEN.balanceOf(CHARLES),
        IERC20(address(STK_TOKEN)).balanceOf(CHARLES)
      )
    );
    assertTrue(aliceDiscountPercentBefore <= GHO_DISCOUNT_STRATEGY.DISCOUNT_RATE());
    assertTrue(charlesDiscountPercentBefore <= GHO_DISCOUNT_STRATEGY.DISCOUNT_RATE());

    // Transfer from Alice to Charles
    vm.prank(ALICE);
    IERC20(address(STK_TOKEN)).transfer(CHARLES, transferAmount);

    assertEq(
      GHO_DEBT_TOKEN.getDiscountPercent(ALICE),
      GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
        aliceDebtBalance,
        aliceDiscountTokenBalance - transferAmount
      )
    );
    assertEq(
      GHO_DEBT_TOKEN.getDiscountPercent(CHARLES),
      GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
        charlesDebtBalance,
        charlesDiscountTokenBalance + transferAmount
      )
    );

    // Transfer from Charles to Alice
    vm.prank(CHARLES);
    IERC20(address(STK_TOKEN)).transfer(ALICE, transferAmount);

    assertEq(
      GHO_DEBT_TOKEN.getDiscountPercent(ALICE),
      GHO_DISCOUNT_STRATEGY.calculateDiscountRate(aliceDebtBalance, aliceDiscountTokenBalance)
    );
    assertEq(
      GHO_DEBT_TOKEN.getDiscountPercent(CHARLES),
      GHO_DISCOUNT_STRATEGY.calculateDiscountRate(charlesDebtBalance, charlesDiscountTokenBalance)
    );
    assertEq(GHO_DEBT_TOKEN.getDiscountPercent(ALICE), aliceDiscountPercentBefore);
    assertEq(GHO_DEBT_TOKEN.getDiscountPercent(CHARLES), charlesDiscountPercentBefore);
  }

  function testUnauthorizedDecreaseBalance() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes('CALLER_NOT_A_TOKEN'));
    GHO_DEBT_TOKEN.decreaseBalanceFromInterest(ALICE, 1);
  }

  function testUnauthorizedMint() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));
    GHO_DEBT_TOKEN.mint(ALICE, ALICE, 0, 0);
  }

  function testUnauthorizedBurn() public {
    vm.startPrank(ALICE);

    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));
    GHO_DEBT_TOKEN.burn(ALICE, 0, 0);
  }

  function testRevertMintZero() public {
    vm.prank(address(POOL));
    vm.expectRevert(bytes(Errors.INVALID_MINT_AMOUNT));
    GHO_DEBT_TOKEN.mint(ALICE, ALICE, 0, 1);
  }

  function testRevertBurnZero() public {
    vm.prank(address(POOL));
    vm.expectRevert(bytes(Errors.INVALID_BURN_AMOUNT));
    GHO_DEBT_TOKEN.burn(ALICE, 0, 1);
  }

  function testUnauthorizedSetAToken() public {
    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));

    vm.startPrank(ALICE);
    ACL_MANAGER.setState(false);

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    debtToken.setAToken(ALICE);
  }

  function testSetAToken() public {
    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));

    vm.expectEmit(true, true, true, true, address(debtToken));
    emit ATokenSet(address(GHO_ATOKEN));

    debtToken.setAToken(address(GHO_ATOKEN));
  }

  function testUpdateAToken() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes('ATOKEN_ALREADY_SET'));
    GHO_DEBT_TOKEN.setAToken(ALICE);
  }

  function testZeroAToken() public {
    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));

    vm.startPrank(ALICE);
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
    debtToken.setAToken(address(0));
  }

  function testUnauthorizedUpdateDiscountRateStrategy() public {
    vm.startPrank(ALICE);
    ACL_MANAGER.setState(false);

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    GHO_DEBT_TOKEN.updateDiscountRateStrategy(ALICE);
  }

  function testUnauthorizedUpdateDiscountToken() public {
    vm.startPrank(ALICE);
    ACL_MANAGER.setState(false);

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    GHO_DEBT_TOKEN.updateDiscountToken(ALICE);
  }

  function testUpdateDiscountTokenToZero() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
    GHO_DEBT_TOKEN.updateDiscountToken(address(0));
  }

  function testUpdateDiscountStrategy() public {
    vm.startPrank(ALICE);
    GHO_DEBT_TOKEN.updateDiscountRateStrategy(CHARLES);
    assertEq(
      GHO_DEBT_TOKEN.getDiscountRateStrategy(),
      CHARLES,
      'Discount Rate Strategy should be updated'
    );
  }

  function testRevertUpdateDiscountStrategyZero() public {
    vm.startPrank(address(POOL));
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
    GHO_DEBT_TOKEN.updateDiscountRateStrategy(address(0));
  }

  function testUpdateDiscountToken() public {
    vm.startPrank(ALICE);
    GHO_DEBT_TOKEN.updateDiscountToken(CHARLES);
    assertEq(GHO_DEBT_TOKEN.getDiscountToken(), CHARLES, 'Discount token should be updated');
  }

  function testUpdateDiscountTokenWithBorrow() public {
    borrowAction(BOB, DEFAULT_BORROW_AMOUNT);
    vm.warp(block.timestamp + 10000);

    vm.startPrank(ALICE);
    GHO_DEBT_TOKEN.updateDiscountToken(BOB);
    assertEq(GHO_DEBT_TOKEN.getDiscountToken(), BOB, 'Discount token should be updated');
  }

  function testScaledUserBalanceAndSupply() public {
    borrowAction(ALICE, DEFAULT_BORROW_AMOUNT);
    borrowAction(BOB, DEFAULT_BORROW_AMOUNT);
    (uint256 userScaledBalance, uint256 totalScaledSupply) = GHO_DEBT_TOKEN
      .getScaledUserBalanceAndSupply(ALICE);
    assertEq(userScaledBalance, DEFAULT_BORROW_AMOUNT, 'Unexpected user balance');
    assertEq(totalScaledSupply, DEFAULT_BORROW_AMOUNT * 2, 'Unexpected total supply');
  }
}
