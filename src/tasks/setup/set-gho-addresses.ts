import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses, ghoReserveConfig, helperAddresses } from '../../helpers/config';
import {
  getGhoToken,
  getGhoAToken,
  getGhoVariableDebtToken,
  getGhoDiscountRateStrategy,
} from '../../helpers/contract-getters';
import { getAaveProtocolDataProvider } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { getNetwork } from '../../helpers/misc-utils';

task('set-gho-addresses', 'Set addresses as needed in GhoAToken and GhoVariableDebtToken')
  .addFlag('deploying', 'true or false contracts are being deployed')
  .setAction(async (params, hre) => {
    await hre.run('set-DRE');
    const { ethers } = DRE;

    const network = getNetwork();
    const { stkAave } = aaveMarketAddresses[network];

    let gho;
    let ghoAToken;
    let ghoVariableDebtToken;
    let aaveDataProvider;
    let treasuryAddress;
    let discountRateStrategy;

    // get contracts
    if (params.deploying) {
      gho = await ethers.getContract('GhoToken');
      aaveDataProvider = await getAaveProtocolDataProvider();
      treasuryAddress = aaveMarketAddresses[network].treasury;
      discountRateStrategy = await getGhoDiscountRateStrategy();
    } else {
      const contracts = require('../../../contracts.json');

      gho = await getGhoToken(contracts.GhoToken);
      aaveDataProvider = await getAaveProtocolDataProvider(contracts['PoolDataProvider-Test']);
      treasuryAddress = contracts.TreasuryProxy;
      discountRateStrategy = await getGhoDiscountRateStrategy(contracts.GhoDiscountRateStrategy);
    }

    const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
    ghoAToken = await getGhoAToken(tokenProxyAddresses.aTokenAddress);
    ghoVariableDebtToken = await getGhoVariableDebtToken(
      tokenProxyAddresses.variableDebtTokenAddress
    );

    // const { deployer } = await hre.getNamedAccounts();
    // const governanceSigner = await impersonateAccountHardhat(deployer);

    const [_deployer] = await hre.ethers.getSigners();

    ghoAToken = ghoAToken.connect(_deployer);
    ghoVariableDebtToken = ghoVariableDebtToken.connect(_deployer);

    // set treasury
    const setTreasuryTx = await ghoAToken.setGhoTreasury(treasuryAddress);
    const setTreasuryTxReceipt = await setTreasuryTx.wait();
    console.log(
      `GhoAToken treasury set to:                       ${treasuryAddress} in tx: ${setTreasuryTxReceipt.transactionHash}`
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

    const updateDiscountRateStrategyTx = await ghoVariableDebtToken.updateDiscountRateStrategy(
      discountRateStrategy.address
    );
    const updateDiscountRateStrategyTxReceipt = await updateDiscountRateStrategyTx.wait();
    console.log(
      `VariableDebtToken discount strategy set to:      ${discountRateStrategy.address} in tx: ${updateDiscountRateStrategyTxReceipt.transactionHash}`
    );

    // set discount token
    const discountTokenAddress = stkAave;
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
