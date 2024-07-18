// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';

import {ITypeAndVersion} from './ITypeAndVersion.sol';
import {ILiquidityContainer} from './ILiquidityContainer.sol';

import {UpgradeableTokenPool} from './UpgradeableTokenPool.sol';
import {RateLimiter} from './RateLimiter.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IRouter} from './IRouter.sol';

/// @title UpgradeableLockReleaseTokenPool
/// @author Aave Labs
/// @notice Upgradeable version of Chainlink's CCIP LockReleaseTokenPool
/// @dev Contract adaptations:
/// - Implementation of Initializable to allow upgrades
/// - Move of allowlist and router definition to initialization stage
/// - Addition of a bridge limit to regulate the maximum amount of tokens that can be transferred out (burned/locked)
contract UpgradeableLockReleaseTokenPool is
  Initializable,
  UpgradeableTokenPool,
  ILiquidityContainer,
  ITypeAndVersion
{
  using SafeERC20 for IERC20;

  error InsufficientLiquidity();
  error LiquidityNotAccepted();
  error Unauthorized(address caller);

  error BridgeLimitExceeded(uint256 bridgeLimit);
  error NotEnoughBridgedAmount();

  event BridgeLimitUpdated(uint256 oldBridgeLimit, uint256 newBridgeLimit);
  event BridgeLimitAdminUpdated(address indexed oldAdmin, address indexed newAdmin);

  string public constant override typeAndVersion = 'LockReleaseTokenPool 1.4.0';

  /// @dev The unique lock release pool flag to signal through EIP 165.
  bytes4 private constant LOCK_RELEASE_INTERFACE_ID = bytes4(keccak256('LockReleaseTokenPool'));

  /// @dev Whether or not the pool accepts liquidity.
  /// External liquidity is not required when there is one canonical token deployed to a chain,
  /// and CCIP is facilitating mint/burn on all the other chains, in which case the invariant
  /// balanceOf(pool) on home chain == sum(totalSupply(mint/burn "wrapped" token) on all remote chains) should always hold
  bool internal immutable i_acceptLiquidity;
  /// @notice The address of the rebalancer.
  address internal s_rebalancer;
  /// @notice The address of the rate limiter admin.
  /// @dev Can be address(0) if none is configured.
  address internal s_rateLimitAdmin;

  /// @notice Maximum amount of tokens that can be bridged to other chains
  uint256 private s_bridgeLimit;
  /// @notice Amount of tokens bridged (transferred out)
  /// @dev Must always be equal to or below the bridge limit
  uint256 private s_currentBridged;
  /// @notice The address of the bridge limit admin.
  /// @dev Can be address(0) if none is configured.
  address internal s_bridgeLimitAdmin;

  /// @dev Constructor
  /// @param token The bridgeable token that is managed by this pool.
  /// @param armProxy The address of the arm proxy
  /// @param allowlistEnabled True if pool is set to access-controlled mode, false otherwise
  /// @param acceptLiquidity True if the pool accepts liquidity, false otherwise
  constructor(
    address token,
    address armProxy,
    bool allowlistEnabled,
    bool acceptLiquidity
  ) UpgradeableTokenPool(IERC20(token), armProxy, allowlistEnabled) {
    i_acceptLiquidity = acceptLiquidity;
  }

  /// @dev Initializer
  /// @dev The address passed as `owner` must accept ownership after initialization.
  /// @dev The `allowlist` is only effective if pool is set to access-controlled mode
  /// @param owner The address of the owner
  /// @param allowlist A set of addresses allowed to trigger lockOrBurn as original senders
  /// @param router The address of the router
  /// @param bridgeLimit The maximum amount of tokens that can be bridged to other chains
  function initialize(
    address owner,
    address[] memory allowlist,
    address router,
    uint256 bridgeLimit
  ) public virtual initializer {
    if (owner == address(0)) revert ZeroAddressNotAllowed();
    if (router == address(0)) revert ZeroAddressNotAllowed();
    _transferOwnership(owner);

    s_router = IRouter(router);

    // Pool can be set as permissioned or permissionless at deployment time only to save hot-path gas.
    if (i_allowlistEnabled) {
      _applyAllowListUpdates(new address[](0), allowlist);
    }
    s_bridgeLimit = bridgeLimit;
  }

  /// @notice Locks the token in the pool
  /// @param amount Amount to lock
  /// @dev The whenHealthy check is important to ensure that even if a ramp is compromised
  /// we're able to stop token movement via ARM.
  function lockOrBurn(
    address originalSender,
    bytes calldata,
    uint256 amount,
    uint64 remoteChainSelector,
    bytes calldata
  )
    external
    virtual
    override
    onlyOnRamp(remoteChainSelector)
    checkAllowList(originalSender)
    whenHealthy
    returns (bytes memory)
  {
    // Increase bridged amount because tokens are leaving the source chain
    if ((s_currentBridged += amount) > s_bridgeLimit) revert BridgeLimitExceeded(s_bridgeLimit);

    _consumeOutboundRateLimit(remoteChainSelector, amount);
    emit Locked(msg.sender, amount);
    return '';
  }

  /// @notice Release tokens from the pool to the recipient
  /// @param receiver Recipient address
  /// @param amount Amount to release
  /// @dev The whenHealthy check is important to ensure that even if a ramp is compromised
  /// we're able to stop token movement via ARM.
  function releaseOrMint(
    bytes memory,
    address receiver,
    uint256 amount,
    uint64 remoteChainSelector,
    bytes memory
  ) external virtual override onlyOffRamp(remoteChainSelector) whenHealthy {
    // This should never occur. Amount should never exceed the current bridged amount
    if (amount > s_currentBridged) revert NotEnoughBridgedAmount();
    // Reduce bridged amount because tokens are back to source chain
    s_currentBridged -= amount;

    _consumeInboundRateLimit(remoteChainSelector, amount);
    getToken().safeTransfer(receiver, amount);
    emit Released(msg.sender, receiver, amount);
  }

  /// @notice returns the lock release interface flag used for EIP165 identification.
  function getLockReleaseInterfaceId() public pure returns (bytes4) {
    return LOCK_RELEASE_INTERFACE_ID;
  }

  // @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
    return
      interfaceId == LOCK_RELEASE_INTERFACE_ID ||
      interfaceId == type(ILiquidityContainer).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  /// @notice Gets Rebalancer, can be address(0) if none is configured.
  /// @return The current liquidity manager.
  function getRebalancer() external view returns (address) {
    return s_rebalancer;
  }

  /// @notice Sets the Rebalancer address.
  /// @dev Only callable by the owner.
  function setRebalancer(address rebalancer) external onlyOwner {
    s_rebalancer = rebalancer;
  }

  /// @notice Sets the rate limiter admin address.
  /// @dev Only callable by the owner.
  /// @param rateLimitAdmin The new rate limiter admin address.
  function setRateLimitAdmin(address rateLimitAdmin) external onlyOwner {
    s_rateLimitAdmin = rateLimitAdmin;
  }

  /// @notice Sets the bridge limit, the maximum amount of tokens that can be bridged out
  /// @dev Only callable by the owner or the bridge limit admin.
  /// @dev Bridge limit changes should be carefully managed, specially when reducing below the current bridged amount
  /// @param newBridgeLimit The new bridge limit
  function setBridgeLimit(uint256 newBridgeLimit) external {
    if (msg.sender != s_bridgeLimitAdmin && msg.sender != owner()) revert Unauthorized(msg.sender);
    uint256 oldBridgeLimit = s_bridgeLimit;
    s_bridgeLimit = newBridgeLimit;
    emit BridgeLimitUpdated(oldBridgeLimit, newBridgeLimit);
  }

  /// @notice Sets the bridge limit admin address.
  /// @dev Only callable by the owner.
  /// @param bridgeLimitAdmin The new bridge limit admin address.
  function setBridgeLimitAdmin(address bridgeLimitAdmin) external onlyOwner {
    address oldAdmin = s_bridgeLimitAdmin;
    s_bridgeLimitAdmin = bridgeLimitAdmin;
    emit BridgeLimitAdminUpdated(oldAdmin, bridgeLimitAdmin);
  }

  /// @notice Gets the bridge limit
  /// @return The maximum amount of tokens that can be transferred out to other chains
  function getBridgeLimit() external view virtual returns (uint256) {
    return s_bridgeLimit;
  }

  /// @notice Gets the current bridged amount to other chains
  /// @return The amount of tokens transferred out to other chains
  function getCurrentBridgedAmount() external view virtual returns (uint256) {
    return s_currentBridged;
  }

  /// @notice Gets the rate limiter admin address.
  function getRateLimitAdmin() external view returns (address) {
    return s_rateLimitAdmin;
  }

  /// @notice Gets the bridge limiter admin address.
  function getBridgeLimitAdmin() external view returns (address) {
    return s_bridgeLimitAdmin;
  }

  /// @notice Checks if the pool can accept liquidity.
  /// @return true if the pool can accept liquidity, false otherwise.
  function canAcceptLiquidity() external view returns (bool) {
    return i_acceptLiquidity;
  }

  /// @notice Adds liquidity to the pool. The tokens should be approved first.
  /// @param amount The amount of liquidity to provide.
  function provideLiquidity(uint256 amount) external {
    if (!i_acceptLiquidity) revert LiquidityNotAccepted();
    if (s_rebalancer != msg.sender) revert Unauthorized(msg.sender);

    i_token.safeTransferFrom(msg.sender, address(this), amount);
    emit LiquidityAdded(msg.sender, amount);
  }

  /// @notice Removed liquidity to the pool. The tokens will be sent to msg.sender.
  /// @param amount The amount of liquidity to remove.
  function withdrawLiquidity(uint256 amount) external {
    if (s_rebalancer != msg.sender) revert Unauthorized(msg.sender);

    if (i_token.balanceOf(address(this)) < amount) revert InsufficientLiquidity();
    i_token.safeTransfer(msg.sender, amount);
    emit LiquidityRemoved(msg.sender, amount);
  }

  /// @notice Sets the rate limiter admin address.
  /// @dev Only callable by the owner or the rate limiter admin. NOTE: overwrites the normal
  /// onlyAdmin check in the base implementation to also allow the rate limiter admin.
  /// @param remoteChainSelector The remote chain selector for which the rate limits apply.
  /// @param outboundConfig The new outbound rate limiter config.
  /// @param inboundConfig The new inbound rate limiter config.
  function setChainRateLimiterConfig(
    uint64 remoteChainSelector,
    RateLimiter.Config memory outboundConfig,
    RateLimiter.Config memory inboundConfig
  ) external override {
    if (msg.sender != s_rateLimitAdmin && msg.sender != owner()) revert Unauthorized(msg.sender);

    _setRateLimitConfig(remoteChainSelector, outboundConfig, inboundConfig);
  }
}
