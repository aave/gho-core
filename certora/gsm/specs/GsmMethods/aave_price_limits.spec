function priceLimits(env e) {
    uint8 exp;
    require 5 <= exp;
    require exp <= 27;
    require getUnderlyingAssetUnits(e) == require_uint256((10^exp)) && getPriceRatio(e) >= 10^16 && getPriceRatio(e) <= 10^20;
}