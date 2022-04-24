import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import {
  getAnteiAToken,
  getAaveProtocolDataProvider,
  getAnteiVariableDebtToken,
} from '../../helpers/contract-getters';

task(
  'set-asd-addresses',
  'Set addresses as needed in AnteiAToken and AnteiVariableDebtToken'
).setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  let asd = await ethers.getContract('AnteiStableDollarEntities');

  const aaveDataProvider = await getAaveProtocolDataProvider(
    aaveMarketAddresses.aaveProtocolDataProvider
  );

  const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(asd.address);
  let anteiAToken = await getAnteiAToken(tokenProxyAddresses.aTokenAddress);
  let anteiVariableDebtToken = await getAnteiVariableDebtToken(
    tokenProxyAddresses.variableDebtTokenAddress
  );

  const governanceSigner = await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor);
  anteiAToken = anteiAToken.connect(governanceSigner);
  anteiVariableDebtToken = anteiVariableDebtToken.connect(governanceSigner);

  // set treasury
  const setTreasuryTx = await anteiAToken.setTreasury(aaveMarketAddresses.treasury);
  const setTreasuryTxReceipt = await setTreasuryTx.wait();
  console.log(
    `AnteiAToken treasury set to: ${aaveMarketAddresses.treasury} in tx: ${setTreasuryTxReceipt.transactionHash}`
  );

  // set variable debt token
  const setVariableDebtTx = await anteiAToken.setVariableDebtToken(
    tokenProxyAddresses.variableDebtTokenAddress
  );
  const setVariableDebtTxReceipt = await setVariableDebtTx.wait();
  console.log(
    `AnteiAToken variableDebtContract set to: ${tokenProxyAddresses.variableDebtTokenAddress} in tx: ${setVariableDebtTxReceipt.transactionHash}`
  );

  // set variable debt token
  const setATokenTx = await anteiVariableDebtToken.setAToken(tokenProxyAddresses.aTokenAddress);
  const setATokenTxReceipt = await setATokenTx.wait();
  console.log(
    `VariableDebtToken aToken set to: ${tokenProxyAddresses.aTokenAddress} in tx: ${setATokenTxReceipt.transactionHash}`
  );
});
