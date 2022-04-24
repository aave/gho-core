import chai from 'chai';
import { Signer } from 'ethers';
import { solidity } from 'ethereum-waffle';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { tEthereumAddress } from '../../helpers/types';
import { evmSnapshot, evmRevert } from '../../helpers/misc-utils';

import { AnteiOracle, IChainlinkAggregator } from '../../../types';
import { getAnteiOracle, getIChainlinkAggregator } from '../../helpers/contract-getters';

declare var hre: HardhatRuntimeEnvironment;

chai.use(solidity);

export interface SignerWithAddress {
  signer: Signer;
  address: tEthereumAddress;
}

export interface TestEnv {
  deployer: SignerWithAddress;
  users: SignerWithAddress[];
  asdOracle: AnteiOracle;
  ethUsdOracle: IChainlinkAggregator;
  aTokenImplementation: {};
  stableDebtTokenImplementation: {};
  variableDebtTokenImplementation: {};
  anteiInterestRateStrategy: {};
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
  asdOracle: {} as AnteiOracle,
  ethUsdOracle: {} as IChainlinkAggregator,
  aTokenImplementation: {},
  stableDebtTokenImplementation: {},
  variableDebtTokenImplementation: {},
  anteiInterestRateStrategy: {},
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
  testEnv.asdOracle = await getAnteiOracle();
  testEnv.ethUsdOracle = await getIChainlinkAggregator(
    '0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419'
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
