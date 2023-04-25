import { DeployFunction } from 'hardhat-deploy/types';
import { StakedTokenV2Rev3__factory, STAKE_AAVE_PROXY, waitForTx } from '@aave/deploy-v3';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const [deployerSigner] = await hre.ethers.getSigners();

  const stkAaveProxy = await deployments.get(STAKE_AAVE_PROXY);
  const instance = StakedTokenV2Rev3__factory.connect(stkAaveProxy.address, deployerSigner);

  const stakedAaveImpl = await deploy('StakedAaveV3Impl', {
    from: deployer,
    contract: 'StakedAaveV3',
    args: [
      await instance.STAKED_TOKEN(),
      await instance.REWARD_TOKEN(),
      await instance.UNSTAKE_WINDOW(),
      await instance.REWARDS_VAULT(),
      await instance.EMISSION_MANAGER(),
      '3153600000', // 100 years from the time of deployment
    ],
    log: true,
  });
  console.log(`stakedAaveImpl Logic:         ${stakedAaveImpl.address}`);
};

func.id = 'StkAaveUpgrade';
func.tags = ['StkAaveUpgrade', 'full_gho_deploy'];

export default func;
