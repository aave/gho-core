import chai from 'chai';
import { Signer } from 'ethers';
import { solidity } from 'ethereum-waffle';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { tEthereumAddress } from '../../helpers/types';
import { evmSnapshot, evmRevert, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses, helperAddresses } from '../../helpers/config';
import { mintErc20 } from './user-setup';

import {
  AaveOracle,
  AaveProtocolDataProvider,
  GhoAToken,
  GhoDiscountRateStrategy,
  GhoInterestRateStrategy,
  GhoToken,
  GhoOracle,
  GhoVariableDebtToken,
  AggregatorInterface,
  Pool,
  IERC20,
  StableDebtToken,
  StakedTokenV2Rev4,
  MintableERC20,
  GhoFlashMinter,
} from '../../../types';
import {
  getGhoDiscountRateStrategy,
  getGhoInterestRateStrategy,
  getGhoOracle,
  getGhoToken,
  getGhoAToken,
  getGhoVariableDebtToken,
  getAggregatorInterface,
  getStableDebtToken,
  getERC20,
  getStakedAave,
  getMintableErc20,
  getGhoFlashMinter,
} from '../../helpers/contract-getters';
import {
  getPool,
  getAaveProtocolDataProvider,
  getAaveOracle,
  getACLManager,
} from '@aave/deploy-v3/dist/helpers/contract-getters';
import { ACLManager, getPoolAddressesProvider } from '@aave/deploy-v3';

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
  aclAdmin: SignerWithAddress;
  users: SignerWithAddress[];
  gho: GhoToken;
  ghoOracle: GhoOracle;
  ethUsdOracle: AggregatorInterface;
  aToken: GhoAToken;
  stableDebtToken: StableDebtToken;
  variableDebtToken: GhoVariableDebtToken;
  aTokenImplementation: GhoAToken;
  stableDebtTokenImplementation: StableDebtToken;
  variableDebtTokenImplementation: GhoVariableDebtToken;
  interestRateStrategy: GhoInterestRateStrategy;
  discountRateStrategy: GhoDiscountRateStrategy;
  pool: Pool;
  aclManager: ACLManager;
  stakedAave: StakedTokenV2Rev4;
  aaveDataProvider: AaveProtocolDataProvider;
  aaveOracle: AaveOracle;
  weth: MintableERC20;
  usdc: MintableERC20;
  aaveToken: IERC20;
  flashMinter: GhoFlashMinter;
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
  aclAdmin: {} as SignerWithAddress,
  users: [] as SignerWithAddress[],
  gho: {} as GhoToken,
  ghoOracle: {} as GhoOracle,
  ethUsdOracle: {} as AggregatorInterface,
  aToken: {} as GhoAToken,
  stableDebtToken: {} as StableDebtToken,
  variableDebtToken: {} as GhoVariableDebtToken,
  aTokenImplementation: {} as GhoAToken,
  stableDebtTokenImplementation: {} as StableDebtToken,
  variableDebtTokenImplementation: {} as GhoVariableDebtToken,
  interestRateStrategy: {} as GhoInterestRateStrategy,
  discountRateStrategy: {} as GhoDiscountRateStrategy,
  pool: {} as Pool,
  aclManager: {} as ACLManager,
  stakedAave: {} as StakedTokenV2Rev4,
  aaveDataProvider: {} as AaveProtocolDataProvider,
  aaveOracle: {} as AaveOracle,
  weth: {} as MintableERC20,
  usdc: {} as MintableERC20,
  aaveToken: {} as IERC20,
  flashMinter: {} as GhoFlashMinter,
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
  testEnv.poolAdmin = deployer;
  testEnv.aclAdmin = deployer;

  // get contracts from gho deployment
  testEnv.gho = await getGhoToken();
  testEnv.ghoOracle = await getGhoOracle();
  testEnv.ethUsdOracle = await getAggregatorInterface('0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419');
  testEnv.pool = await getPool();
  testEnv.aaveDataProvider = await getAaveProtocolDataProvider();

  testEnv.aclManager = await getACLManager();

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
  testEnv.aaveOracle = await getAaveOracle();

  testEnv.weth = await getMintableErc20(aaveMarketAddresses.weth);
  testEnv.usdc = await getMintableErc20(aaveMarketAddresses.usdc);

  const userAddresses = testEnv.users.map((u) => u.address);

  await mintErc20(testEnv.weth, userAddresses, hre.ethers.utils.parseUnits('1000.0', 18));

  await mintErc20(testEnv.usdc, userAddresses, hre.ethers.utils.parseUnits('100000.0', 18));

  testEnv.stkAaveWhale.address = helperAddresses.stkAaveWhale;
  testEnv.stkAaveWhale.signer = await impersonateAccountHardhat(helperAddresses.stkAaveWhale);

  testEnv.stakedAave = await getStakedAave(helperAddresses.stkAave);
  testEnv.aaveToken = await getERC20(helperAddresses.aaveToken);

  testEnv.flashMinter = await getGhoFlashMinter();
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
