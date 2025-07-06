# ERD v9 Migration Summary

## Changes Made to Update from ERDv8 to ERDv9

### New Models Created:

1. **Customer** (`lib/models/customer.dart`)
   - `customerID` (PK)
   - `fullName`, `contactNum`, `address`, `email`, `notes`
   - `createdBy` (FK → USERS), `createdAt`

2. **Transaction** (`lib/models/transaction.dart`)
   - `transactionID` (PK)
   - `type` (Enum: 'income', 'expense')
   - `category`, `amount`, `description`, `date`
   - `createdBy` (FK → USERS), `createdAt`

3. **JobOrderLog** (`lib/models/job_order_log.dart`)
   - `jobOrderLogID` (PK)
   - `jobOrderID` (FK → JOBORDER)
   - `changeType` (Enum: 'statusUpdate', 'reassign', 'edit')
   - `previousValue`, `newValue`, `notes`
   - `changedBy` (FK → USERS), `timestamp`

4. **Category** (`lib/models/category.dart`)
   - `categoryID` (PK)
   - `name`, `createdBy` (FK → USERS), `createdAt`
   - `type` (Enum: 'product', 'fabric', 'expense')

5. **Color** (`lib/models/color.dart`)
   - `colorID` (PK)
   - `name`, `hexCode`, `createdBy` (FK → USERS)

### Models Updated:

1. **JobOrder** (`lib/models/job_order.dart`)
   - **Added:** `customerID` (FK → CUSTOMER)
   - **Added:** `linkedProductID` (nullable FK → PRODUCT)
   - **Added:** `name` (String)

2. **Fabric** (`lib/models/fabric.dart`)
   - **Changed:** `color` → `colorID` (FK → COLOR)
   - **Added:** `categoryID` (FK → CATEGORY)

3. **ProductVariant** (`lib/models/product_variant.dart`)
   - **Changed:** `color` → `colorID` (FK → COLOR)

4. **Product** (`lib/models/product.dart`)
   - **Changed:** `category` → `categoryID` (FK → CATEGORY)
   - **Removed:** `description` field (simplified)

5. **JobOrderDetail** (`lib/models/job_order_detail.dart`)
   - Already had `notes` field - no changes needed

### Export Updates:

- Updated `lib/models/models.dart` to export all new models
- Updated comments to reflect ERDv9 compliance

### Breaking Changes:

1. **Fabric Model:**
   - `color` field changed to `colorID` - requires data migration
   - Added `categoryID` field - requires default values for existing data

2. **ProductVariant Model:**
   - `color` field changed to `colorID` - requires data migration

3. **Product Model:**
   - `category` field changed to `categoryID` - requires data migration
   - Removed `description` field

4. **JobOrder Model:**
   - Added required `customerID` field - requires default values for existing data
   - Added required `name` field - requires default values for existing data

### Data Migration Required:

1. Create default Color records for existing color strings
2. Create default Category records for existing category strings
3. Create default Customer records for existing customerName values
4. Update all existing documents to use new ID-based references

### Backward Compatibility:

- Added fallback logic in `fromMap` methods to handle legacy data
- Example: `data['colorID'] ?? data['color'] ?? ''` in ProductVariant
- Example: `data['categoryID'] ?? data['category'] ?? ''` in Product

### Next Steps:

1. Create data migration scripts to convert existing data
2. Update UI components to work with new ID-based references
3. Create admin pages for managing Colors and Categories
4. Update business logic to use Customer records instead of plain strings
5. Implement Transaction tracking for income/expense management
6. Add JobOrderLog tracking for audit trails
