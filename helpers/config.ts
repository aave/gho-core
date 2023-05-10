import { ethers } from 'ethers';
import { ZERO_ADDRESS } from './constants';

export const helperAddresses = {
  wethWhale: '0xe78388b4ce79068e89bf8aa7f218ef6b9ab0e9d0',
  usdcWhale: '0x55fe002aeff02f77364de339a1292923a15844b8',
  stkAaveWhale: '0x32b61bb22cbe4834bc3e73dce85280037d944a4d',
  aaveToken: '0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9',
  aaveWhale: '0x26a78d5b6d7a7aceedd1e6ee3229b372a624d8b7',
};

export const ghoTokenConfig = {
  TOKEN_NAME: 'Gho Token',
  TOKEN_SYMBOL: 'GHO',
  TOKEN_DECIMALS: 18,
};

export const ghoReserveConfig = {
  INTEREST_RATE: ethers.utils.parseUnits('2.0', 25),
};

export const ghoEntityConfig = {
  label: 'Aave V3 Mainnet Market',
  entityAddress: ZERO_ADDRESS,
  mintLimit: ethers.utils.parseUnits('1.0', 27), // 100M
  flashMinterCapacity: ethers.utils.parseUnits('1.0', 26), // 10M
  flashMinterMaxFee: ethers.utils.parseUnits('10000', 0),
  flashMinterFee: 100,
};
