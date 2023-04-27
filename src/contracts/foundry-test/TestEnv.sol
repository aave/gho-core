// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {WETH9Mock} from '@aave/periphery-v3/contracts/mocks/WETH9Mock.sol';
import {ERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/ERC20.sol';
import {GhoAToken} from '../facilitators/aave/tokens/GhoAToken.sol';
import {GhoToken} from '../gho/GhoToken.sol';
import {MockedConfigurator} from './mocks/MockedConfigurator.sol';
import {MockedPool} from './mocks/MockedPool.sol';
import {MockedProvider} from './mocks/MockedProvider.sol';
import {MockedAclManager} from './mocks/MockedAclManager.sol';
import {GhoVariableDebtToken} from '../facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {GhoFlashMinter} from '../facilitators/flashMinter/GhoFlashMinter.sol';
import {MockFlashBorrower} from '../facilitators/flashMinter/mocks/MockFlashBorrower.sol';
import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';
import {IGhoToken} from '../gho/interfaces/IGhoToken.sol';
import {GhoDiscountRateStrategy} from '../facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol';
import {GhoInterestRateStrategy} from '../facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IAaveIncentivesController} from '@aave/core-v3/contracts/interfaces/IAaveIncentivesController.sol';
import {TestnetERC20} from '@aave/periphery-v3/contracts/mocks/testnet-helpers/TestnetERC20.sol';
import {StakedAaveV3} from 'aave-stk-v1-5/src/contracts/StakedAaveV3.sol';
import {IStakedAaveV3} from 'aave-stk-v1-5/src/interfaces/IStakedAaveV3.sol';
import {IERC20} from 'aave-stk-v1-5/src/interfaces/IERC20.sol';
import {IGhoVariableDebtTokenTransferHook} from 'aave-stk-v1-5/src/interfaces/IGhoVariableDebtTokenTransferHook.sol';
import {GhoOracle} from '../facilitators/aave/oracle/GhoOracle.sol';
import {AdminUpgradeabilityProxy} from '@aave/core-v3/contracts/dependencies/openzeppelin/upgradeability/AdminUpgradeabilityProxy.sol';

contract TestEnv is Test {
  address constant faucet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  address constant treasury = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
  address constant stkAaveExecutor = 0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;
  address constant stkAaveProxyDeployer = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;
  uint256 constant DEFAULT_FLASH_FEE = 9; // 0.09%
  uint128 constant DEFAULT_CAPACITY = 100_000_000e18;

  address[3] users = [
    0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
    0x90F79bf6EB2c4f870365E785982E1f101E93b906,
    0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
  ];
  GhoToken GHO_TOKEN;
  TestnetERC20 AAVE_TOKEN;
  IStakedAaveV3 STK_TOKEN;
  MockedPool POOL;
  MockedAclManager ACL_MANAGER;
  MockedProvider PROVIDER;
  MockedConfigurator CONFIGURATOR;
  WETH9Mock WETH;
  GhoVariableDebtToken GHO_DEBT_TOKEN;
  GhoAToken GHO_ATOKEN;
  GhoFlashMinter GHO_FLASH_MINTER;
  GhoDiscountRateStrategy GHO_DISCOUNT_STRATEGY;
  MockFlashBorrower FLASH_BORROWER;
  GhoOracle GHO_ORACLE;

  function setupGho() public {
    bytes memory empty;
    ACL_MANAGER = new MockedAclManager();
    PROVIDER = new MockedProvider(address(ACL_MANAGER));
    POOL = new MockedPool(IPoolAddressesProvider(address(PROVIDER)));
    CONFIGURATOR = new MockedConfigurator(IPool(POOL));
    GHO_ORACLE = new GhoOracle();
    GHO_TOKEN = new GhoToken();
    AAVE_TOKEN = new TestnetERC20('AAVE', 'AAVE', 18, faucet);
    StakedAaveV3 stkAave = new StakedAaveV3(
      IERC20(address(AAVE_TOKEN)),
      IERC20(address(AAVE_TOKEN)),
      1,
      address(0),
      address(0),
      1
    );
    vm.startPrank(stkAaveProxyDeployer);
    AdminUpgradeabilityProxy stkAaveProxy = new AdminUpgradeabilityProxy(
      address(stkAave),
      msg.sender,
      ''
    );
    StakedAaveV3(address(stkAaveProxy)).initialize(msg.sender, msg.sender, msg.sender, 0, 1);
    vm.stopPrank();
    STK_TOKEN = IStakedAaveV3(address(stkAaveProxy));
    address ghoToken = address(GHO_TOKEN);
    address discountToken = address(STK_TOKEN);
    IPool iPool = IPool(address(POOL));
    WETH = new WETH9Mock('Wrapped Ether', 'WETH', faucet);
    GHO_DEBT_TOKEN = new GhoVariableDebtToken(iPool);
    GHO_ATOKEN = new GhoAToken(iPool);
    GHO_DEBT_TOKEN.initialize(
      iPool,
      ghoToken,
      IAaveIncentivesController(address(0)),
      18,
      'GHO Variable Debt',
      'GHOVarDebt',
      empty
    );
    GHO_ATOKEN.initialize(
      iPool,
      treasury,
      ghoToken,
      IAaveIncentivesController(address(0)),
      18,
      'GHO AToken',
      'aGHO',
      empty
    );
    GHO_ATOKEN.updateGhoTreasury(treasury);
    GHO_DEBT_TOKEN.updateDiscountToken(discountToken);
    GHO_DISCOUNT_STRATEGY = new GhoDiscountRateStrategy();
    GHO_DEBT_TOKEN.updateDiscountRateStrategy(address(GHO_DISCOUNT_STRATEGY));
    GHO_DEBT_TOKEN.setAToken(address(GHO_ATOKEN));
    GHO_ATOKEN.setVariableDebtToken(address(GHO_DEBT_TOKEN));
    vm.prank(stkAaveExecutor);
    STK_TOKEN.setGHODebtToken(IGhoVariableDebtTokenTransferHook(address(GHO_DEBT_TOKEN)));
    IGhoToken(ghoToken).addFacilitator(address(GHO_ATOKEN), 'Gho Atoken Market', DEFAULT_CAPACITY);
    POOL.setGhoTokens(GHO_DEBT_TOKEN, GHO_ATOKEN);

    GHO_FLASH_MINTER = new GhoFlashMinter(
      address(GHO_TOKEN),
      treasury,
      DEFAULT_FLASH_FEE,
      address(PROVIDER)
    );
    FLASH_BORROWER = new MockFlashBorrower(IERC3156FlashLender(GHO_FLASH_MINTER));

    IGhoToken(ghoToken).addFacilitator(
      address(GHO_FLASH_MINTER),
      'Gho Flash Minter',
      DEFAULT_CAPACITY
    );
    IGhoToken(ghoToken).addFacilitator(
      address(FLASH_BORROWER),
      'Gho Flash Borrower',
      DEFAULT_CAPACITY
    );

    IGhoToken(ghoToken).addFacilitator(faucet, 'Faucet Facilitator', DEFAULT_CAPACITY);
  }

  function ghoFaucet(address to, uint256 amount) public {
    vm.prank(faucet);
    GHO_TOKEN.mint(to, amount);
  }

  constructor() {
    setupGho();
  }
}
