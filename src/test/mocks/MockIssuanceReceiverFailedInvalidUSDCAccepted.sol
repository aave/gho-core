pragma solidity ^0.8.10;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**
 * @title MockIssuanceReceiverFailedInvalidUSDCAccepted
 * @dev During issuance, the contract does not accept the proper amount of USDC but issues asset properly
 */
contract MockIssuanceReceiverFailedInvalidUSDCAccepted {
  using SafeERC20 for IERC20;

  address public immutable asset;
  address public immutable liquidity;

  /**
   * @param _asset Address of asset token, ie BUIDL
   * @param _liquidity Address of liquidity token, ie USDC
   */
  constructor(address _asset, address _liquidity) {
    asset = _asset;
    liquidity = _liquidity;
  }

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

  /**
   * @notice Issue the asset token in exchange for selling the liquidity token
   */
  function issuance(uint256 amount) external {
    // TRIGGER ERROR: no enough payment token retrieved from msg.sender
    IERC20(liquidity).safeTransferFrom(msg.sender, address(this), amount - 1);
    IERC20(asset).safeTransfer(msg.sender, amount);
  }
}
