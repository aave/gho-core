import chai from 'chai';
import { Signer } from 'ethers';
import { solidity } from 'ethereum-waffle';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { tEthereumAddress } from '../../helpers/types';
import { evmSnapshot, evmRevert, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses, helperAddresses } from '../../helpers/config';
import { mintErc20 } from './user-setup';
import { getNetwork } from '../../helpers/misc-utils';

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
} from '../../helpers/contract-getters';
import {
  getPool,
  getAaveProtocolDataProvider,
  getAaveOracle,
} from '@aave/deploy-v3/dist/helpers/contract-getters';

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
  stakedAave: StakedTokenV2Rev4;
  aaveDataProvider: AaveProtocolDataProvider;
  aaveOracle: AaveOracle;
  treasuryAddress: tEthereumAddress;
  weth: MintableERC20;
  usdc: MintableERC20;
  aave: MintableERC20;
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
  stakedAave: {} as StakedTokenV2Rev4,
  aaveDataProvider: {} as AaveProtocolDataProvider,
  aaveOracle: {} as AaveOracle,
  treasuryAddress: {} as tEthereumAddress,
  weth: {} as MintableERC20,
  usdc: {} as MintableERC20,
  aave: {} as MintableERC20,
} as TestEnv;

export async function initializeMakeSuite(deploying: boolean) {
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

  let contracts;
  if (!deploying) {
    contracts = require('../../../contracts.json');
  }

  // get contracts from gho deployment
  testEnv.gho = await getGhoToken(deploying ? undefined : contracts.GhoToken);
  testEnv.ghoOracle = await getGhoOracle(deploying ? undefined : contracts.GhoOracle);
  testEnv.ethUsdOracle = await getAggregatorInterface('0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419');
  testEnv.pool = await getPool(deploying ? undefined : contracts['Pool-Proxy-Test']);
  testEnv.aaveDataProvider = await getAaveProtocolDataProvider(
    deploying ? undefined : contracts['PoolDataProvider-Test']
  );

  const tokenProxyAddresses = await testEnv.aaveDataProvider.getReserveTokensAddresses(
    testEnv.gho.address
  );
  testEnv.aToken = await getGhoAToken(tokenProxyAddresses.aTokenAddress);
  testEnv.stableDebtToken = await getStableDebtToken(tokenProxyAddresses.stableDebtTokenAddress);
  testEnv.variableDebtToken = await getGhoVariableDebtToken(
    tokenProxyAddresses.variableDebtTokenAddress
  );

  testEnv.aTokenImplementation = await getGhoAToken(deploying ? undefined : contracts.GhoAToken);
  testEnv.stableDebtTokenImplementation = await getStableDebtToken(
    deploying ? undefined : contracts.StableDebtToken
  );
  testEnv.variableDebtTokenImplementation = await getGhoVariableDebtToken(
    deploying ? undefined : contracts.GhoVariableDebtToken
  );

  testEnv.interestRateStrategy = await getGhoInterestRateStrategy(
    deploying ? undefined : contracts.GhoInterestRateStrategy
  );
  testEnv.discountRateStrategy = await getGhoDiscountRateStrategy(
    deploying ? undefined : contracts.GhoDiscountRateStrategy
  );
  testEnv.aaveOracle = await getAaveOracle(deploying ? undefined : contracts['AaveOracle-Test']);

  const network = getNetwork();

  testEnv.treasuryAddress = deploying
    ? aaveMarketAddresses[network].treasury
    : contracts.TreasuryProxy;
  testEnv.weth = await getMintableErc20(
    deploying ? aaveMarketAddresses[network].weth : contracts['WETH-TestnetMintableERC20-Test']
  );
  testEnv.usdc = await getMintableErc20(
    deploying ? aaveMarketAddresses[network].usdc : contracts['USDC-TestnetMintableERC20-Test']
  );

  const userAddresses = testEnv.users.map((u) => u.address);

  await mintErc20(testEnv.weth, userAddresses, hre.ethers.utils.parseUnits('1000.0', 18));

  await mintErc20(testEnv.usdc, userAddresses, hre.ethers.utils.parseUnits('100000.0', 18));

  if (network === 'goerli') {
    testEnv.aave = await getMintableErc20(aaveMarketAddresses[network].aave);
    await mintErc20(testEnv.aave, userAddresses, hre.ethers.utils.parseUnits('10.0', 18));
    console.log(await (await testEnv.aave.balanceOf(testEnv.users[1].address)).toString());
  }

  // testEnv.stkAaveWhale.address = helperAddresses.stkAaveWhale;
  // testEnv.stkAaveWhale.signer = await impersonateAccountHardhat(helperAddresses.stkAaveWhale);

  testEnv.stakedAave = (await getStakedAave(aaveMarketAddresses[network].stkAave)).connect(
    testEnv.users[0].address
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
