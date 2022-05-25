import chai from 'chai';
import { Signer } from 'ethers';
import { solidity } from 'ethereum-waffle';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { tEthereumAddress } from '../../helpers/types';
import { evmSnapshot, evmRevert } from '../../helpers/misc-utils';
import { aaveMarketAddresses, helperAddresses } from '../../helpers/config';
import { distributeErc20 } from './user-setup';

import {
  AaveOracle,
  AaveProtocolDataProvider,
  AnteiAToken,
  AnteiDiscountRateStrategy,
  AnteiInterestRateStrategy,
  AnteiStableDollarEntities,
  AnteiOracle,
  AnteiVariableDebtToken,
  IChainlinkAggregator,
  LendingPool,
  IERC20,
  StableDebtToken,
} from '../../../types';
import {
  getAaveOracle,
  getAaveProtocolDataProvider,
  getAnteiDiscountRateStrategy,
  getAnteiInterestRateStrategy,
  getAnteiOracle,
  getAnteiToken,
  getAnteiAToken,
  getAnteiVariableDebtToken,
  getIChainlinkAggregator,
  getLendingPool,
  getStableDebtToken,
  getERC20,
} from '../../helpers/contract-getters';

declare var hre: HardhatRuntimeEnvironment;

chai.use(solidity);

export interface SignerWithAddress {
  signer: Signer;
  address: tEthereumAddress;
}

export interface TestEnv {
  deployer: SignerWithAddress;
  users: SignerWithAddress[];
  asd: AnteiStableDollarEntities;
  asdOracle: AnteiOracle;
  ethUsdOracle: IChainlinkAggregator;
  aToken: AnteiAToken;
  stableDebtToken: StableDebtToken;
  variableDebtToken: AnteiVariableDebtToken;
  aTokenImplementation: AnteiAToken;
  stableDebtTokenImplementation: StableDebtToken;
  variableDebtTokenImplementation: AnteiVariableDebtToken;
  interestRateStrategy: AnteiInterestRateStrategy;
  discountRateStrategy: AnteiDiscountRateStrategy;
  pool: LendingPool;
  aaveDataProvider: AaveProtocolDataProvider;
  aaveOracle: AaveOracle;
  weth: IERC20;
  usdc: IERC20;
}

let HardhatSnapshotId: string = '0x1';
const setHardhatSnapshotId = (id: string) => {
  HardhatSnapshotId = id;
};

const testEnv: TestEnv = {
  deployer: {} as SignerWithAddress,
  poolAdmin: {} as SignerWithAddress,
  emergencyAdmin: {} as SignerWithAddress,
  riskAdmin: {} as SignerWithAddress,
  users: [] as SignerWithAddress[],
  asd: {} as AnteiStableDollarEntities,
  asdOracle: {} as AnteiOracle,
  ethUsdOracle: {} as IChainlinkAggregator,
  aToken: {} as AnteiAToken,
  stableDebtToken: {} as StableDebtToken,
  variableDebtToken: {} as AnteiVariableDebtToken,
  aTokenImplementation: {} as AnteiAToken,
  stableDebtTokenImplementation: {} as StableDebtToken,
  variableDebtTokenImplementation: {} as AnteiVariableDebtToken,
  interestRateStrategy: {} as AnteiInterestRateStrategy,
  discountRateStrategy: {} as AnteiDiscountRateStrategy,
  pool: {} as LendingPool,
  aaveDataProvider: {} as AaveProtocolDataProvider,
  aaveOracle: {} as AaveOracle,
  weth: {} as IERC20,
  usdc: {} as IERC20,
} as TestEnv;

export async function initializeMakeSuite() {
  const [_deployer, ...restSigners] = await hre.ethers.getSigners();
  const deployer: SignerWithAddress = {
    address: await _deployer.getAddress(),
    signer: _deployer,
  };

  for (const signer of restSigners) {
    testEnv.users.push({
      signer,
      address: await signer.getAddress(),
    });
  }
  testEnv.deployer = deployer;

  // get contracts from antei deployment
  testEnv.asd = await getAnteiToken();
  testEnv.asdOracle = await getAnteiOracle();
  testEnv.ethUsdOracle = await getIChainlinkAggregator(
    '0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419'
  );
  testEnv.pool = await getLendingPool(aaveMarketAddresses.pool);
  testEnv.aaveDataProvider = await getAaveProtocolDataProvider(
    aaveMarketAddresses.aaveProtocolDataProvider
  );

  const tokenProxyAddresses = await testEnv.aaveDataProvider.getReserveTokensAddresses(
    testEnv.asd.address
  );
  testEnv.aToken = await getAnteiAToken(tokenProxyAddresses.aTokenAddress);
  testEnv.stableDebtToken = await getStableDebtToken(tokenProxyAddresses.stableDebtTokenAddress);
  testEnv.variableDebtToken = await getAnteiVariableDebtToken(
    tokenProxyAddresses.variableDebtTokenAddress
  );

  testEnv.aTokenImplementation = await getAnteiAToken();
  testEnv.stableDebtTokenImplementation = await getStableDebtToken();
  testEnv.variableDebtTokenImplementation = await getAnteiVariableDebtToken();

  testEnv.interestRateStrategy = await getAnteiInterestRateStrategy();
  testEnv.discountRateStrategy = await getAnteiDiscountRateStrategy();
  testEnv.aaveOracle = await getAaveOracle(aaveMarketAddresses.aaveOracle);

  testEnv.weth = await getERC20(aaveMarketAddresses.weth);
  await distributeErc20(
    testEnv.weth,
    helperAddresses.wethWhale,
    testEnv.users.map((u) => u.address),
    hre.ethers.utils.parseUnits('1000.0', 18)
  );

  testEnv.usdc = await getERC20(aaveMarketAddresses.usdc);

  await distributeErc20(
    testEnv.usdc,
    helperAddresses.usdcWhale,
    testEnv.users.map((u) => u.address),
    hre.ethers.utils.parseUnits('100000.0', 6)
  );
}

const setSnapshot = async () => {
  setHardhatSnapshotId(await evmSnapshot());
};

const revertHead = async () => {
  await evmRevert(HardhatSnapshotId);
};

export function makeSuite(name: string, tests: (testEnv: TestEnv) => void) {
  describe(name, () => {
    before(async () => {
      await setSnapshot();
    });
    tests(testEnv);
    after(async () => {
      await revertHead();
    });
  });
}
