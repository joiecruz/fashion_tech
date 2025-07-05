# Job Order to Product Transformation - Data Field Mapping

## Overview
This document explains how data flows from Job Orders to Products when marking a job order as "Done", including the comprehensive field mappings and data transformations.

## Data Flow Architecture

### 1. Job Order Collection Structure
```
jobOrders/{jobOrderID}
├── id: string (document ID)
├── name: string (job order name)
├── productID: string (template product reference)
├── linkedProductID: string (target product for stock addition)
├── customerID: string (customer reference)
├── customerName: string (customer name)
├── quantity: number (total quantity ordered)
├── status: string ('Open', 'In Progress', 'Done')
├── dueDate: Timestamp
├── assignedTo: string (user ID)
├── createdBy: string (user ID)
├── createdAt: Timestamp
└── updatedAt: Timestamp
```

### 2. Job Order Details Collection Structure
```
jobOrderDetails/{detailID}
├── id: string (document ID)
├── jobOrderID: string (parent job order reference)
├── fabricID: string (fabric reference)
├── yardageUsed: number (fabric consumed)
├── size: string (product size)
├── color: string (product color)
└── notes: string (optional notes)
```

### 3. Product Collection Structure
```
products/{productID}
├── id: string (document ID)
├── name: string (product name)
├── notes: string (product description)
├── price: number (product price)
├── categoryID: string (product category)
├── isUpcycled: boolean (sustainability flag)
├── isMade: boolean (manufacturing status)
├── createdBy: string (user ID)
├── createdAt: Timestamp
├── updatedAt: Timestamp
├── deletedAt: Timestamp (soft delete)
└── sourceJobOrderID: string (origin job order)
```

### 4. Product Variants Collection Structure
```
productVariants/{variantID}
├── id: string (document ID)
├── productID: string (parent product reference)
├── size: string (variant size)
├── colorID: string (color reference)
├── quantityInStock: number (available stock)
├── createdAt: Timestamp
├── updatedAt: Timestamp
├── sourceJobOrderID: string (origin job order)
└── sourceJobOrderDetailID: string (origin detail)
```

## Data Transformation Process

### Phase 1: Confirmation & Data Gathering
```dart
// 1. User confirms marking job order as done
// 2. Fetch job order data from jobOrders collection
// 3. Fetch all jobOrderDetails for the job order
// 4. Determine if job order has linkedProductID
```

### Phase 2: Product Action Selection
The system presents three options based on the job order's linkedProductID:

#### Option A: Add to Linked Product (if linkedProductID exists)
```dart
// Uses existing linkedProductID
// Creates new ProductVariant records
// Maps jobOrderDetails → ProductVariants
```

#### Option B: Create New Product
```dart
// Creates new Product record
// Creates new ProductVariant records
// Maps jobOrder → Product
// Maps jobOrderDetails → ProductVariants
```

#### Option C: Select Existing Product
```dart
// User selects existing product
// Creates new ProductVariant records
// Maps jobOrderDetails → ProductVariants
```

### Phase 3: Data Mapping

#### Job Order → Product Mapping
```dart
// Source: jobOrders/{jobOrderID}
// Target: products/{productID}

Product Fields:
├── name: jobOrder.name
├── notes: "Created from job order: {jobOrder.name}"
├── price: originalProduct.price || 0.0
├── categoryID: originalProduct.categoryID || 'custom'
├── isUpcycled: originalProduct.isUpcycled || false
├── isMade: true (always true for completed job orders)
├── createdBy: jobOrder.createdBy
├── createdAt: Timestamp.now()
├── updatedAt: Timestamp.now()
├── deletedAt: null
└── sourceJobOrderID: jobOrder.id
```

#### Job Order Details → Product Variants Mapping
```dart
// Source: jobOrderDetails/{detailID}
// Target: productVariants/{variantID}

For Each JobOrderDetail:
ProductVariant Fields:
├── productID: targetProduct.id
├── size: jobOrderDetail.size
├── colorID: jobOrderDetail.color (converted to colorID in production)
├── quantityInStock: 1 (each detail represents 1 piece)
├── createdAt: Timestamp.now()
├── updatedAt: Timestamp.now()
├── sourceJobOrderID: jobOrderDetail.jobOrderID
└── sourceJobOrderDetailID: jobOrderDetail.id
```

## Implementation Details

### Data Sources and Fields Retrieved

#### From Job Order Document:
```dart
final jobOrderData = {
  'id': jobOrderID,
  'name': data['name'],
  'productID': data['productID'],
  'linkedProductID': data['linkedProductID'],
  'customerID': data['customerID'],
  'customerName': data['customerName'],
  'quantity': data['quantity'],
  'status': data['status'],
  'dueDate': data['dueDate'],
  'assignedTo': data['assignedTo'],
  'createdBy': data['createdBy'],
  'createdAt': data['createdAt'],
  'updatedAt': data['updatedAt'],
};
```

#### From Job Order Details Documents:
```dart
final jobOrderDetails = jobOrderDetailsSnap.docs.map((doc) {
  final data = doc.data() as Map<String, dynamic>;
  return {
    'id': doc.id,
    'jobOrderID': data['jobOrderID'],
    'fabricID': data['fabricID'],
    'yardageUsed': data['yardageUsed'],
    'size': data['size'],
    'color': data['color'],
    'notes': data['notes'],
  };
}).toList();
```

#### From Original Product Template (if exists):
```dart
final originalProductInfo = productData[jobOrderData['productID']] ?? {
  'name': 'Unknown Product',
  'price': 0.0,
  'category': 'custom',
  'isUpcycled': false,
  'imageURL': '',
};
```

### Transaction Creation
```dart
// Expense tracking for completed job order
final transactionData = {
  'jobOrderID': jobOrderID,
  'amount': originalProductInfo['price'] ?? 0.0,
  'type': 'expense',
  'date': Timestamp.now(),
  'description': 'Expense for job order "${jobOrderName}"',
  'createdAt': Timestamp.now(),
  'createdBy': jobOrderData['assignedTo'] ?? jobOrderData['createdBy'],
};
```

## Error Handling & Validation

### Pre-processing Validation
```dart
// Check for required fields
if (jobOrderData['name'] == null || jobOrderData['name'].isEmpty) {
  throw Exception('Job order name is required');
}

// Note: jobOrderDetails are guaranteed to exist since job orders 
// cannot be created without at least one variant (ERDv8 requirement)

// Validate each detail
for (final detail in jobOrderDetails) {
  if (detail['size'] == null || detail['size'].isEmpty) {
    throw Exception('Size is required for all variants');
  }
  if (detail['yardageUsed'] == null || detail['yardageUsed'] <= 0) {
    throw Exception('Yardage used must be greater than 0');
  }
}
```

### Post-processing Verification
```dart
// Verify product creation
final createdProduct = await FirebaseFirestore.instance
    .collection('products')
    .doc(productID)
    .get();

if (!createdProduct.exists) {
  throw Exception('Failed to create product');
}

// Verify variant creation
final createdVariants = await FirebaseFirestore.instance
    .collection('productVariants')
    .where('productID', isEqualTo: productID)
    .where('sourceJobOrderID', isEqualTo: jobOrderID)
    .get();

if (createdVariants.docs.length != jobOrderDetails.length) {
  throw Exception('Failed to create all product variants');
}
```

## User Interface Flow

### 1. Initial Confirmation
- User clicks "Mark as Done" button
- System shows confirmation dialog
- User confirms action

### 2. Product Handling Selection
- System analyzes job order data
- Shows appropriate options based on linkedProductID presence
- User selects desired action

### 3. Product Selection (if needed)
- For "Select Existing Product" option
- System fetches and displays available products
- User selects target product

### 4. Processing & Feedback
- System processes data transformation
- Shows progress indicator
- Displays success/error message

## Database Operations Summary

### Collections Modified:
1. **jobOrders** - Status updated to 'Done'
2. **transactions** - New expense record created
3. **products** - New product created (if applicable)
4. **productVariants** - New variant records created

### Atomic Operations:
- All operations are wrapped in try-catch blocks
- Firestore batch writes ensure consistency
- Rollback mechanisms prevent partial updates

## Field Mapping Reference

| Source Collection | Source Field | Target Collection | Target Field | Transformation |
|-------------------|--------------|-------------------|--------------|----------------|
| jobOrders | name | products | name | Direct copy |
| jobOrders | createdBy | products | createdBy | Direct copy |
| jobOrders | id | products | sourceJobOrderID | Direct copy |
| jobOrders | productID | N/A | N/A | Used for template lookup |
| jobOrderDetails | size | productVariants | size | Direct copy |
| jobOrderDetails | color | productVariants | colorID | Direct copy* |
| jobOrderDetails | jobOrderID | productVariants | sourceJobOrderID | Direct copy |
| jobOrderDetails | id | productVariants | sourceJobOrderDetailID | Direct copy |
| N/A | 1 | productVariants | quantityInStock | Fixed value |
| N/A | Timestamp.now() | All | createdAt/updatedAt | Generated |

*Note: In production, color strings should be converted to colorID foreign keys.

## Security Considerations

### User Permissions
- Only assigned users or admins can mark job orders as done
- Product creation requires appropriate permissions
- All operations are logged with user attribution

### Data Integrity
- Foreign key relationships maintained
- Soft delete used for products (deletedAt field)
- Audit trail through sourceJobOrderID fields

## Performance Optimization

### Batch Operations
- ProductVariant creation uses Firestore batch writes
- Multiple database operations combined where possible
- Minimal network round trips

### Data Caching
- Product template data cached in memory
- User information cached to avoid repeated lookups
- Efficient query patterns used
