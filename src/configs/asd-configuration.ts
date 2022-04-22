import { ethers } from 'ethers';

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
