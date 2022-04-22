import { ethers } from 'ethers';
import { ZERO_ADDRESS } from '../helpers/constants';

export const asdConfiguration = {
  tokenConfig: {
    TOKEN_NAME: 'Antei Stable Coin',
    TOKEN_SYMBOL: 'ASD',
    TOKEN_DECIMALS: 18,
  },
  marketConfig: {
    INTEREST_RATE: ethers.utils.parseUnits('2.0', 25),
  },
};

export const asdEntityConfig = {
  label: 'Aave V2 Mainnet Market',
  entityAddress: ZERO_ADDRESS,
  mintLimit: ethers.utils.parseUnits('1.0', 27),
};
