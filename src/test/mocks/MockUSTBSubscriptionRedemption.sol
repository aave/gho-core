pragma solidity ^0.8.10;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**
 * @title MockUSTBSubscription
 */
contract MockUSTBSubscription {
  using SafeERC20 for IERC20;

  address public immutable asset;
  address public immutable liquidity;
  uint256 public USTBPrice;

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
    uint256 USDCAmount = amount * USTBPrice;
    IERC20(asset).safeTransfer(msg.sender, amount);
    IERC20(liquidity).safeTransferFrom(msg.sender, address(this), USDCAmount);
  }

  /**
   * @notice Set the price of USTB, amount of USDC for 1 USTB. Accounts for decimal mismatch.
   * @param newPrice The new price of USTB
   */
  function setUSTBPrice(uint256 newPrice) public {
    USTBPrice = newPrice;
  }
}
