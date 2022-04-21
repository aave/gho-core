import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Signer } from 'ethers';

export let DRE: HardhatRuntimeEnvironment;

export const setDRE = (_DRE) => {
  DRE = _DRE;
};

export const impersonateAccountHardhat = async (account: string): Promise<Signer> => {
  await DRE.network.provider.send('hardhat_setBalance', [account, '0xFFFFFFFFFFFFFFFFFFFFFFFFF']);

  await DRE.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [account],
  });
  return await DRE.ethers.getSigner(account);
};
