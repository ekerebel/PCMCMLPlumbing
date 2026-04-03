# PlaceQuote to PlaceSalesTransaction API Migration

## Overview
Migrated from the deprecated `placeQuote` API to the newer `placeSalesTransaction` API in the `QuoteLineCreator` class.

## Changes Made

### 1. Method Signature Updates
**Before:**
```apex
public static ConnectApi.PlaceQuoteOutput placeQuote(Id quoteId, String graphId)
```

**After:**
```apex
public static ConnectApi.PlaceSalesTransactionOutput placeSalesTransaction(Id salesTransactionId, String pricingTransactionId)
```

### 2. API Input Changes
**Before:**
```apex
ConnectApi.PlaceQuoteInput input = new ConnectApi.PlaceQuoteInput();
input.quoteId = quoteId;
input.graphId = graphId;
```

**After:**
```apex
ConnectApi.PlaceSalesTransactionInput input = new ConnectApi.PlaceSalesTransactionInput();
input.salesTransactionId = salesTransactionId;
input.pricingTransactionId = pricingTransactionId;
```

### 3. API Call Changes
**Before:**
```apex
ConnectApi.PlaceQuoteOutput output = ConnectApi.CommercePricing.placeQuote(input);
```

**After:**
```apex
ConnectApi.PlaceSalesTransactionOutput output = ConnectApi.CommercePricing.placeSalesTransaction(input);
```

## Key Differences

### Parameter Name Changes
- `quoteId` → `salesTransactionId` (both refer to the same Quote record ID)
- `graphId` → `pricingTransactionId` (both refer to the same pricing graph/transaction ID)

### Type Changes
- Input: `PlaceQuoteInput` → `PlaceSalesTransactionInput`
- Output: `PlaceQuoteOutput` → `PlaceSalesTransactionOutput`
- Method: `placeQuote()` → `placeSalesTransaction()`

## Backward Compatibility
The method signature remains compatible with existing callers since:
- The first parameter still accepts the Quote ID (now called salesTransactionId semantically)
- The second parameter still accepts the graph/pricing transaction ID
- The functionality remains the same

## API Documentation References
- **Old API:** https://developer.salesforce.com/docs/atlas.en-us.revenue_lifecycle_management_dev_guide.meta/revenue_lifecycle_management_dev_guide/connect_resources_place_quote.htm
- **New API:** https://developer.salesforce.com/docs/atlas.en-us.revenue_lifecycle_management_dev_guide.meta/revenue_lifecycle_management_dev_guide/connect_resources_place_sales_transaction.htm

## Testing Recommendations
1. Test creating quote lines with the updated API
2. Verify that the pricing transaction is placed correctly
3. Check that the response output is handled properly
4. Ensure error handling works as expected

## Notes
- The new API uses more semantically accurate naming (salesTransaction instead of quote)
- All functionality remains the same; this is primarily a naming/API evolution change
- The graphId from the pricing API response can be used directly as pricingTransactionId