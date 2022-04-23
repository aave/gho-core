import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/aave-v2-addresses';
import { getAnteiAToken, getAaveProtocolDataProvider } from '../../helpers/contract-getters';
import { AnteiStableDollarEntities } from '../../../types/src/contracts/antei/';
import { asdEntityConfig } from '../../configs//asd-configuration';

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

  const governanceSigner = await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor);
  anteiAToken = anteiAToken.connect(governanceSigner);

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
});
