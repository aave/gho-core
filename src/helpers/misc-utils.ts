import { formatEther } from 'ethers/lib/utils';
import path from 'path';
import fs from 'fs';
import { BigNumber, Signer } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { tEthereumAddress } from './types';
import { config } from 'dotenv';
import Bluebird from 'bluebird';
import { getWalletBalances } from '@aave/deploy-v3';

config();

declare var hre: HardhatRuntimeEnvironment;

export const evmSnapshot = async () => await hre.ethers.provider.send('evm_snapshot', []);

export const evmRevert = async (id: string) => hre.ethers.provider.send('evm_revert', [id]);

export const timeLatest = async () => {
  const block = await hre.ethers.provider.getBlock('latest');
  return BigNumber.from(block.timestamp);
};

export const setBlocktime = async (time: number) => {
  await hre.ethers.provider.send('evm_setNextBlockTimestamp', [time]);
};

export const advanceTimeAndBlock = async function (forwardTime: number) {
  const currentBlockNumber = await hre.ethers.provider.getBlockNumber();
  const currentBlock = await hre.ethers.provider.getBlock(currentBlockNumber);

  const currentTime = currentBlock.timestamp;
  const futureTime = currentTime + forwardTime;
  await hre.ethers.provider.send('evm_setNextBlockTimestamp', [futureTime]);
  await hre.ethers.provider.send('evm_mine', []);
};

export const mine = async () => {
  await hre.ethers.provider.send('evm_mine', []);
};

export const impersonateAccountHardhat = async (account: string): Promise<Signer> => {
  await hre.network.provider.send('hardhat_setBalance', [account, '0xFFFFFFFFFFFFFFFFFFFFFFFFF']);

  await hre.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [account],
  });
  return await hre.ethers.getSigner(account);
};

export const setCode = async (address: tEthereumAddress, bytecode: string): Promise<void> => {
  await hre.network.provider.request({
    method: 'hardhat_setCode',
    params: [address, bytecode],
  });
};

export const setStorageAt = async (
  address: tEthereumAddress,
  storageSlot: string,
  storageValue: string
): Promise<void> => {
  await hre.network.provider.request({
    method: 'hardhat_setStorageAt',
    params: [address, storageSlot, storageValue],
  });
};

export const getProxyImplementationBySlot = async (proxyAddress: tEthereumAddress) => {
  const proxyImplementationSlot = await hre.ethers.provider.getStorageAt(
    proxyAddress,
    '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc'
  );

  return hre.ethers.utils.getAddress(
    hre.ethers.utils.defaultAbiCoder.decode(['address'], proxyImplementationSlot).toString()
  );
};

export const FULL_DEPLOY = process.env.FULL_DEPLOY === 'true';

export const loadHardhatTasks = (taskFolders: string[]): void =>
  taskFolders.forEach((folder) => {
    const tasksPath = path.join(__dirname, '../../src/tasks', folder);
    fs.readdirSync(tasksPath)
      .filter((pth) => pth.includes('.ts') || pth.includes('.js'))
      .forEach((task) => {
        require(`${tasksPath}/${task}`);
      });
  });

export const setSignersBalance = async () => {
  const signers = await hre.ethers.getSigners();

  await Bluebird.each(signers, async (signer) => {
    await setBalance(signer.address);
  });

  const balances = await getWalletBalances();
  console.log('Balances');
  console.log('========');
  console.table(balances);
};

export const setBalance = async (address: string) => {
  await hre.ethers.provider.send('hardhat_setBalance', [address, '0x3635c9adc5dea00000']);
  console.log(
    'Updated balance',
    address,
    formatEther(await hre.ethers.provider.getBalance(address))
  );
};
