import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const ghoManager = await deploy('GhoManager', {
    from: deployer,
    args: [],
    log: true,
  });
  console.log(`GHO Manager:               ${ghoManager.address}`);

  return true;
};

func.id = 'GhoManager';
func.tags = ['GhoManager', 'full_gho_deploy'];

export default func;
