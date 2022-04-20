import { task } from 'hardhat/config';
import { DRE, setDRE } from '../helpers/misc-utils';

task(`set-DRE`, `Inits the DRE, to have access to all the plugins' objects`).setAction(
  async (_, _DRE) => {
    if (DRE) {
      return;
    }
    setDRE(_DRE);
    return _DRE;
  }
);
