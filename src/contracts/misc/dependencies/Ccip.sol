// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// End consumer library.
library Client {
  /// @dev RMN depends on this struct, if changing, please notify the RMN maintainers.
  struct EVMTokenAmount {
    address token; // token address on the local chain.
    uint256 amount; // Amount of tokens.
  }

  struct Any2EVMMessage {
    bytes32 messageId; // MessageId corresponding to ccipSend on source.
    uint64 sourceChainSelector; // Source chain selector.
    bytes sender; // abi.decode(sender) if coming from an EVM chain.
    bytes data; // payload sent in original message.
    EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
  }

  // If extraArgs is empty bytes, the default is 200k gas limit.
  struct EVM2AnyMessage {
    bytes receiver; // abi.encode(receiver address) for dest EVM chains
    bytes data; // Data payload
    EVMTokenAmount[] tokenAmounts; // Token transfers
    address feeToken; // Address of feeToken. address(0) means you will send msg.value.
    bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV1)
  }

  // bytes4(keccak256("CCIP EVMExtraArgsV1"));
  bytes4 public constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;
  struct EVMExtraArgsV1 {
    uint256 gasLimit;
  }

  function _argsToBytes(EVMExtraArgsV1 memory extraArgs) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(EVM_EXTRA_ARGS_V1_TAG, extraArgs);
  }
}

/// @notice Implements Token Bucket rate limiting.
/// @dev Reduced library from https://github.com/aave/ccip/blob/ccip-gho/contracts/src/v0.8/ccip/libraries/RateLimiter.sol
/// @dev uint128 is safe for rate limiter state.
/// For USD value rate limiting, it can adequately store USD value in 18 decimals.
/// For ERC20 token amount rate limiting, all tokens that will be listed will have at most
/// a supply of uint128.max tokens, and it will therefore not overflow the bucket.
/// In exceptional scenarios where tokens consumed may be larger than uint128,
/// e.g. compromised issuer, an enabled RateLimiter will check and revert.
library RateLimiter {
  error InvalidRatelimitRate(Config rateLimiterConfig);
  error DisabledNonZeroRateLimit(Config config);
  error RateLimitMustBeDisabled();

  event ConfigChanged(Config config);

  struct TokenBucket {
    uint128 tokens; // ──────╮ Current number of tokens that are in the bucket.
    uint32 lastUpdated; //   │ Timestamp in seconds of the last token refill, good for 100+ years.
    bool isEnabled; // ──────╯ Indication whether the rate limiting is enabled or not
    uint128 capacity; // ────╮ Maximum number of tokens that can be in the bucket.
    uint128 rate; // ────────╯ Number of tokens per second that the bucket is refilled.
  }

  struct Config {
    bool isEnabled; // Indication whether the rate limiting should be enabled
    uint128 capacity; // ────╮ Specifies the capacity of the rate limiter
    uint128 rate; //  ───────╯ Specifies the rate of the rate limiter
  }

  /// @notice Gets the token bucket with its values for the block it was requested at.
  /// @return The token bucket.
  function _currentTokenBucketState(
    TokenBucket memory bucket
  ) internal view returns (TokenBucket memory) {
    // We update the bucket to reflect the status at the exact time of the
    // call. This means we might need to refill a part of the bucket based
    // on the time that has passed since the last update.
    bucket.tokens = uint128(
      _calculateRefill(
        bucket.capacity,
        bucket.tokens,
        block.timestamp - bucket.lastUpdated,
        bucket.rate
      )
    );
    bucket.lastUpdated = uint32(block.timestamp);
    return bucket;
  }

  /// @notice Sets the rate limited config.
  /// @param s_bucket The token bucket
  /// @param config The new config
  function _setTokenBucketConfig(TokenBucket storage s_bucket, Config memory config) internal {
    // First update the bucket to make sure the proper rate is used for all the time
    // up until the config change.
    uint256 timeDiff = block.timestamp - s_bucket.lastUpdated;
    if (timeDiff != 0) {
      s_bucket.tokens = uint128(
        _calculateRefill(s_bucket.capacity, s_bucket.tokens, timeDiff, s_bucket.rate)
      );

      s_bucket.lastUpdated = uint32(block.timestamp);
    }

    s_bucket.tokens = uint128(_min(config.capacity, s_bucket.tokens));
    s_bucket.isEnabled = config.isEnabled;
    s_bucket.capacity = config.capacity;
    s_bucket.rate = config.rate;

    emit ConfigChanged(config);
  }

  /// @notice Validates the token bucket config
  function _validateTokenBucketConfig(Config memory config, bool mustBeDisabled) internal pure {
    if (config.isEnabled) {
      if (config.rate >= config.capacity || config.rate == 0) {
        revert InvalidRatelimitRate(config);
      }
      if (mustBeDisabled) {
        revert RateLimitMustBeDisabled();
      }
    } else {
      if (config.rate != 0 || config.capacity != 0) {
        revert DisabledNonZeroRateLimit(config);
      }
    }
  }

  /// @notice Calculate refilled tokens
  /// @param capacity bucket capacity
  /// @param tokens current bucket tokens
  /// @param timeDiff block time difference since last refill
  /// @param rate bucket refill rate
  /// @return the value of tokens after refill
  function _calculateRefill(
    uint256 capacity,
    uint256 tokens,
    uint256 timeDiff,
    uint256 rate
  ) private pure returns (uint256) {
    return _min(capacity, tokens + timeDiff * rate);
  }

  /// @notice Return the smallest of two integers
  /// @param a first int
  /// @param b second int
  /// @return smallest
  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }
}

/// @dev Reduced interface of CCIP Router contract with needed functions only
/// @dev Adapted from https://github.com/aave/ccip/blob/ccip-gho/contracts/src/v0.8/ccip/interfaces/IRouter.sol
interface IRouter {
  error OnlyOffRamp();

  /// @notice Route the message to its intended receiver contract.
  /// @param message Client.Any2EVMMessage struct.
  /// @param gasForCallExactCheck of params for exec
  /// @param gasLimit set of params for exec
  /// @param receiver set of params for exec
  /// @dev if the receiver is a contracts that signals support for CCIP execution through EIP-165.
  /// the contract is called. If not, only tokens are transferred.
  /// @return success A boolean value indicating whether the ccip message was received without errors.
  /// @return retBytes A bytes array containing return data form CCIP receiver.
  /// @return gasUsed the gas used by the external customer call. Does not include any overhead.
  function routeMessage(
    Client.Any2EVMMessage calldata message,
    uint16 gasForCallExactCheck,
    uint256 gasLimit,
    address receiver
  ) external returns (bool success, bytes memory retBytes, uint256 gasUsed);

  /// @notice Returns the configured onramp for a specific destination chain.
  /// @param destChainSelector The destination chain Id to get the onRamp for.
  /// @return onRampAddress The address of the onRamp.
  function getOnRamp(uint64 destChainSelector) external view returns (address onRampAddress);

  /// @notice Return true if the given offRamp is a configured offRamp for the given source chain.
  /// @param sourceChainSelector The source chain selector to check.
  /// @param offRamp The address of the offRamp to check.
  function isOffRamp(
    uint64 sourceChainSelector,
    address offRamp
  ) external view returns (bool isOffRamp);
}

/// @dev Reduced interface of CCIP UpgradeableLockReleaseTokenPool contract with needed functions only
/// @dev Adapted from https://github.com/aave/ccip/blob/ccip-gho/contracts/src/v0.8/ccip/pools/GHO/UpgradeableLockReleaseTokenPool.sol
interface IUpgradeableLockReleaseTokenPool {
  function setBridgeLimit(uint256 newBridgeLimit) external;

  function setChainRateLimiterConfig(
    uint64 remoteChainSelector,
    RateLimiter.Config memory outboundConfig,
    RateLimiter.Config memory inboundConfig
  ) external;

  function setRateLimitAdmin(address rateLimitAdmin) external;

  function setBridgeLimitAdmin(address bridgeLimitAdmin) external;

  function getRateLimitAdmin() external view returns (address);

  function getBridgeLimitAdmin() external view returns (address);

  function getBridgeLimit() external view returns (uint256);

  function getCurrentOutboundRateLimiterState(
    uint64 remoteChainSelector
  ) external view returns (RateLimiter.TokenBucket memory);

  function getCurrentInboundRateLimiterState(
    uint64 remoteChainSelector
  ) external view returns (RateLimiter.TokenBucket memory);
}
