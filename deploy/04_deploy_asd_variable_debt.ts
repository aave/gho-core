import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';
import { asdTokenConfig } from '../src/helpers/config';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { pool, incentivesController, addressesProvider } = aaveMarketAddresses;
  const asd = await hre.ethers.getContract('AnteiStableDollarEntities');

  const { TOKEN_NAME, TOKEN_SYMBOL } = asdTokenConfig;

  const variableDebtImplementation = await deploy('AnteiVariableDebtToken', {
    from: deployer,
    args: [pool, asd.address, TOKEN_NAME, TOKEN_SYMBOL, incentivesController, addressesProvider],
  });

  console.log(`Variable Debt Implementation:  ${variableDebtImplementation.address}`);
  return true;
};

func.id = 'AnteiVariableDebt';
func.tags = ['AnteiVariableDebt', 'full_antei_deploy'];

export default func;
