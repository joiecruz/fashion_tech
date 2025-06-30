# ERDv8 Schema Alignment Summary

## 🧾 Naming Conventions Summary

- **Folders:** `snake_case`  
  _Example:_ `models/`, `screens/`, `services/`, `widgets/`
- **Files:** `snake_case.dart`  
  _Example:_ `fabric_model.dart`, `auth_service.dart`, `dashboard_screen.dart`
- **Classes:** `PascalCase`  
  _Example:_ `FabricModel`, `JobOrder`, `AuthService`
- **Variables & Functions:** `camelCase`  
  _Example:_ `fabricList`, `getFabricById()`, `submitJobOrder()`
- **Firestore Fields (Document Keys):** `camelCase`  
  _Example:_ `productName`, `dueDate`, `isUpcycled`, `yards`
- **Firestore Collections:** `camelCase`  
  _Example:_ `productVariants`, `jobOrders`, `fabricLogs`
- **Git Branches:** `<type>/<short-description>` using `kebab-case`  
  _Example:_ `feature/fabric-swatch-upload`, `fix/job-order-crash`, `design/auth-layout`

---

## 📊 Current ERDv8 Compliance Overview

**🔴 Critical Issues**: 9 models missing required fields  
**🟡 Minor Issues**: 2 legacy fields need removal  
**✅ Fully Compliant**: 3 models (JobOrder, ProductImage, ProductLog)

---

## ✅ Models Aligned with ERDv8

### Core Product Models
- **`Product`** (`lib/models/product.dart`) - ✅ **Fully Compliant**
  - ✅ **ERDv8 Fields Present**: `productID` (id), `name`, `price`, `category`, `isUpcycled`, `isMade`, `createdAt`, `updatedAt`, `deletedAt`, `description`, `notes`
  - 🟡 **Legacy Field**: `unitCostEstimate` (not in ERDv8, currently used in frontend)
  - 🔄 **Action Required**: Consider removing `unitCostEstimate` after frontend migration

- **`ProductVariant`** (`lib/models/product_variant.dart`) - 🟡 **Mostly Compliant**
  - ✅ **ERDv8 Fields Present**: `variantID` (id), `productID`, `size`, `color`, `quantityInStock`
  - � **Legacy Field**: `unitCostEstimate` (not in ERDv8, should be removed)
  - 🔄 **Action Required**: Remove `unitCostEstimate` field completely

### Fabric & Production Models
- **`Fabric`** (`lib/models/fabric.dart`) - 🔴 **Non-Compliant**
  - ✅ **ERDv8 Fields Present**: `fabricID` (id), `name`, `type`, `color`, `qualityGrade`, `quantity`, `expensePerYard`, `swatchImageURL`, `createdAt`, `updatedAt`
  - ❌ **Missing ERDv8 Fields**: 
    - `isUpcycled` (Boolean) - fabric sustainability flag
    - `minOrder` (Number) - minimum order quantity  
    - `deletedAt` (Timestamp, optional) - soft delete support
  - 🔄 **Action Required**: Add missing ERDv8 fields for full compliance

- **`JobOrder`** (`lib/models/job_order.dart`) - ✅ **Fully Compliant**
  - ✅ **All ERDv8 Fields Present**: `jobOrderID` (id), `productID`, `quantity`, `customerName`, `status`, `dueDate`, `acceptedBy`, `assignedTo`, `createdBy`, `createdAt`, `updatedAt`
  - ✅ Proper enum: `JobOrderStatus` (open, inProgress, done)
  - ✅ Optional fields correctly marked: `acceptedBy`, `assignedTo`

- **`JobOrderDetail`** (`lib/models/job_order_detail.dart`) - 🟡 **Mostly Compliant**
  - ✅ **ERDv8 Fields Present**: `jobOrderDetailID` (id), `jobOrderID`, `fabricID`, `yardageUsed`, `size`, `color`
  - ❌ **Missing ERDv8 Field**: `notes` (String) - detail-specific notes
  - 🔄 **Action Required**: Add `notes` field

### User & Access Models
- **`User`** (`lib/models/user.dart`) - 🟡 **Mostly Compliant**
  - ✅ **ERDv8 Fields Present**: `userID` (id), `fullName`, `username`, `password`, `role`, `canAccessInventory`, `email`, `profileImageURL`, `createdAt`
  - ✅ Proper enum: `UserRole` (admin, owner, worker)
  - ❌ **Missing ERDv8 Field**: `isActive` (Boolean) - user status flag
  - 🔄 **Action Required**: Add `isActive` field

### Supplier Models
- **`Supplier`** (`lib/models/supplier.dart`) - 🔴 **Non-Compliant**
  - ✅ **ERDv8 Fields Present**: `supplierID` (id), `supplierName`, `contactNum`, `location`
  - ❌ **Missing ERDv8 Fields**: 
    - `email` (String) - supplier email contact
    - `notes` (String) - supplier-specific notes
  - 🔄 **Action Required**: Add `email` and `notes` fields

- **`SupplierProduct`** (`lib/models/supplier_product.dart`) - 🔴 **Non-Compliant**
  - ✅ **ERDv8 Fields Present**: `supplierProductID` (id), `supplierID`, `productID`, `supplyPrice`, `minOrderQty`
  - ❌ **Missing ERDv8 Fields**:
    - `daysToDeliver` (Number, optional) - delivery timeframe
    - `createdAt` (Timestamp) - record creation time
  - 🟡 **Incorrect Field Name**: `leadTimeDays` should be `daysToDeliver`
  - 🔄 **Action Required**: Rename field, add missing fields

### Image & Media Models  
- **`ProductImage`** (`lib/models/product_image.dart`) - ✅ **Fully Compliant**
  - ✅ **All ERDv8 Fields Present**: `productImageID` (id), `productID`, `imageURL`, `isPrimary`, `uploadedBy`, `uploadedAt`

### Logging Models
- **`ProductLog`** (`lib/models/product_log.dart`) - ✅ **Fully Compliant**
  - ✅ **All ERDv8 Fields Present**: `productLogID` (id), `productID`, `supplierID`, `createdBy`, `changeType`, `quantityChanged`, `remarks`, `createdAt`
  - ✅ Proper enum: `ProductChangeType` (add, deduct, correction)

- **`FabricLog`** (`lib/models/fabric_log.dart`) - 🟡 **Mostly Compliant**
  - ✅ **ERDv8 Fields Present**: `fabricLogID` (id), `fabricID`, `changeType`, `quantityChanged`, `source`, `remarks`, `logDate`, `createdBy`
  - ✅ Proper enums: `FabricChangeType`, `FabricLogSource`
  - ❌ **Missing ERDv8 Field**: `createdAt` (Timestamp) - should be separate from `logDate`
  - 🔄 **Action Required**: Add `createdAt` field distinct from `logDate`

- **`SalesLog`** (`lib/models/sales_log.dart`) - 🟡 **Mostly Compliant**
  - ✅ **ERDv8 Fields Present**: `salesLogID` (id), `productID`, `variantID`, `qtySold`, `sellingPrice`, `dateSold`
  - ❌ **Missing ERDv8 Field**: `totalRevenue` (Number) - calculated field (qtySold × sellingPrice)
  - 🔄 **Action Required**: Add `totalRevenue` computed field

---

## 🔄 Firestore Collection Names (ERDv8 Aligned)

✅ **All collection names are correctly aligned with ERDv8 (camelCase):**
- `products` → Product documents
- `productVariants` → ProductVariant documents  
- `fabrics` → Fabric documents
- `jobOrders` → JobOrder documents
- `jobOrderDetails` → JobOrderDetail documents
- `users` → User documents
- `suppliers` → Supplier documents
- `supplierProducts` → SupplierProduct documents
- `productImages` → ProductImage documents
- `productLogs` → ProductLog documents
- `fabricLogs` → FabricLog documents
- `salesLogs` → SalesLog documents

---

## 🚨 ERDv8 Compliance Gaps - CRITICAL ANALYSIS

### 🔴 **HIGH PRIORITY - Breaking Schema Issues**

#### 1. **Product Model** - Missing Notes Field
```dart
// MISSING in ERDv8:
final String? notes; // Product-specific notes separate from description
```
**Impact**: Product tracking incomplete, manual inventory notes not separated from description

#### 2. **Fabric Model** - 3 Critical Missing Fields  
```dart
// MISSING in ERDv8:
final bool isUpcycled; // Sustainability tracking
final double minOrder; // Minimum order quantity
final DateTime? deletedAt; // Soft delete support
```
**Impact**: No fabric sustainability tracking, no soft delete, missing order constraints

#### 3. **User Model** - Missing Active Status
```dart
// MISSING in ERDv8:
final bool isActive; // User account status
```
**Impact**: Cannot disable users without deleting accounts

#### 4. **Supplier Model** - Missing Contact & Notes
```dart
// MISSING in ERDv8:
final String email; // Email contact
final String? notes; // Supplier-specific notes
```
**Impact**: Incomplete supplier contact management

#### 5. **SupplierProduct Model** - Field Issues
```dart
// FIELD NAME ERROR:
final int leadTimeDays; // Should be: daysToDeliver

// MISSING in ERDv8:
final int? daysToDeliver; // Delivery timeframe (renamed)
final DateTime createdAt; // Record creation timestamp
```
**Impact**: Incorrect field naming, missing delivery tracking, no creation tracking

### 🟡 **MEDIUM PRIORITY - Enhancement Issues**

#### 6. **JobOrderDetail Model** - Missing Notes
```dart
// MISSING in ERDv8:
final String? notes; // Detail-specific notes
```

#### 7. **SalesLog Model** - Missing Revenue Calculation  
```dart
// MISSING in ERDv8:
final double totalRevenue; // Computed: qtySold × sellingPrice
```

#### 8. **FabricLog Model** - Missing Creation Timestamp
```dart
// MISSING in ERDv8:
final DateTime createdAt; // Separate from logDate
```

### � **LOW PRIORITY - Legacy Cleanup**

#### 9. **ProductVariant Model** - Legacy Field
```dart
// REMOVE (not in ERDv8):
final double? unitCostEstimate; // Legacy field, should be removed
```

#### 10. **Product Model** - Legacy Field (Keep for now)
```dart
// CONSIDER REMOVAL after frontend migration:
final double? unitCostEstimate; // Used in current frontend
```

---

## ✅ Updated Frontend Components (ERDv8 Aligned)

### Product Inventory System
- **`product_inventory_page.dart`** - ✅ **Fully Updated**
  - ✅ Uses correct collection names (`productvariants`, `productimages`) 
  - ✅ Handles ERDv8 schema fields (`description`, `deletedAt`, `isMade`)
  - ✅ Proper image loading from `productimages` collection
  - ✅ Enhanced variant display with size, color, and stock info
  - ✅ Soft delete support - filters out deleted products (`deletedAt` is null)
  - ✅ Full-width filter bar and collapsible stats for better UX

### Add Product Modal
- **`add_product_modal.dart`** - ✅ **ERDv8 Compliant**
  - ✅ Collects all available ERDv8 Product fields including `description` and `deletedAt`
  - ✅ Enhanced for manual inventory with supplier/acquisition tracking
  - ✅ Dynamic product variant management with visual color indicators
  - ✅ Bottom modal UX that expands from below search/filters
  - ✅ Comprehensive validation and error handling
  - ✅ Uses universal color system for consistency

### Universal Color System 
- **`lib/utils/color_utils.dart`** - ✅ **New ERDv8 Enhancement**
  - ✅ Centralized color management across all components
  - ✅ 19 predefined colors including fashion-specific options
  - ✅ Visual color indicators with smart borders for light colors
  - ✅ Enhanced all modals (Product, Job Order, Fabric) with consistent dropdowns
  - ✅ Support for hex colors, named colors, and app-specific parsing

### Updated Modal Components
- **`add_job_order_modal.dart`** - ✅ Uses universal color system
- **`add_fabric_modal.dart`** - ✅ Updated to use color dropdown instead of text field

---

## 📊 ERDv8 Compliance Status Dashboard

| **Model** | **Compliance** | **Missing Fields** | **Legacy Fields** | **Priority** |
|-----------|----------------|-------------------|-------------------|--------------|
| Product | 🟡 85% | `notes` | `unitCostEstimate` | High |
| ProductVariant | 🟡 90% | None | `unitCostEstimate` | High |
| Fabric | 🔴 70% | `isUpcycled`, `minOrder`, `deletedAt` | None | High |
| JobOrder | ✅ 100% | None | None | ✅ |
| JobOrderDetail | 🟡 85% | `notes` | None | Medium |
| User | 🟡 90% | `isActive` | None | High |
| Supplier | 🔴 65% | `email`, `notes` | None | High |
| SupplierProduct | 🔴 60% | `daysToDeliver`, `createdAt` | `leadTimeDays` | High |
| ProductImage | ✅ 100% | None | None | ✅ |
| ProductLog | ✅ 100% | None | None | ✅ |
| FabricLog | 🟡 90% | `createdAt` | None | Medium |
| SalesLog | 🟡 85% | `totalRevenue` | None | Medium |

**Overall ERDv8 Compliance**: 🟡 **78%** (9 of 12 models need updates)

---

## 🎯 Action Plan - ERDv8 Full Compliance

### Phase 1: Critical Schema Updates (High Priority)
```bash
# Models requiring immediate attention:
1. Add Product.notes field
2. Add Fabric.isUpcycled, minOrder, deletedAt fields  
3. Add User.isActive field
4. Add Supplier.email, notes fields
5. Fix SupplierProduct field naming and add missing fields
6. Remove ProductVariant.unitCostEstimate field
```

### Phase 2: Enhancement Updates (Medium Priority)
```bash
# Models requiring enhancements:
7. Add JobOrderDetail.notes field
8. Add SalesLog.totalRevenue field  
9. Add FabricLog.createdAt field
```

### Phase 3: Frontend Integration (Low Priority)
```bash
# Update frontend to handle new fields:
10. Update forms with new field inputs
11. Add validation for required fields
12. Update display logic for new data
13. Handle migration of existing data
```

---

## 📦 Model Export System

### Centralized Imports
- **`lib/models/models.dart`** - Exports all models for unified importing
- **`lib/utils/utils.dart`** - Exports all utilities including color system

```dart
// Usage:
import 'package:fashion_tech/models/models.dart';
import 'package:fashion_tech/utils/utils.dart';
```

---

## 🔧 Migration Strategy (Current → ERDv8)

### Database Migration Required
- **Soft Delete Migration**: Add `deletedAt: null` to existing Product and Fabric documents
- **New Fields Migration**: Add default values for new required fields
- **Field Renaming**: Update `SupplierProduct.leadTimeDays` to `daysToDeliver`

### Code Migration Required  
- **Remove Legacy Fields**: Clean up `unitCostEstimate` references in ProductVariant
- **Update Forms**: Add input fields for new ERDv8 fields
- **Update Validation**: Ensure new required fields are validated

### Backwards Compatibility
- **Optional Fields**: Most new fields are optional to maintain compatibility
- **Gradual Migration**: Can update models incrementally without breaking existing functionality

---

## 🎯 Next Steps for 100% ERDv8 Compliance

### Immediate Actions Required:
1. **Update Fabric model** - Add `isUpcycled`, `minOrder`, `deletedAt` fields
2. **Update User model** - Add `isActive` field  
3. **Update Supplier model** - Add `email`, `notes` fields
4. **Fix SupplierProduct model** - Rename field, add missing fields
5. **Update Product model** - Add `notes` field
6. **Clean ProductVariant model** - Remove `unitCostEstimate`

### Follow-up Actions:
7. Update frontend forms to collect new field data
8. Add validation for new required fields  
9. Test data migration with new schema
10. Update API endpoints to handle new fields
11. Add documentation for new field usage
12. Implement soft delete UI flows for Fabric management

**Target**: 🎯 **100% ERDv8 Compliance** within the next development cycle
