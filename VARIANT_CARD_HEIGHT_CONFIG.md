# Variant Card Quantity Field Height Configuration

## Overview
This guide explains how to modify the height of the quantity input field in variant cards to match your design requirements.

## Quick Configuration

### Location
The quantity field height is configured in:
**File:** `lib/frontend/job_orders/widgets/variant_card.dart`

### Steps to Change Height

1. **Open the file** and search for "QUANTITY FIELD HEIGHT CONFIGURATION"
2. **Find the Container** with height property (around line 155):
   ```dart
   Container(
     height: 56, // <-- CHANGE THIS VALUE
     child: TextFormField(
   ```
3. **Modify the height value** to your desired size
4. **Adjust padding** if needed (see padding configuration below)

## Height Recommendations

| Height | Use Case | Padding Recommendation |
|--------|----------|----------------------|
| 48px   | Compact design | `vertical: 12` |
| 56px   | Standard (current) | `vertical: 16` |
| 64px   | Large/accessibility | `vertical: 20` |
| 72px   | Extra large | `vertical: 24` |

## Padding Configuration

When changing height significantly, also adjust the `contentPadding`:

**Location:** Search for "QUANTITY FIELD PADDING CONFIGURATION"
```dart
contentPadding: const EdgeInsets.symmetric(
  horizontal: 14, 
  vertical: 16  // <-- ADJUST THIS VALUE
),
```

### Padding Guidelines
- **Horizontal padding:** Keep at `14` for consistency
- **Vertical padding:** Adjust based on height:
  - Small height (48px): `vertical: 12`
  - Medium height (56px): `vertical: 16`
  - Large height (64px+): `vertical: 20-24`

## Size Dropdown Synchronization

The quantity field height is designed to match the size dropdown. If you want them to have different heights:

1. **Keep them matched:** Both fields should have the same height for visual consistency
2. **Different heights:** You can modify them independently, but consider the visual impact

## Example Configurations

### Compact Design (48px)
```dart
Container(
  height: 48,
  child: TextFormField(
    decoration: InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // ... other properties
    ),
  ),
),
```

### Large Design (64px)
```dart
Container(
  height: 64,
  child: TextFormField(
    decoration: InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      // ... other properties
    ),
  ),
),
```

### Extra Large (72px)
```dart
Container(
  height: 72,
  child: TextFormField(
    decoration: InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      // ... other properties
    ),
  ),
),
```

## Testing Your Changes

After modifying the height:

1. **Hot reload** the app to see changes
2. **Test on different screen sizes** (phone, tablet)
3. **Verify text visibility** and input comfort
4. **Check alignment** with the size dropdown
5. **Test accessibility** with larger text sizes

## Related Files

- **Main file:** `lib/frontend/job_orders/widgets/variant_card.dart`
- **Size utilities:** `lib/utils/size_utils.dart`
- **Color utilities:** `lib/utils/color_utils.dart`

## Troubleshooting

### Common Issues

1. **Text appears cut off:**
   - Increase vertical padding
   - Check if height is too small

2. **Field looks too spacious:**
   - Decrease vertical padding
   - Consider reducing height

3. **Misaligned with size dropdown:**
   - Ensure both fields have same height
   - Check if size dropdown has custom styling

### Best Practices

- **Keep consistency:** Both size and quantity fields should have matching heights
- **Consider accessibility:** Larger heights benefit users with motor impairments
- **Test thoroughly:** Always test on different devices and screen sizes
- **Document changes:** Note any modifications for team members

## Support

If you encounter issues or need custom configurations not covered here, refer to:
- Flutter TextFormField documentation
- Material Design input field specifications
- App's design system guidelines
