import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';
import { asdTokenConfig } from '../src/helpers/config';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { pool, treasury, incentivesController, addressesProvider } = aaveMarketAddresses;
  const asd = await hre.ethers.getContract('AnteiStableDollarEntities');

  const { TOKEN_NAME, TOKEN_SYMBOL } = asdTokenConfig;

  const aTokenImplementation = await deploy('AnteiAToken', {
    from: deployer,
    args: [
      pool,
      asd.address,
      treasury,
      TOKEN_NAME,
      TOKEN_SYMBOL,
      incentivesController,
      addressesProvider,
    ],
  });

  console.log(`AToken Implementation:         ${aTokenImplementation.address}`);
  return true;
};

func.id = 'AnteiAToken';
func.tags = ['AnteiAToken', 'full_antei_deploy'];

export default func;
