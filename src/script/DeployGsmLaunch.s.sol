// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from 'forge-std/Script.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {TransparentUpgradeableProxy} from 'solidity-utils/contracts/transparent-proxy/TransparentUpgradeableProxy.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {Gsm} from '../contracts/facilitators/gsm/Gsm.sol';
import {IGsm} from '../contracts/facilitators/gsm/interfaces/IGsm.sol';
import {FixedPriceStrategy} from '../contracts/facilitators/gsm/priceStrategy/FixedPriceStrategy.sol';
import {FixedFeeStrategy} from '../contracts/facilitators/gsm/feeStrategy/FixedFeeStrategy.sol';
import {GsmRegistry} from '../contracts/facilitators/gsm/misc/GsmRegistry.sol';
import {OracleSwapFreezer} from '../contracts/facilitators/gsm/swapFreezer/OracleSwapFreezer.sol';

address constant GHO_TOKEN = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

address constant USDC_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
uint8 constant USDC_DECIMALS = 6;
uint128 constant USDC_EXPOSURE_CAP = 500_000e6;
string constant GSM_USDC_FACILITATOR_LABEL = 'GSM USDC';
uint128 constant GSM_USDC_BUCKET_CAPACITY = 500_000e18;

address constant USDT_TOKEN = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
uint8 constant USDT_DECIMALS = 6;
uint128 constant USDT_EXPOSURE_CAP = 500_000e6;
string constant GSM_USDT_FACILITATOR_LABEL = 'GSM USDT';
uint128 constant GSM_USDT_BUCKET_CAPACITY = 500_000e18;

uint256 constant GSM_PRICE_RATIO = 1e18;
uint256 constant GSM_BUY_FEE_BPS = 0.002e4; // 0.2%, 0.5e4 is 50%
uint256 constant GSM_SELL_FEE_BPS = 0.002e4; // 0.2%

uint128 constant SWAP_FREEZE_LOWER_BOUND = 0.99e8;
uint128 constant SWAP_FREEZE_UPPER_BOUND = 1.01e8;
uint128 constant SWAP_UNFREEZE_LOWER_BOUND = 0.995e8;
uint128 constant SWAP_UNFREEZE_UPPER_BOUND = 1.005e8;
bool constant SWAP_UNFREEZE_ALLOWED = true;

contract DeployGsmLaunch is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address deployerAddress = vm.addr(deployerPrivateKey);
    console2.log('Deployer Address: ', deployerAddress);
    console2.log('Deployer Balance: ', address(deployerAddress).balance);
    console2.log('Block Number: ', block.number);
    vm.startBroadcast(deployerPrivateKey);
    _deploy();
    vm.stopBroadcast();
  }

  function _deploy() internal {
    // ------------------------------------------------
    // 1. FixedPriceStrategy
    // ------------------------------------------------
    FixedPriceStrategy gsmUsdcPriceStrategy = new FixedPriceStrategy(
      GSM_PRICE_RATIO,
      USDC_TOKEN,
      USDC_DECIMALS
    );
    console2.log('GSM USDC FixedPriceStrategy: ', address(gsmUsdcPriceStrategy));

    FixedPriceStrategy gsmUsdtPriceStrategy = new FixedPriceStrategy(
      GSM_PRICE_RATIO,
      USDT_TOKEN,
      USDT_DECIMALS
    );
    console2.log('GSM USDT FixedPriceStrategy: ', address(gsmUsdtPriceStrategy));

    // ------------------------------------------------
    // 2. GSM implementations
    // ------------------------------------------------
    Gsm gsmUsdcImpl = new Gsm(GHO_TOKEN, USDC_TOKEN, address(gsmUsdcPriceStrategy));
    console2.log('GSM USDC Implementation: ', address(gsmUsdcImpl));

    Gsm gsmUsdtImpl = new Gsm(GHO_TOKEN, USDT_TOKEN, address(gsmUsdtPriceStrategy));
    console2.log('GSM USDT Implementation: ', address(gsmUsdtImpl));

    gsmUsdcImpl.initialize(
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      address(AaveV3Ethereum.COLLECTOR),
      USDC_EXPOSURE_CAP
    );
    gsmUsdtImpl.initialize(
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      address(AaveV3Ethereum.COLLECTOR),
      USDT_EXPOSURE_CAP
    );

    // ------------------------------------------------
    // 3. GSM proxy deployment and initialization
    // ------------------------------------------------
    bytes memory paramsUsdc = abi.encodeWithSignature(
      'initialize(address,address,uint128)',
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      address(AaveV3Ethereum.COLLECTOR),
      USDC_EXPOSURE_CAP
    );
    TransparentUpgradeableProxy gsmUsdcProxy = new TransparentUpgradeableProxy(
      address(gsmUsdcImpl),
      MiscEthereum.PROXY_ADMIN,
      paramsUsdc
    );
    Gsm gsmUsdc = Gsm(address(gsmUsdcProxy));
    console2.log('GSM USDC Proxy: ', address(gsmUsdcProxy));

    bytes memory paramsUsdt = abi.encodeWithSignature(
      'initialize(address,address,uint128)',
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      address(AaveV3Ethereum.COLLECTOR),
      USDT_EXPOSURE_CAP
    );
    TransparentUpgradeableProxy gsmUsdtProxy = new TransparentUpgradeableProxy(
      address(gsmUsdtImpl),
      MiscEthereum.PROXY_ADMIN,
      paramsUsdt
    );
    Gsm gsmUsdt = Gsm(address(gsmUsdtProxy));
    console2.log('GSM USDT Proxy: ', address(gsmUsdtProxy));

    // ------------------------------------------------
    // 4. FixedFeeStrategy
    // ------------------------------------------------
    FixedFeeStrategy fixedFeeStrategy = new FixedFeeStrategy(GSM_BUY_FEE_BPS, GSM_SELL_FEE_BPS);
    console2.log('GSM FixedFeeStrategy: ', address(fixedFeeStrategy));

    // ------------------------------------------------
    // 5. OracleSwapFreezers
    // ------------------------------------------------
    OracleSwapFreezer gsmUsdcOracleSwapFreezer = new OracleSwapFreezer(
      IGsm(address(gsmUsdc)),
      USDC_TOKEN,
      IPoolAddressesProvider(address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER)),
      SWAP_FREEZE_LOWER_BOUND,
      SWAP_FREEZE_UPPER_BOUND,
      SWAP_UNFREEZE_LOWER_BOUND,
      SWAP_UNFREEZE_UPPER_BOUND,
      SWAP_UNFREEZE_ALLOWED
    );
    console2.log('GSM USDC OracleSwapFreezer: ', address(gsmUsdcOracleSwapFreezer));

    OracleSwapFreezer gsmUsdtOracleSwapFreezer = new OracleSwapFreezer(
      IGsm(address(gsmUsdt)),
      USDT_TOKEN,
      IPoolAddressesProvider(address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER)),
      SWAP_FREEZE_LOWER_BOUND,
      SWAP_FREEZE_UPPER_BOUND,
      SWAP_UNFREEZE_LOWER_BOUND,
      SWAP_UNFREEZE_UPPER_BOUND,
      SWAP_UNFREEZE_ALLOWED
    );
    console2.log('GSM USDT OracleSwapFreezer: ', address(gsmUsdtOracleSwapFreezer));

    // ------------------------------------------------
    // 6. Deploy GsmRegistry
    // ------------------------------------------------
    GsmRegistry gsmRegistry = new GsmRegistry(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    console2.log('GsmRegistry: ', address(gsmRegistry));
  }
}
