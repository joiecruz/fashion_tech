# ERDv8 Updates - Job Orders and Job Order Details

## Updated Entity: JobOrders

### Required Fields:
- `name` (String) - **NEW REQUIRED FIELD** - Name/title of the job order
- `productID` (String) - Reference to Products collection
- `quantity` (Integer) - Total quantity for this job order
- `customerName` (String) - Customer name
- `status` (String) - Job status (Open, In Progress, Done)
- `dueDate` (Timestamp) - Due date for completion
- `createdBy` (String) - User ID who created the order

### Optional Fields:
- `assignedTo` (String) - Who the job is assigned to
- `specialInstructions` (String) - Special instructions/notes
- `orderDate` (Timestamp) - When the order was placed
- `createdAt` (Timestamp) - Auto-generated creation timestamp
- `updatedAt` (Timestamp) - Auto-generated update timestamp

## Updated Entity: JobOrderDetails

### Required Fields:
- `jobOrderID` (String) - Reference to JobOrders collection
- `fabricID` (String) - Reference to Fabrics collection
- `yardageUsed` (Double) - Amount of fabric used in yards
- `size` (String) - **UPDATED: NOW REQUIRED** - Size of the product variant
- `quantity` (Integer) - **NEW REQUIRED FIELD** - Quantity of this specific variant

### Auto-Populated Fields:
- `color` (String) - **UPDATED: AUTO-POPULATED** - Color(s) derived from fabrics used

### System Fields:
- `createdAt` (Timestamp) - Auto-generated creation timestamp
- `updatedAt` (Timestamp) - Auto-generated update timestamp

## Key Business Logic:

### JobOrderDetails → ProductVariants Conversion:
- When a JobOrder status is changed to "Done", the system should:
  1. Create ProductVariant records from JobOrderDetails
  2. Set ProductVariant.quantityInStock = JobOrderDetails.quantity
  3. Copy size, color, and fabric relationships
  4. Update the associated Product.isMade = true

### Color Field Logic:
- `color` field in JobOrderDetails is automatically populated by concatenating all fabric colors used in that variant
- Format: "Red, Blue, Green" (comma-separated list)
- This ensures color accuracy based on actual fabrics used

### Quantity Validation:
- Sum of all JobOrderDetails.quantity for a jobOrderID must equal JobOrders.quantity
- Each JobOrderDetails record represents one size/variant combination
- Multiple fabrics for the same variant create additional JobOrderDetails records with quantity = 0 for secondary fabrics

## Migration Notes:
1. **Existing JobOrders**: Add `name` field (copy from associated Product.name if available)
2. **Existing JobOrderDetails**: 
   - Add `quantity` field (distribute JobOrder.quantity across variants)
   - Make `size` field required (set default "One Size" for missing values)
   - Update `color` field with fabric-derived colors

## Database Indexes Recommended:
- JobOrders: `status`, `dueDate`, `createdBy`
- JobOrderDetails: `jobOrderID`, `fabricID`, `size`
