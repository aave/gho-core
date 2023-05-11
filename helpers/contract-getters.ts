import { Contract } from 'ethers';
import { tEthereumAddress } from './types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import {
  AaveOracle,
  AaveProtocolDataProvider,
  GhoInterestRateStrategy,
  GhoAToken,
  GhoDiscountRateStrategy,
  GhoOracle,
  GhoToken,
  GhoVariableDebtToken,
  GhoStableDebtToken,
  AToken,
  BaseImmutableAdminUpgradeabilityProxy,
  Pool,
  AggregatorInterface,
  MintableERC20,
  IERC20,
  PoolConfigurator,
  StableDebtToken,
  VariableDebtToken,
  StakedAaveV3,
  GhoFlashMinter,
  GhoManager,
  GhoStableDebtToken,
} from '../types';

// Prevent error HH9 when importing this file inside tasks or helpers at Hardhat config load
declare var hre: HardhatRuntimeEnvironment;

export const getAaveOracle = async (address: tEthereumAddress): Promise<AaveOracle> =>
  getContract('AaveOracle', address);

export const getAaveProtocolDataProvider = async (
  address: tEthereumAddress
): Promise<AaveProtocolDataProvider> => getContract('AaveProtocolDataProvider', address);

export const getGhoInterestRateStrategy = async (
  address?: tEthereumAddress
): Promise<GhoInterestRateStrategy> =>
  getContract(
    'GhoInterestRateStrategy',
    address || (await hre.deployments.get('GhoInterestRateStrategy')).address
  );

export const getGhoOracle = async (address?: tEthereumAddress): Promise<GhoOracle> =>
  getContract('GhoOracle', address || (await hre.deployments.get('GhoOracle')).address);

export const getGhoToken = async (address?: tEthereumAddress): Promise<GhoToken> =>
  getContract('GhoToken', address || (await hre.deployments.get('GhoToken')).address);

export const getGhoAToken = async (address?: tEthereumAddress): Promise<GhoAToken> =>
  getContract('GhoAToken', address || (await hre.deployments.get('GhoAToken')).address);

export const getGhoDiscountRateStrategy = async (
  address?: tEthereumAddress
): Promise<GhoDiscountRateStrategy> =>
  getContract(
    'GhoDiscountRateStrategy',
    address || (await hre.deployments.get('GhoDiscountRateStrategy')).address
  );

export const getGhoVariableDebtToken = async (
  address?: tEthereumAddress
): Promise<GhoVariableDebtToken> =>
  getContract(
    'GhoVariableDebtToken',
    address || (await hre.deployments.get('GhoVariableDebtToken')).address
  );

export const getGhoStableDebtToken = async (
  address?: tEthereumAddress
): Promise<GhoStableDebtToken> =>
  getContract(
    'GhoStableDebtToken',
    address || (await hre.deployments.get('GhoStableDebtToken')).address
  );

export const getGhoManager = async (address?: tEthereumAddress): Promise<GhoManager> =>
  getContract('GhoManager', address || (await hre.deployments.get('GhoManager')).address);

export const getBaseImmutableAdminUpgradeabilityProxy = async (
  address: tEthereumAddress
): Promise<BaseImmutableAdminUpgradeabilityProxy> =>
  getContract('BaseImmutableAdminUpgradeabilityProxy', address);

export const getERC20 = async (address: tEthereumAddress): Promise<IERC20> =>
  getContract(
    '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol:IERC20',
    address
  );

export const getAggregatorInterface = async (
  address?: tEthereumAddress
): Promise<AggregatorInterface> =>
  getContract(
    'AggregatorInterface',
    address || (await hre.deployments.get('AggregatorInterface')).address
  );

export const getPool = async (address: tEthereumAddress): Promise<Pool> =>
  getContract('Pool', address);

export const getPoolConfigurator = async (address: tEthereumAddress): Promise<PoolConfigurator> =>
  getContract('PoolConfigurator', address);

export const getAToken = async (address?: tEthereumAddress): Promise<AToken> =>
  getContract('AToken', address || (await hre.deployments.get('AToken')).address);

export const getVariableDebtToken = async (
  address?: tEthereumAddress
): Promise<VariableDebtToken> =>
  getContract(
    'VariableDebtToken',
    address || (await hre.deployments.get('VariableDebtToken')).address
  );

export const getStableDebtToken = async (address?: tEthereumAddress): Promise<StableDebtToken> =>
  getContract('StableDebtToken', address || (await hre.deployments.get('StableDebtToken')).address);

export const getStakedAave = async (address?: tEthereumAddress): Promise<StakedAaveV3> => {
  return (
    await getContract(
      'StakedAaveV3',
      address || (await hre.deployments.get('StakedAaveV3')).address
    )
  ).connect((await hre.ethers.getSigners())[2]) as StakedAaveV3;
};

export const getMintableErc20 = async (address?: tEthereumAddress): Promise<MintableERC20> =>
  getContract('MintableERC20', address);

export const getGhoFlashMinter = async (address?: tEthereumAddress): Promise<GhoFlashMinter> =>
  getContract('GhoFlashMinter', address);

export const getContract = async <ContractType extends Contract>(
  id: string,
  address?: tEthereumAddress
): Promise<ContractType> => {
  const artifact = await hre.deployments.getArtifact(id);
  return hre.ethers.getContractAt(
    artifact.abi,
    address || (await (await hre.deployments.get(id)).address)
  );
};
