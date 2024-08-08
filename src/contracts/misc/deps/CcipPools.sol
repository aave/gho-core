import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {RateLimiter} from 'src/contracts/misc/deps/RateLimiter.sol';
import {IRouter} from 'src/contracts/misc/deps/Dependencies.sol';
import {IARM} from 'src/contracts/misc/deps/Dependencies.sol';

interface IOwnable {
  function owner() external returns (address);

  function transferOwnership(address recipient) external;

  function acceptOwnership() external;
}

/// @title The ConfirmedOwner contract
/// @notice A contract with helpers for basic contract ownership.
contract ConfirmedOwnerWithProposal is IOwnable {
  address private s_owner;
  address private s_pendingOwner;

  event OwnershipTransferRequested(address indexed from, address indexed to);
  event OwnershipTransferred(address indexed from, address indexed to);

  constructor(address newOwner, address pendingOwner) {
    // solhint-disable-next-line custom-errors
    require(newOwner != address(0), 'Cannot set owner to zero');

    s_owner = newOwner;
    if (pendingOwner != address(0)) {
      _transferOwnership(pendingOwner);
    }
  }

  /// @notice Allows an owner to begin transferring ownership to a new address.
  function transferOwnership(address to) public override onlyOwner {
    _transferOwnership(to);
  }

  /// @notice Allows an ownership transfer to be completed by the recipient.
  function acceptOwnership() external override {
    // solhint-disable-next-line custom-errors
    require(msg.sender == s_pendingOwner, 'Must be proposed owner');

    address oldOwner = s_owner;
    s_owner = msg.sender;
    s_pendingOwner = address(0);

    emit OwnershipTransferred(oldOwner, msg.sender);
  }

  /// @notice Get the current owner
  function owner() public view override returns (address) {
    return s_owner;
  }

  /// @notice validate, transfer ownership, and emit relevant events
  function _transferOwnership(address to) internal {
    s_pendingOwner = to;

    emit OwnershipTransferRequested(s_owner, to);
  }

  /// @notice validate access
  function _validateOwnership() internal view {
    // solhint-disable-next-line custom-errors
    require(msg.sender == s_owner, 'Only callable by owner');
  }

  /// @notice Reverts if called by anyone other than the contract owner.
  modifier onlyOwner() {
    _validateOwnership();
    _;
  }
}

/// @title The ConfirmedOwner contract
/// @notice A contract with helpers for basic contract ownership.
contract ConfirmedOwner is ConfirmedOwnerWithProposal {
  constructor(address newOwner) ConfirmedOwnerWithProposal(newOwner, address(0)) {}
}

/// @title The OwnerIsCreator contract
/// @notice A contract with helpers for basic contract ownership.
contract OwnerIsCreator is ConfirmedOwner {
  constructor() ConfirmedOwner(msg.sender) {}
}

/// @notice Base abstract class with common functions for all token pools.
/// @dev Reduced contract from https://github.com/aave/ccip/blob/ccip-gho/contracts/src/v0.8/ccip/pools/GHO/UpgradeableTokenPool.sol
/// A token pool serves as isolated place for holding tokens and token specific logic
/// that may execute as tokens move across the bridge.
abstract contract UpgradeableTokenPool is OwnerIsCreator {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.UintSet;
  using RateLimiter for RateLimiter.TokenBucket;

  error ZeroAddressNotAllowed();
  error SenderNotAllowed(address sender);
  error NonExistentChain(uint64 remoteChainSelector);
  error ChainAlreadyExists(uint64 chainSelector);

  event ChainAdded(
    uint64 remoteChainSelector,
    RateLimiter.Config outboundRateLimiterConfig,
    RateLimiter.Config inboundRateLimiterConfig
  );
  event ChainConfigured(
    uint64 remoteChainSelector,
    RateLimiter.Config outboundRateLimiterConfig,
    RateLimiter.Config inboundRateLimiterConfig
  );
  event ChainRemoved(uint64 remoteChainSelector);
  event RouterUpdated(address oldRouter, address newRouter);

  struct ChainUpdate {
    uint64 remoteChainSelector; // ──╮ Remote chain selector
    bool allowed; // ────────────────╯ Whether the chain is allowed
    RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
    RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
  }

  /// @dev The bridgeable token that is managed by this pool.
  IERC20 internal immutable i_token;
  /// @dev The address of the arm proxy
  address internal immutable i_armProxy;
  /// @dev The immutable flag that indicates if the pool is access-controlled.
  bool internal immutable i_allowlistEnabled;
  /// @dev A set of addresses allowed to trigger lockOrBurn as original senders.
  /// Only takes effect if i_allowlistEnabled is true.
  /// This can be used to ensure only token-issuer specified addresses can
  /// move tokens.
  EnumerableSet.AddressSet internal s_allowList;
  /// @dev The address of the router
  IRouter internal s_router;
  /// @dev A set of allowed chain selectors. We want the allowlist to be enumerable to
  /// be able to quickly determine (without parsing logs) who can access the pool.
  /// @dev The chain selectors are in uin256 format because of the EnumerableSet implementation.
  EnumerableSet.UintSet internal s_remoteChainSelectors;
  /// @dev Outbound rate limits. Corresponds to the inbound rate limit for the pool
  /// on the remote chain.
  mapping(uint64 => RateLimiter.TokenBucket) internal s_outboundRateLimits;
  /// @dev Inbound rate limits. This allows per destination chain
  /// token issuer specified rate limiting (e.g. issuers may trust chains to varying
  /// degrees and prefer different limits)
  mapping(uint64 => RateLimiter.TokenBucket) internal s_inboundRateLimits;

  constructor(IERC20 token, address armProxy, bool allowlistEnabled) {
    if (address(token) == address(0)) revert ZeroAddressNotAllowed();
    i_token = token;
    i_armProxy = armProxy;
    i_allowlistEnabled = allowlistEnabled;
  }

  /// @notice Get ARM proxy address
  /// @return armProxy Address of arm proxy
  function getArmProxy() public view returns (address armProxy) {
    return i_armProxy;
  }

  function getToken() public view returns (IERC20 token) {
    return i_token;
  }

  /// @notice Gets the pool's Router
  /// @return router The pool's Router
  function getRouter() public view returns (address router) {
    return address(s_router);
  }

  // ================================================================
  // │                     Chain permissions                        │
  // ================================================================

  /// @notice Checks whether a chain selector is permissioned on this contract.
  /// @return true if the given chain selector is a permissioned remote chain.
  function isSupportedChain(uint64 remoteChainSelector) public view returns (bool) {
    return s_remoteChainSelectors.contains(remoteChainSelector);
  }

  /// @notice Get list of allowed chains
  /// @return list of chains.
  function getSupportedChains() public view returns (uint64[] memory) {
    uint256[] memory uint256ChainSelectors = s_remoteChainSelectors.values();
    uint64[] memory chainSelectors = new uint64[](uint256ChainSelectors.length);
    for (uint256 i = 0; i < uint256ChainSelectors.length; ++i) {
      chainSelectors[i] = uint64(uint256ChainSelectors[i]);
    }

    return chainSelectors;
  }

  /// @notice Sets the permissions for a list of chains selectors. Actual senders for these chains
  /// need to be allowed on the Router to interact with this pool.
  /// @dev Only callable by the owner
  /// @param chains A list of chains and their new permission status & rate limits. Rate limits
  /// are only used when the chain is being added through `allowed` being true.
  function applyChainUpdates(ChainUpdate[] calldata chains) external virtual onlyOwner {
    for (uint256 i = 0; i < chains.length; ++i) {
      ChainUpdate memory update = chains[i];
      RateLimiter._validateTokenBucketConfig(update.outboundRateLimiterConfig, !update.allowed);
      RateLimiter._validateTokenBucketConfig(update.inboundRateLimiterConfig, !update.allowed);

      if (update.allowed) {
        // If the chain already exists, revert
        if (!s_remoteChainSelectors.add(update.remoteChainSelector)) {
          revert ChainAlreadyExists(update.remoteChainSelector);
        }

        s_outboundRateLimits[update.remoteChainSelector] = RateLimiter.TokenBucket({
          rate: update.outboundRateLimiterConfig.rate,
          capacity: update.outboundRateLimiterConfig.capacity,
          tokens: update.outboundRateLimiterConfig.capacity,
          lastUpdated: uint32(block.timestamp),
          isEnabled: update.outboundRateLimiterConfig.isEnabled
        });

        s_inboundRateLimits[update.remoteChainSelector] = RateLimiter.TokenBucket({
          rate: update.inboundRateLimiterConfig.rate,
          capacity: update.inboundRateLimiterConfig.capacity,
          tokens: update.inboundRateLimiterConfig.capacity,
          lastUpdated: uint32(block.timestamp),
          isEnabled: update.inboundRateLimiterConfig.isEnabled
        });
        emit ChainAdded(
          update.remoteChainSelector,
          update.outboundRateLimiterConfig,
          update.inboundRateLimiterConfig
        );
      } else {
        // If the chain doesn't exist, revert
        if (!s_remoteChainSelectors.remove(update.remoteChainSelector)) {
          revert NonExistentChain(update.remoteChainSelector);
        }

        delete s_inboundRateLimits[update.remoteChainSelector];
        delete s_outboundRateLimits[update.remoteChainSelector];
        emit ChainRemoved(update.remoteChainSelector);
      }
    }
  }

  // ================================================================
  // │                        Rate limiting                         │
  // ================================================================

  /// @notice Gets the token bucket with its values for the block it was requested at.
  /// @return The token bucket.
  function getCurrentOutboundRateLimiterState(
    uint64 remoteChainSelector
  ) external view returns (RateLimiter.TokenBucket memory) {
    return s_outboundRateLimits[remoteChainSelector]._currentTokenBucketState();
  }

  /// @notice Gets the token bucket with its values for the block it was requested at.
  /// @return The token bucket.
  function getCurrentInboundRateLimiterState(
    uint64 remoteChainSelector
  ) external view returns (RateLimiter.TokenBucket memory) {
    return s_inboundRateLimits[remoteChainSelector]._currentTokenBucketState();
  }

  /// @notice Sets the chain rate limiter config.
  /// @param remoteChainSelector The remote chain selector for which the rate limits apply.
  /// @param outboundConfig The new outbound rate limiter config, meaning the onRamp rate limits for the given chain.
  /// @param inboundConfig The new inbound rate limiter config, meaning the offRamp rate limits for the given chain.
  function setChainRateLimiterConfig(
    uint64 remoteChainSelector,
    RateLimiter.Config memory outboundConfig,
    RateLimiter.Config memory inboundConfig
  ) external virtual onlyOwner {
    _setRateLimitConfig(remoteChainSelector, outboundConfig, inboundConfig);
  }

  function _setRateLimitConfig(
    uint64 remoteChainSelector,
    RateLimiter.Config memory outboundConfig,
    RateLimiter.Config memory inboundConfig
  ) internal {
    if (!isSupportedChain(remoteChainSelector)) revert NonExistentChain(remoteChainSelector);
    RateLimiter._validateTokenBucketConfig(outboundConfig, false);
    s_outboundRateLimits[remoteChainSelector]._setTokenBucketConfig(outboundConfig);
    RateLimiter._validateTokenBucketConfig(inboundConfig, false);
    s_inboundRateLimits[remoteChainSelector]._setTokenBucketConfig(inboundConfig);
    emit ChainConfigured(remoteChainSelector, outboundConfig, inboundConfig);
  }

  // ================================================================
  // │                          Allowlist                           │
  // ================================================================

  modifier checkAllowList(address sender) {
    if (i_allowlistEnabled && !s_allowList.contains(sender)) revert SenderNotAllowed(sender);
    _;
  }

  /// @notice Gets whether the allowList functionality is enabled.
  /// @return true is enabled, false if not.
  function getAllowListEnabled() external view returns (bool) {
    return i_allowlistEnabled;
  }

  /// @notice Gets the allowed addresses.
  /// @return The allowed addresses.
  function getAllowList() external view returns (address[] memory) {
    return s_allowList.values();
  }
}

/// @title UpgradeableLockReleaseTokenPool
/// @author Aave Labs
/// @notice Upgradeable version of Chainlink's CCIP LockReleaseTokenPool
/// @dev Reduced contract from https://github.com/aave/ccip/blob/ccip-gho/contracts/src/v0.8/ccip/pools/GHO/UpgradeableLockReleaseTokenPool.sol
/// @dev Contract adaptations:
/// - Implementation of Initializable to allow upgrades
/// - Move of allowlist and router definition to initialization stage
/// - Addition of a bridge limit to regulate the maximum amount of tokens that can be transferred out (burned/locked)
contract UpgradeableLockReleaseTokenPool is Initializable, UpgradeableTokenPool {
  using SafeERC20 for IERC20;

  error Unauthorized(address caller);

  event BridgeLimitUpdated(uint256 oldBridgeLimit, uint256 newBridgeLimit);
  event BridgeLimitAdminUpdated(address indexed oldAdmin, address indexed newAdmin);

  /// @dev Whether or not the pool accepts liquidity.
  /// External liquidity is not required when there is one canonical token deployed to a chain,
  /// and CCIP is facilitating mint/burn on all the other chains, in which case the invariant
  /// balanceOf(pool) on home chain == sum(totalSupply(mint/burn "wrapped" token) on all remote chains) should always hold
  bool internal immutable i_acceptLiquidity;
  /// @notice The address of the rate limiter admin.
  /// @dev Can be address(0) if none is configured.
  address internal s_rateLimitAdmin;

  /// @notice Maximum amount of tokens that can be bridged to other chains
  uint256 private s_bridgeLimit;
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
    s_bridgeLimit = bridgeLimit;
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

  /// @notice Gets the rate limiter admin address.
  function getRateLimitAdmin() external view returns (address) {
    return s_rateLimitAdmin;
  }

  /// @notice Gets the bridge limiter admin address.
  function getBridgeLimitAdmin() external view returns (address) {
    return s_bridgeLimitAdmin;
  }

  /// @notice Sets the chain rate limiter config.
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
