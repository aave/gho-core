import { HardhatRuntimeEnvironment } from 'hardhat/types';

export let DRE: HardhatRuntimeEnvironment;

export const setDRE = (_DRE) => {
  DRE = _DRE;
};
