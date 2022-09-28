import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const ghoPrice = hre.ethers.utils.parseUnits('1', 8).toString();

  const ghoOracle = await deploy('GhoOracle', {
    from: deployer,
    args: [ghoPrice],
  });
  console.log(`Gho Oracle:                    ${ghoOracle.address}`);

  return true;
};

func.id = 'GhoOracle';
func.tags = ['GhoOracle', 'full_gho_deploy'];

export default func;
