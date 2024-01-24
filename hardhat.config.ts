import {
  getCommonNetworkConfig,
  getRemappings,
  hardhatNetworkSettings,
} from './helpers/hardhat-config';
import { config } from 'dotenv';
import { HardhatUserConfig } from 'hardhat/types';
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from 'hardhat/builtin-tasks/task-names';
import { subtask } from 'hardhat/config';
import { DEFAULT_NAMED_ACCOUNTS, eEthereumNetwork } from '@aave/deploy-v3';
import '@nomicfoundation/hardhat-toolbox';
import 'hardhat-deploy';
import 'hardhat-contract-sizer';
import 'hardhat-dependency-compiler';
import 'hardhat-tracer';
import 'hardhat-preprocessor';

config();

import { loadHardhatTasks } from './helpers/misc-utils';
import '@aave/deploy-v3';

// Prevent to load tasks before compilation and typechain
if (!process.env.SKIP_LOAD) {
  loadHardhatTasks(['misc', 'testnet-setup', 'roles', 'main']);
}

const hardhatConfig: HardhatUserConfig = {
  networks: {
    hardhat: hardhatNetworkSettings,
    goerli: getCommonNetworkConfig(eEthereumNetwork.goerli, 5),
    sepolia: getCommonNetworkConfig('sepolia', 11155111),
    localhost: {
      url: 'http://127.0.0.1:8545',
      ...hardhatNetworkSettings,
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.10',
        settings: {
          optimizer: {
            enabled: true,
            runs: 100000,
          },
          evmVersion: 'london',
        },
      },
      {
        version: '0.8.0',
      },
      {
        version: '0.7.0',
        settings: {},
      },
      {
        version: '0.7.5',
        settings: {
          optimizer: { enabled: true, runs: 200 },
          evmVersion: 'istanbul',
        },
      },
      {
        version: '0.6.12',
        settings: {
          optimizer: { enabled: true, runs: 200 },
          evmVersion: 'istanbul',
        },
      },
    ],
  },
  paths: {
    sources: './src/',
    tests: './test/',
    cache: './cache',
    artifacts: './artifacts',
  },
  namedAccounts: {
    ...DEFAULT_NAMED_ACCOUNTS,
  },
  typechain: {
    outDir: 'types',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS ? true : false,
  },
  mocha: {
    timeout: 0,
    bail: true,
  },
  external: {
    contracts: [
      {
        artifacts: './artifacts',
        deploy: 'node_modules/@aave/deploy-v3/dist/deploy',
      },
    ],
  },
  dependencyCompiler: {
    paths: [
      '@aave/core-v3/contracts/protocol/configuration/PoolAddressesProviderRegistry.sol',
      '@aave/core-v3/contracts/protocol/configuration/PoolAddressesProvider.sol',
      '@aave/core-v3/contracts/misc/AaveOracle.sol',
      '@aave/core-v3/contracts/protocol/tokenization/AToken.sol',
      '@aave/core-v3/contracts/protocol/tokenization/DelegationAwareAToken.sol',
      '@aave/core-v3/contracts/protocol/tokenization/StableDebtToken.sol',
      '@aave/core-v3/contracts/protocol/tokenization/VariableDebtToken.sol',
      '@aave/core-v3/contracts/protocol/libraries/logic/GenericLogic.sol',
      '@aave/core-v3/contracts/protocol/libraries/logic/ValidationLogic.sol',
      '@aave/core-v3/contracts/protocol/libraries/logic/ReserveLogic.sol',
      '@aave/core-v3/contracts/protocol/libraries/logic/SupplyLogic.sol',
      '@aave/core-v3/contracts/protocol/libraries/logic/EModeLogic.sol',
      '@aave/core-v3/contracts/protocol/libraries/logic/BorrowLogic.sol',
      '@aave/core-v3/contracts/protocol/libraries/logic/BridgeLogic.sol',
      '@aave/core-v3/contracts/protocol/libraries/logic/FlashLoanLogic.sol',
      '@aave/core-v3/contracts/protocol/libraries/logic/CalldataLogic.sol',
      '@aave/core-v3/contracts/protocol/pool/Pool.sol',
      '@aave/core-v3/contracts/protocol/pool/L2Pool.sol',
      '@aave/core-v3/contracts/protocol/pool/PoolConfigurator.sol',
      '@aave/core-v3/contracts/protocol/pool/DefaultReserveInterestRateStrategy.sol',
      '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/InitializableImmutableAdminUpgradeabilityProxy.sol',
      '@aave/core-v3/contracts/dependencies/openzeppelin/upgradeability/InitializableAdminUpgradeabilityProxy.sol',
      '@aave/core-v3/contracts/deployments/ReservesSetupHelper.sol',
      '@aave/core-v3/contracts/misc/AaveProtocolDataProvider.sol',
      '@aave/core-v3/contracts/misc/L2Encoder.sol',
      '@aave/core-v3/contracts/protocol/configuration/ACLManager.sol',
      '@aave/core-v3/contracts/dependencies/weth/WETH9.sol',
      '@aave/core-v3/contracts/mocks/helpers/MockIncentivesController.sol',
      '@aave/core-v3/contracts/mocks/helpers/MockReserveConfiguration.sol',
      '@aave/core-v3/contracts/mocks/oracle/CLAggregators/MockAggregator.sol',
      '@aave/core-v3/contracts/mocks/tokens/MintableERC20.sol',
      '@aave/core-v3/contracts/mocks/flashloan/MockFlashLoanReceiver.sol',
      '@aave/core-v3/contracts/mocks/tokens/WETH9Mocked.sol',
      '@aave/core-v3/contracts/mocks/upgradeability/MockVariableDebtToken.sol',
      '@aave/core-v3/contracts/mocks/upgradeability/MockAToken.sol',
      '@aave/core-v3/contracts/mocks/upgradeability/MockStableDebtToken.sol',
      '@aave/core-v3/contracts/mocks/upgradeability/MockInitializableImplementation.sol',
      '@aave/core-v3/contracts/mocks/helpers/MockPool.sol',
      '@aave/core-v3/contracts/mocks/helpers/MockL2Pool.sol',
      '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol',
      '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol',
      '@aave/core-v3/contracts/mocks/oracle/PriceOracle.sol',
      '@aave/core-v3/contracts/mocks/tokens/MintableDelegationERC20.sol',
      '@aave/periphery-v3/contracts/misc/UiPoolDataProviderV3.sol',
      '@aave/periphery-v3/contracts/misc/WalletBalanceProvider.sol',
      '@aave/periphery-v3/contracts/misc/WrappedTokenGatewayV3.sol',
      '@aave/periphery-v3/contracts/misc/interfaces/IWETH.sol',
      '@aave/periphery-v3/contracts/misc/UiIncentiveDataProviderV3.sol',
      '@aave/periphery-v3/contracts/rewards/RewardsController.sol',
      '@aave/periphery-v3/contracts/rewards/transfer-strategies/StakedTokenTransferStrategy.sol',
      '@aave/periphery-v3/contracts/rewards/transfer-strategies/PullRewardsTransferStrategy.sol',
      '@aave/periphery-v3/contracts/rewards/EmissionManager.sol',
      '@aave/periphery-v3/contracts/mocks/WETH9Mock.sol',
      '@aave/periphery-v3/contracts/mocks/testnet-helpers/Faucet.sol',
      '@aave/periphery-v3/contracts/mocks/testnet-helpers/TestnetERC20.sol',
      '@aave/periphery-v3/contracts/treasury/Collector.sol',
      '@aave/periphery-v3/contracts/treasury/CollectorController.sol',
      '@aave/periphery-v3/contracts/treasury/AaveEcosystemReserveV2.sol',
      '@aave/periphery-v3/contracts/treasury/AaveEcosystemReserveController.sol',
      '@aave/periphery-v3/contracts/adapters/paraswap/ParaSwapLiquiditySwapAdapter.sol',
      '@aave/periphery-v3/contracts/adapters/paraswap/ParaSwapRepayAdapter.sol',
      '@aave/safety-module/contracts/stake/StakedAave.sol',
      '@aave/safety-module/contracts/stake/StakedAaveV2.sol',
      '@aave/safety-module/contracts/proposals/extend-stkaave-distribution/StakedTokenV2Rev3.sol',
      'aave-stk-v1-5/src/contracts/StakedAaveV3.sol',
    ],
  },
  tracer: {
    nameTags: {},
  },
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          for (const [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to);
              break;
            }
          }
        }
        return line;
      },
    }),
  },
};

export default hardhatConfig;
