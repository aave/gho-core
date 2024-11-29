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
   * @notice The ```subscribe``` function takes in stablecoins and mints SuperstateToken in the proper amount for the msg.sender depending on the current Net Asset Value per Share.
   * @param inAmount The amount of the stablecoin in
   * @param stablecoin The address of the stablecoin to calculate with
   */
  function subscribe(uint256 inAmount, address stablecoin) external {
    (
      uint256 superstateTokenOutAmount,
      uint256 stablecoinInAmountAfterFee,

    ) = calculateSuperstateTokenOut({inAmount: inAmount, stablecoin: stablecoin});

    IERC20(stablecoin).safeTransferFrom({from: msg.sender, to: address(this), value: inAmount});
    IERC20(asset).safeTransfer(msg.sender, superstateTokenOutAmount);
  }

  /**
   * @notice The ```calculateSuperstateTokenOut``` function calculates the total amount of Superstate tokens you'll receive for the inAmount of stablecoin. Treats all stablecoins as if they are always worth a dollar.
   * @param inAmount The amount of the stablecoin in
   * @param stablecoin The address of the stablecoin to calculate with
   * @return superstateTokenOutAmount The amount of Superstate tokens received for inAmount of stablecoin
   * @return stablecoinInAmountAfterFee The amount of the stablecoin in after any fees
   * @return feeOnStablecoinInAmount The amount of the stablecoin taken in fees
   */
  function calculateSuperstateTokenOut(
    uint256 inAmount,
    address stablecoin
  )
    public
    view
    returns (
      uint256 superstateTokenOutAmount,
      uint256 stablecoinInAmountAfterFee,
      uint256 feeOnStablecoinInAmount
    )
  {
    StablecoinConfig memory config = supportedStablecoins[stablecoin];

    feeOnStablecoinInAmount = 0;
    stablecoinInAmountAfterFee = inAmount - feeOnStablecoinInAmount;

    usdPerSuperstateTokenChainlinkRaw = USTBPrice; // 9.5 USDC/SUPERSTATE_TOKEN

    uint256 stablecoinPrecision = 10 ** 6;
    uint256 chainlinkFeedPrecision = 10 ** 8;

    // converts from a USD amount to a SUPERSTATE_TOKEN amount
    superstateTokenOutAmount =
      (stablecoinInAmountAfterFee * chainlinkFeedPrecision * SUPERSTATE_TOKEN_PRECISION) /
      (usdPerSuperstateTokenChainlinkRaw * stablecoinPrecision);
  }

  /**
   * @notice Set the price of USTB, amount of USDC for 1 USTB. USTB/USDC both have 6 decimals.
   * @param newPrice The new price of USTB
   */
  function setUSTBPrice(uint256 newPrice) public {
    USTBPrice = newPrice;
  }
}
