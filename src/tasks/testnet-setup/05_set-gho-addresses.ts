import { task } from 'hardhat/config';
import {
  STAKE_AAVE_PROXY,
  TREASURY_PROXY_ID,
  getAaveProtocolDataProvider,
  waitForTx,
} from '@aave/deploy-v3';
import { GhoToken } from '../../../types/src/contracts/gho/GhoToken';
import { ghoReserveConfig } from '../../helpers/config';
import {
  getGhoAToken,
  getGhoVariableDebtToken,
  getGhoDiscountRateStrategy,
} from '../../helpers/contract-getters';

task(
  'set-gho-addresses',
  'Set addresses as needed in GhoAToken and GhoVariableDebtToken'
).setAction(async (_, hre) => {
  const { ethers } = hre;

  const stkAave = await (await hre.deployments.get(STAKE_AAVE_PROXY)).address;

  const gho = (await ethers.getContract('GhoToken')) as GhoToken;
  const aaveDataProvider = await getAaveProtocolDataProvider();
  const treasuryAddress = await (await hre.deployments.get(TREASURY_PROXY_ID)).address;
  const discountRateStrategy = await getGhoDiscountRateStrategy();
  const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
  const ghoAToken = await getGhoAToken(tokenProxyAddresses.aTokenAddress);
  const ghoVariableDebtToken = await getGhoVariableDebtToken(
    tokenProxyAddresses.variableDebtTokenAddress
  );

  // Set treasury
  const setTreasuryTxReceipt = await waitForTx(await ghoAToken.updateGhoTreasury(treasuryAddress));
  console.log(
    `GhoAToken treasury set to: ${treasuryAddress} in tx: ${setTreasuryTxReceipt.transactionHash}`
  );

  // Set variable debt token
  const setVariableDebtTxReceipt = await waitForTx(
    await ghoAToken.setVariableDebtToken(tokenProxyAddresses.variableDebtTokenAddress)
  );
  console.log(
    `GhoAToken variableDebtContract set to: ${tokenProxyAddresses.variableDebtTokenAddress} in tx: ${setVariableDebtTxReceipt.transactionHash}`
  );

  // Set variable debt token
  const setATokenTxReceipt = await waitForTx(
    await ghoVariableDebtToken.setAToken(tokenProxyAddresses.aTokenAddress)
  );
  console.log(
    `VariableDebtToken aToken set to: ${tokenProxyAddresses.aTokenAddress} in tx: ${setATokenTxReceipt.transactionHash}`
  );

  // Set discount strategy
  const updateDiscountRateStrategyTxReceipt = await waitForTx(
    await ghoVariableDebtToken.updateDiscountRateStrategy(discountRateStrategy.address)
  );
  console.log(
    `VariableDebtToken discount strategy set to: ${discountRateStrategy.address} in tx: ${updateDiscountRateStrategyTxReceipt.transactionHash}`
  );

  // Set discount token
  const updateDiscountTokenTxReceipt = await waitForTx(
    await ghoVariableDebtToken.updateDiscountToken(stkAave)
  );
  console.log(
    `VariableDebtToken discount token set to:  ${stkAave} in tx: ${updateDiscountTokenTxReceipt.transactionHash}`
  );
});
