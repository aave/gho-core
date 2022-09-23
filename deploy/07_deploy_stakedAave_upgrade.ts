import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';
import { helperAddresses } from '../src/helpers/config';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const stakedAaveLogic = await deploy('StakedTokenV2Rev4', {
    from: deployer,
    args: [
      helperAddresses.aaveToken,
      helperAddresses.aaveToken,
      '864000',
      '172800',
      '0x25F2226B597E8F9514B3F68F00f494cF4f286491',
      '0xEE56e2B3D491590B5b31738cC34d5232F378a8D5',
      '3153600000', // 100 years from the time of deployment
      'Staked AAVE',
      'stkAAVE',
      '18',
      '0x0000000000000000000000000000000000000000',
    ],
  });
  console.log(`stakedAaveLogic Logic:         ${stakedAaveLogic.address}`);
};

func.id = 'StkAaveUpgrade';
func.tags = ['StkAaveUpgrade', 'full_gho_deploy'];

export default func;
