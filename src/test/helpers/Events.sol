// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Events {
  // core token events
  event Mint(
    address indexed caller,
    address indexed onBehalfOf,
    uint256 value,
    uint256 balanceIncrease,
    uint256 index
  );
  event Burn(
    address indexed from,
    address indexed target,
    uint256 value,
    uint256 balanceIncrease,
    uint256 index
  );
  event Transfer(address indexed from, address indexed to, uint256 value);

  // setter/updater methods
  event ATokenSet(address indexed);
  event VariableDebtTokenSet(address indexed variableDebtToken);
  event GhoTreasuryUpdated(address indexed oldGhoTreasury, address indexed newGhoTreasury);
  event DiscountPercentUpdated(
    address indexed user,
    uint256 oldDiscountPercent,
    uint256 indexed newDiscountPercent
  );
  event DiscountRateStrategyUpdated(
    address indexed oldDiscountRateStrategy,
    address indexed newDiscountRateStrategy
  );
  event ReserveInterestRateStrategyChanged(
    address indexed asset,
    address oldStrategy,
    address newStrategy
  );

  // flashmint-related events
  event FlashMint(
    address indexed receiver,
    address indexed initiator,
    address asset,
    uint256 indexed amount,
    uint256 fee
  );
  event FeeUpdated(uint256 oldFee, uint256 newFee);

  // facilitator-related events
  event FacilitatorAdded(
    address indexed facilitatorAddress,
    bytes32 indexed label,
    uint256 bucketCapacity
  );
  event FacilitatorRemoved(address indexed facilitatorAddress);
  event FacilitatorBucketCapacityUpdated(
    address indexed facilitatorAddress,
    uint256 oldCapacity,
    uint256 newCapacity
  );
  event FacilitatorBucketLevelUpdated(
    address indexed facilitatorAddress,
    uint256 oldLevel,
    uint256 newLevel
  );

  // GSM events
  event BuyAsset(
    address indexed originator,
    address indexed receiver,
    uint256 underlyingAmount,
    uint256 ghoAmount,
    uint256 fee
  );
  event SellAsset(
    address indexed originator,
    address indexed receiver,
    uint256 underlyingAmount,
    uint256 ghoAmount,
    uint256 fee
  );
  event BuyTokenizedAsset(
    address indexed originator,
    address indexed receiver,
    uint256 tokenizedAmount,
    uint256 ghoAmount,
    uint256 fee
  );
  event RedeemTokenizedAsset(address indexed originator, address indexed receiver, uint256 amount);
  event SwapFreeze(address indexed freezer, bool enabled);
  event Seized(
    address indexed seizer,
    address indexed recipient,
    uint256 underlyingAmount,
    uint256 ghoOutstanding
  );
  event BurnAfterSeize(address indexed burner, uint256 amount, uint256 ghoOutstanding);
  event BackingProvided(
    address indexed backer,
    address indexed asset,
    uint256 amount,
    uint256 ghoAmount,
    uint256 remainingLoss
  );
  event GsmTokenUpdated(address indexed oldGsmToken, address indexed newGsmToken);
  event PriceStrategyUpdated(address indexed oldPriceStrategy, address indexed newPriceStrategy);
  event FeeStrategyUpdated(address indexed oldFeeStrategy, address indexed newFeeStrategy);
  event ExposureCapUpdated(uint256 oldExposureCap, uint256 newExposureCap);
  event TokensRescued(
    address indexed tokenRescued,
    address indexed recipient,
    uint256 amountRescued
  );

  // IGhoFacilitator events
  event FeesDistributedToTreasury(
    address indexed ghoTreasury,
    address indexed asset,
    uint256 amount
  );

  // GhoSteward
  event StewardExpirationUpdated(uint40 oldStewardExpiration, uint40 newStewardExpiration);

  // IGsmRegistry events
  event GsmAdded(address gsmAddress);
  event GsmRemoved(address gsmAddress);

  // AccessControl
  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

  // Ownable
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  // Upgrades
  event Upgraded(address indexed implementation);
}
