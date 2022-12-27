import chai from 'chai';
import { ContractTransaction, Signer } from 'ethers';
import { solidity } from 'ethereum-waffle';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { tEthereumAddress } from '../../helpers/types';
import { evmSnapshot, evmRevert, impersonateAccountHardhat, DRE } from '../../helpers/misc-utils';
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
import { ACLManager, ERC20FaucetOwnable, getERC20FaucetOwnable } from '@aave/deploy-v3';

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
  treasuryAddress: tEthereumAddress;
  shortExecutorAddress: tEthereumAddress;
  weth: MintableERC20;
  usdc: MintableERC20;
  aaveToken: IERC20;
  flashMinter: GhoFlashMinter;
  faucetOwner: ERC20FaucetOwnable;
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
  treasuryAddress: {} as tEthereumAddress,
  shortExecutorAddress: {} as tEthereumAddress,
  weth: {} as MintableERC20,
  usdc: {} as MintableERC20,
  aaveToken: {} as IERC20,
  flashMinter: {} as GhoFlashMinter,
  faucetOwner: {} as ERC20FaucetOwnable,
} as TestEnv;

export async function initializeMakeSuite(deploying: boolean) {
  const [_deployer, ...restSigners] = await hre.ethers.getSigners();

  const network = getNetwork();
  console.log('Network:', network);

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

  let contracts;
  if (!deploying) {
    contracts = require('../../../contracts.json');
  }

  // get contracts from gho deployment
  testEnv.gho = await getGhoToken(deploying ? undefined : contracts.GhoToken);
  testEnv.ghoOracle = await getGhoOracle(deploying ? undefined : contracts.GhoOracle);

  testEnv.ethUsdOracle = await getAggregatorInterface(aaveMarketAddresses[network].ethUsdOracle);
  testEnv.pool = await getPool(deploying ? undefined : contracts['Pool-Proxy-Test']);
  testEnv.aaveDataProvider = await getAaveProtocolDataProvider(
    deploying ? undefined : contracts['PoolDataProvider-Test']
  );

  testEnv.aclManager = await getACLManager(deploying ? undefined : contracts['ACLManager-Test']);

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

  testEnv.treasuryAddress = deploying
    ? aaveMarketAddresses[network].treasury
    : contracts.TreasuryProxy;

  testEnv.shortExecutorAddress = aaveMarketAddresses[network].shortExecutor;

  testEnv.faucetOwner = await getERC20FaucetOwnable();
  testEnv.weth = await getMintableErc20(
    deploying ? aaveMarketAddresses[network].weth : contracts['WETH-TestnetMintableERC20-Test']
  );
  testEnv.usdc = await getMintableErc20(
    deploying ? aaveMarketAddresses[network].usdc : contracts['USDC-TestnetMintableERC20-Test']
  );

  const userAddresses = testEnv.users.map((u) => u.address);

  await mintErc20(
    testEnv.faucetOwner,
    testEnv.weth.address,
    userAddresses,
    hre.ethers.utils.parseUnits('1000.0', 18)
  );

  await mintErc20(
    testEnv.faucetOwner,
    testEnv.usdc.address,
    userAddresses,
    hre.ethers.utils.parseUnits('100000.0', 18)
  );

  if (network === 'goerli') {
    testEnv.aaveToken = await getMintableErc20(
      aaveMarketAddresses[network].aave // AAVE linked to stkAave module
    );

    const promises: Promise<ContractTransaction>[] = [];
    userAddresses.forEach(async (recipient) => {
      const signer = await impersonateAccountHardhat(recipient);
      promises.push(
        testEnv.aaveToken.connect(signer)['mint(uint256)'](hre.ethers.utils.parseUnits('10.0', 18))
      );
    });
    await Promise.all(promises);
  }

  testEnv.stakedAave = (await getStakedAave(aaveMarketAddresses[network].stkAave)).connect(
    testEnv.users[0].address
  );

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
