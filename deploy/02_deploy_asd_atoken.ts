import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/aave-v2-addresses';
import { asdConfiguration } from '../src/configs/asdConfiguration';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { pool, treasury, incentivesController } = aaveMarketAddresses;
  const asd = await hre.ethers.getContract('AnteiStableDollarEntities');

  const { TOKEN_NAME, TOKEN_SYMBOL } = asdConfiguration.tokenConfig;

  const aTokenImplementation = await deploy('AToken', {
    from: deployer,
    args: [pool, asd.address, treasury, TOKEN_NAME, TOKEN_SYMBOL, incentivesController],
  });

  console.log(`AToken Implementation:         ${aTokenImplementation.address}`);
  return true;
};

func.id = 'AnteiAToken';
func.tags = ['AnteiAToken', 'full_antei_deploy'];

export default func;
