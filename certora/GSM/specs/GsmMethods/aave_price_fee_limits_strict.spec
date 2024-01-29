function feeLimits(env e) {
    require currentContract.getSellFeeBP(e) <= 1000 && currentContract.getBuyFeeBP(e) < 1000 && (currentContract.getSellFeeBP(e) > 0 || currentContract.getBuyFeeBP(e) > 0);
}

function priceLimits(env e) {
    uint8 exp;
    require 5 <= exp;
    require exp <= 27;
    require getUnderlyingAssetUnits(e) == require_uint256((10^exp)) && getPriceRatio(e) >= 10^16 && getPriceRatio(e) <= 10^20;
}
