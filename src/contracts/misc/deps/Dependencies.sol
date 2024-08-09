// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Address} from 'solidity-utils/contracts/oz-common/Address.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';

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

/// @notice This interface contains the only ARM-related functions that might be used on-chain by other CCIP contracts.
interface IARM {
  /// @notice A Merkle root tagged with the address of the commit store contract it is destined for.
  struct TaggedRoot {
    address commitStore;
    bytes32 root;
  }

  /// @notice Callers MUST NOT cache the return value as a blessed tagged root could become unblessed.
  function isBlessed(TaggedRoot calldata taggedRoot) external view returns (bool);

  /// @notice When the ARM is "cursed", CCIP pauses until the curse is lifted.
  function isCursed() external view returns (bool);
}

library DataTypes {
  struct CalculateInterestRatesParams {
    uint256 unbacked;
    uint256 liquidityAdded;
    uint256 liquidityTaken;
    uint256 totalStableDebt;
    uint256 totalVariableDebt;
    uint256 averageStableBorrowRate;
    uint256 reserveFactor;
    address reserve;
    bool usingVirtualBalance;
    uint256 virtualUnderlyingBalance;
  }
}

/**
 * @title IReserveInterestRateStrategy
 * @author BGD Labs
 * @notice Basic interface for any rate strategy used by the Aave protocol
 */
interface IReserveInterestRateStrategy {
  /**
   * @notice Sets interest rate data for an Aave rate strategy
   * @param reserve The reserve to update
   * @param rateData The abi encoded reserve interest rate data to apply to the given reserve
   *   Abstracted this way as rate strategies can be custom
   */
  function setInterestRateParams(address reserve, bytes calldata rateData) external;

  /**
   * @notice Calculates the interest rates depending on the reserve's state and configurations
   * @param params The parameters needed to calculate interest rates
   * @return liquidityRate The liquidity rate expressed in ray
   * @return stableBorrowRate The stable borrow rate expressed in ray
   * @return variableBorrowRate The variable borrow rate expressed in ray
   */
  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  ) external view returns (uint256, uint256, uint256);
}

/**
 * @title IDefaultInterestRateStrategyV2
 * @author BGD Labs
 * @notice Interface of the default interest rate strategy used by the Aave protocol
 */
interface IDefaultInterestRateStrategyV2 is IReserveInterestRateStrategy {
  struct CalcInterestRatesLocalVars {
    uint256 availableLiquidity;
    uint256 totalDebt;
    uint256 currentVariableBorrowRate;
    uint256 currentLiquidityRate;
    uint256 borrowUsageRatio;
    uint256 supplyUsageRatio;
    uint256 availableLiquidityPlusDebt;
  }

  /**
   * @notice Holds the interest rate data for a given reserve
   *
   * @dev Since values are in bps, they are multiplied by 1e23 in order to become rays with 27 decimals. This
   * in turn means that the maximum supported interest rate is 4294967295 (2**32-1) bps or 42949672.95%.
   *
   * @param optimalUsageRatio The optimal usage ratio, in bps
   * @param baseVariableBorrowRate The base variable borrow rate, in bps
   * @param variableRateSlope1 The slope of the variable interest curve, before hitting the optimal ratio, in bps
   * @param variableRateSlope2 The slope of the variable interest curve, after hitting the optimal ratio, in bps
   */
  struct InterestRateData {
    uint16 optimalUsageRatio;
    uint32 baseVariableBorrowRate;
    uint32 variableRateSlope1;
    uint32 variableRateSlope2;
  }

  /**
   * @notice The interest rate data, where all values are in ray (fixed-point 27 decimal numbers) for a given reserve,
   * used in in-memory calculations.
   *
   * @param optimalUsageRatio The optimal usage ratio
   * @param baseVariableBorrowRate The base variable borrow rate
   * @param variableRateSlope1 The slope of the variable interest curve, before hitting the optimal ratio
   * @param variableRateSlope2 The slope of the variable interest curve, after hitting the optimal ratio
   */
  struct InterestRateDataRay {
    uint256 optimalUsageRatio;
    uint256 baseVariableBorrowRate;
    uint256 variableRateSlope1;
    uint256 variableRateSlope2;
  }

  /**
   * @notice emitted when new interest rate data is set in a reserve
   *
   * @param reserve address of the reserve that has new interest rate data set
   * @param optimalUsageRatio The optimal usage ratio, in bps
   * @param baseVariableBorrowRate The base variable borrow rate, in bps
   * @param variableRateSlope1 The slope of the variable interest curve, before hitting the optimal ratio, in bps
   * @param variableRateSlope2 The slope of the variable interest curve, after hitting the optimal ratio, in bps
   */
  event RateDataUpdate(
    address indexed reserve,
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  );

  /**
   * @notice Returns the address of the PoolAddressesProvider
   * @return The address of the PoolAddressesProvider contract
   */
  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  /**
   * @notice Returns the maximum value achievable for variable borrow rate, in bps
   * @return The maximum rate
   */
  function MAX_BORROW_RATE() external view returns (uint256);

  /**
   * @notice Returns the minimum optimal point, in bps
   * @return The optimal point
   */
  function MIN_OPTIMAL_POINT() external view returns (uint256);

  /**
   * @notice Returns the maximum optimal point, in bps
   * @return The optimal point
   */
  function MAX_OPTIMAL_POINT() external view returns (uint256);

  /**
   * notice Returns the full InterestRateDataRay object for the given reserve, in bps
   *
   * @param reserve The reserve to get the data of
   *
   * @return The InterestRateData object for the given reserve
   */
  function getInterestRateDataBps(address reserve) external view returns (InterestRateData memory);

  /**
   * @notice Returns the optimal usage rate for the given reserve in ray
   *
   * @param reserve The reserve to get the optimal usage rate of
   *
   * @return The optimal usage rate is the level of borrow / collateral at which the borrow rate
   */
  function getOptimalUsageRatio(address reserve) external view returns (uint256);

  /**
   * @notice Returns the variable rate slope below optimal usage ratio in ray
   * @dev It's the variable rate when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO
   *
   * @param reserve The reserve to get the variable rate slope 1 of
   *
   * @return The variable rate slope
   */
  function getVariableRateSlope1(address reserve) external view returns (uint256);

  /**
   * @notice Returns the variable rate slope above optimal usage ratio in ray
   * @dev It's the variable rate when usage ratio > OPTIMAL_USAGE_RATIO
   *
   * @param reserve The reserve to get the variable rate slope 2 of
   *
   * @return The variable rate slope
   */
  function getVariableRateSlope2(address reserve) external view returns (uint256);

  /**
   * @notice Returns the base variable borrow rate, in ray
   *
   * @param reserve The reserve to get the base variable borrow rate of
   *
   * @return The base variable borrow rate
   */
  function getBaseVariableBorrowRate(address reserve) external view returns (uint256);

  /**
   * @notice Returns the maximum variable borrow rate, in ray
   *
   * @param reserve The reserve to get the maximum variable borrow rate of
   *
   * @return The maximum variable borrow rate
   */
  function getMaxVariableBorrowRate(address reserve) external view returns (uint256);

  /**
   * @notice Sets interest rate data for an Aave rate strategy
   * @param reserve The reserve to update
   * @param rateData The reserve interest rate data to apply to the given reserve
   *   Being specific to this custom implementation, with custom struct type,
   *   overloading the function on the generic interface
   */
  function setInterestRateParams(address reserve, InterestRateData calldata rateData) external;
}

/**
 * @title PercentageMath library
 * @author Aave
 * @notice Provides functions to perform percentage calculations
 * @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 */
library PercentageMath {
  // Maximum percentage factor (100.00%)
  uint256 internal constant PERCENTAGE_FACTOR = 1e4;

  // Half percentage factor (50.00%)
  uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

  /**
   * @notice Executes a percentage multiplication
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return result value percentmul percentage
   */
  function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
    assembly {
      if iszero(
        or(
          iszero(percentage),
          iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage)))
        )
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
    }
  }

  /**
   * @notice Executes a percentage division
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return result value percentdiv percentage
   */
  function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    // to avoid overflow, value <= (type(uint256).max - halfPercentage) / PERCENTAGE_FACTOR
    assembly {
      if or(
        iszero(percentage),
        iszero(iszero(gt(value, div(sub(not(0), div(percentage, 2)), PERCENTAGE_FACTOR))))
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, PERCENTAGE_FACTOR), div(percentage, 2)), percentage)
    }
  }
}

/**
 * @title WadRayMath library
 * @author Aave
 * @notice Provides functions to perform calculations with Wad and Ray units
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits of precision) and rays (decimal numbers
 * with 27 digits of precision)
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 */
library WadRayMath {
  // HALF_WAD and HALF_RAY expressed with extended notation as constant with operations are not supported in Yul assembly
  uint256 internal constant WAD = 1e18;
  uint256 internal constant HALF_WAD = 0.5e18;

  uint256 internal constant RAY = 1e27;
  uint256 internal constant HALF_RAY = 0.5e27;

  uint256 internal constant WAD_RAY_RATIO = 1e9;

  /**
   * @dev Multiplies two wad, rounding half up to the nearest wad
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Wad
   * @param b Wad
   * @return c = a*b, in wad
   */
  function wadMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= (type(uint256).max - HALF_WAD) / b
    assembly {
      if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_WAD), b))))) {
        revert(0, 0)
      }

      c := div(add(mul(a, b), HALF_WAD), WAD)
    }
  }

  /**
   * @dev Divides two wad, rounding half up to the nearest wad
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Wad
   * @param b Wad
   * @return c = a/b, in wad
   */
  function wadDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= (type(uint256).max - halfB) / WAD
    assembly {
      if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), WAD))))) {
        revert(0, 0)
      }

      c := div(add(mul(a, WAD), div(b, 2)), b)
    }
  }

  /**
   * @notice Multiplies two ray, rounding half up to the nearest ray
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Ray
   * @param b Ray
   * @return c = a raymul b
   */
  function rayMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= (type(uint256).max - HALF_RAY) / b
    assembly {
      if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_RAY), b))))) {
        revert(0, 0)
      }

      c := div(add(mul(a, b), HALF_RAY), RAY)
    }
  }

  /**
   * @notice Divides two ray, rounding half up to the nearest ray
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Ray
   * @param b Ray
   * @return c = a raydiv b
   */
  function rayDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= (type(uint256).max - halfB) / RAY
    assembly {
      if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), RAY))))) {
        revert(0, 0)
      }

      c := div(add(mul(a, RAY), div(b, 2)), b)
    }
  }

  /**
   * @dev Casts ray down to wad
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Ray
   * @return b = a converted to wad, rounded half up to the nearest wad
   */
  function rayToWad(uint256 a) internal pure returns (uint256 b) {
    assembly {
      b := div(a, WAD_RAY_RATIO)
      let remainder := mod(a, WAD_RAY_RATIO)
      if iszero(lt(remainder, div(WAD_RAY_RATIO, 2))) {
        b := add(b, 1)
      }
    }
  }

  /**
   * @dev Converts wad up to ray
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Wad
   * @return b = a converted in ray
   */
  function wadToRay(uint256 a) internal pure returns (uint256 b) {
    // to avoid overflow, b/WAD_RAY_RATIO == a
    assembly {
      b := mul(a, WAD_RAY_RATIO)

      if iszero(eq(div(b, WAD_RAY_RATIO), a)) {
        revert(0, 0)
      }
    }
  }
}

/**
 * @title Errors library
 * @author Aave
 * @notice Defines the error messages emitted by the different contracts of the Aave protocol
 */
library Errors {
  string public constant CALLER_NOT_POOL_CONFIGURATOR = '10'; // 'The caller of the function is not the pool configurator'
  string public constant INVALID_ADDRESSES_PROVIDER = '12'; // 'The address of the pool addresses provider is invalid'
  string public constant ZERO_ADDRESS_NOT_VALID = '77'; // 'Zero address not valid'
  string public constant INVALID_OPTIMAL_USAGE_RATIO = '83'; // 'Invalid optimal usage ratio'
  string public constant INVALID_MAX_RATE = '92'; // The expect maximum borrow rate is invalid
  string public constant SLOPE_2_MUST_BE_GTE_SLOPE_1 = '95'; // Variable interest rate slope 2 can not be lower than slope 1
}

/**
 * @title DefaultReserveInterestRateStrategyV2 contract
 * @author BGD Labs
 * @notice Default interest rate strategy used by the Aave protocol
 * @dev Strategies are pool-specific: each contract CAN'T be used across different Aave pools
 *   due to the caching of the PoolAddressesProvider and the usage of underlying addresses as
 *   index of the _interestRateData
 */
contract DefaultReserveInterestRateStrategyV2 is IDefaultInterestRateStrategyV2 {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  /// @inheritdoc IDefaultInterestRateStrategyV2
  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

  /// @inheritdoc IDefaultInterestRateStrategyV2
  uint256 public constant MAX_BORROW_RATE = 1000_00;

  /// @inheritdoc IDefaultInterestRateStrategyV2
  uint256 public constant MIN_OPTIMAL_POINT = 1_00;

  /// @inheritdoc IDefaultInterestRateStrategyV2
  uint256 public constant MAX_OPTIMAL_POINT = 99_00;

  /// @dev Map of reserves address and their interest rate data (reserveAddress => interestRateData)
  mapping(address => InterestRateData) internal _interestRateData;

  modifier onlyPoolConfigurator() {
    require(
      msg.sender == ADDRESSES_PROVIDER.getPoolConfigurator(),
      Errors.CALLER_NOT_POOL_CONFIGURATOR
    );
    _;
  }

  /**
   * @dev Constructor.
   * @param provider The address of the PoolAddressesProvider of the associated Aave pool
   */
  constructor(address provider) {
    require(provider != address(0), Errors.INVALID_ADDRESSES_PROVIDER);
    ADDRESSES_PROVIDER = IPoolAddressesProvider(provider);
  }

  /// @inheritdoc IReserveInterestRateStrategy
  function setInterestRateParams(
    address reserve,
    bytes calldata rateData
  ) external onlyPoolConfigurator {
    _setInterestRateParams(reserve, abi.decode(rateData, (InterestRateData)));
  }

  /// @inheritdoc IDefaultInterestRateStrategyV2
  function setInterestRateParams(
    address reserve,
    InterestRateData calldata rateData
  ) external onlyPoolConfigurator {
    _setInterestRateParams(reserve, rateData);
  }

  /// @inheritdoc IDefaultInterestRateStrategyV2
  function getInterestRateDataBps(address reserve) external view returns (InterestRateData memory) {
    return _interestRateData[reserve];
  }

  /// @inheritdoc IDefaultInterestRateStrategyV2
  function getOptimalUsageRatio(address reserve) external view returns (uint256) {
    return _bpsToRay(uint256(_interestRateData[reserve].optimalUsageRatio));
  }

  /// @inheritdoc IDefaultInterestRateStrategyV2
  function getVariableRateSlope1(address reserve) external view returns (uint256) {
    return _bpsToRay(uint256(_interestRateData[reserve].variableRateSlope1));
  }

  /// @inheritdoc IDefaultInterestRateStrategyV2
  function getVariableRateSlope2(address reserve) external view returns (uint256) {
    return _bpsToRay(uint256(_interestRateData[reserve].variableRateSlope2));
  }

  /// @inheritdoc IDefaultInterestRateStrategyV2
  function getBaseVariableBorrowRate(address reserve) external view override returns (uint256) {
    return _bpsToRay(uint256(_interestRateData[reserve].baseVariableBorrowRate));
  }

  /// @inheritdoc IDefaultInterestRateStrategyV2
  function getMaxVariableBorrowRate(address reserve) external view override returns (uint256) {
    return
      _bpsToRay(
        uint256(
          _interestRateData[reserve].baseVariableBorrowRate +
            _interestRateData[reserve].variableRateSlope1 +
            _interestRateData[reserve].variableRateSlope2
        )
      );
  }

  /// @inheritdoc IReserveInterestRateStrategy
  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  ) external view virtual override returns (uint256, uint256, uint256) {
    InterestRateDataRay memory rateData = _rayifyRateData(_interestRateData[params.reserve]);

    // @note This is a short circuit to allow mintable assets (ex. GHO), which by definition cannot be supplied
    // and thus do not use virtual underlying balances.
    if (!params.usingVirtualBalance) {
      return (0, 0, rateData.baseVariableBorrowRate);
    }

    CalcInterestRatesLocalVars memory vars;

    vars.totalDebt = params.totalStableDebt + params.totalVariableDebt;

    vars.currentLiquidityRate = 0;
    vars.currentVariableBorrowRate = rateData.baseVariableBorrowRate;

    if (vars.totalDebt != 0) {
      vars.availableLiquidity =
        params.virtualUnderlyingBalance +
        params.liquidityAdded -
        params.liquidityTaken;

      vars.availableLiquidityPlusDebt = vars.availableLiquidity + vars.totalDebt;
      vars.borrowUsageRatio = vars.totalDebt.rayDiv(vars.availableLiquidityPlusDebt);
      vars.supplyUsageRatio = vars.totalDebt.rayDiv(
        vars.availableLiquidityPlusDebt + params.unbacked
      );
    } else {
      return (0, 0, vars.currentVariableBorrowRate);
    }

    if (vars.borrowUsageRatio > rateData.optimalUsageRatio) {
      uint256 excessBorrowUsageRatio = (vars.borrowUsageRatio - rateData.optimalUsageRatio).rayDiv(
        WadRayMath.RAY - rateData.optimalUsageRatio
      );

      vars.currentVariableBorrowRate +=
        rateData.variableRateSlope1 +
        rateData.variableRateSlope2.rayMul(excessBorrowUsageRatio);
    } else {
      vars.currentVariableBorrowRate += rateData
        .variableRateSlope1
        .rayMul(vars.borrowUsageRatio)
        .rayDiv(rateData.optimalUsageRatio);
    }

    vars.currentLiquidityRate = _getOverallBorrowRate(
      params.totalStableDebt,
      params.totalVariableDebt,
      vars.currentVariableBorrowRate,
      params.averageStableBorrowRate
    ).rayMul(vars.supplyUsageRatio).percentMul(
        PercentageMath.PERCENTAGE_FACTOR - params.reserveFactor
      );

    return (vars.currentLiquidityRate, 0, vars.currentVariableBorrowRate);
  }

  /**
   * @dev Calculates the overall borrow rate as the weighted average between the total variable debt and total stable
   * debt
   * @param totalStableDebt The total borrowed from the reserve at a stable rate
   * @param totalVariableDebt The total borrowed from the reserve at a variable rate
   * @param currentVariableBorrowRate The current variable borrow rate of the reserve
   * @param currentAverageStableBorrowRate The current weighted average of all the stable rate loans
   * @return The weighted averaged borrow rate
   */
  function _getOverallBorrowRate(
    uint256 totalStableDebt,
    uint256 totalVariableDebt,
    uint256 currentVariableBorrowRate,
    uint256 currentAverageStableBorrowRate
  ) internal pure returns (uint256) {
    uint256 totalDebt = totalStableDebt + totalVariableDebt;

    uint256 weightedVariableRate = totalVariableDebt.wadToRay().rayMul(currentVariableBorrowRate);

    uint256 weightedStableRate = totalStableDebt.wadToRay().rayMul(currentAverageStableBorrowRate);

    uint256 overallBorrowRate = (weightedVariableRate + weightedStableRate).rayDiv(
      totalDebt.wadToRay()
    );

    return overallBorrowRate;
  }

  /**
   * @dev Doing validations and data update for an asset
   * @param reserve address of the underlying asset of the reserve
   * @param rateData Encoded reserve interest rate data to apply
   */
  function _setInterestRateParams(address reserve, InterestRateData memory rateData) internal {
    require(reserve != address(0), Errors.ZERO_ADDRESS_NOT_VALID);

    require(
      rateData.optimalUsageRatio <= MAX_OPTIMAL_POINT &&
        rateData.optimalUsageRatio >= MIN_OPTIMAL_POINT,
      Errors.INVALID_OPTIMAL_USAGE_RATIO
    );

    require(
      rateData.variableRateSlope1 <= rateData.variableRateSlope2,
      Errors.SLOPE_2_MUST_BE_GTE_SLOPE_1
    );

    // The maximum rate should not be above certain threshold
    require(
      uint256(rateData.baseVariableBorrowRate) +
        uint256(rateData.variableRateSlope1) +
        uint256(rateData.variableRateSlope2) <=
        MAX_BORROW_RATE,
      Errors.INVALID_MAX_RATE
    );

    _interestRateData[reserve] = rateData;
    emit RateDataUpdate(
      reserve,
      rateData.optimalUsageRatio,
      rateData.baseVariableBorrowRate,
      rateData.variableRateSlope1,
      rateData.variableRateSlope2
    );
  }

  /**
   * @dev Transforms an InterestRateData struct to an InterestRateDataRay struct by multiplying all values
   * by 1e23, turning them into ray values
   *
   * @param data The InterestRateData struct to transform
   *
   * @return The resulting InterestRateDataRay struct
   */
  function _rayifyRateData(
    InterestRateData memory data
  ) internal pure returns (InterestRateDataRay memory) {
    return
      InterestRateDataRay({
        optimalUsageRatio: _bpsToRay(uint256(data.optimalUsageRatio)),
        baseVariableBorrowRate: _bpsToRay(uint256(data.baseVariableBorrowRate)),
        variableRateSlope1: _bpsToRay(uint256(data.variableRateSlope1)),
        variableRateSlope2: _bpsToRay(uint256(data.variableRateSlope2))
      });
  }

  // @dev helper function added here, as generally the protocol doesn't use bps
  function _bpsToRay(uint256 n) internal pure returns (uint256) {
    return n * 1e23;
  }
}
