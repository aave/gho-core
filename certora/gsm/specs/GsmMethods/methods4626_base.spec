import "./erc20.spec";


using FixedPriceStrategy4626Harness as _priceStrategy;
using FixedFeeStrategyHarness as _FixedFeeStrategy;
using GhoToken as _ghoToken;
using ERC20Helper as erc20Helper;

/////////////////// Methods ////////////////////////

methods
{
    function _ghoToken.transferFrom(address from, address to, uint256 amount) external returns bool with (env e) =>
                    erc20_transferFrom_assumption(calledContract, e, from, to, amount);
    function _ghoToken.mint(address account, uint256 amount) external with (env e) =>
                    erc20_mint_assumption(calledContract, e, account, amount);
    function _ghoToken.transfer(address to, uint256 amount) external returns bool with (env e) =>
                    erc20_transfer_assumption(calledContract, e, to, amount);
    function getAvailableLiquidity() external returns (uint256) envfree;
    function getCurrentBacking() external returns(uint256, uint256) envfree;
    function erc20Helper.tokenBalanceOf(address token, address user) external returns (uint256) envfree;
    function erc20Helper.tokenTotalSupply(address token) external returns (uint256) envfree;
    // GSM.sol
    function _.UNDERLYING_ASSET() external  => DISPATCHER(true);

    // priceStrategy

    function _priceStrategy.getAssetPriceInGho(uint256, bool) external returns(uint256) envfree;
    function _priceStrategy.getUnderlyingAssetUnits() external returns(uint256) envfree;
    function _priceStrategy.PRICE_RATIO() external returns(uint256) envfree;

    // feeStrategy

    function _FixedFeeStrategy.getBuyFeeBP() external returns(uint256) envfree;
    function _FixedFeeStrategy.getSellFeeBP() external returns(uint256) envfree;
    function _FixedFeeStrategy.getBuyFee(uint256) external returns(uint256) envfree;
    function _FixedFeeStrategy.getSellFee(uint256) external returns(uint256) envfree;

    // GhoToken

    function _ghoToken.getFacilitatorBucket(address) external returns (uint256, uint256) envfree;
    function _ghoToken.balanceOf(address) external returns (uint256) envfree;

    // Harness
    function getGhoMinted() external returns(uint256) envfree;
    function getPriceRatio() external returns (uint256) envfree;
    function getAccruedFees() external returns (uint256) envfree;
}

definition harnessOnlyMethods(method f) returns bool =
        (f.selector == sig:getAccruedFees().selector ||
        f.selector == sig:getGhoMinted().selector ||
        f.selector == sig:getDearth().selector ||
        f.selector == sig:getPriceRatio().selector);

definition buySellAssetsFunctions(method f) returns bool =
        (f.selector == sig:buyAsset(uint256,address).selector ||
        f.selector == sig:buyAssetWithSig(address,uint256,address,uint256,bytes).selector ||
        f.selector == sig:sellAsset(uint256,address).selector ||
        f.selector == sig:sellAssetWithSig(address,uint256,address,uint256,bytes).selector);

function basicBuySellSetup( env e, address receiver){
    require receiver != currentContract;
    require e.msg.sender != currentContract;
    require UNDERLYING_ASSET(e) != _ghoToken;
}
function erc20_transferFrom_assumption(address token, env e, address from, address to, uint256 amount) returns bool {
        require erc20Helper.tokenBalanceOf(token, from) + erc20Helper.tokenBalanceOf(token, to) <= max_uint256;
		return _ghoToken.transferFrom(e, from, to, amount);
}

function erc20_mint_assumption(address token, env e, address account, uint256 amount) {
        require erc20Helper.tokenBalanceOf(token, account) + amount <= max_uint256;
		 _ghoToken.mint(e, account, amount);
}

function erc20_transfer_assumption(address token, env e, address to, uint256 amount) returns bool{
        require erc20Helper.tokenBalanceOf(token, to) + amount <= max_uint256;
		return _ghoToken.transfer(e, to, amount);
}