import "../GsmMethods/methods_base.spec";
import "../GsmMethods/methods_divint_summary.spec";

// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/ae736e76b281420493006752c3f952f6/?anonymousKey=8b267ac5c59ebb69e767810cb01808f9182daf57
rule buySellInverse5(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 5;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}

// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse6(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 6;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse7(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 7;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse8(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 8;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse9(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 9;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse10(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 10;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse11(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 11;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse12(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 12;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse13(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 13;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse14(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 14;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse15(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 15;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse16(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 16;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse17(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 17;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse18(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 18;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse19(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 19;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse20(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 20;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse21(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 21;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse22(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 22;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse23(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 23;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse24(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 24;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse25(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 25;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse26(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 26;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


// @title Buy/sell invariants property #6: In case of using a 1:1 ratio and 0 fees, the inverse action of buyAsset must be sellAsset. (e.g. if buyAsset(x assets) needs y GHO, sellAsset(x assets) gives y GHO).
// STATUS: PASSED
// https://prover.certora.com/output/11775/a6e4d092b5c4424e883ab5810f92ce68/?anonymousKey=ca318da3a72834395fdd1198c23cd189d9d6c988
rule buySellInverse27(){
    uint256 _underlyingAssetUnits = _priceStrategy.getUnderlyingAssetUnits(); 
    uint8 underlyingAssetDecimals = 27;
    require to_mathint(_underlyingAssetUnits) == 10^underlyingAssetDecimals;

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

    assert assetsBought == assetsSold => ghoBought == ghoSold,"buying and selling should be inverse in case of 1:1 price ratio and 0 fees";
}


