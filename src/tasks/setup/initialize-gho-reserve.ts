import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { ghoTokenConfig } from '../../helpers/config';
import { getPoolConfiguratorProxy } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { BigNumberish, BytesLike } from 'ethers';
import { PoolConfigurator } from '@aave/deploy-v3';

task('initialize-gho-reserve', 'Initialize Gho Reserve').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  // get contracts
  const ghoATokenImplementation = await ethers.getContract('GhoAToken');
  const stableDebtTokenImplementation = await ethers.getContract('StableDebtToken');
  const ghoVariableDebtTokenImplementation = await ethers.getContract('GhoVariableDebtToken');
  const ghoInterestRateStrategy = await ethers.getContract('GhoInterestRateStrategy');
  const ghoToken = await ethers.getContract('GhoToken');

  let poolConfigurator = await getPoolConfiguratorProxy();

  const { deployer } = await hre.getNamedAccounts();
  const governanceSigner = await impersonateAccountHardhat(deployer);
  poolConfigurator = poolConfigurator.connect(governanceSigner);

  type InitReserveInputStruct = {
    aTokenImpl: string;
    stableDebtTokenImpl: string;
    variableDebtTokenImpl: string;
    underlyingAssetDecimals: BigNumberish;
    interestRateStrategyAddress: string;
    underlyingAsset: string;
    treasury: string;
    incentivesController: string;
    aTokenName: string;
    aTokenSymbol: string;
    variableDebtTokenName: string;
    variableDebtTokenSymbol: string;
    stableDebtTokenName: string;
    stableDebtTokenSymbol: string;
    params: BytesLike;
  };

  const reserveInput: InitReserveInputStruct = {
    aTokenImpl: ghoATokenImplementation.address,
    stableDebtTokenImpl: stableDebtTokenImplementation.address,
    variableDebtTokenImpl: ghoVariableDebtTokenImplementation.address,
    underlyingAssetDecimals: ghoTokenConfig.TOKEN_DECIMALS,
    interestRateStrategyAddress: ghoInterestRateStrategy.address,
    underlyingAsset: ghoToken.address,
    treasury: aaveMarketAddresses.treasury,
    incentivesController: aaveMarketAddresses.incentivesController,
    aTokenName: `Aave Ethereum GHO`,
    aTokenSymbol: `aEthGHO`,
    variableDebtTokenName: `Aave Variable Debt Ethereum GHO`,
    variableDebtTokenSymbol: `variableDebtEthGHO`,
    stableDebtTokenName: 'Aave Stable Debt Ethereum GHO',
    stableDebtTokenSymbol: 'stableDebtEthGHO',
    params: '0x10',
  };

  // init reserve
  const initReserveTx = await poolConfigurator.initReserves([reserveInput]);

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
  console.log(`\tghoAToken:                   ${initReserveEvent.args.aToken}`);
  console.log(`\tstableDebtToken              ${initReserveEvent.args.stableDebtToken}`);
  console.log(`\tghoVariableDebtToken         ${initReserveEvent.args.variableDebtToken}`);
  console.log(
    `\tinterestRateStrategyAddress  ${initReserveEvent.args.interestRateStrategyAddress}`
  );
};
