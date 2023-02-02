import { impersonateAccountHardhat } from '../../helpers/misc-utils';
import { tEthereumAddress } from '../../helpers/types';
import { BigNumber } from 'ethers';
import { IERC20 } from '../../../types';
import { ContractTransaction } from 'ethers';
import { Faucet } from '@aave/deploy-v3';

export const distributeErc20 = async (
  erc20: IERC20,
  whale: tEthereumAddress,
  recipients: tEthereumAddress[],
  amount: BigNumber
) => {
  const promises: Promise<ContractTransaction>[] = [];
  const whaleSigner = await impersonateAccountHardhat(whale);
  erc20 = erc20.connect(whaleSigner);
  recipients.forEach((recipient) => {
    promises.push(erc20.transfer(recipient, amount));
  });
  await Promise.all(promises);
};

export const mintErc20 = async (
  faucetOwner: Faucet,
  mintableErc20: tEthereumAddress,
  recipients: tEthereumAddress[],
  amount: BigNumber
) => {
  const promises: Promise<ContractTransaction>[] = [];
  recipients.forEach(async (recipient) => {
    promises.push(faucetOwner.mint(mintableErc20, recipient, amount));
  });
  await Promise.all(promises);
};
