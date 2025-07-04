# Camera Functionality Update - Edit Fabric Modal

## Enhancement Summary

### 🆕 **Camera Support Added**
The edit fabric modal now includes camera functionality matching the add fabric modal.

### **Changes Made**

#### 1. **Image Source Selection**
- Added bottom sheet modal to choose between Camera and Gallery
- Users can now tap on the image area to get options:
  - 📷 **Camera** - Take a new photo
  - 🖼️ **Gallery** - Select from existing photos

#### 2. **Improved User Experience**
- **Better Instructions**: Updated placeholder text to "Tap to take photo or select from gallery"
- **Consistent Behavior**: Now matches the add fabric modal functionality
- **Visual Feedback**: Clear icons and text for better user guidance

#### 3. **Technical Implementation**
- **Modal Bottom Sheet**: Clean interface for source selection
- **Image Quality**: Maintains 80% quality and 800x800 max dimensions
- **Platform Support**: Works on both web and mobile platforms
- **Error Handling**: Proper error messages for failed image operations

### **User Flow**
1. User taps on image area
2. Bottom sheet appears with two options:
   - Camera (with camera icon)
   - Gallery (with gallery icon)
3. User selects preferred option
4. Image picker opens with selected source
5. Image is processed and displayed

### **Benefits**
- ✅ **Consistency** with add fabric modal
- ✅ **Better UX** with clear options
- ✅ **Flexibility** for users to choose image source
- ✅ **Mobile-friendly** camera integration
- ✅ **Professional appearance** with proper UI elements

### **Technical Notes**
- Uses `showModalBottomSheet` for source selection
- Maintains existing upload logic (base64/Firebase Storage)
- Preserves all existing functionality
- No breaking changes to existing code
