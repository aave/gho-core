import {
  DEFAULT_BLOCK_GAS_LIMIT,
  eEthereumNetwork,
  FORK,
  FORK_BLOCK_NUMBER,
  getAlchemyKey,
} from '@aave/deploy-v3';
import { HardhatNetworkForkingUserConfig } from 'hardhat/types';
import fs from 'fs';

/** HARDHAT NETWORK CONFIGURATION */
const MNEMONIC = process.env.MNEMONIC || '';
const MNEMONIC_PATH = "m/44'/60'/0'/0";

export const NETWORKS_RPC_URL: Record<string, string> = {
  [eEthereumNetwork.main]: `https://eth-mainnet.alchemyapi.io/v2/${getAlchemyKey(
    eEthereumNetwork.main
  )}`,
  [eEthereumNetwork.hardhat]: 'http://localhost:8545',
  [eEthereumNetwork.goerli]: `https://eth-goerli.alchemyapi.io/v2/${getAlchemyKey(
    eEthereumNetwork.goerli
  )}`,
  sepolia: 'https://rpc.sepolia.ethpandaops.io',
  baseSepolia: 'https://sepolia.base.org',
  fuji: 'https://ava-testnet.public.blastapi.io/ext/bc/C/rpc',
};

const GAS_PRICE_PER_NET: Record<string, number> = {};

export const LIVE_NETWORKS: Record<string, boolean> = {
  [eEthereumNetwork.main]: true,
};

/** HARDHAT HELPERS */
export const buildForkConfig = (): HardhatNetworkForkingUserConfig | undefined => {
  let forkMode: HardhatNetworkForkingUserConfig | undefined;
  if (FORK && NETWORKS_RPC_URL[FORK]) {
    forkMode = {
      url: NETWORKS_RPC_URL[FORK] as string,
    };
    console.log('Fork mode activated:', NETWORKS_RPC_URL[FORK]);
    if (FORK_BLOCK_NUMBER) {
      forkMode.blockNumber = FORK_BLOCK_NUMBER;
    }
  }
  return forkMode;
};

export const hardhatNetworkSettings = {
  blockGasLimit: DEFAULT_BLOCK_GAS_LIMIT,
  throwOnTransactionFailures: true,
  throwOnCallFailures: true,
  chainId: 31337,
  forking: buildForkConfig(),
  saveDeployments: true,
  allowUnlimitedContractSize: true,
  tags: ['local'],
  accounts:
    FORK && !!MNEMONIC
      ? {
          mnemonic: MNEMONIC,
          path: MNEMONIC_PATH,
          initialIndex: 0,
          count: 10,
        }
      : undefined,
};

export const getCommonNetworkConfig = (networkName: string, chainId?: number) => ({
  url: NETWORKS_RPC_URL[networkName] || '',
  blockGasLimit: DEFAULT_BLOCK_GAS_LIMIT,
  chainId,
  gasPrice: GAS_PRICE_PER_NET[networkName] || undefined,
  ...(!!MNEMONIC && {
    accounts: {
      mnemonic: MNEMONIC,
      path: MNEMONIC_PATH,
      initialIndex: 0,
      count: 10,
    },
  }),
  live: !!LIVE_NETWORKS[networkName],
});

export function getRemappings() {
  return fs
    .readFileSync('hardhat-remappings.txt', 'utf8')
    .split('\n')
    .filter(Boolean) // remove empty lines
    .map((line) => {
      return line.trim().split('=');
    });
}
