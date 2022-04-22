import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/aave-v2-addresses';
import { asdConfiguration } from '../../configs/asd-configuration';
import { getLendingPoolConfigurator } from '../../helpers/contract-getters';

task('initialize-asd-reserve', 'Initialize Antei Reserve').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  // get contracts
  const aTokenImplementation = await ethers.getContract('AToken');
  const stableDebtTokenImplementation = await ethers.getContract('StableDebtToken');
  const variableDebtTokenImplementation = await ethers.getContract('VariableDebtToken');
  const anteiInterestRateStrategy = await ethers.getContract('AnteiInterestRateStrategy');
  let lendingPoolConfiguratior = await getLendingPoolConfigurator(
    aaveMarketAddresses.lendingPoolConfigurator
  );

  const governanceSigner = await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor);
  lendingPoolConfiguratior = lendingPoolConfiguratior.connect(governanceSigner);

  // init reserve
  const initReserveTx = await lendingPoolConfiguratior.initReserve(
    aTokenImplementation.address,
    stableDebtTokenImplementation.address,
    variableDebtTokenImplementation.address,
    asdConfiguration.tokenConfig.TOKEN_DECIMALS,
    anteiInterestRateStrategy.address
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
  console.log(`Antei Reserve Initialized`);
  console.log(`\tasset:                       ${initReserveEvent.args.asset}`);
  console.log(`\taToken:                      ${initReserveEvent.args.aToken}`);
  console.log(`\tstableDebtToken              ${initReserveEvent.args.stableDebtToken}`);
  console.log(`\tvariableDebtToken            ${initReserveEvent.args.variableDebtToken}`);
  console.log(
    `\tinterestRateStrategyAddress  ${initReserveEvent.args.interestRateStrategyAddress}`
  );
};
