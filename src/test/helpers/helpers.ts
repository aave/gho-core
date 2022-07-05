import { BigNumber, ContractReceipt } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

declare var hre: HardhatRuntimeEnvironment;

export const getTxCostAndTimestamp = async (tx: ContractReceipt) => {
  if (!tx.blockNumber || !tx.transactionHash || !tx.cumulativeGasUsed) {
    throw new Error('No tx blocknumber');
  }
  const txTimestamp = BigNumber.from(
    (await hre.ethers.provider.getBlock(tx.blockNumber)).timestamp
  );

  const txInfo = await hre.ethers.provider.getTransaction(tx.transactionHash);
  const gasPrice = txInfo.gasPrice ? txInfo.gasPrice : tx.effectiveGasPrice;
  const txCost = BigNumber.from(tx.cumulativeGasUsed).mul(gasPrice);

  return { txCost, txTimestamp };
};
