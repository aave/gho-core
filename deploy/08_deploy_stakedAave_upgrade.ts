import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';
import { asdReserveConfig } from '../src/helpers/config';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const stakedAaveLogic = await deploy('StakedTokenV2Rev4', {
    from: deployer,
    args: [
      '0x41a08648c3766f9f9d85598ff102a08f4ef84f84',
      '0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9',
      '864000',
      '172800',
      '0x25F2226B597E8F9514B3F68F00f494cF4f286491',
      '0xEE56e2B3D491590B5b31738cC34d5232F378a8D5',
      '3153600000', // 100 years from now
      'Aave stakedToken',
      'stkToken',
      '18',
      '0xec568fffba86c094cf06b22134b23074dfe2252c',
    ],
  });
  console.log(`stakedAaveLogic Logic:                 ${stakedAaveLogic.address}`);
};

func.id = 'StkAaveUpgrade';
func.tags = ['StkAaveUpgrade', 'full_antei_deploy'];

export default func;
