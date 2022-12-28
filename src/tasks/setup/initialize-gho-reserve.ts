import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { ghoTokenConfig } from '../../helpers/config';
import {
  getAToken,
  getStableDebtToken,
  getVariableDebtToken,
  getGhoInterestRateStrategy,
  getGhoToken,
} from '../../helpers/contract-getters';
import { getPoolConfiguratorProxy } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { getNetwork } from '../../helpers/misc-utils';
import { BigNumberish, BytesLike } from 'ethers';

task('initialize-gho-reserve', 'Initialize Gho Reserve')
  .addFlag('deploying', 'true or false contracts are being deployed')
  .setAction(async (params, hre) => {
    await hre.run('set-DRE');
    const { ethers } = DRE;

    const network = getNetwork();
    const { treasury, incentivesController } = aaveMarketAddresses[network];

    let ghoATokenImplementation;
    let stableDebtTokenImplementation;
    let ghoVariableDebtTokenImplementation;
    let ghoInterestRateStrategy;
    let ghoToken;
    let poolConfigurator;

    let treasuryAddress;
    let incentivesControllerAddress;

    if (params.deploying) {
      ghoATokenImplementation = await ethers.getContract('GhoAToken');
      stableDebtTokenImplementation = await ethers.getContract('StableDebtToken');
      ghoVariableDebtTokenImplementation = await ethers.getContract('GhoVariableDebtToken');
      ghoInterestRateStrategy = await ethers.getContract('GhoInterestRateStrategy');
      ghoToken = await ethers.getContract('GhoToken');
      poolConfigurator = await getPoolConfiguratorProxy();
      treasuryAddress = treasury;
      incentivesControllerAddress = incentivesController;
    } else {
      const contracts = require('../../../contracts.json');

      ghoATokenImplementation = await getAToken(contracts.GhoAToken);
      stableDebtTokenImplementation = await getStableDebtToken(contracts.StableDebtToken);
      ghoVariableDebtTokenImplementation = await getVariableDebtToken(
        contracts.GhoVariableDebtToken
      );
      ghoInterestRateStrategy = await getGhoInterestRateStrategy(contracts.GhoInterestRateStrategy);
      ghoToken = await getGhoToken(contracts.GhoToken);
      poolConfigurator = await getPoolConfiguratorProxy(contracts['PoolConfigurator-Proxy-Test']);
      treasuryAddress = contracts.TreasuryProxy;
      incentivesControllerAddress = contracts.IncentivesProxy;
    }

    const [_deployer] = await hre.ethers.getSigners();
    poolConfigurator = poolConfigurator.connect(_deployer);

    const { deployer } = await hre.getNamedAccounts();

    if (DRE.network.name == 'hardhat') {
      const governanceSigner = await impersonateAccountHardhat(deployer);
      poolConfigurator = poolConfigurator.connect(governanceSigner);
    }
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
      treasury: treasuryAddress,
      incentivesController: incentivesControllerAddress,
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
