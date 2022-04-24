import { Contract } from 'ethers';
import { tEthereumAddress } from './types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import {
  AnteiOracle,
  AToken,
  StableDebtToken,
  VariableDebtToken,
  IChainlinkAggregator,
} from '../../types';

// Prevent error HH9 when importing this file inside tasks or helpers at Hardhat config load
declare var hre: HardhatRuntimeEnvironment;

export const getAnteiOracle = async (address?: tEthereumAddress): Promise<AnteiOracle> =>
  getContract('AnteiOracle', address || (await hre.deployments.get('AnteiOracle')).address);

export const getIChainlinkAggregator = async (
  address?: tEthereumAddress
): Promise<IChainlinkAggregator> =>
  getContract(
    'IChainlinkAggregator',
    address || (await hre.deployments.get('IChainlinkAggregator')).address
  );

export const getAToken = async (address: tEthereumAddress): Promise<AToken> =>
  getContract('AToken', address);

export const getVariableDebtToken = async (address: tEthereumAddress): Promise<VariableDebtToken> =>
  getContract('VariableDebtToken', address);

export const getStableDebtToken = async (address: tEthereumAddress): Promise<StableDebtToken> =>
  getContract('StableDebtToken', address);

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
