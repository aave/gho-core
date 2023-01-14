import { writeFile, copyFile } from 'fs';
import { DeployFunction } from 'hardhat-deploy/types';
import { getNetwork } from '../src/helpers/misc-utils';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  console.log('hello!!');
  const contracts = await deployments.all();
  const printableContracts = {};

  Object.keys(contracts).forEach((contract) => {
    printableContracts[contract] = contracts[contract].address;
  });

  writeFile(
    `${process.cwd()}/deployments/local/current_deployment.json`,
    JSON.stringify(printableContracts, null, 2),
    (error) => {
      if (error) {
        throw error;
      }
    }
  );

  const date = new Date(Date.now());
  const formattedTimestamp = `${
    date.getUTCMonth() + 1
  }_${date.getUTCDate()}_${date.getUTCFullYear()}_${date.getUTCHours}_${date.getUTCMinutes}}`;

  copyFile(
    `${process.cwd()}/deployments/local/current_deployment.json`,
    `${process.cwd()}/deployments/local/gho_${getNetwork()}_${formattedTimestamp}.json`,
    (error) => {
      if (error) {
        throw error;
      }
    }
  );
};

func.id = 'PrintDeployments';
func.tags = ['PrintDeployments', 'full_gho_deploy'];

export default func;
