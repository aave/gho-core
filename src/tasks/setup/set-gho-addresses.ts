import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses, ghoReserveConfig, helperAddresses } from '../../helpers/config';
import {
  getGhoAToken,
  getGhoVariableDebtToken,
  getGhoDiscountRateStrategy,
} from '../../helpers/contract-getters';
import { getAaveProtocolDataProvider } from '@aave/deploy-v3/dist/helpers/contract-getters';

task(
  'set-gho-addresses',
  'Set addresses as needed in GhoAToken and GhoVariableDebtToken'
).setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  let gho = await ethers.getContract('GhoToken');

  const aaveDataProvider = await getAaveProtocolDataProvider();

  const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
  let ghoAToken = await getGhoAToken(tokenProxyAddresses.aTokenAddress);
  let ghoVariableDebtToken = await getGhoVariableDebtToken(
    tokenProxyAddresses.variableDebtTokenAddress
  );

  const { deployer } = await hre.getNamedAccounts();
  const governanceSigner = await impersonateAccountHardhat(deployer);

  ghoAToken = ghoAToken.connect(governanceSigner);
  ghoVariableDebtToken = ghoVariableDebtToken.connect(governanceSigner);

  // set treasury
  const setTreasuryTx = await ghoAToken.setGhoTreasury(aaveMarketAddresses.treasury);
  const setTreasuryTxReceipt = await setTreasuryTx.wait();
  console.log(
    `GhoAToken treasury set to:                       ${aaveMarketAddresses.treasury} in tx: ${setTreasuryTxReceipt.transactionHash}`
  );

  // set variable debt token
  const setVariableDebtTx = await ghoAToken.setVariableDebtToken(
    tokenProxyAddresses.variableDebtTokenAddress
  );
  const setVariableDebtTxReceipt = await setVariableDebtTx.wait();
  console.log(
    `GhoAToken variableDebtContract set to:           ${tokenProxyAddresses.variableDebtTokenAddress} in tx: ${setVariableDebtTxReceipt.transactionHash}`
  );

  // set variable debt token
  const setATokenTx = await ghoVariableDebtToken.setAToken(tokenProxyAddresses.aTokenAddress);
  const setATokenTxReceipt = await setATokenTx.wait();
  console.log(
    `VariableDebtToken aToken set to:                 ${tokenProxyAddresses.aTokenAddress} in tx: ${setATokenTxReceipt.transactionHash}`
  );

  // set discount strategy
  const discountRateStrategy = await getGhoDiscountRateStrategy();
  const updateDiscountRateStrategyTx = await ghoVariableDebtToken.updateDiscountRateStrategy(
    discountRateStrategy.address
  );
  const updateDiscountRateStrategyTxReceipt = await updateDiscountRateStrategyTx.wait();
  console.log(
    `VariableDebtToken discount strategy set to:      ${discountRateStrategy.address} in tx: ${updateDiscountRateStrategyTxReceipt.transactionHash}`
  );

  // set discount token
  const discountTokenAddress = helperAddresses.stkAave;
  const updateDiscountTokenTx = await ghoVariableDebtToken.updateDiscountToken(
    discountTokenAddress
  );
  const updateDiscountTokenTxReceipt = await updateDiscountTokenTx.wait();
  console.log(
    `VariableDebtToken discount token set to:         ${discountTokenAddress} in tx: ${updateDiscountTokenTxReceipt.transactionHash}`
  );

  // set initial discount lock period
  const discountLockPeriod = ghoReserveConfig.DISCOUNT_LOCK_PERIOD;
  const updateDiscountLockPeriodTx = await ghoVariableDebtToken.updateDiscountLockPeriod(
    discountLockPeriod
  );
  const updateDiscountLockPeriodReceipt = await updateDiscountLockPeriodTx.wait();
  console.log(
    `VariableDebtToken discount lock period set to:   ${await ghoVariableDebtToken.getDiscountLockPeriod()} in tx: ${
      updateDiscountLockPeriodReceipt.transactionHash
    }`
  );
});
