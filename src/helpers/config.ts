import { ethers } from 'ethers';
import { ZERO_ADDRESS } from './constants';

export const aaveMarketAddresses = {
  pool: '0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9',
  incentivesController: '0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5',
  treasury: '0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c',
  addressesProvider: '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5',
  lendingPoolConfigurator: '0x311Bb771e4F8952E6Da169b425E7e92d6Ac45756',
  shortExecutor: '0xEE56e2B3D491590B5b31738cC34d5232F378a8D5',
  aaveOracle: '0xA50ba011c48153De246E5192C8f9258A2ba79Ca9',
  aaveProtocolDataProvider: '0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d',
  ethUsdOracle: '0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419',
  weth: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
  usdc: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
};

export const helperAddresses = {
  wethWhale: '0xe78388b4ce79068e89bf8aa7f218ef6b9ab0e9d0',
  usdcWhale: '0x55fe002aeff02f77364de339a1292923a15844b8',
  stkAave: '0x4da27a545c0c5B758a6BA100e3a049001de870f5',
};

export const asdTokenConfig = {
  TOKEN_NAME: 'Antei Stable Coin',
  TOKEN_SYMBOL: 'ASD',
  TOKEN_DECIMALS: 18,
};

export const asdReserveConfig = {
  INTEREST_RATE: ethers.utils.parseUnits('2.0', 25),
  discountRate: 2000,
  maxDiscountRate: 6500,
};

export const asdEntityConfig = {
  label: 'Aave V2 Mainnet Market',
  entityAddress: ZERO_ADDRESS,
  mintLimit: ethers.utils.parseUnits('1.0', 27),
};
