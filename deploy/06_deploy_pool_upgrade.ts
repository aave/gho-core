import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const reserveLogic = await deploy('ReserveLogic', {
    from: deployer,
    args: [],
  });
  console.log(`Reserve Logic:                 ${reserveLogic.address}`);

  const genericLogic = await deploy('GenericLogic', {
    from: deployer,
    args: [],
    libraries: {
      ReserveLogic: reserveLogic.address,
    },
  });
  console.log(`Generic Logic:                 ${genericLogic.address}`);

  const validationLogic = await deploy('ValidationLogic', {
    from: deployer,
    args: [],
    libraries: {
      ReserveLogic: reserveLogic.address,
      GenericLogic: genericLogic.address,
    },
  });
  console.log(`Validation Logic:              ${validationLogic.address}`);

  const pool = await deploy('LendingPool', {
    from: deployer,
    args: [],
    libraries: {
      ValidationLogic: validationLogic.address,
      ReserveLogic: reserveLogic.address,
    },
  });

  console.log(`Pool Implementation:           ${pool.address}`);
  return true;
};

func.id = 'PoolUpgrade';
func.tags = ['PoolUpgrade', 'full_gho_deploy'];

export default func;
