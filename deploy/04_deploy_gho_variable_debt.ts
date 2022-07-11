import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';
import { ghoTokenConfig } from '../src/helpers/config';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { pool, incentivesController } = aaveMarketAddresses;
  const gho = await hre.ethers.getContract('GhoToken');

  const { TOKEN_NAME, TOKEN_SYMBOL } = ghoTokenConfig;

  const variableDebtImplementation = await deploy('GhoVariableDebtToken', {
    from: deployer,
    args: [pool, gho.address, TOKEN_NAME, TOKEN_SYMBOL, incentivesController],
  });

  console.log(`Variable Debt Implementation:  ${variableDebtImplementation.address}`);
  return true;
};

func.id = 'GhoVariableDebt';
func.tags = ['GhoVariableDebt', 'full_gho_deploy'];

export default func;
