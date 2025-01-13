import "./erc20.spec";

using GhoToken as _ghoToken;
using ERC20Helper as erc20Helper;


/////////////////// Methods ////////////////////////

methods
{
	function _ghoToken.transferFrom(address from, address to, uint256 amount) external returns bool with (env e) =>
                   erc20_transferFrom_assumption(calledContract, e, from, to, amount);
	function _ghoToken.mint(address account, uint256 amount) external with (env e) =>
                   erc20_mint_assumption(calledContract, e, account, amount);

	function erc20Helper.tokenBalanceOf(address token, address user) external returns (uint256) envfree;
    function erc20Helper.tokenTotalSupply(address token) external returns (uint256) envfree;
    function getAvailableLiquidity() external returns (uint256) envfree;
    // GSM.sol
    // function _.previewRedeem(uint256 shares) external with(env e) => sharesToVaultAssets(e.block.timestamp, shares) expect uint256;
    // function _.previewWithdraw(uint256 vaultAssets) external with(env e) => vaultAssetsToShares(vaultAssets) expect uint256;
    function _.UNDERLYING_ASSET() external  => DISPATCHER(true);
    function _.GHO_TOKEN() external  => DISPATCHER(true);
    
    // GhoToken

    function _ghoToken.getFacilitatorBucket(address) external returns (uint256, uint256) envfree;

    // Harness
    function getGhoMinted() external returns(uint256) envfree;
    function getPriceRatio() external returns (uint256) envfree;
    function zeroModulo(uint256, uint256, uint256) external envfree;
}

definition harnessOnlyMethods(method f) returns bool =
        (f.selector == sig:getAccruedFees().selector ||
        f.selector == sig:getGhoMinted().selector ||
        f.selector == sig:getPriceRatio().selector ||
        f.selector == sig:getExposureCap().selector ||
        f.selector == sig:getGhoMinted().selector ||
        f.selector == sig:getGhoMinted().selector ||
        f.selector == sig:getPriceRatio().selector ||
        f.selector == sig:getUnderlyingAssetUnits().selector ||
        f.selector == sig:getUnderlyingAssetDecimals().selector ||
        f.selector == sig:getAssetPriceInGho(uint256, bool).selector ||
        f.selector == sig:getAssetPriceInGho(uint256, bool).selector ||
        f.selector == sig:getSellFee(uint256).selector ||
        f.selector == sig:getBuyFee(uint256).selector ||
        f.selector == sig:getBuyFeeBP().selector ||
        f.selector == sig:getSellFeeBP().selector ||
        f.selector == sig:getPercMathPercentageFactor().selector ||
        f.selector == sig:balanceOfGho(address).selector ||
        f.selector == sig:getCurrentGhoBalance().selector ||
        f.selector == sig:getCurrentUnderlyingBalance().selector ||
        f.selector == sig:getGhoBalanceOfThis().selector ||
        f.selector == sig:giftGho(address, uint).selector ||
        f.selector == sig:giftUnderlyingAsset(address, uint).selector ||
        f.selector == sig:balanceOfUnderlying(address).selector ||
        f.selector == sig:getCurrentExposure().selector);

// Wrapping function of erc20 transferFrom that guarantees no overflow.
function erc20_transferFrom_assumption(address token, env e, address from, address to, uint256 amount) returns bool {
        require erc20Helper.tokenBalanceOf(token, from) + erc20Helper.tokenBalanceOf(token, to) <= max_uint256;
		return _ghoToken.transferFrom(e, from, to, amount);
}

// Wrapping function of erc20 mint that guarantees no overflow.
function erc20_mint_assumption(address token, env e, address account, uint256 amount) {
        require erc20Helper.tokenBalanceOf(token, account) + amount <= max_uint256;
		 _ghoToken.mint(e, account, amount);
}

/**
* Maps shares to an arbitrary value
ghost mapping(uint256 => mapping(uint256 => uint256)) shares_ghost {
    axiom (forall uint256 timestamp. forall uint256 shares1. forall uint256 shares2. (!(shares1 <= shares2) => !(shares_ghost[timestamp][shares1] <= shares_ghost[timestamp][shares2]))
	&& shares_ghost[timestamp][0] == 0 && (shares_ghost[timestamp][shares1]/shares1 == shares_ghost[timestamp][shares2]/shares2));
}
**/

function sharesToVaultAssets(uint256 timestamp, uint256 shares) returns uint256 {
    return require_uint256(shares * 5 / 3);
    // return assert_uint256((shares*3)/5); // MY ORIGINAL
	//return shares_ghost[timestamp][shares];
}

function vaultAssetsToShares(uint256 vaultAssets) returns uint256 {
    return mulDivSummaryRounding(vaultAssets, 3, 5, Math.Rounding.Up);
    // return require_uint256((vaultAssets*5)/3); // MY ORIGINAL
}
