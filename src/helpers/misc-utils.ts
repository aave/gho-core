import { BigNumber } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Signer } from 'ethers';
import { tEthereumAddress } from './types';

export let DRE: HardhatRuntimeEnvironment;

export const setDRE = (_DRE) => {
  DRE = _DRE;
};

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
  const currentBlockNumber = await DRE.ethers.provider.getBlockNumber();
  const currentBlock = await DRE.ethers.provider.getBlock(currentBlockNumber);

  const currentTime = currentBlock.timestamp;
  const futureTime = currentTime + forwardTime;
  await DRE.ethers.provider.send('evm_setNextBlockTimestamp', [futureTime]);
  await DRE.ethers.provider.send('evm_mine', []);
};

export const mine = async () => {
  await hre.ethers.provider.send('evm_mine', []);
};

export const impersonateAccountHardhat = async (account: string): Promise<Signer> => {
  await DRE.network.provider.send('hardhat_setBalance', [account, '0xFFFFFFFFFFFFFFFFFFFFFFFFF']);

  await DRE.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [account],
  });
  return await DRE.ethers.getSigner(account);
};

export const setCode = async (address: tEthereumAddress, bytecode: string): Promise<void> => {
  await DRE.network.provider.request({
    method: 'hardhat_setCode',
    params: [address, bytecode],
  });
};

export const setStorageAt = async (
  address: tEthereumAddress,
  storageSlot: string,
  storageValue: string
): Promise<void> => {
  await DRE.network.provider.request({
    method: 'hardhat_setStorageAt',
    params: [address, storageSlot, storageValue],
  });
};
