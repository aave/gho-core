pragma solidity ^0.8.10;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**
 * @title MockUSTBSubscription
 */
contract MockUSTBSubscription {
  using SafeERC20 for IERC20;

  uint256 constant USDC_PRECISION = 1e6;
  uint256 constant SUPERSTATE_TOKEN_PRECISION = 1e6;
  uint256 constant CHAINLINK_FEED_PRECISION = 1e8;

  address public immutable asset;
  address public immutable liquidity;
  uint256 public USTBPrice; // 1_100_000_000 is 1 USTB = 11 USDC, including chainlink precision

  /**
   * @param _asset Address of asset token, ie USTB
   * @param _liquidity Address of liquidity token, ie USDC
   */
  constructor(address _asset, address _liquidity, uint256 _price) {
    asset = _asset;
    liquidity = _liquidity;
    setUSTBPrice(_price);
  }

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

  /**
   * @notice Subscribe to the asset token (USTB) in exchange for the liquidity token (USDC)
   * @param amount The amount of the USDC token to exchange, in base units
   */
  function subscribe(uint256 amount) external {
    uint256 USTBAmount = amount / USTBPrice;
    IERC20(liquidity).safeTransferFrom(msg.sender, address(this), amount);
    IERC20(asset).safeTransfer(msg.sender, USTBAmount);
  }

  /**
   * @notice Redeem the asset token (USTB) in exchange for the liquidity token (USDC)
   * @param amount The amount of the USTB token to exchange, in base units
   */
  function redeem(uint256 amount) external {
    (uint256 USDCAmount, ) = calculateUsdcOut(amount);
    IERC20(asset).safeTransfer(msg.sender, amount);
    IERC20(liquidity).safeTransferFrom(msg.sender, address(this), USDCAmount);
  }

  // for redemption preview
  function calculateUsdcOut(
    uint256 superstateTokenInAmount
  ) public view returns (uint256 usdcOutAmount, uint256 usdPerUstbChainlinkRaw) {
    usdPerUstbChainlinkRaw = 1_100_000_000; // 11 USDC/USTB
    uint256 fee = 500; // in BPS

    usdcOutAmount =
      (superstateTokenInAmount * usdPerUstbChainlinkRaw * USDC_PRECISION) /
      (CHAINLINK_FEED_PRECISION * SUPERSTATE_TOKEN_PRECISION);

    usdcOutAmount = (usdcOutAmount * (10_000 - fee)) / 10_000;
  }

  // for redemption preview
  function calculateUstbIn(
    uint256 usdcOutAmount
  ) public view returns (uint256 ustbInAmount, uint256 usdPerUstbChainlinkRaw) {
    uint256 fee = 500; // in BPS
    uint256 usdcOutAmountWithFee = usdcOutAmount * (10_000 + fee);
    usdPerUstbChainlinkRaw = 1_100_000_000; // 11 USDC/USTB

    ustbInAmount =
      (usdcOutAmountWithFee * CHAINLINK_FEED_PRECISION * SUPERSTATE_TOKEN_PRECISION) /
      (usdPerUstbChainlinkRaw * USDC_PRECISION);
  }

  /**
   * @notice Set the price of USTB, amount of USDC for 1 USTB. USTB/USDC both have 6 decimals.
   * @param newPrice The new price of USTB
   */
  function setUSTBPrice(uint256 newPrice) public {
    USTBPrice = newPrice;
  }
}
