import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { getPoolAddressesProvider } from '@aave/deploy-v3';
import { getGhoToken } from '../helpers/contract-getters';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const addressesProvider = await getPoolAddressesProvider();
  const ghoToken = await getGhoToken();

  const ghoManager = await deploy('GhoManager', {
    from: deployer,
    args: [addressesProvider.address, ghoToken.address],
    log: true,
  });
  console.log(`GHO Manager:               ${ghoManager.address}`);

  return true;
};

func.id = 'GhoManager';
func.tags = ['GhoManager', 'full_gho_deploy'];

export default func;
