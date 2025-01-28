import "../GsmMethods/methods4626_base.spec";
import "../GsmMethods/methods_divint_summary.spec";
import "../GsmMethods/erc4626.spec";


// // @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse5(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 5;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought + 1) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }


// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse6(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 6;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }


// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse7(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 7;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }


// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse8(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 8;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }


// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse9(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 9;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }


// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse10(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 10;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }


// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse11(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 11;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }


// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse12(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 12;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }


// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse13(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 13;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }


// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse14(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 14;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }


// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse15(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 15;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }


// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c
// rule buySellInverse16(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 16;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }

// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c

// rule buySellInverse17(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 17;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +priceRatio/UAU) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }

// // STATUS: TIMEOUT
// // https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c

// rule buySellInverse18(){
//     uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
//     uint8 underlyingAssetDecimals = 18;
//     require to_mathint(UAU) == 10^underlyingAssetDecimals;

//     uint256 priceRatio = _priceStrategy.PRICE_RATIO();
//     require priceRatio == 10^18;
    
//     uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
//     uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
//     require buyFee == 0 && sellFee == 0;

//     uint256 assetsBuy;
//     address receiver1;
//     uint256 assetsBought;
//     uint256 ghoSold;
//     env e1;
//     assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

//     uint256 assetsSell;
//     address receiver2;
//     uint256 assetsSold;
//     uint256 ghoBought;
//     env e2;
//     assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

//     assert assetsBought == assetsSold => to_mathint(ghoBought +1) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
// }

// STATUS: PASS
// https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c   

rule buySellInverse19(){
    uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 19;
    require to_mathint(UAU) == 10^underlyingAssetDecimals;

    uint256 priceRatio = _priceStrategy.PRICE_RATIO();
    require priceRatio == 10^18;
    
    uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
    uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
    require buyFee == 0 && sellFee == 0;

    uint256 assetsBuy;
    address receiver1;
    uint256 assetsBought;
    uint256 ghoSold;
    env e1;
    assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

    uint256 assetsSell;
    address receiver2;
    uint256 assetsSold;
    uint256 ghoBought;
    env e2;
    assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

    assert assetsBought == assetsSold => to_mathint(ghoBought +1) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}

// STATUS: PASS
// https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c   

rule buySellInverse20(){
    uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 20;
    require to_mathint(UAU) == 10^underlyingAssetDecimals;

    uint256 priceRatio = _priceStrategy.PRICE_RATIO();
    require priceRatio == 10^18;
    
    uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
    uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
    require buyFee == 0 && sellFee == 0;

    uint256 assetsBuy;
    address receiver1;
    uint256 assetsBought;
    uint256 ghoSold;
    env e1;
    assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

    uint256 assetsSell;
    address receiver2;
    uint256 assetsSold;
    uint256 ghoBought;
    env e2;
    assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

    assert assetsBought == assetsSold => to_mathint(ghoBought +1) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// STATUS: PASS
// https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c   
rule buySellInverse21(){
    uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 21;
    require to_mathint(UAU) == 10^underlyingAssetDecimals;

    uint256 priceRatio = _priceStrategy.PRICE_RATIO();
    require priceRatio == 10^18;
    
    uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
    uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
    require buyFee == 0 && sellFee == 0;

    uint256 assetsBuy;
    address receiver1;
    uint256 assetsBought;
    uint256 ghoSold;
    env e1;
    assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

    uint256 assetsSell;
    address receiver2;
    uint256 assetsSold;
    uint256 ghoBought;
    env e2;
    assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

    assert assetsBought == assetsSold => to_mathint(ghoBought +1) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// STATUS: PASS
// https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c   
rule buySellInverse22(){
    uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 22;
    require to_mathint(UAU) == 10^underlyingAssetDecimals;

    uint256 priceRatio = _priceStrategy.PRICE_RATIO();
    require priceRatio == 10^18;
    
    uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
    uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
    require buyFee == 0 && sellFee == 0;

    uint256 assetsBuy;
    address receiver1;
    uint256 assetsBought;
    uint256 ghoSold;
    env e1;
    assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

    uint256 assetsSell;
    address receiver2;
    uint256 assetsSold;
    uint256 ghoBought;
    env e2;
    assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

    assert assetsBought == assetsSold => to_mathint(ghoBought +1) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// STATUS: PASS
// https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c   
rule buySellInverse23(){
    uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 23;
    require to_mathint(UAU) == 10^underlyingAssetDecimals;

    uint256 priceRatio = _priceStrategy.PRICE_RATIO();
    require priceRatio == 10^18;
    
    uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
    uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
    require buyFee == 0 && sellFee == 0;

    uint256 assetsBuy;
    address receiver1;
    uint256 assetsBought;
    uint256 ghoSold;
    env e1;
    assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

    uint256 assetsSell;
    address receiver2;
    uint256 assetsSold;
    uint256 ghoBought;
    env e2;
    assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

    assert assetsBought == assetsSold => to_mathint(ghoBought +1) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// STATUS: PASS
// https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c   
rule buySellInverse24(){
    uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 24;
    require to_mathint(UAU) == 10^underlyingAssetDecimals;

    uint256 priceRatio = _priceStrategy.PRICE_RATIO();
    require priceRatio == 10^18;
    
    uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
    uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
    require buyFee == 0 && sellFee == 0;

    uint256 assetsBuy;
    address receiver1;
    uint256 assetsBought;
    uint256 ghoSold;
    env e1;
    assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

    uint256 assetsSell;
    address receiver2;
    uint256 assetsSold;
    uint256 ghoBought;
    env e2;
    assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

    assert assetsBought == assetsSold => to_mathint(ghoBought +1) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// STATUS: PASS
// https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c   
rule buySellInverse25(){
    uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 25;
    require to_mathint(UAU) == 10^underlyingAssetDecimals;

    uint256 priceRatio = _priceStrategy.PRICE_RATIO();
    require priceRatio == 10^18;
    
    uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
    uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
    require buyFee == 0 && sellFee == 0;

    uint256 assetsBuy;
    address receiver1;
    uint256 assetsBought;
    uint256 ghoSold;
    env e1;
    assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

    uint256 assetsSell;
    address receiver2;
    uint256 assetsSold;
    uint256 ghoBought;
    env e2;
    assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

    assert assetsBought == assetsSold => to_mathint(ghoBought +1) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// STATUS: PASS
// https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c   
rule buySellInverse26(){
    uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 26;
    require to_mathint(UAU) == 10^underlyingAssetDecimals;

    uint256 priceRatio = _priceStrategy.PRICE_RATIO();
    require priceRatio == 10^18;
    
    uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
    uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
    require buyFee == 0 && sellFee == 0;

    uint256 assetsBuy;
    address receiver1;
    uint256 assetsBought;
    uint256 ghoSold;
    env e1;
    assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

    uint256 assetsSell;
    address receiver2;
    uint256 assetsSold;
    uint256 ghoBought;
    env e2;
    assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

    assert assetsBought == assetsSold => to_mathint(ghoBought +1) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// STATUS: PASS
// https://prover.certora.com/output/11775/8250b43937bb4c14a6468c51aa024e7a?anonymousKey=87764143874e8e012d1418e95780c6da3e7bf12c   
rule buySellInverse27(){
    uint256 UAU = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 27;
    require to_mathint(UAU) == 10^underlyingAssetDecimals;

    uint256 priceRatio = _priceStrategy.PRICE_RATIO();
    require priceRatio == 10^18;
    
    uint256 buyFee = _FixedFeeStrategy.getBuyFeeBP();
    uint256 sellFee = _FixedFeeStrategy.getSellFeeBP();
    require buyFee == 0 && sellFee == 0;

    uint256 assetsBuy;
    address receiver1;
    uint256 assetsBought;
    uint256 ghoSold;
    env e1;
    assetsBought, ghoSold = buyAsset(e1, assetsBuy, receiver1);

    uint256 assetsSell;
    address receiver2;
    uint256 assetsSold;
    uint256 ghoBought;
    env e2;
    assetsSold, ghoBought = sellAsset(e2, assetsSell, receiver2);

    assert assetsBought == assetsSold => to_mathint(ghoBought +1) >= to_mathint(ghoSold),"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


