import 'package:flutter/material.dart';
import 'package:fashion_tech/backend/sell_be.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellModal extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<Map<String, dynamic>> variants;
  const SellModal({Key? key, required this.product, required this.variants}) : super(key: key);

  @override
  State<SellModal> createState() => _SellModalState();
}

class _SellModalState extends State<SellModal> {
  Map<String, dynamic>? _selectedVariant;
  bool _sellAll = false;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.variants.isNotEmpty ? widget.variants.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final double basePrice = (widget.product['price'] ?? 0).toDouble();
    final int stock = _selectedVariant?['quantityInStock'] ?? 0;
    final int maxQty = stock;
    final int quantity = _sellAll ? stock : _quantity;
    final double price = basePrice;
    final double totalPrice = price * quantity;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sell "${widget.product['name'] ?? ''}"',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Variant + Price Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedVariant,
                  items: widget.variants.map((variant) {
                    final label = '${variant['size'] ?? ''} - ${variant['color'] ?? ''} (${variant['quantityInStock'] ?? 0} in stock)';
                    return DropdownMenuItem(
                      value: variant,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (variant) {
                    setState(() {
                      _selectedVariant = variant;
                      _sellAll = false;
                      _quantity = 1;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Variant',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  '₱${basePrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quantity controls
          Row(
            children: [
              const Text('Quantity:', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: !_sellAll && quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
              ),
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(
                  quantity.toString(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: !_sellAll && quantity < maxQty
                    ? () => setState(() => _quantity++)
                    : null,
              ),
              const SizedBox(width: 12),
              Checkbox(
                value: _sellAll,
                onChanged: (val) {
                  setState(() {
                    _sellAll = val ?? false;
                    if (_sellAll) {
                      _quantity = stock;
                    } else if (_quantity == 0) {
                      _quantity = 1;
                    }
                  });
                },
              ),
              const Text('Sell all'),
              const Spacer(),
              Text('/ $stock in stock', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Base Price:', style: TextStyle(color: Colors.grey[700])),
              Text('₱${basePrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Price:', style: TextStyle(fontSize: 16)),
              Text(
                '₱${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Confirm Sell'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final variantId = _selectedVariant?['variantID'];
                final productId = widget.product['productID'];
                final userId = FirebaseAuth.instance.currentUser?.uid;

                if (variantId == null || productId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product or variant is missing.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                if (quantity <= 0 || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter valid price and quantity'), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  await SellBackend.sellProductVariant(
                    productId: productId,
                    variantId: variantId,
                    quantity: quantity,
                    pricePerItem: price,
                    userId: userId,
                  );
                  Navigator.of(context).pop({
                    'price': price,
                    'quantity': quantity,
                    'sellAll': _sellAll,
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sell failed: $e'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}