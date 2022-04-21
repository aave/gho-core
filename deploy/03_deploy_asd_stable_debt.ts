import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/aave-v2-addresses';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { pool, treasury, incentivesController } = aaveMarketAddresses;
  const asd = await hre.ethers.getContract('AnteiStableDollarEntities');

  const stableDebtImplementation = await deploy('StableDebtToken', {
    from: deployer,
    args: [pool, asd.address, 'Antei Stable Dollar', 'ASD', incentivesController],
  });

  console.log(`Stable Debt Implementation:    ${stableDebtImplementation.address}`);
  return true;
};

func.id = 'AnteiStableDebt';
func.tags = ['AnteiStableDebt', 'full_antei_deploy'];

export default func;
