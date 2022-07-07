import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { ghoTokenConfig } from '../../helpers/config';
import { getLendingPoolConfigurator } from '../../helpers/contract-getters';

task('initialize-gho-reserve', 'Initialize Gho Reserve').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  // get contracts
  const ghoATokenImplementation = await ethers.getContract('GhoAToken');
  const stableDebtTokenImplementation = await ethers.getContract('StableDebtToken');
  const ghoVariableDebtTokenImplementation = await ethers.getContract('GhoVariableDebtToken');
  const ghoInterestRateStrategy = await ethers.getContract('GhoInterestRateStrategy');
  let lendingPoolConfiguratior = await getLendingPoolConfigurator(
    aaveMarketAddresses.lendingPoolConfigurator
  );

  const governanceSigner = await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor);
  lendingPoolConfiguratior = lendingPoolConfiguratior.connect(governanceSigner);

  // init reserve
  const initReserveTx = await lendingPoolConfiguratior.initReserve(
    ghoATokenImplementation.address,
    stableDebtTokenImplementation.address,
    ghoVariableDebtTokenImplementation.address,
    ghoTokenConfig.TOKEN_DECIMALS,
    ghoInterestRateStrategy.address
  );

  let error = false;
  const initReserveTxReceipt = await initReserveTx.wait();
  if (initReserveTxReceipt && initReserveTxReceipt.events) {
    const initReserveEvents = initReserveTxReceipt.events.filter(
      (e) => e.event === 'ReserveInitialized'
    );
    if (initReserveEvents[0]) {
      const initReserveEvent = initReserveEvents[0];
      printReserveInfo(initReserveEvent);
    } else {
      error = true;
    }
  } else {
    error = true;
  }
  if (error) {
    console.log(`ERROR: oracle not configured correctly`);
  }
});

const printReserveInfo = (initReserveEvent) => {
  console.log(`Gho Reserve Initialized`);
  console.log(`\tasset:                       ${initReserveEvent.args.asset}`);
  console.log(`\tghoAToken:                      ${initReserveEvent.args.aToken}`);
  console.log(`\tstableDebtToken              ${initReserveEvent.args.stableDebtToken}`);
  console.log(`\tghoVariableDebtToken            ${initReserveEvent.args.variableDebtToken}`);
  console.log(
    `\tinterestRateStrategyAddress  ${initReserveEvent.args.interestRateStrategyAddress}`
  );
};
