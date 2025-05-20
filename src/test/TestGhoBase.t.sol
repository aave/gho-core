// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';

// helpers
import {Constants} from './helpers/Constants.sol';
import {DebtUtils} from './helpers/DebtUtils.sol';
import {Events} from './helpers/Events.sol';
import {AccessControlErrorsLib, OwnableErrorsLib} from './helpers/ErrorsLib.sol';

// generic libs
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {SafeCast} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/SafeCast.sol';
import {WadRayMath} from '@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol';

// mocks
import {MockAclManager} from './mocks/MockAclManager.sol';
import {MockConfigurator} from './mocks/MockConfigurator.sol';
import {MockFlashBorrower} from './mocks/MockFlashBorrower.sol';
import {MockGsmV2} from './mocks/MockGsmV2.sol';
import {MockPool} from './mocks/MockPool.sol';
import {MockAddressesProvider} from './mocks/MockAddressesProvider.sol';
import {MockERC4626} from './mocks/MockERC4626.sol';
import {MockUpgradeable} from './mocks/MockUpgradeable.sol';
import {PriceOracle} from '@aave/core-v3/contracts/mocks/oracle/PriceOracle.sol';
import {TestnetERC20} from '@aave/periphery-v3/contracts/mocks/testnet-helpers/TestnetERC20.sol';
import {WETH9Mock} from '@aave/periphery-v3/contracts/mocks/WETH9Mock.sol';
import {MockPoolDataProvider} from './mocks/MockPoolDataProvider.sol';

// interfaces
import {IAaveIncentivesController} from '@aave/core-v3/contracts/interfaces/IAaveIncentivesController.sol';
import {IAToken} from '@aave/core-v3/contracts/interfaces/IAToken.sol';
import {IERC20} from 'aave-stk-v1-5/src/interfaces/IERC20.sol';
import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';
import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';
import {IGhoToken} from '../contracts/gho/interfaces/IGhoToken.sol';
import {IGhoVariableDebtTokenTransferHook} from 'aave-stk-v1-5/src/interfaces/IGhoVariableDebtTokenTransferHook.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IStakedAaveV3} from 'aave-stk-v1-5/src/interfaces/IStakedAaveV3.sol';

// non-GHO contracts
import {AdminUpgradeabilityProxy} from '@aave/core-v3/contracts/dependencies/openzeppelin/upgradeability/AdminUpgradeabilityProxy.sol';
import {ERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/ERC20.sol';
import {StakedAaveV3} from 'aave-stk-v1-5/src/contracts/StakedAaveV3.sol';
import {ReserveConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {TransparentUpgradeableProxy} from 'solidity-utils/contracts/transparent-proxy/TransparentUpgradeableProxy.sol';

// GHO contracts
import {GhoAToken} from '../contracts/facilitators/aave/tokens/GhoAToken.sol';
import {GhoDiscountRateStrategy} from '../contracts/facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol';
import {GhoFlashMinter} from '../contracts/facilitators/flashMinter/GhoFlashMinter.sol';
import {GhoInterestRateStrategy} from '../contracts/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {IGhoAaveSteward} from '../contracts/misc/interfaces/IGhoAaveSteward.sol';
import {GhoAaveSteward} from '../contracts/misc/GhoAaveSteward.sol';
import {GhoOracle} from '../contracts/facilitators/aave/oracle/GhoOracle.sol';
import {GhoStableDebtToken} from '../contracts/facilitators/aave/tokens/GhoStableDebtToken.sol';
import {GhoToken} from '../contracts/gho/GhoToken.sol';
import {UpgradeableGhoToken} from '../contracts/gho/UpgradeableGhoToken.sol';
import {GhoVariableDebtToken} from '../contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {FixedRateStrategyFactory} from '../contracts/facilitators/aave/interestStrategy/FixedRateStrategyFactory.sol';

// GSM contracts
import {IGsm} from '../contracts/facilitators/gsm/interfaces/IGsm.sol';
import {Gsm} from '../contracts/facilitators/gsm/Gsm.sol';
import {Gsm4626} from '../contracts/facilitators/gsm/Gsm4626.sol';
import {FixedPriceStrategy} from '../contracts/facilitators/gsm/priceStrategy/FixedPriceStrategy.sol';
import {FixedPriceStrategy4626} from '../contracts/facilitators/gsm/priceStrategy/FixedPriceStrategy4626.sol';
import {IGsmFeeStrategy} from '../contracts/facilitators/gsm/feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {FixedFeeStrategy} from '../contracts/facilitators/gsm/feeStrategy/FixedFeeStrategy.sol';
import {SampleLiquidator} from '../contracts/facilitators/gsm/misc/SampleLiquidator.sol';
import {SampleSwapFreezer} from '../contracts/facilitators/gsm/misc/SampleSwapFreezer.sol';
import {GsmRegistry} from '../contracts/facilitators/gsm/misc/GsmRegistry.sol';
import {IGhoGsmSteward} from '../contracts/misc/interfaces/IGhoGsmSteward.sol';
import {GhoGsmSteward} from '../contracts/misc/GhoGsmSteward.sol';
import {FixedFeeStrategyFactory} from '../contracts/facilitators/gsm/feeStrategy/FixedFeeStrategyFactory.sol';

// CCIP contracts
import {MockUpgradeableLockReleaseTokenPool} from './mocks/MockUpgradeableLockReleaseTokenPool.sol';
import {RateLimiter} from '../contracts/misc/dependencies/Ccip.sol';
import {IGhoCcipSteward} from '../contracts/misc/interfaces/IGhoCcipSteward.sol';
import {GhoCcipSteward} from '../contracts/misc/GhoCcipSteward.sol';
import {GhoBucketSteward} from '../contracts/misc/GhoBucketSteward.sol';

import {GhoReserve} from '../contracts/facilitators/gsm/GhoReserve.sol';
import {OwnableFacilitator} from '../contracts/facilitators/gsm/OwnableFacilitator.sol';

contract TestGhoBase is Test, Constants, Events {
  using WadRayMath for uint256;
  using SafeCast for uint256;
  using PercentageMath for uint256;

  // helper for state tracking
  struct BorrowState {
    uint256 supplyBeforeAction;
    uint256 debtSupplyBeforeAction;
    uint256 debtScaledSupplyBeforeAction;
    uint256 balanceBeforeAction;
    uint256 debtScaledBalanceBeforeAction;
    uint256 debtBalanceBeforeAction;
    uint256 userIndexBeforeAction;
    uint256 userInterestsBeforeAction;
    uint256 assetIndexBefore;
    uint256 discountPercent;
  }

  GhoToken GHO_TOKEN;
  TestnetERC20 AAVE_TOKEN;
  IStakedAaveV3 STK_TOKEN;
  TestnetERC20 USDC_TOKEN;
  MockERC4626 USDC_4626_TOKEN;
  MockPool POOL;
  MockAclManager ACL_MANAGER;
  MockAddressesProvider PROVIDER;
  MockConfigurator CONFIGURATOR;
  PriceOracle PRICE_ORACLE;
  WETH9Mock WETH;
  GhoVariableDebtToken GHO_DEBT_TOKEN;
  GhoStableDebtToken GHO_STABLE_DEBT_TOKEN;
  GhoAToken GHO_ATOKEN;
  GhoFlashMinter GHO_FLASH_MINTER;
  GhoDiscountRateStrategy GHO_DISCOUNT_STRATEGY;
  MockFlashBorrower FLASH_BORROWER;
  Gsm GHO_GSM;
  Gsm4626 GHO_GSM_4626;
  FixedPriceStrategy GHO_GSM_FIXED_PRICE_STRATEGY;
  FixedPriceStrategy4626 GHO_GSM_4626_FIXED_PRICE_STRATEGY;
  FixedFeeStrategy GHO_GSM_FIXED_FEE_STRATEGY;
  SampleLiquidator GHO_GSM_LAST_RESORT_LIQUIDATOR;
  SampleSwapFreezer GHO_GSM_SWAP_FREEZER;
  GsmRegistry GHO_GSM_REGISTRY;
  GhoOracle GHO_ORACLE;
  GhoAaveSteward GHO_AAVE_STEWARD;
  GhoCcipSteward GHO_CCIP_STEWARD;
  GhoGsmSteward GHO_GSM_STEWARD;
  GhoBucketSteward GHO_BUCKET_STEWARD;
  MockPoolDataProvider MOCK_POOL_DATA_PROVIDER;

  FixedRateStrategyFactory FIXED_RATE_STRATEGY_FACTORY;
  FixedFeeStrategyFactory FIXED_FEE_STRATEGY_FACTORY;
  MockUpgradeableLockReleaseTokenPool GHO_TOKEN_POOL;

  GhoReserve GHO_RESERVE;
  OwnableFacilitator OWNABLE_FACILITATOR;

  constructor() {
    setupGho();
  }

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

  function setupGho() public {
    bytes memory empty;
    ACL_MANAGER = new MockAclManager();
    PROVIDER = new MockAddressesProvider(address(ACL_MANAGER));
    MOCK_POOL_DATA_PROVIDER = new MockPoolDataProvider(address(PROVIDER));
    POOL = new MockPool(IPoolAddressesProvider(address(PROVIDER)));
    CONFIGURATOR = new MockConfigurator(IPool(POOL));
    PRICE_ORACLE = new PriceOracle();
    PROVIDER.setPool(address(POOL));
    PROVIDER.setConfigurator(address(CONFIGURATOR));
    PROVIDER.setPriceOracle(address(PRICE_ORACLE));
    GHO_ORACLE = new GhoOracle();
    GHO_TOKEN = new GhoToken(address(this));
    GHO_TOKEN.grantRole(GHO_TOKEN_FACILITATOR_MANAGER_ROLE, address(this));
    GHO_TOKEN.grantRole(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(this));
    AAVE_TOKEN = new TestnetERC20('AAVE', 'AAVE', 18, FAUCET);
    StakedAaveV3 stkAave = new StakedAaveV3(
      IERC20(address(AAVE_TOKEN)),
      IERC20(address(AAVE_TOKEN)),
      1,
      address(0),
      address(0),
      1
    );
    AdminUpgradeabilityProxy stkAaveProxy = new AdminUpgradeabilityProxy(
      address(stkAave),
      STKAAVE_PROXY_ADMIN,
      ''
    );
    StakedAaveV3(address(stkAaveProxy)).initialize(
      STKAAVE_PROXY_ADMIN,
      STKAAVE_PROXY_ADMIN,
      STKAAVE_PROXY_ADMIN,
      0,
      1
    );
    STK_TOKEN = IStakedAaveV3(address(stkAaveProxy));
    USDC_TOKEN = new TestnetERC20('USD Coin', 'USDC', 6, FAUCET);
    USDC_4626_TOKEN = new MockERC4626('USD Coin 4626', '4626', address(USDC_TOKEN));
    IPool iPool = IPool(address(POOL));
    WETH = new WETH9Mock('Wrapped Ether', 'WETH', FAUCET);
    GHO_DEBT_TOKEN = new GhoVariableDebtToken(iPool);
    GHO_STABLE_DEBT_TOKEN = new GhoStableDebtToken(iPool);
    GHO_ATOKEN = new GhoAToken(iPool);
    GHO_DEBT_TOKEN.initialize(
      iPool,
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      'Aave Variable Debt GHO',
      'variableDebtGHO',
      empty
    );
    GHO_STABLE_DEBT_TOKEN.initialize(
      iPool,
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      'Aave Stable Debt GHO',
      'stableDebtGHO',
      empty
    );
    GHO_ATOKEN.initialize(
      iPool,
      TREASURY,
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      'Aave GHO',
      'aGHO',
      empty
    );
    GHO_ATOKEN.updateGhoTreasury(TREASURY);
    GHO_DEBT_TOKEN.updateDiscountToken(address(STK_TOKEN));
    GHO_DISCOUNT_STRATEGY = new GhoDiscountRateStrategy();
    GHO_DEBT_TOKEN.updateDiscountRateStrategy(address(GHO_DISCOUNT_STRATEGY));
    GHO_DEBT_TOKEN.setAToken(address(GHO_ATOKEN));
    GHO_ATOKEN.setVariableDebtToken(address(GHO_DEBT_TOKEN));
    vm.prank(SHORT_EXECUTOR);
    STK_TOKEN.setGHODebtToken(IGhoVariableDebtTokenTransferHook(address(GHO_DEBT_TOKEN)));
    GHO_TOKEN.addFacilitator(address(GHO_ATOKEN), 'Aave V3 Pool', DEFAULT_CAPACITY);
    POOL.setGhoTokens(GHO_DEBT_TOKEN, GHO_ATOKEN);

    GHO_RESERVE = new GhoReserve(address(this), address(GHO_TOKEN));
    GHO_RESERVE.initialize(address(this));

    OWNABLE_FACILITATOR = new OwnableFacilitator(address(this), address(GHO_TOKEN));
    // Give OwnableFacilitator twice the default capacity to fully fund two GSMs
    GHO_TOKEN.addFacilitator(
      address(OWNABLE_FACILITATOR),
      'OwnableFacilitator',
      DEFAULT_CAPACITY * 2
    );

    GHO_FLASH_MINTER = new GhoFlashMinter(
      address(GHO_TOKEN),
      TREASURY,
      DEFAULT_FLASH_FEE,
      address(PROVIDER)
    );
    FLASH_BORROWER = new MockFlashBorrower(IERC3156FlashLender(GHO_FLASH_MINTER));

    GHO_TOKEN.addFacilitator(
      address(GHO_FLASH_MINTER),
      'FlashMinter Facilitator',
      DEFAULT_CAPACITY
    );
    GHO_TOKEN.addFacilitator(address(FLASH_BORROWER), 'Gho Flash Borrower', DEFAULT_CAPACITY);

    GHO_GSM_FIXED_PRICE_STRATEGY = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE,
      address(USDC_TOKEN),
      6
    );
    GHO_GSM_4626_FIXED_PRICE_STRATEGY = new FixedPriceStrategy4626(
      DEFAULT_FIXED_PRICE,
      address(USDC_4626_TOKEN),
      6
    );
    GHO_GSM_LAST_RESORT_LIQUIDATOR = new SampleLiquidator();
    GHO_GSM_SWAP_FREEZER = new SampleSwapFreezer();
    Gsm gsm = new Gsm(
      address(GHO_TOKEN),
      address(USDC_TOKEN),
      address(GHO_GSM_FIXED_PRICE_STRATEGY)
    );
    AdminUpgradeabilityProxy gsmProxy = new AdminUpgradeabilityProxy(
      address(gsm),
      SHORT_EXECUTOR,
      ''
    );
    GHO_GSM = Gsm(address(gsmProxy));

    GHO_GSM.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE, address(GHO_RESERVE));
    GHO_GSM_4626 = new Gsm4626(
      address(GHO_TOKEN),
      address(USDC_4626_TOKEN),
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY)
    );
    GHO_GSM_4626.initialize(
      address(this),
      TREASURY,
      DEFAULT_GSM_USDC_EXPOSURE,
      address(GHO_RESERVE)
    );

    GHO_RESERVE.setEntityLimit(address(GHO_GSM), DEFAULT_CAPACITY);
    GHO_RESERVE.setEntityLimit(address(GHO_GSM_4626), DEFAULT_CAPACITY);

    // Mint twice default capacity for both GSMs to be fully funded
    OWNABLE_FACILITATOR.mint(address(GHO_RESERVE), DEFAULT_CAPACITY * 2);

    GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(DEFAULT_GSM_BUY_FEE, DEFAULT_GSM_SELL_FEE);
    GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    GHO_GSM_4626.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));

    GHO_GSM.grantRole(GSM_LIQUIDATOR_ROLE, address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM.grantRole(GSM_SWAP_FREEZER_ROLE, address(GHO_GSM_SWAP_FREEZER));
    GHO_GSM_4626.grantRole(GSM_LIQUIDATOR_ROLE, address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM_4626.grantRole(GSM_SWAP_FREEZER_ROLE, address(GHO_GSM_SWAP_FREEZER));

    GHO_TOKEN.addFacilitator(FAUCET, 'Faucet Facilitator', type(uint128).max);

    GHO_GSM_REGISTRY = new GsmRegistry(address(this));
    FIXED_RATE_STRATEGY_FACTORY = new FixedRateStrategyFactory(address(PROVIDER));

    // Deploy Gho Token Pool
    address ARM_PROXY = makeAddr('ARM_PROXY');
    address OWNER = makeAddr('OWNER');
    address ROUTER = makeAddr('ROUTER');
    address PROXY_ADMIN = makeAddr('PROXY_ADMIN');
    uint256 INITIAL_BRIDGE_LIMIT = 100e6 * 1e18;
    MockUpgradeableLockReleaseTokenPool tokenPoolImpl = new MockUpgradeableLockReleaseTokenPool(
      address(GHO_TOKEN),
      ARM_PROXY,
      false,
      true
    );
    // proxy deploy and init
    address[] memory emptyArray = new address[](0);
    bytes memory tokenPoolInitParams = abi.encodeWithSignature(
      'initialize(address,address[],address,uint256)',
      OWNER,
      emptyArray,
      ROUTER,
      INITIAL_BRIDGE_LIMIT
    );
    TransparentUpgradeableProxy tokenPoolProxy = new TransparentUpgradeableProxy(
      address(tokenPoolImpl),
      PROXY_ADMIN,
      tokenPoolInitParams
    );

    // Manage ownership
    vm.prank(OWNER);
    MockUpgradeableLockReleaseTokenPool(address(tokenPoolProxy)).acceptOwnership();
    GHO_TOKEN_POOL = MockUpgradeableLockReleaseTokenPool(address(tokenPoolProxy));

    // Setup GHO Token Pool
    uint64 SOURCE_CHAIN_SELECTOR = 1;
    uint64 DEST_CHAIN_SELECTOR = 2;
    RateLimiter.Config memory initialOutboundRateLimit = RateLimiter.Config({
      isEnabled: true,
      capacity: 100e28,
      rate: 1e15
    });
    RateLimiter.Config memory initialInboundRateLimit = RateLimiter.Config({
      isEnabled: true,
      capacity: 222e30,
      rate: 1e18
    });
    MockUpgradeableLockReleaseTokenPool.ChainUpdate[]
      memory chainUpdate = new MockUpgradeableLockReleaseTokenPool.ChainUpdate[](1);
    chainUpdate[0] = MockUpgradeableLockReleaseTokenPool.ChainUpdate({
      remoteChainSelector: DEST_CHAIN_SELECTOR,
      allowed: true,
      outboundRateLimiterConfig: initialOutboundRateLimit,
      inboundRateLimiterConfig: initialInboundRateLimit
    });
    vm.prank(OWNER);
    GHO_TOKEN_POOL.applyChainUpdates(chainUpdate);
  }

  function ghoFaucet(address to, uint256 amount) public {
    vm.prank(FAUCET);
    GHO_TOKEN.mint(to, amount);
  }

  function borrowAction(address user, uint256 amount) public {
    borrowActionOnBehalf(user, user, amount);
  }

  function borrowActionOnBehalf(address caller, address onBehalfOf, uint256 amount) public {
    BorrowState memory bs;
    bs.supplyBeforeAction = GHO_TOKEN.totalSupply();
    bs.debtSupplyBeforeAction = GHO_DEBT_TOKEN.totalSupply();
    bs.debtScaledSupplyBeforeAction = GHO_DEBT_TOKEN.scaledTotalSupply();
    bs.balanceBeforeAction = GHO_TOKEN.balanceOf(onBehalfOf);
    bs.debtScaledBalanceBeforeAction = GHO_DEBT_TOKEN.scaledBalanceOf(onBehalfOf);
    bs.debtBalanceBeforeAction = GHO_DEBT_TOKEN.balanceOf(onBehalfOf);
    bs.userIndexBeforeAction = GHO_DEBT_TOKEN.getPreviousIndex(onBehalfOf);
    bs.userInterestsBeforeAction = GHO_DEBT_TOKEN.getBalanceFromInterest(onBehalfOf);
    bs.assetIndexBefore = POOL.getReserveNormalizedVariableDebt(address(GHO_TOKEN));
    bs.discountPercent = GHO_DEBT_TOKEN.getDiscountPercent(onBehalfOf);

    if (bs.userIndexBeforeAction == 0) {
      bs.userIndexBeforeAction = 1e27;
    }

    (uint256 computedInterest, uint256 discountScaled, ) = DebtUtils.computeDebt(
      bs.userIndexBeforeAction,
      bs.assetIndexBefore,
      bs.debtScaledBalanceBeforeAction,
      bs.userInterestsBeforeAction,
      bs.discountPercent
    );
    uint256 newDiscountRate = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
      (bs.debtScaledBalanceBeforeAction - discountScaled).rayMul(bs.assetIndexBefore) + amount,
      IERC20(address(STK_TOKEN)).balanceOf(onBehalfOf)
    );

    if (newDiscountRate != bs.discountPercent) {
      vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
      emit DiscountPercentUpdated(onBehalfOf, bs.discountPercent, newDiscountRate);
    }

    vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
    emit Transfer(address(0), onBehalfOf, amount + computedInterest);
    vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
    emit Mint(caller, onBehalfOf, amount + computedInterest, computedInterest, bs.assetIndexBefore);

    // Action
    vm.prank(caller);
    POOL.borrow(address(GHO_TOKEN), amount, 2, 0, onBehalfOf);

    // Checks
    assertEq(
      GHO_TOKEN.balanceOf(onBehalfOf),
      bs.balanceBeforeAction + amount,
      'Gho amount does not match borrow'
    );
    assertEq(GHO_DEBT_TOKEN.getDiscountPercent(onBehalfOf), newDiscountRate);
    assertEq(
      GHO_TOKEN.totalSupply(),
      bs.supplyBeforeAction + amount,
      'Gho total supply does not match borrow'
    );

    assertEq(
      GHO_DEBT_TOKEN.scaledBalanceOf(onBehalfOf),
      bs.debtScaledBalanceBeforeAction + amount.rayDiv(bs.assetIndexBefore) - discountScaled,
      'Gho debt token balance does not match borrow'
    );
    assertEq(
      GHO_DEBT_TOKEN.scaledTotalSupply(),
      bs.debtScaledSupplyBeforeAction + amount.rayDiv(bs.assetIndexBefore) - discountScaled,
      'Gho debt token Supply does not match borrow'
    );
    assertEq(
      GHO_DEBT_TOKEN.getBalanceFromInterest(onBehalfOf),
      bs.userInterestsBeforeAction + computedInterest,
      'Gho debt interests does not match borrow'
    );
  }

  function repayAction(address user, uint256 amount) public {
    BorrowState memory bs;
    bs.supplyBeforeAction = GHO_TOKEN.totalSupply();
    bs.debtSupplyBeforeAction = GHO_DEBT_TOKEN.totalSupply();
    bs.debtScaledSupplyBeforeAction = GHO_DEBT_TOKEN.scaledTotalSupply();
    bs.balanceBeforeAction = GHO_TOKEN.balanceOf(user);
    bs.debtScaledBalanceBeforeAction = GHO_DEBT_TOKEN.scaledBalanceOf(user);
    bs.debtBalanceBeforeAction = GHO_DEBT_TOKEN.balanceOf(user);
    bs.userIndexBeforeAction = GHO_DEBT_TOKEN.getPreviousIndex(user);
    bs.userInterestsBeforeAction = GHO_DEBT_TOKEN.getBalanceFromInterest(user);
    bs.assetIndexBefore = POOL.getReserveNormalizedVariableDebt(address(GHO_TOKEN));
    bs.discountPercent = GHO_DEBT_TOKEN.getDiscountPercent(user);
    uint256 expectedDebt = 0;
    uint256 expectedBurnOffset = 0;

    if (bs.userIndexBeforeAction == 0) {
      bs.userIndexBeforeAction = 1e27;
    }

    (uint256 computedInterest, uint256 discountScaled, ) = DebtUtils.computeDebt(
      bs.userIndexBeforeAction,
      bs.assetIndexBefore,
      bs.debtScaledBalanceBeforeAction,
      bs.userInterestsBeforeAction,
      bs.discountPercent
    );
    uint256 newDiscountRate = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
      (bs.debtScaledBalanceBeforeAction - discountScaled).rayMul(bs.assetIndexBefore) - amount,
      IERC20(address(STK_TOKEN)).balanceOf(user)
    );

    if (amount <= (bs.userInterestsBeforeAction + computedInterest)) {
      expectedDebt = bs.userInterestsBeforeAction + computedInterest - amount;
    } else {
      expectedBurnOffset = amount - bs.userInterestsBeforeAction + computedInterest;
    }

    // Action
    vm.startPrank(user);
    GHO_TOKEN.approve(address(POOL), amount);

    if (newDiscountRate != bs.discountPercent) {
      vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
      emit DiscountPercentUpdated(user, bs.discountPercent, newDiscountRate);
    }

    if (computedInterest > amount) {
      vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
      emit Transfer(address(0), user, computedInterest - amount);
    } else {
      vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
      emit Transfer(user, address(0), amount - computedInterest);
    }

    POOL.repay(address(GHO_TOKEN), amount, 2, user);
    vm.stopPrank();

    // Checks
    assertEq(
      GHO_TOKEN.balanceOf(user),
      bs.balanceBeforeAction - amount,
      'Gho amount does not match repay'
    );
    assertEq(GHO_DEBT_TOKEN.getDiscountPercent(user), newDiscountRate);
    if (expectedBurnOffset != 0) {
      assertEq(
        GHO_TOKEN.totalSupply(),
        bs.supplyBeforeAction - amount + computedInterest + bs.userInterestsBeforeAction,
        'Gho total supply does not match repay b'
      );
    } else {
      assertEq(
        GHO_TOKEN.totalSupply(),
        bs.supplyBeforeAction,
        'Gho total supply does not match repay a'
      );
    }

    assertEq(
      GHO_DEBT_TOKEN.scaledBalanceOf(user),
      bs.debtScaledBalanceBeforeAction - amount.rayDiv(bs.assetIndexBefore) - discountScaled,
      'Gho debt token balance does not match repay'
    );
    assertEq(
      GHO_DEBT_TOKEN.scaledTotalSupply(),
      bs.debtScaledSupplyBeforeAction - amount.rayDiv(bs.assetIndexBefore) - discountScaled,
      'Gho debt token Supply does not match repay'
    );
    assertEq(
      GHO_DEBT_TOKEN.getBalanceFromInterest(user),
      expectedDebt,
      'Gho debt interests does not match repay'
    );
  }

  function mintAndStakeDiscountToken(address user, uint256 amount) public {
    vm.prank(FAUCET);
    AAVE_TOKEN.mint(user, amount);

    vm.startPrank(user);
    AAVE_TOKEN.approve(address(STK_TOKEN), amount);
    STK_TOKEN.stake(user, amount);
    vm.stopPrank();
  }

  function rebalanceDiscountAction(address user) public {
    BorrowState memory bs;
    bs.supplyBeforeAction = GHO_TOKEN.totalSupply();
    bs.debtSupplyBeforeAction = GHO_DEBT_TOKEN.totalSupply();
    bs.debtScaledSupplyBeforeAction = GHO_DEBT_TOKEN.scaledTotalSupply();
    bs.balanceBeforeAction = GHO_TOKEN.balanceOf(user);
    bs.debtScaledBalanceBeforeAction = GHO_DEBT_TOKEN.scaledBalanceOf(user);
    bs.debtBalanceBeforeAction = GHO_DEBT_TOKEN.balanceOf(user);
    bs.userIndexBeforeAction = GHO_DEBT_TOKEN.getPreviousIndex(user);
    bs.userInterestsBeforeAction = GHO_DEBT_TOKEN.getBalanceFromInterest(user);
    bs.assetIndexBefore = POOL.getReserveNormalizedVariableDebt(address(GHO_TOKEN));
    bs.discountPercent = GHO_DEBT_TOKEN.getDiscountPercent(user);

    if (bs.userIndexBeforeAction == 0) {
      bs.userIndexBeforeAction = 1e27;
    }

    (uint256 computedInterest, uint256 discountScaled, ) = DebtUtils.computeDebt(
      bs.userIndexBeforeAction,
      bs.assetIndexBefore,
      bs.debtScaledBalanceBeforeAction,
      bs.userInterestsBeforeAction,
      bs.discountPercent
    );
    uint256 newDiscountRate = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
      (bs.debtScaledBalanceBeforeAction - discountScaled).rayMul(bs.assetIndexBefore),
      IERC20(address(STK_TOKEN)).balanceOf(user)
    );

    if (newDiscountRate != bs.discountPercent) {
      vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
      emit DiscountPercentUpdated(user, bs.discountPercent, newDiscountRate);
    }

    vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
    emit Transfer(address(0), user, computedInterest);
    vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
    emit Mint(address(0), user, computedInterest, computedInterest, bs.assetIndexBefore);

    // Action
    vm.prank(user);
    GHO_DEBT_TOKEN.rebalanceUserDiscountPercent(user);

    // Checks
    assertEq(
      GHO_TOKEN.balanceOf(user),
      bs.balanceBeforeAction,
      'Gho amount does not match rebalance'
    );
    assertEq(GHO_DEBT_TOKEN.getDiscountPercent(user), newDiscountRate);
    assertEq(
      GHO_TOKEN.totalSupply(),
      bs.supplyBeforeAction,
      'Gho total supply does not match rebalance'
    );

    assertEq(
      GHO_DEBT_TOKEN.scaledBalanceOf(user),
      bs.debtScaledBalanceBeforeAction - discountScaled,
      'Gho debt token balance does not match rebalance'
    );
    assertEq(
      GHO_DEBT_TOKEN.scaledTotalSupply(),
      bs.debtScaledSupplyBeforeAction - discountScaled,
      'Gho debt token Supply does not match borrow'
    );
    assertEq(
      GHO_DEBT_TOKEN.getBalanceFromInterest(user),
      bs.userInterestsBeforeAction + computedInterest,
      'Gho debt interests does not match borrow'
    );
  }

  /// Helper function to sell asset in the GSM
  function _sellAsset(
    Gsm gsm,
    TestnetERC20 token,
    address receiver,
    uint256 amount
  ) internal returns (uint256) {
    vm.startPrank(FAUCET);
    token.mint(FAUCET, amount);
    token.approve(address(gsm), amount);
    (, uint256 ghoBought) = gsm.sellAsset(amount, receiver);
    vm.stopPrank();
    return ghoBought;
  }

  /// Helper function to mint an amount of assets of an ERC4626 token
  function _mintVaultAssets(
    MockERC4626 vault,
    TestnetERC20 token,
    address receiver,
    uint256 amount
  ) internal {
    vm.startPrank(FAUCET);
    token.mint(FAUCET, amount);
    token.approve(address(vault), amount);
    vault.deposit(amount, receiver);
    vm.stopPrank();
  }

  /// Helper function to mint an amount of shares of an ERC4626 token
  function _mintVaultShares(
    MockERC4626 vault,
    TestnetERC20 token,
    address receiver,
    uint256 sharesAmount
  ) internal {
    uint256 assets = vault.previewMint(sharesAmount);
    vm.startPrank(FAUCET);
    token.mint(FAUCET, assets);
    token.approve(address(vault), assets);
    vault.deposit(assets, receiver);
    vm.stopPrank();
  }

  /// Helper function to sell shares of an ERC4626 token in the GSM
  function _sellAsset(
    Gsm4626 gsm,
    MockERC4626 vault,
    TestnetERC20 token,
    address receiver,
    uint256 amount
  ) internal returns (uint256) {
    uint256 assetsToMint = vault.previewRedeem(amount);
    _mintVaultAssets(vault, token, address(this), assetsToMint);
    vault.approve(address(gsm), amount);
    (, uint256 ghoBought) = gsm.sellAsset(amount, receiver);
    return ghoBought;
  }

  /// Helper function to alter the exchange rate between shares and assets in a ERC4626 vault
  function _changeExchangeRate(
    MockERC4626 vault,
    TestnetERC20 token,
    uint256 amount,
    bool inflate
  ) internal {
    if (inflate) {
      // Inflate
      vm.prank(FAUCET);
      token.mint(address(vault), amount);
    } else {
      // Deflate
      vm.prank(address(vault));
      token.transfer(address(1), amount);
    }
  }

  function _contains(address[] memory list, address item) internal pure returns (bool) {
    for (uint256 i = 0; i < list.length; i++) {
      if (list[i] == item) {
        return true;
      }
    }
    return false;
  }

  function getProxyAdminAddress(address proxy) internal view returns (address) {
    bytes32 adminSlot = vm.load(proxy, ERC1967_ADMIN_SLOT);
    return address(uint160(uint256(adminSlot)));
  }

  function getProxyImplementationAddress(address proxy) internal view returns (address) {
    bytes32 implSlot = vm.load(proxy, ERC1967_IMPLEMENTATION_SLOT);
    return address(uint160(uint256(implSlot)));
  }
}
