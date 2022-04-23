import { Contract } from 'ethers';
import { tEthereumAddress } from './types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import {
  AaveOracle,
  AaveProtocolDataProvider,
  AnteiInterestRateStrategy,
  AnteiAToken,
  AnteiOracle,
  AnteiStableDollarEntities,
  AnteiVariableDebtToken,
  AToken,
  BaseImmutableAdminUpgradeabilityProxy,
  ILendingPool,
  IChainlinkAggregator,
  LendingPoolConfigurator,
  StableDebtToken,
  VariableDebtToken,
} from '../../types';

// Prevent error HH9 when importing this file inside tasks or helpers at Hardhat config load
declare var hre: HardhatRuntimeEnvironment;

export const getAaveOracle = async (address: tEthereumAddress): Promise<AaveOracle> =>
  getContract('AaveOracle', address);

export const getAaveProtocolDataProvider = async (
  address: tEthereumAddress
): Promise<AaveProtocolDataProvider> => getContract('AaveProtocolDataProvider', address);

export const getAnteiInterestRateStrategy = async (
  address?: tEthereumAddress
): Promise<AnteiInterestRateStrategy> =>
  getContract(
    'AnteiInterestRateStrategy',
    address || (await hre.deployments.get('AnteiInterestRateStrategy')).address
  );

export const getAnteiOracle = async (address?: tEthereumAddress): Promise<AnteiOracle> =>
  getContract('AnteiOracle', address || (await hre.deployments.get('AnteiOracle')).address);

export const getAnteiToken = async (
  address?: tEthereumAddress
): Promise<AnteiStableDollarEntities> =>
  getContract(
    'AnteiStableDollarEntities',
    address || (await hre.deployments.get('AnteiStableDollarEntities')).address
  );

export const getAnteiAToken = async (address?: tEthereumAddress): Promise<AnteiAToken> =>
  getContract('AnteiAToken', address || (await hre.deployments.get('AnteiAToken')).address);

export const getAnteiVariableDebtToken = async (
  address?: tEthereumAddress
): Promise<AnteiVariableDebtToken> =>
  getContract(
    'AnteiVariableDebtToken',
    address || (await hre.deployments.get('AnteiVariableDebtToken')).address
  );

export const getBaseImmutableAdminUpgradeabilityProxy = async (
  address: tEthereumAddress
): Promise<BaseImmutableAdminUpgradeabilityProxy> =>
  getContract('BaseImmutableAdminUpgradeabilityProxy', address);

export const getIChainlinkAggregator = async (
  address?: tEthereumAddress
): Promise<IChainlinkAggregator> =>
  getContract(
    'IChainlinkAggregator',
    address || (await hre.deployments.get('IChainlinkAggregator')).address
  );

export const getLendingPool = async (address: tEthereumAddress): Promise<ILendingPool> =>
  getContract('ILendingPool', address);

export const getLendingPoolConfigurator = async (
  address: tEthereumAddress
): Promise<LendingPoolConfigurator> => getContract('LendingPoolConfigurator', address);

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
