// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:invoice_autoparts/theme/app_theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => InvoiceState(),
      child: const AutoShopApp(),
    ),
  );
}

class AutoShopApp extends StatelessWidget {
  const AutoShopApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Shop Invoice',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const InvoiceScreen(),
    );
  }
}

// Add Navigation Drawer
class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Auto Shop Manager',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt),
            title: const Text('Invoices'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const InvoiceScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('New Customer'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddCustomerScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_box),
            title: const Text('New Product'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddProductScreen()),
              );
            },
          ),
          // Update the AppDrawer class by adding this new list tile:
ListTile(
  leading: const Icon(Icons.inventory),
  title: const Text('Products List'),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductListScreen()),
    );
  },
),
        ],
      ),
    );
  }
}

// Add Customer Screen
class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({Key? key}) : super(key: key);

  @override
  _AddCustomerScreenState createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/customers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'address': _addressController.text,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer added successfully!')),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Failed to add customer');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Customer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter a name';
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter an email';
                  if (!value!.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter a phone number';
                  return null;
                },
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCustomer,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Add Customer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Add Product Screen
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({Key? key}) : super(key: key);

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/products'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': _nameController.text,
          'code': _codeController.text,
          'price': double.parse(_priceController.text),
          'stock': int.parse(_stockController.text),
          'category': _categoryController.text,
          'description': _descriptionController.text,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!')),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Failed to add product');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter a product name';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Product Code'),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter a product code';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter a price';
                    if (double.tryParse(value!) == null) return 'Please enter a valid price';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(labelText: 'Stock'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter stock quantity';
                    if (int.tryParse(value!) == null) return 'Please enter a valid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Add Product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// Update the InvoiceState class
class InvoiceState extends ChangeNotifier {
  List<Product> products = [];
  Customer? _customer;  // Make the customer field private and nullable
  List<InvoiceItem> items = [];
  double total = 0;
  
  // Add a getter for customer
  Customer? get customer => _customer;
  
  void addItem(Product product, int quantity) {
    final item = InvoiceItem(
      product: product,
      quantity: quantity,
      price: product.price,
    );
    items.add(item);
    calculateTotal();
    notifyListeners();
  }
  
  void removeItem(int index) {
    items.removeAt(index);
    calculateTotal();
    notifyListeners();
  }
  
  void calculateTotal() {
    total = items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }
  
  // Update setCustomer to accept nullable Customer
  void setCustomer(Customer? newCustomer) {
    _customer = newCustomer;
    notifyListeners();
  }
  
  void clear() {
    _customer = null;
    items.clear();
    total = 0;
    notifyListeners();
  }
}

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({Key? key}) : super(key: key);

  @override
  _InvoiceScreenState createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _customerSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice'),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Customer Search Section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Consumer<InvoiceState>(
                      builder: (context, state, child) {
                        if (state.customer != null) {
                          return CustomerInfoCard(customer: state.customer!);
                        }
                        return CustomerSearchField(
                          controller: _customerSearchController,
                          onCustomerSelected: (customer) {
                            context.read<InvoiceState>().setCustomer(customer);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Products Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Products',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ProductSearchField(
                        controller: _productSearchController,
                        onProductSelected: (product) {
                          _showQuantityDialog(context, product);
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Consumer<InvoiceState>(
                          builder: (context, state, child) {
                            return ListView.builder(
                              itemCount: state.items.length,
                              itemBuilder: (context, index) {
                                final item = state.items[index];
                                return InvoiceItemCard(
                                  item: item,
                                  onDelete: () {
                                    context.read<InvoiceState>().removeItem(index);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Total and Actions
          Consumer<InvoiceState>(
            builder: (context, state, child) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: \$${state.total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    ElevatedButton(
                      onPressed: state.customer != null && state.items.isNotEmpty
                          ? () => _generateInvoice(context)
                          : null,
                      child: const Text('Generate Invoice'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _showQuantityDialog(BuildContext context, Product product) async {
    final quantityController = TextEditingController(text: '1');
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Quantity - ${product.name}'),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0 && quantity <= product.stock) {
                context.read<InvoiceState>().addItem(product, quantity);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _generateInvoice(BuildContext context) async {
    final state = context.read<InvoiceState>();
    
    final invoice = {
      'customer': state.customer!.id,
      'items': state.items.map((item) => {
        'product': item.product.id,
        'quantity': item.quantity,
        'price': item.price,
        'subtotal': item.price * item.quantity,
      }).toList(),
      'totalAmount': state.total,
      'tax': state.total * 0.1,
      'grandTotal': state.total * 1.1,
    };
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/invoices'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(invoice),
      );
      
      if (response.statusCode == 201) {
        state.clear();
        // Show success message and navigate
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice generated successfully!')),
        );
      } else {
        throw Exception('Failed to generate invoice');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}

// Models
class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? address;
  
  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
  });
  
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['_id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      address: json['address'],
    );
  }
}

class Product {
  final String id;
  final String name;
  final String code;
  final double price;
  final int stock;
  final String? category;
  final String? description;
  
  Product({
    required this.id,
    required this.name,
    required this.code,
    required this.price,
    required this.stock,
    this.category,
    this.description,
  });
  
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'],
      name: json['name'],
      code: json['code'],
      price: json['price'].toDouble(),
      stock: json['stock'],
      category: json['category'],
      description: json['description'],
    );
  }
}

// lib/main.dart
// ... (previous code remains the same until InvoiceItem class)

class InvoiceItem {
  final Product product;
  final int quantity;
  final double price;
  
  InvoiceItem({
    required this.product,
    required this.quantity,
    required this.price,
  });
  
  double get subtotal => price * quantity;
}

// Custom Widgets
class CustomerInfoCard extends StatelessWidget {
  final Customer customer;
  
  const CustomerInfoCard({Key? key, required this.customer}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  customer.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    context.read<InvoiceState>().setCustomer(null);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Email: ${customer.email}'),
            Text('Phone: ${customer.phone}'),
            if (customer.address != null) Text('Address: ${customer.address}'),
          ],
        ),
      ),
    );
  }
}

class CustomerSearchField extends StatefulWidget {
  final TextEditingController controller;
  final Function(Customer) onCustomerSelected;
  
  const CustomerSearchField({
    Key? key,
    required this.controller,
    required this.onCustomerSelected,
  }) : super(key: key);
  
  @override
  _CustomerSearchFieldState createState() => _CustomerSearchFieldState();
}

class _CustomerSearchFieldState extends State<CustomerSearchField> {
  List<Customer> _searchResults = [];
  bool _isLoading = false;
  
  Future<void> _searchCustomers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/customers/search?query=$query'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data.map((json) => Customer.fromJson(json)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching customers: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: 'Search Customer',
            suffixIcon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
          ),
          onChanged: _searchCustomers,
        ),
        if (_searchResults.isNotEmpty)
          Container(
            height: 200,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final customer = _searchResults[index];
                return ListTile(
                  title: Text(customer.name),
                  subtitle: Text(customer.phone),
                  onTap: () {
                    widget.onCustomerSelected(customer);
                    widget.controller.clear();
                    setState(() => _searchResults = []);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  Map<String, List<Product>> _categorizedProducts = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _categorizeProducts() {
    _categorizedProducts.clear();
    
    // Add uncategorized products to "Other" category
    for (var product in _products) {
      final category = product.category?.isNotEmpty == true ? product.category! : "Other";
      if (!_categorizedProducts.containsKey(category)) {
        _categorizedProducts[category] = [];
      }
      _categorizedProducts[category]!.add(product);
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/products'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _products = data.map((json) => Product.fromJson(json)).toList();
          _categorizeProducts();
        });
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editProduct(Product product) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ProductEditDialog(product: product),
    );

    if (result != null) {
      try {
        final response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/products/${product.id}'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(result),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product updated successfully')),
          );
          _loadProducts(); // Refresh the list
        } else {
          throw Exception('Failed to update product');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteProduct(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/products/$id'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _products.removeWhere((product) => product.id == id);
          _categorizeProducts();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully')),
        );
      } else {
        throw Exception('Failed to delete product');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddProductScreen()),
              );
              _loadProducts();
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('No products available'))
              : ListView.builder(
                  itemCount: _categorizedProducts.length,
                  itemBuilder: (context, index) {
                    final category = _categorizedProducts.keys.elementAt(index);
                    final categoryProducts = _categorizedProducts[category]!;
                    
                    return ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      children: categoryProducts.map((product) => Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(product.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Code: ${product.code}'),
                              Text('Stock: ${product.stock}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editProduct(product),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _showDeleteConfirmation(product),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      )).toList(),
                    );
                  },
                ),
    );
  }

  Future<void> _showDeleteConfirmation(Product product) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete ${product.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(product.id);
            },
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}

// Add this new class for editing products
class ProductEditDialog extends StatefulWidget {
  final Product product;

  const ProductEditDialog({Key? key, required this.product}) : super(key: key);

  @override
  _ProductEditDialogState createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<ProductEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _codeController = TextEditingController(text: widget.product.code);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _stockController = TextEditingController(text: widget.product.stock.toString());
    _categoryController = TextEditingController(text: widget.product.category ?? '');
    _descriptionController = TextEditingController(text: widget.product.description ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Product'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _stockController,
              decoration: const InputDecoration(labelText: 'Stock'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final updatedProduct = {
              'name': _nameController.text,
              'code': _codeController.text,
              'price': double.parse(_priceController.text),
              'stock': int.parse(_stockController.text),
              'category': _categoryController.text,
              'description': _descriptionController.text,
            };
            Navigator.pop(context, updatedProduct);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class ProductSearchField extends StatefulWidget {
  final TextEditingController controller;
  final Function(Product) onProductSelected;
  
  const ProductSearchField({
    Key? key,
    required this.controller,
    required this.onProductSelected,
  }) : super(key: key);
  
  @override
  _ProductSearchFieldState createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends State<ProductSearchField> {
  List<Product> _products = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadProducts();
  }
  
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/products'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _products = data.map((json) => Product.fromJson(json)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading products: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  List<Product> _getFilteredProducts(String query) {
    return _products.where((product) {
      return product.name.toLowerCase().contains(query.toLowerCase()) ||
             product.code.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: 'Search Product',
            suffixIcon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
          ),
          onChanged: (query) {
            setState(() {});
          },
        ),
        if (widget.controller.text.isNotEmpty)
          Container(
            height: 200,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              itemCount: _getFilteredProducts(widget.controller.text).length,
              itemBuilder: (context, index) {
                final product = _getFilteredProducts(widget.controller.text)[index];
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('Code: ${product.code} | Stock: ${product.stock}'),
                  trailing: Text('\$${product.price.toStringAsFixed(2)}'),
                  onTap: () {
                    widget.onProductSelected(product);
                    widget.controller.clear();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}



class InvoiceItemCard extends StatelessWidget {
  final InvoiceItem item;
  final VoidCallback onDelete;
  
  const InvoiceItemCard({
    Key? key,
    required this.item,
    required this.onDelete,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Code: ${item.product.code}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Qty: ${item.quantity}'),
                Text('\$${item.subtotal.toStringAsFixed(2)}'),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// Configuration
class ApiConfig {
  static const String baseUrl = 'http://localhost:3000/api';
}

// Invoice Preview Screen
class InvoicePreviewScreen extends StatelessWidget {
  final Map<String, dynamic> invoiceData;
  
  const InvoicePreviewScreen({Key? key, required this.invoiceData}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Implement sharing functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // Implement printing functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice #${invoiceData['invoiceNumber']}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Customer Details',
              [
                Text('Name: ${invoiceData['customer']['name']}'),
                Text('Email: ${invoiceData['customer']['email']}'),
                Text('Phone: ${invoiceData['customer']['phone']}'),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Items',
              [
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1),
                  },
                  children: [
                    const TableRow(
                      children: [
                        Text('Item'),
                        Text('Qty'),
                        Text('Price'),
                        Text('Total'),
                      ],
                    ),
                    ...invoiceData['items'].map<TableRow>((item) {
                      return TableRow(
                        children: [
                          Text(item['product']['name']),
                          Text('${item['quantity']}'),
                          Text('\$${item['price'].toStringAsFixed(2)}'),
                          Text('\$${item['subtotal'].toStringAsFixed(2)}'),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Summary',
              [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:'),
                    Text('\$${invoiceData['totalAmount'].toStringAsFixed(2)}'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tax (10%):'),
                    Text('\$${invoiceData['tax'].toStringAsFixed(2)}'),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total:'),
                    Text(
                      '\$${invoiceData['grandTotal'].toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}