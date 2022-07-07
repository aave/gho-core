import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';
import { ghoTokenConfig } from '../src/helpers/config';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { pool, incentivesController } = aaveMarketAddresses;
  const gho = await hre.ethers.getContract('GhoToken');

  const { TOKEN_NAME, TOKEN_SYMBOL } = ghoTokenConfig;

  const stableDebtImplementation = await deploy('StableDebtToken', {
    from: deployer,
    args: [pool, gho.address, TOKEN_NAME, TOKEN_SYMBOL, incentivesController],
  });

  console.log(`Stable Debt Implementation:    ${stableDebtImplementation.address}`);
  return true;
};

func.id = 'GhoStableDebt';
func.tags = ['GhoStableDebt', 'full_gho_deploy'];

export default func;
