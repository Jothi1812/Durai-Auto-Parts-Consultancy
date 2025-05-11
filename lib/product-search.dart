import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Import from your main.dart
// This is a separate component for product search

class ProductSearchDialog extends StatefulWidget {
  final List<Product> products;
  final Function(Product, int) onProductSelected;

  const ProductSearchDialog({
    Key? key,
    required this.products,
    required this.onProductSelected,
  }) : super(key: key);

  @override
  _ProductSearchDialogState createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  late List<Product> filteredProducts;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  Product? selectedProduct;
  int quantity = 1;

  @override
  void initState() {
    super.initState();
    filteredProducts = widget.products;
    _quantityController.text = quantity.toString();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProducts = widget.products;
      } else {
        filteredProducts = widget.products
            .where((product) =>
                product.name.toLowerCase().contains(query.toLowerCase()) ||
                product.description.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Product'),
      content: Container(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Products',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _filterProducts,
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text(
                      '${product.description}\nPrice: \$${product.price.toStringAsFixed(2)} • Stock: ${product.stock}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      setState(() {
                        selectedProduct = product;
                      });
                    },
                    selected: selectedProduct?.id == product.id,
                    selectedTileColor: Colors.blue.withOpacity(0.1),
                  );
                },
              ),
            ),
            if (selectedProduct != null) ...[
              SizedBox(height: 16),
              Text(
                'Selected: ${selectedProduct!.name}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    quantity = int.tryParse(value) ?? 1;
                  });
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        if (selectedProduct != null)
          ElevatedButton(
            onPressed: () {
              if (quantity > 0 && quantity <= selectedProduct!.stock) {
                widget.onProductSelected(selectedProduct!, quantity);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Invalid quantity. Must be between 1 and ${selectedProduct!.stock}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Add to Invoice'),
          ),
      ],
    );
  }
}
