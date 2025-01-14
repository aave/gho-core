function feeLimits(env e) {
    require currentContract.getSellFeeBP(e) <= 5000 && currentContract.getBuyFeeBP(e) < 5000 && (currentContract.getSellFeeBP(e) > 0 || currentContract.getBuyFeeBP(e) > 0);
}
