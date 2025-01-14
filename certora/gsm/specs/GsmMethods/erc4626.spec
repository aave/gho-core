methods {
    function _.previewWithdraw(uint256 vaultAssets) external with (env e) =>
        mulDivSummaryRounding(vaultAssets, 3, 5, Math.Rounding.Up) expect uint256;

    function _.convertToShares(uint256 vaultAssets) external with (env e) =>
        require_uint256(vaultAssets * 3 / 5) expect uint256;

    function _.previewMint(uint256 shares) external with (env e) =>
        mulDivSummaryRounding(shares, 5, 3, Math.Rounding.Up) expect uint256;

    function _.convertToAssets(uint256 shares) external with (env e) =>
        require_uint256(shares * 5 / 3) expect uint256;
}
