# Market swap

## Create order

```shell
ExchangeRouter.multicall
├ ExchangeRouter.sendWnt
├ ExchangeRouter.sendTokens //order vaulet tarifa ejecucion
└ ExchangeRouter.createOrder
   └ OrderHandler.createOrder
      └ OrderUtils.createOrder
         ├ OrderVault.recordTransferIn
         ├ OrderVault.recordTransferIn
         └ OrderStoreUtils.set
```

## Execute order

```shell
OrderHandler.executeOrder
├ OracleModule.withOraclePrices
│  └ Oracle.setPrices
├ OrderStoreUtils.get
├ _executeOrder
│  └ ExecuteOrderUtils.executeOrder
│     ├ OrderStoreUtils.remove
│     ├ MarketUtils.getMarketPrices
│     ├ MarketUtils.distributePositionImpactPool
│     ├ PositionUtils.updateFundingAndBorrowingState
│     ├ processOrder
│     │  └ SwapOrderUtils.processOrder
│     │     └ SwapUtils.swap
│     │        ├ OrderVault.transferOut
│     │        └ for loop for each market in swap path
│     │           └ _swap
│     │              ├ Oracle.getPrimaryPrice
│     │              ├ Oracle.getPrimaryPrice
│     │              ├ SwapPricingUtils.getPriceImpactUsd
│     │              ├ SwapPricingUtils.getSwapFees
│     │              ├ MarketToken.transferOut
│     │              ├ MarketUtils.applyDeltaToPoolAmount
│     │              │  └ applyDeltaToVirtualInventoryForSwaps
│     │              └ MarketUtils.applyDeltaToPoolAmount
│     │                 └ applyDeltaToVirtualInventoryForSwaps
│     └ GasUtils.payExecutionFee
└ OracleModule.withOraclePrices
   └ Oracle.clearAllPrices
```
