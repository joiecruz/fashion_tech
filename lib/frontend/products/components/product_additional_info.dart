import 'package:flutter/material.dart';

class ProductAdditionalInfo extends StatelessWidget {
  final TextEditingController notesController;
  final FocusNode notesFocus;
  final DateTime? acquisitionDate;
  final Function(DateTime?) onDateChanged;

  const ProductAdditionalInfo({
    super.key,
    required this.notesController,
    required this.notesFocus,
    required this.acquisitionDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Acquisition Date
        Card(
          elevation: 0,
          color: Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acquisition Date',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: acquisitionDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(primary: Colors.blue[600]!),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (selectedDate != null) {
                      onDateChanged(selectedDate);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        Text(
                          acquisitionDate != null
                              ? '${acquisitionDate!.day}/${acquisitionDate!.month}/${acquisitionDate!.year}'
                              : 'Select date',
                          style: TextStyle(
                            fontSize: 16,
                            color: acquisitionDate != null ? Colors.black87 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Additional Notes
        Card(
          elevation: 0,
          color: Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Additional Notes - Optional',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: notesController,
                  focusNode: notesFocus,
                  textInputAction: TextInputAction.done,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Any additional notes, purchase details, condition, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue[600]!),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
