// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {WETH9Mock} from '@aave/periphery-v3/contracts/mocks/WETH9Mock.sol';
import {IERC20, ERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/ERC20.sol';
import {IStkAave} from '../facilitators/aave/stkAaveUpgrade/interfaces/IStkAave.sol';
import {GhoAToken} from '../facilitators/aave/tokens/GhoAToken.sol';
import {GhoToken} from '../gho/GhoToken.sol';
import {MockedPool} from './mocks/MockedPool.sol';
import {MockedProvider} from './mocks/MockedProvider.sol';
import {MockedAclManager} from './mocks/MockedAclManager.sol';
import {GhoVariableDebtToken} from '../facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {IGhoToken} from '../gho/interfaces/IGhoToken.sol';
import {GhoDiscountRateStrategy} from '../facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IAaveIncentivesController} from '@aave/core-v3/contracts/interfaces/IAaveIncentivesController.sol';

contract TestEnv is Test {
  address[3] users = [
    0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
    0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
    0x90F79bf6EB2c4f870365E785982E1f101E93b906
  ];
  address faucet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  GhoToken GHO_TOKEN;
  ERC20 AAVE_TOKEN;
  IStkAave STK_TOKEN;
  MockedPool POOL;
  MockedAclManager ACL_MANAGER;
  WETH9Mock WETH;
  GhoVariableDebtToken GHO_DEBT_TOKEN;
  GhoAToken GHO_ATOKEN;

  // Events to listen
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Mint(
    address indexed caller,
    address indexed onBehalfOf,
    uint256 value,
    uint256 balanceIncrease,
    uint256 index
  );

  function setupGho() public {
    bytes memory empty;
    ACL_MANAGER = new MockedAclManager();
    POOL = new MockedPool(
      IPoolAddressesProvider(address(new MockedProvider(address(ACL_MANAGER))))
    );
    GHO_TOKEN = new GhoToken();
    AAVE_TOKEN = new ERC20('AAVE', 'AAVE');
    STK_TOKEN = IStkAave(
      deployCode(
        'StakedAaveV2Rev4.sol:StakedTokenV2Rev4',
        abi.encode(
          IERC20(address(AAVE_TOKEN)),
          IERC20(address(AAVE_TOKEN)),
          1,
          1,
          address(0),
          address(0),
          1,
          'STK AAVE',
          'stkAAVE',
          18,
          faucet
        )
      )
    );
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
      address(0),
      ghoToken,
      IAaveIncentivesController(address(0)),
      18,
      'GHO AToken',
      'aGHO',
      empty
    );
    GHO_DEBT_TOKEN.updateDiscountToken(discountToken);
    GHO_DEBT_TOKEN.updateDiscountRateStrategy(address(new GhoDiscountRateStrategy()));
    GHO_DEBT_TOKEN.setAToken(address(GHO_ATOKEN));
    GHO_ATOKEN.setVariableDebtToken(address(GHO_DEBT_TOKEN));
    IGhoToken.Facilitator memory facilitatorData = IGhoToken.Facilitator({
      bucketCapacity: 100_000_000e18,
      bucketLevel: 0,
      label: 'Gho AToken Market'
    });
    IGhoToken(ghoToken).addFacilitator(address(GHO_ATOKEN), facilitatorData);
    POOL.setGhoTokens(GHO_DEBT_TOKEN, GHO_ATOKEN);

    IGhoToken.Facilitator memory faucetFacilitator = IGhoToken.Facilitator({
      bucketCapacity: 100_000_000e18,
      bucketLevel: 1,
      label: 'Faucet Facilitator'
    });
    IGhoToken(ghoToken).addFacilitator(faucet, facilitatorData);
  }

  function ghoFaucet(address to, uint256 amount) public {
    vm.stopPrank();
    vm.prank(faucet);
    GHO_TOKEN.mint(to, amount);
  }

  constructor() {
    setupGho();
  }
}
