import { task } from 'hardhat/config';
import { ethers } from 'ethers';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/aave-v2-addresses';

const LendingPoolConfiguratorV2Artifact = require('@aave/protocol-v2/artifacts/contracts/protocol/lendingpool/LendingPoolConfigurator.sol/LendingPoolConfigurator.json');
const AaveOracleV2Artifact = require('@aave/protocol-v2/artifacts/contracts/misc/AaveOracle.sol/AaveOracle.json');

const TOKEN_NAME = 'Antei Stable Dollar';
const TOKEN_SYMBOL = 'ASD';
const TOKEN_DECIMALS = 18;

const INTEREST_RATE = ethers.utils.parseUnits('2.0', 25);

task('antei-setup', 'Deploy and Configure Antei').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { deployments, ethers } = DRE;

  /*****************************************
   *        DEPLOY DEPENDENT CONTRACTS     *
   ******************************************/

  if (hre.network.name === 'hardhat') {
    await deployments.fixture(['full_antei_deploy']);
  } else {
    console.log('Contracts already deployed!');
  }
  const asd = await ethers.getContract('AnteiStableDollarEntities');
  const asdOracle = await ethers.getContract('AnteiOracle');
  const aTokenImplementation = await ethers.getContract('AToken');
  const stableDebtTokenImplementation = await ethers.getContract('StableDebtToken');
  const variableDebtTokenImplementation = await ethers.getContract('VariableDebtToken');
  const anteiInterestRateStrategy = await ethers.getContract('AnteiInterestRateStrategy');

  /*****************************************
   *          INITIALIZE RESERVE           *
   ******************************************/
  blankSpace();

  const lendingPoolConfiguratior = new ethers.Contract(
    aaveMarketAddresses.lendingPoolConfigurator,
    LendingPoolConfiguratorV2Artifact.abi,
    await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor)
  );

  const initReserveTx = await lendingPoolConfiguratior.initReserve(
    aTokenImplementation.address,
    stableDebtTokenImplementation.address,
    variableDebtTokenImplementation.address,
    TOKEN_DECIMALS,
    anteiInterestRateStrategy.address
  );
  const initReserveTxReceipt = await initReserveTx.wait();
  const initReserveEvents = initReserveTxReceipt.events.filter(
    (e) => e.event === 'ReserveInitialized'
  );
  const initReserveEvent = initReserveEvents[0];
  printReserveInfo(initReserveEvent);

  /*****************************************
   *            Configure Reserve          *
   * 1. enable borrowing                   *
   * 2. configure oracle                   *
   ******************************************/
  blankSpace();
  const enableBorrowingTx = await lendingPoolConfiguratior.enableBorrowingOnReserve(
    asd.address,
    false
  );
  const enableBorrowingTxReceipt = await enableBorrowingTx.wait();
  const borrowingEnabledEvents = enableBorrowingTxReceipt.events.filter(
    (e) => e.event === 'BorrowingEnabledOnReserve'
  );
  console.log(
    `Borrowing enabled on asset:\n\t${borrowingEnabledEvents[0].args.asset}\n\tstable borrowing: ${borrowingEnabledEvents[0].args.stableRateEnabled}`
  );

  const aaveOracle = new ethers.Contract(
    aaveMarketAddresses.aaveOracle,
    AaveOracleV2Artifact.abi,
    await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor)
  );

  blankSpace();
  const setSourcesTx = await aaveOracle.setAssetSources([asd.address], [asdOracle.address]);
  const setSourcesTxReceipt = await setSourcesTx.wait();
  const assetSourceUpdates = setSourcesTxReceipt.events.filter(
    (e) => e.event === 'AssetSourceUpdated'
  );
  console.log(
    `Source set to: ${assetSourceUpdates[0].args.source} for asset ${assetSourceUpdates[0].args.asset}`
  );
  console.log(`\nAntei Setup Complete!\n`);
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

const blankSpace = () => {
  console.log();
};
