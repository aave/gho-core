// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from 'forge-std/Script.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {ITransparentProxyFactory} from 'src/script/ITransparentProxyFactory.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';

import {Gsm4626} from 'src/contracts/facilitators/gsm/Gsm4626.sol';
import {FixedPriceStrategy4626} from 'src/contracts/facilitators/gsm/priceStrategy/FixedPriceStrategy4626.sol';
import {IGsm} from 'src/contracts/facilitators/gsm/interfaces/IGsm.sol';
import {OracleSwapFreezer} from 'src/contracts/facilitators/gsm/swapFreezer/OracleSwapFreezer.sol';

address constant TRANSPARENT_PROXY_FACTORY = 0xEB0682d148e874553008730f0686ea89db7DA412;

// GSM USDC
uint8 constant USDC_DECIMALS = 6;
uint128 constant USDC_EXPOSURE_CAP = 8_000_000e6;

// GSM USDT
uint8 constant USDT_DECIMALS = 6;
uint128 constant USDT_EXPOSURE_CAP = 16_000_000e6;

uint256 constant GSM_PRICE_RATIO = 1e18;
uint128 constant SWAP_FREEZE_LOWER_BOUND = 0.99e8;
uint128 constant SWAP_FREEZE_UPPER_BOUND = 1.01e8;
uint128 constant SWAP_UNFREEZE_LOWER_BOUND = 0.995e8;
uint128 constant SWAP_UNFREEZE_UPPER_BOUND = 1.005e8;
bool constant SWAP_UNFREEZE_ALLOWED = true;

contract DeployGsm4626 is Script {
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
    FixedPriceStrategy4626 gsmUsdcPriceStrategy = new FixedPriceStrategy4626(
      GSM_PRICE_RATIO,
      AaveV3EthereumAssets.USDC_STATA_TOKEN,
      USDC_DECIMALS
    );
    console2.log('GSM stataUSDC FixedPriceStrategy4626: ', address(gsmUsdcPriceStrategy));

    FixedPriceStrategy4626 gsmUsdtPriceStrategy = new FixedPriceStrategy4626(
      GSM_PRICE_RATIO,
      AaveV3EthereumAssets.USDT_STATA_TOKEN,
      USDT_DECIMALS
    );
    console2.log('GSM stataUSDT FixedPriceStrategy4626: ', address(gsmUsdtPriceStrategy));

    // ------------------------------------------------
    // 2. GSM implementations
    // ------------------------------------------------
    Gsm4626 gsmUsdcImpl = new Gsm4626(
      AaveV3EthereumAssets.GHO_UNDERLYING,
      AaveV3EthereumAssets.USDC_STATA_TOKEN,
      address(gsmUsdcPriceStrategy)
    );
    console2.log('GSM stataUSDC Implementation: ', address(gsmUsdcImpl));

    Gsm4626 gsmUsdtImpl = new Gsm4626(
      AaveV3EthereumAssets.GHO_UNDERLYING,
      AaveV3EthereumAssets.USDT_STATA_TOKEN,
      address(gsmUsdtPriceStrategy)
    );
    console2.log('GSM stataUSDT Implementation: ', address(gsmUsdtImpl));

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
    bytes memory gsmUsdcInitParams = abi.encodeWithSignature(
      'initialize(address,address,uint128)',
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      address(AaveV3Ethereum.COLLECTOR),
      USDC_EXPOSURE_CAP
    );
    address gsmUsdcProxy = ITransparentProxyFactory(TRANSPARENT_PROXY_FACTORY).create(
      address(gsmUsdcImpl),
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      gsmUsdcInitParams
    );
    console2.log('GSM stataUSDC Proxy: ', gsmUsdcProxy);

    bytes memory gsmUsdtInitParams = abi.encodeWithSignature(
      'initialize(address,address,uint128)',
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      address(AaveV3Ethereum.COLLECTOR),
      USDT_EXPOSURE_CAP
    );
    address gsmUsdtProxy = ITransparentProxyFactory(TRANSPARENT_PROXY_FACTORY).create(
      address(gsmUsdtImpl),
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      gsmUsdtInitParams
    );
    console2.log('GSM stataUSDT Proxy: ', gsmUsdtProxy);

    // ------------------------------------------------
    // 4. OracleSwapFreezers
    // ------------------------------------------------
    OracleSwapFreezer gsmUsdcOracleSwapFreezer = new OracleSwapFreezer(
      IGsm(gsmUsdcProxy),
      AaveV3EthereumAssets.USDC_STATA_TOKEN,
      IPoolAddressesProvider(address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER)),
      SWAP_FREEZE_LOWER_BOUND,
      SWAP_FREEZE_UPPER_BOUND,
      SWAP_UNFREEZE_LOWER_BOUND,
      SWAP_UNFREEZE_UPPER_BOUND,
      SWAP_UNFREEZE_ALLOWED
    );
    console2.log('GSM stataUSDC OracleSwapFreezer: ', address(gsmUsdcOracleSwapFreezer));

    OracleSwapFreezer gsmUsdtOracleSwapFreezer = new OracleSwapFreezer(
      IGsm(gsmUsdtProxy),
      AaveV3EthereumAssets.USDT_STATA_TOKEN,
      IPoolAddressesProvider(address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER)),
      SWAP_FREEZE_LOWER_BOUND,
      SWAP_FREEZE_UPPER_BOUND,
      SWAP_UNFREEZE_LOWER_BOUND,
      SWAP_UNFREEZE_UPPER_BOUND,
      SWAP_UNFREEZE_ALLOWED
    );
    console2.log('GSM stataUSDT OracleSwapFreezer: ', address(gsmUsdtOracleSwapFreezer));
  }
}
