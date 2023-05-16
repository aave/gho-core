import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  console.log();
  console.log(`~~~~~~~   Beginning GHO Deployments   ~~~~~~~`);

  const [_deployer, ...restSigners] = await hre.ethers.getSigners();

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const ghoResult = await deploy('GhoToken', {
    from: deployer,
    args: [deployer],
    log: true,
  });
  console.log(`GHO Address:                   ${ghoResult.address}`);

  return true;
};

func.id = 'GhoToken';
func.tags = ['GhoToken', 'full_gho_deploy'];

export default func;
