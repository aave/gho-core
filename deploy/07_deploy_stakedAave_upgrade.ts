import { ZERO_ADDRESS } from './../src/helpers/constants';
import { DeployFunction } from 'hardhat-deploy/types';
import { StakedTokenV2Rev4__factory } from '../types';
import { StakedTokenV2Rev3__factory, STAKE_AAVE_PROXY, waitForTx } from '@aave/deploy-v3';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const [deployerSigner] = await hre.ethers.getSigners();

  const stkAaveProxy = await deployments.get(STAKE_AAVE_PROXY);
  const instance = StakedTokenV2Rev3__factory.connect(stkAaveProxy.address, deployerSigner);

  const stakedAaveImpl = await deploy('StakedTokenV2Rev4Impl', {
    from: deployer,
    contract: 'StakedTokenV2Rev4',
    args: [
      await instance.STAKED_TOKEN(),
      await instance.REWARD_TOKEN(),
      await instance.COOLDOWN_SECONDS(),
      await instance.UNSTAKE_WINDOW(),
      await instance.REWARDS_VAULT(),
      await instance.EMISSION_MANAGER(),
      '3153600000', // 100 years from the time of deployment
      await instance.name(),
      await instance.symbol(),
      await instance.decimals(),
      await instance._aaveGovernance(),
    ],
    log: true,
  });
  console.log(`stakedAaveImpl Logic:         ${stakedAaveImpl.address}`);

  // Initialize implementation
  const impl = await StakedTokenV2Rev4__factory.connect(stakedAaveImpl.address, deployerSigner);
  await waitForTx(await impl.initialize(ZERO_ADDRESS));
};

func.id = 'StkAaveUpgrade';
func.tags = ['StkAaveUpgrade', 'full_gho_deploy'];

export default func;
