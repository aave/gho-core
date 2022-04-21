import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const asdOracle = await deploy('AnteiOracle', {
    from: deployer,
    args: [],
  });
  console.log(`Antei Oracle:                  ${asdOracle.address}`);

  return true;
};

func.id = 'AnteiOracle';
func.tags = ['AnteiOracle', 'full_antei_deploy'];

export default func;
