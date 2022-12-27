import { ethers } from 'ethers';
import { ZERO_ADDRESS } from './constants';

export const aaveMarketAddresses = {
  goerli: {
    stkAave: '0x716AD55707ddbA3Bb180f717688A21C315Ce6A49',
    aave: '0x0B7a69d978DdA361Db5356D4Bd0206496aFbDD96',
    rewardsVault: '0x0000000000000000000000000000000000000000',
    emissionManager: '0x1824EfE9e022d07F59bBeB6ac68529CD6A72C6Bd',
    incentivesController: ZERO_ADDRESS,
    treasury: '0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c',
    shortExecutor: '0x1824EfE9e022d07F59bBeB6ac68529CD6A72C6Bd',
    ethUsdOracle: '0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e',
    weth: '0x3D45e807DF39D0A1CC2b959BfEa473d0774B5a57',
    usdc: '0x80375a58741948c972cf04033880352e3E853c26',
  },
  mainnet: {
    pool: '0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9',
    incentivesController: '0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5',
    treasury: '0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c',
    addressesProvider: '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5',
    poolConfigurator: '0x311Bb771e4F8952E6Da169b425E7e92d6Ac45756',
    shortExecutor: '0xEE56e2B3D491590B5b31738cC34d5232F378a8D5',
    aaveOracle: '0xA50ba011c48153De246E5192C8f9258A2ba79Ca9',
    aaveProtocolDataProvider: '0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d',
    ethUsdOracle: '0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419',
    weth: '0x58F132FBB86E21545A4Bace3C19f1C05d86d7A22',
    usdc: '0xFAe0fd738dAbc8a0426F47437322b6d026A9FD95',
  },
};

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
  DISCOUNT_LOCK_PERIOD: 31556952,
};

export const ghoEntityConfig = {
  label: 'Aave V2 Mainnet Market',
  entityAddress: ZERO_ADDRESS,
  mintLimit: ethers.utils.parseUnits('1.0', 27), // 100M
  flashMinterCapacity: ethers.utils.parseUnits('1.0', 26), // 10M
  flashMinterMaxFee: ethers.utils.parseUnits('10000', 0),
  flashMinterFee: 100,
};
