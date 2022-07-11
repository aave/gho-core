import chai from 'chai';
import { Signer } from 'ethers';
import { solidity } from 'ethereum-waffle';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { tEthereumAddress } from '../../helpers/types';
import { evmSnapshot, evmRevert, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses, helperAddresses } from '../../helpers/config';
import { distributeErc20 } from './user-setup';

import {
  AaveOracle,
  AaveProtocolDataProvider,
  GhoAToken,
  GhoDiscountRateStrategy,
  GhoInterestRateStrategy,
  GhoToken,
  GhoOracle,
  GhoVariableDebtToken,
  IChainlinkAggregator,
  LendingPool,
  IERC20,
  StableDebtToken,
  StakedTokenV2Rev4,
} from '../../../types';
import {
  getAaveOracle,
  getAaveProtocolDataProvider,
  getGhoDiscountRateStrategy,
  getGhoInterestRateStrategy,
  getGhoOracle,
  getGhoToken,
  getGhoAToken,
  getGhoVariableDebtToken,
  getIChainlinkAggregator,
  getLendingPool,
  getStableDebtToken,
  getERC20,
  getStakedAave,
} from '../../helpers/contract-getters';

declare var hre: HardhatRuntimeEnvironment;

chai.use(solidity);

export interface SignerWithAddress {
  signer: Signer;
  address: tEthereumAddress;
}

export interface TestEnv {
  deployer: SignerWithAddress;
  poolAdmin: SignerWithAddress;
  emergencyAdmin: SignerWithAddress;
  riskAdmin: SignerWithAddress;
  stkAaveWhale: SignerWithAddress;
  users: SignerWithAddress[];
  gho: GhoToken;
  ghoOracle: GhoOracle;
  ethUsdOracle: IChainlinkAggregator;
  aToken: GhoAToken;
  stableDebtToken: StableDebtToken;
  variableDebtToken: GhoVariableDebtToken;
  aTokenImplementation: GhoAToken;
  stableDebtTokenImplementation: StableDebtToken;
  variableDebtTokenImplementation: GhoVariableDebtToken;
  interestRateStrategy: GhoInterestRateStrategy;
  discountRateStrategy: GhoDiscountRateStrategy;
  pool: LendingPool;
  stakedAave: StakedTokenV2Rev4;
  aaveDataProvider: AaveProtocolDataProvider;
  aaveOracle: AaveOracle;
  weth: IERC20;
  usdc: IERC20;
  aaveToken: IERC20;
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
  stkAaveWhale: {} as SignerWithAddress,
  users: [] as SignerWithAddress[],
  gho: {} as GhoToken,
  ghoOracle: {} as GhoOracle,
  ethUsdOracle: {} as IChainlinkAggregator,
  aToken: {} as GhoAToken,
  stableDebtToken: {} as StableDebtToken,
  variableDebtToken: {} as GhoVariableDebtToken,
  aTokenImplementation: {} as GhoAToken,
  stableDebtTokenImplementation: {} as StableDebtToken,
  variableDebtTokenImplementation: {} as GhoVariableDebtToken,
  interestRateStrategy: {} as GhoInterestRateStrategy,
  discountRateStrategy: {} as GhoDiscountRateStrategy,
  pool: {} as LendingPool,
  stakedAave: {} as StakedTokenV2Rev4,
  aaveDataProvider: {} as AaveProtocolDataProvider,
  aaveOracle: {} as AaveOracle,
  weth: {} as IERC20,
  usdc: {} as IERC20,
  aaveToken: {} as IERC20,
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

  // get contracts from gho deployment
  testEnv.gho = await getGhoToken();
  testEnv.ghoOracle = await getGhoOracle();
  testEnv.ethUsdOracle = await getIChainlinkAggregator(
    '0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419'
  );
  testEnv.pool = await getLendingPool(aaveMarketAddresses.pool);
  testEnv.aaveDataProvider = await getAaveProtocolDataProvider(
    aaveMarketAddresses.aaveProtocolDataProvider
  );

  const tokenProxyAddresses = await testEnv.aaveDataProvider.getReserveTokensAddresses(
    testEnv.gho.address
  );
  testEnv.aToken = await getGhoAToken(tokenProxyAddresses.aTokenAddress);
  testEnv.stableDebtToken = await getStableDebtToken(tokenProxyAddresses.stableDebtTokenAddress);
  testEnv.variableDebtToken = await getGhoVariableDebtToken(
    tokenProxyAddresses.variableDebtTokenAddress
  );

  testEnv.aTokenImplementation = await getGhoAToken();
  testEnv.stableDebtTokenImplementation = await getStableDebtToken();
  testEnv.variableDebtTokenImplementation = await getGhoVariableDebtToken();

  testEnv.interestRateStrategy = await getGhoInterestRateStrategy();
  testEnv.discountRateStrategy = await getGhoDiscountRateStrategy();
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

  testEnv.stkAaveWhale.address = hre.ethers.utils.getAddress(helperAddresses.stkAaveWhale);
  testEnv.stkAaveWhale.signer = await impersonateAccountHardhat(helperAddresses.stkAaveWhale);

  testEnv.stakedAave = await getStakedAave(helperAddresses.stkAave);
  testEnv.aaveToken = await getERC20(helperAddresses.aaveToken);
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
