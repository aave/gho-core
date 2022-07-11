import { ethers } from 'hardhat';
import { utils, BigNumber } from 'ethers';
import { TransactionReceipt } from '@ethersproject/providers';
import { GhoVariableDebtToken, VariableDebtToken } from '../../../types';

const GHO_VARIABLE_DEBT_TOKEN_EVENTS = [
  { sig: 'Transfer(address,address,uint256)', args: ['from', 'to', 'value'] },
  {
    sig: 'Mint(address,address,uint256,uint256,uint256)',
    args: ['caller', 'onBehalfOf', 'value', 'balanceIncrease', 'index'],
  },
  {
    sig: 'Burn(address,address,uint256,uint256,uint256)',
    args: ['from', 'target', 'value', 'balanceIncrease', 'index'],
  },
  {
    sig: 'DiscountPercentLocked(address,uint256,uint256)',
    args: ['user', 'nextDiscountPercent', 'rebalanceTimestamp'],
  },
];

export const printVariableDebtTokenEvents = (
  variableDebtToken: GhoVariableDebtToken,
  receipt: TransactionReceipt
) => {
  for (const eventSig of GHO_VARIABLE_DEBT_TOKEN_EVENTS) {
    const eventName = eventSig.sig.split('(')[0];
    const encodedSig = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(eventSig.sig));
    const rawEvents = receipt.logs.filter(
      (log) => log.topics[0] === encodedSig && log.address == variableDebtToken.address
    );
    for (const rawEvent of rawEvents) {
      const rawParsed = variableDebtToken.interface.decodeEventLog(
        eventName,
        rawEvent.data,
        rawEvent.topics
      );
      const parsed: any[] = [];

      let i = 0;
      for (const arg of eventSig.args) {
        parsed[i] = ['value', 'balanceIncrease', 'amountDiscounted'].includes(arg)
          ? ethers.utils.formatEther(rawParsed[arg])
          : rawParsed[arg];
        i++;
      }

      console.log(`event ${eventName} ${parsed[0]} -> ${parsed[1]}: ${parsed.slice(2).join(' ')}`);
    }
  }
};

export const getVariableDebtTokenEvent = (
  variableDebtToken: GhoVariableDebtToken,
  receipt: TransactionReceipt,
  eventName: string
) => {
  const eventSig = GHO_VARIABLE_DEBT_TOKEN_EVENTS.find(
    (item) => item.sig.split('(')[0] === eventName
  );
  const results: utils.Result = [];
  if (eventSig) {
    const encodedSig = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(eventSig.sig));
    const rawEvents = receipt.logs.filter(
      (log) => log.topics[0] === encodedSig && log.address == variableDebtToken.address
    );
    for (const rawEvent of rawEvents) {
      results.push(
        variableDebtToken.interface.decodeEventLog(eventName, rawEvent.data, rawEvent.topics)
      );
    }
  }
  return results;
};
