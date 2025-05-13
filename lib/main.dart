import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:invoice_autoparts/theme/app_theme.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart'; // For getApplicationDocumentsDirectory
import 'dart:io'; // For File
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shimmer/shimmer.dart';
import 'dart:math';

class ApiConfig {
  static const String baseUrl = 'http://localhost:3000';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(prefs)),
        ChangeNotifierProvider(create: (_) => InvoiceState()),
      ],
      child: const AutoShopApp(),
    ),
  );
}

// Models
class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
    };
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String category;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
  return Product(
    id: json['_id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    price: double.parse(json['price'].toString()),
    stock: int.parse(json['stock'].toString()),
    category: json['category'] ?? '', // Ensure category is parsed
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'category': category,
    };
  }
}

class InvoiceItem {
  final Product product;
  final int quantity;
  final double price;

  InvoiceItem({
    required this.product,
    required this.quantity,
    required this.price,
  });

  double get total => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'product': product.id,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }
}

class Invoice {
  final String? id;
  final String? invoiceNumber;
  final Customer customer;
  final List<InvoiceItem> items;
  final double total;
  final String date;

  Invoice({
    this.id,
    this.invoiceNumber,
    required this.customer,
    required this.items,
    required this.total,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'customer': customer.id,
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
      'date': date,
    };
  }

  factory Invoice.fromJson(Map<String, dynamic> json, {
    required Customer customer,
    required List<InvoiceItem> items,
  }) {
    return Invoice(
      id: json['_id'],
      invoiceNumber: json['invoiceNumber'],
      customer: customer,
      items: items,
      total: double.parse(json['total'].toString()),
      date: json['date'],
    );
  }
}

class AuthProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._prefs) {
    _token = _prefs.getString('auth_token');
    _user = _prefs.getString('user') != null 
        ? json.decode(_prefs.getString('user')!) 
        : null;
  }

  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get user => _user;
  String? get token => _token;

  Future<void> _persistAuthData() async {
    if (_token != null) {
      await _prefs.setString('auth_token', _token!);
    }
    if (_user != null) {
      await _prefs.setString('user', json.encode(_user));
    }
  }

  Future<void> login(String email, String password) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email, // Use the email parameter here
        'password': password, // Use the password parameter here
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _token = data['token'];
      _user = data['user'];
      await _persistAuthData();
    } else {
      final errorData = json.decode(response.body);
      _error = errorData['error'] ?? 'Invalid email or password';
    }
  } catch (e) {
    _error = 'Failed to connect to server';
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
  Future<void> register(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _token = data['token'];
        _user = data['user'];
        await _persistAuthData();
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'Registration failed';
      }
    } catch (e) {
      _error = 'Failed to connect to server';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _prefs.remove('auth_token');
    await _prefs.remove('user');
    notifyListeners();
  }
}

class InvoiceState with ChangeNotifier {
  List<Product> products = [];
  List<Customer> customers = [];
  Customer? customer;
  List<InvoiceItem> items = [];
  double total = 0;
  bool isLoading = false;
  String? error;
  List<Invoice> invoices = [];

 List<String> get categories {
    return products.map((product) => product.category).toSet().toList();
  }

  Future<void> fetchProducts(String token) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/products'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        products = data.map((item) => Product.fromJson(item)).toList();
      } else {
        error = 'Failed to load products';
      }
    } catch (e) {
      error = 'Network error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCustomers(String token) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/customers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        customers = data.map((item) => Customer.fromJson(item)).toList();
      } else {
        error = 'Failed to load customers';
      }
    } catch (e) {
      error = 'Network error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchInvoices(String token) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/invoices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Process the populated data directly
        invoices = data.map((invoiceData) {
          // Extract customer data
          final customerData = invoiceData['customer'];
          final customer = Customer.fromJson(customerData);
          
          // Extract items data
          List<InvoiceItem> invoiceItems = [];
          for (var item in invoiceData['items']) {
            final productData = item['product'];
            final product = Product.fromJson(productData);
            
            invoiceItems.add(InvoiceItem(
              product: product,
              quantity: item['quantity'],
              price: double.parse(item['price'].toString()),
            ));
          }
          
          return Invoice.fromJson(
            invoiceData,
            customer: customer,
            items: invoiceItems,
          );
        }).toList();
      } else {
        error = 'Failed to load invoices';
      }
    } catch (e) {
      error = 'Network error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addCustomer(Customer customer, String token) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/customers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(customer.toJson()),
      );

      if (response.statusCode == 201) {
        await fetchCustomers(token);
        return true;
      } else {
        final errorData = json.decode(response.body);
        error = errorData['error'] ?? 'Failed to add customer';
        return false;
      }
    } catch (e) {
      error = 'Network error: $e';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addProduct(Product product, String token) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/products'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(product.toJson()),
      );

      if (response.statusCode == 201) {
        await fetchProducts(token);
        return true;
      } else {
        final errorData = json.decode(response.body);
        error = errorData['error'] ?? 'Failed to add product';
        return false;
      }
    } catch (e) {
      error = 'Network error: $e';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  Future<bool> deleteProduct(String productId, String token) async {
  isLoading = true;
  error = null;
  notifyListeners();

  try {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/products/$productId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      await fetchProducts(token); // Refresh the product list
      return true;
    } else {
      final errorData = json.decode(response.body);
      error = errorData['error'] ?? 'Failed to delete product';
      return false;
    }
  } catch (e) {
    error = 'Network error: $e';
    return false;
  } finally {
    isLoading = false;
    notifyListeners();
  }
}
  
  Future<bool> createInvoice(String token) async {
    if (customer == null || items.isEmpty) {
      error = 'Customer and items are required';
      notifyListeners();
      return false;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final invoice = Invoice(
        customer: customer!,
        items: items,
        total: total,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/invoices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(invoice.toJson()),
      );

      if (response.statusCode == 201) {
        // Clear the current invoice
        clear();
        
        // Refresh products to get updated stock levels
        await fetchProducts(token);
        await fetchInvoices(token);
        return true;
      } else {
        final errorData = json.decode(response.body);
        error = errorData['error'] ?? 'Failed to create invoice';
        return false;
      }
    } catch (e) {
      error = 'Network error: $e';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void addItem(Product product, int quantity) {
    if (quantity <= 0) {
      error = 'Quantity must be greater than 0';
      notifyListeners();
      return;
    }

    if (quantity > product.stock) {
      error = 'Not enough stock available';
      notifyListeners();
      return;
    }

    // Check if product already exists in items
    final existingItemIndex = items.indexWhere((item) => item.product.id == product.id);

    if (existingItemIndex >= 0) {
      // Update existing item
      final existingItem = items[existingItemIndex];
      final newQuantity = existingItem.quantity + quantity;
      
      if (newQuantity > product.stock) {
        error = 'Not enough stock available';
        notifyListeners();
        return;
      }
      
      items[existingItemIndex] = InvoiceItem(
        product: product,
        quantity: newQuantity,
        price: product.price,
      );
    } else {
      // Add new item
      items.add(InvoiceItem(
        product: product,
        quantity: quantity,
        price: product.price,
      ));
    }

    calculateTotal();
    error = null;
    notifyListeners();
  }

  void removeItem(int index) {
    if (index >= 0 && index < items.length) {
      items.removeAt(index);
      calculateTotal();
      notifyListeners();
    }
  }

  void calculateTotal() {
    total = items.fold(0, (sum, item) => sum + item.total);
  }

  void setCustomer(Customer newCustomer) {
    customer = newCustomer;
    notifyListeners();
  }

  void clear() {
    customer = null;
    items.clear();
    total = 0;
    notifyListeners();
  }
}

// Customer Search Dialog
class CustomerSearchDialog extends StatefulWidget {
  final List<Customer> customers;
  final Function(Customer) onCustomerSelected;

  const CustomerSearchDialog({
    Key? key,
    required this.customers,
    required this.onCustomerSelected,
  }) : super(key: key);

  @override
  _CustomerSearchDialogState createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<CustomerSearchDialog> {
  late List<Customer> filteredCustomers;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredCustomers = [];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        // If the query is empty, show no customers
        filteredCustomers = [];
      } else {
        // Convert query to lowercase for case-insensitive search
        final lowerCaseQuery = query.toLowerCase();

        // Filter customers based on name, email, or phone
        filteredCustomers = widget.customers.where((customer) {
          return customer.name.toLowerCase().contains(lowerCaseQuery) ||
                 customer.email.toLowerCase().contains(lowerCaseQuery) ||
                 customer.phone.toLowerCase().contains(lowerCaseQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Select Customer',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Container(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Customers',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterCustomers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _filterCustomers,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredCustomers.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Start typing to search for customers'
                            : 'No customers found',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              customer.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customer.email),
                                Text(customer.phone),
                              ],
                            ),
                            onTap: () {
                              widget.onCustomerSelected(customer);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),
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
      ],
    );
  }
}
// Product Search Dialog
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
    // Filter out products with stock less than 20
    filteredProducts = widget.products.where((product) => product.stock >= 5).toList();
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
      if (query.trim().isEmpty) {
        filteredProducts = widget.products.where((product) => product.stock >= 5).toList();
      } else {
        final lowerCaseQuery = query.toLowerCase();
        filteredProducts = widget.products
            .where((product) =>
                product.stock >= 20 &&
                (product.name.toLowerCase().contains(lowerCaseQuery) ||
                    product.description.toLowerCase().contains(lowerCaseQuery)))
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
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterProducts('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _filterProducts,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredProducts.isEmpty
                  ? Center(
                      child: Text(
                        'No products found',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return ListTile(
                          title: Text(product.name),
                          subtitle: Text(
                            '${product.description}\nPrice: \₹${product.price.toStringAsFixed(2)} • Stock: ${product.stock}',
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
              const SizedBox(height: 16),
              Text(
                'Selected: ${selectedProduct!.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
                    content: Text(
                        'Invalid quantity. Must be between 1 and ${selectedProduct!.stock}'),
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

class AutoShopApp extends StatelessWidget {
  const AutoShopApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Durai Auto Parts',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth.isAuthenticated) {
            return const MainNavigationScreen();
          } else {
            return const AuthScreen();
          }
        },
      ),
    );
  }
}
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _registerUsernameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  
  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withOpacity(0.8),
              AppTheme.accentColor.withOpacity(0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.build_circle,
                        size: 60,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Durai Auto Parts',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Invoice & Inventory Management',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 40),
                    
                    Container(
                      width: size.width > 600 ? 500 : double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              tabs: [
                                Tab(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login),
                                      SizedBox(width: 8),
                                      Text('Login'),
                                    ],
                                  ),
                                ),
                                Tab(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add),
                                      SizedBox(width: 8),
                                      Text('Register'),
                                    ],
                                  ),
                                ),
                              ],
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicatorWeight: 3,
                              indicatorPadding: EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                          
                          Container(
                            height: 380,
                            padding: EdgeInsets.all(24),
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                Form(
                                  key: _loginFormKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _loginEmailController,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          hintText: 'Enter your email',
                                          prefixIcon: Icon(Icons.email_outlined),
                                        ),
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your email';
                                          }
                                          if (!value.contains('@gmail')) {
                                            return 'Please enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      SizedBox(height: 20),
                                      TextFormField(
                                        controller: _loginPasswordController,

                                        decoration: InputDecoration(
                                          labelText: 'Password',

                                          hintText: 'Enter your password',
                                          prefixIcon: Icon(Icons.lock_outline),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureLoginPassword ? Icons.visibility_off : Icons.visibility,
                                              color: Colors.grey,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscureLoginPassword = !_obscureLoginPassword;
                                              });
                                            },
                                          ),
                                        ),

                                        obscureText: _obscureLoginPassword,
                                        textInputAction: TextInputAction.done,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          if (value.length < 6) {
                                            return 'Password must be at least 6 characters';
                                          }
                                          return null;
                                        },
                                      ),

                                      SizedBox(height: 30),
                                      if (authProvider.error != null)



                                        Container(
                                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.error_outline, color: Colors.red),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  authProvider.error!,
                                                  style: TextStyle(color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: authProvider.isLoading
                                            ? null
                                            : () {
                                                if (_loginFormKey.currentState!.validate()) {
                                                  authProvider.login(
                                                    _loginEmailController.text,
                                                    _loginPasswordController.text,
                                                  );
                                                }
                                              },
                                        child: authProvider.isLoading
                                            ? CircularProgressIndicator(color: Colors.white)
                                            : Text('Login'),
                                        style: ElevatedButton.styleFrom(



                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(

                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),






                                      ),
                                    ],
                                  ),
                                ),





                                Form(
                                  key: _registerFormKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _registerUsernameController,

                                        decoration: InputDecoration(
                                          labelText: 'Username',

                                          hintText: 'Enter your username',
                                          prefixIcon: Icon(Icons.person_outline),
                                        ),
                                        textInputAction: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter a username';
                                          }
                                          if (value.length < 3) {
                                            return 'Username must be at least 3 characters';
                                          }
                                          return null;
                                        },
                                      ),

                                      SizedBox(height: 20),
                                      TextFormField(
                                        controller: _registerEmailController,

                                        decoration: InputDecoration(
                                          labelText: 'Email',

                                          hintText: 'Enter your email',
                                          prefixIcon: Icon(Icons.email_outlined),
                                        ),
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your email';
                                          }
                                          if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(value)) {
                                            return 'Please enter a valid email address';
                                          }
                                          return null;
                                        },
                                      ),

                                      SizedBox(height: 20),
                                      TextFormField(
                                        controller: _registerPasswordController,

                                        decoration: InputDecoration(
                                          labelText: 'Password',

                                          hintText: 'Enter your password',
                                          prefixIcon: Icon(Icons.lock_outline),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureRegisterPassword ? Icons.visibility_off : Icons.visibility,
                                              color: Colors.grey,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscureRegisterPassword = !_obscureRegisterPassword;
                                              });
                                            },
                                          ),
                                        ),

                                        obscureText: _obscureRegisterPassword,
                                        textInputAction: TextInputAction.done,
                                        validator: (value) {
                                        if (value == null || value.isEmpty) {
                                            return 'Please enter your password';
                                        }
  if (value.length < 6 ||
      !RegExp(r'[A-Z]').hasMatch(value) ||
      !RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
    return 'Password must be at least 6 characters\n'
    'include one uppercase letter, and one special character';
  }
  return null;
},
                                      ),

                                      SizedBox(height: 30),
                                      if (authProvider.error != null)



                                        Container(
                                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.error_outline, color: Colors.red),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  authProvider.error!,
                                                  style: TextStyle(color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: authProvider.isLoading
                                            ? null
                                            : () {
                                                if (_registerFormKey.currentState!.validate()) {
                                                  authProvider.register(
                                                    _registerUsernameController.text,
                                                    _registerEmailController.text,
                                                    _registerPasswordController.text,
                                                  );
                                                }
                                              },
                                        child: authProvider.isLoading
                                            ? CircularProgressIndicator(color: Colors.white)
                                            : Text('Register'),
                                        style: ElevatedButton.styleFrom(



                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(

                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),






                                      ),
                                    ],
                                  ),
                                ),


                              ],
                            ),
                          ),


                        ],
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Fetch data when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final invoiceState = Provider.of<InvoiceState>(context, listen: false);

    if (auth.token != null) {
      await invoiceState.fetchProducts(auth.token!);
      await invoiceState.fetchCustomers(auth.token!);
      await invoiceState.fetchInvoices(auth.token!);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
Widget build(BuildContext context) {
  final auth = Provider.of<AuthProvider>(context);

  final List<Widget> _widgetOptions = <Widget>[
    InvoiceScreen(),
    AddCustomerScreen(),
    AddProductScreen(),
    ProductListScreen(),
    LowStockAlertScreen(),
    ReportsScreen(),
  ];

  return Scaffold(
    appBar: AppBar(
      title: Shimmer.fromColors(
        baseColor: Colors.white,
        highlightColor: Colors.yellow,
        child: const Text(
          'Durai Auto Parts Shop',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () {
            auth.logout();
          },
        ),
      ],
    ),
    body: Stack(
      children: [
        // Shower-like effect as a background
        Positioned.fill(
          child: Stack(
            children: List.generate(100, (index) {
              final random = Random();
              final left = random.nextDouble() * MediaQuery.of(context).size.width;
              final sizeParticle = random.nextDouble() * 5 + 2; // Random size between 2 and 7
              final color = Colors.primaries[random.nextInt(Colors.primaries.length)];

              return AnimatedPositioned(
                duration: const Duration(seconds: 5),
                curve: Curves.easeInOut,
                top: random.nextDouble() * MediaQuery.of(context).size.height,
                left: left,
                child: Container(
                  width: sizeParticle,
                  height: sizeParticle,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ),
        // Main content
        SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue[50]!,
                  Colors.white,
                ],
              ),
            ),
            child: _widgetOptions.elementAt(_selectedIndex),
          ),
        ),
      ],
    ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: const Icon(Icons.receipt),
                label: 'Invoices',
                backgroundColor: Theme.of(context).primaryColor,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_add),
                label: 'New Customer',
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.add_box),
                label: 'New Product',
                backgroundColor: Theme.of(context).colorScheme.tertiary,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.inventory),
                label: 'Products List',
                backgroundColor: Colors.purple,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.warning),
                label: 'Low Stock',
                backgroundColor: Colors.red,
              ),
              BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.shifting,
            elevation: 8,
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}
// class _MainNavigationScreenState extends State<MainNavigationScreen> {
//   int _selectedIndex = 0;

//   @override
//   void initState() {
//     super.initState();
//     // Fetch data when the screen is initialized
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchData();
//     });
//   }

//   Future<void> _fetchData() async {
//     final auth = Provider.of<AuthProvider>(context, listen: false);
//     final invoiceState = Provider.of<InvoiceState>(context, listen: false);

//     if (auth.token != null) {
//       await invoiceState.fetchProducts(auth.token!);
//       await invoiceState.fetchCustomers(auth.token!);
//       await invoiceState.fetchInvoices(auth.token!);
//     }
//   }

//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final auth = Provider.of<AuthProvider>(context);

//     final List<Widget> _widgetOptions = <Widget>[
//       InvoiceScreen(),
//       AddCustomerScreen(),
//       AddProductScreen(),
//       ProductListScreen(),
//       LowStockAlertScreen(), // Add the new screen here
//     ];

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Durai Auto Parts Shop'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () {
//               auth.logout();
//             },
//           ),
//         ],
//       ),
//       body: SafeArea(
//         child: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [
//                 Colors.blue[50]!,
//                 Colors.white,
//               ],
//             ),
//           ),
//           child: _widgetOptions.elementAt(_selectedIndex),
//         ),
//       ),
//       bottomNavigationBar: Container(
//         decoration: BoxDecoration(
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.1),
//               blurRadius: 10,
//               offset: const Offset(0, -5),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: const BorderRadius.only(
//             topLeft: Radius.circular(20),
//             topRight: Radius.circular(20),
//           ),
//           child: BottomNavigationBar(
//             items: <BottomNavigationBarItem>[
//               BottomNavigationBarItem(
//                 icon: const Icon(Icons.receipt),
//                 label: 'Invoices',
//                 backgroundColor: Theme.of(context).primaryColor,
//               ),
//               BottomNavigationBarItem(
//                 icon: const Icon(Icons.person_add),
//                 label: 'New Customer',
//                 backgroundColor: Theme.of(context).colorScheme.secondary,
//               ),
//               BottomNavigationBarItem(
//                 icon: const Icon(Icons.add_box),
//                 label: 'New Product',
//                 backgroundColor: Theme.of(context).colorScheme.tertiary,
//               ),
//               BottomNavigationBarItem(
//                 icon: const Icon(Icons.inventory),
//                 label: 'Products List',
//                 backgroundColor: Colors.purple,
//               ),
//               BottomNavigationBarItem(
//                 icon: const Icon(Icons.warning),
//                 label: 'Low Stock',
//                 backgroundColor: Colors.red,
//               ),
//             ],
//             currentIndex: _selectedIndex,
//             selectedItemColor: Colors.white,
//             unselectedItemColor: Colors.white70,
//             showUnselectedLabels: true,
//             type: BottomNavigationBarType.shifting,
//             elevation: 8,
//             onTap: _onItemTapped,
//           ),
//         ),
//       ),
//     );
//   }
// }
// class _MainNavigationScreenState extends State<MainNavigationScreen> {
//   int _selectedIndex = 0;

//   @override
//   void initState() {
//     super.initState();
//     // Fetch data when the screen is initialized
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchData();
//     });
//   }

//   Future<void> _fetchData() async {
//     final auth = Provider.of<AuthProvider>(context, listen: false);
//     final invoiceState = Provider.of<InvoiceState>(context, listen: false);
    
//     if (auth.token != null) {
//       await invoiceState.fetchProducts(auth.token!);
//       await invoiceState.fetchCustomers(auth.token!);
//       await invoiceState.fetchInvoices(auth.token!);
//     }
//   }

//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final auth = Provider.of<AuthProvider>(context);
    
//     final List<Widget> _widgetOptions = <Widget>[
//       InvoiceScreen(),
//       AddCustomerScreen(),
//       AddProductScreen(),
//       ProductListScreen(),
//     ];
    
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Durai Auto Parts Shop'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () {
//               auth.logout();
//             },
//           ),
//         ],
//       ),
//       body: SafeArea(
//         child: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [
//                 Colors.blue[50]!,
//                 Colors.white,
//               ],
//             ),
//           ),
//           child: _widgetOptions.elementAt(_selectedIndex),
//         ),
//       ),
//       bottomNavigationBar: Container(
//         decoration: BoxDecoration(
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.1),
//               blurRadius: 10,
//               offset: const Offset(0, -5),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: const BorderRadius.only(
//             topLeft: Radius.circular(20),
//             topRight: Radius.circular(20),
//           ),
//           child: BottomNavigationBar(
//             items: <BottomNavigationBarItem>[
//               BottomNavigationBarItem(
//                 icon: const Icon(Icons.receipt),
//                 label: 'Invoices',
//                 backgroundColor: Theme.of(context).primaryColor,
//               ),
//               BottomNavigationBarItem(
//                 icon: const Icon(Icons.person_add),
//                 label: 'New Customer',
//                 backgroundColor: Theme.of(context).colorScheme.secondary,
//               ),
//               BottomNavigationBarItem(
//                 icon: const Icon(Icons.add_box),
//                 label: 'New Product',
//                 backgroundColor: Theme.of(context).colorScheme.tertiary,
//               ),
//               BottomNavigationBarItem(
//                 icon: const Icon(Icons.inventory),
//                 label: 'Products List',
//                 backgroundColor: Colors.purple,
//               ),
//             ],
//             currentIndex: _selectedIndex,
//             selectedItemColor: Colors.white,
//             unselectedItemColor: Colors.white70,
//             showUnselectedLabels: true,
//             type: BottomNavigationBarType.shifting,
//             elevation: 8,
//             onTap: _onItemTapped,
//           ),
//         ),
//       ),
//     );
//   }
// }

class InvoiceScreen extends StatefulWidget {
  @override
  _InvoiceScreenState createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'New Invoice'),
            Tab(text: 'Invoice History'),
          ],
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              NewInvoiceTab(),
              InvoiceHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class NewInvoiceTab extends StatefulWidget {
  @override
  _NewInvoiceTabState createState() => _NewInvoiceTabState();
}

class _NewInvoiceTabState extends State<NewInvoiceTab> {
  @override
  Widget build(BuildContext context) {
    final invoiceState = Provider.of<InvoiceState>(context);
    final auth = Provider.of<AuthProvider>(context);
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (invoiceState.customer != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Name: ${invoiceState.customer!.name}'),
                          Text('Email: ${invoiceState.customer!.email}'),
                          Text('Phone: ${invoiceState.customer!.phone}'),
                          Text('Address: ${invoiceState.customer!.address}'),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _showCustomerSearchDialog(context);
                            },
                            child: const Text('Change Customer'),
                          ),
                        ],
                      )
                    else
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            _showCustomerSearchDialog(context);
                          },
                          child: const Text('Select Customer'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          _showProductSearchDialog(context);
                        },
                        child: const Text('Search & Add Product'),
                      ),
                    ),
                    if (invoiceState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          invoiceState.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invoice Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    invoiceState.items.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No items added yet'),
                            ),
                          )
                        : Container(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: invoiceState.items.length,
                              itemBuilder: (context, index) {
                                final item = invoiceState.items[index];
                                return ListTile(
                                  title: Text(item.product.name),
                                  subtitle: Text('${item.quantity} x \₹${item.price.toStringAsFixed(2)}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('\₹${item.total.toStringAsFixed(2)}'),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          invoiceState.removeItem(index);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\₹${invoiceState.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
  child: ElevatedButton(
    onPressed: invoiceState.customer == null || invoiceState.items.isEmpty
        ? null
        : () async {
            final success = await invoiceState.createInvoice(auth.token!);
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invoice created successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(invoiceState.error ?? 'Failed to create invoice'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: 40,
        vertical: 12,
      ),
    ),
    child: invoiceState.isLoading
        ? Shimmer.fromColors(
            baseColor: Colors.white,
            highlightColor: Colors.grey.shade300,
            child: const Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : const Text('Create Invoice'),
  ),
),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerSearchDialog(BuildContext context) {
    final invoiceState = Provider.of<InvoiceState>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return CustomerSearchDialog(
          customers: invoiceState.customers,
          onCustomerSelected: (customer) {
            invoiceState.setCustomer(customer);
          },
        );
      },
    );
  }

  void _showProductSearchDialog(BuildContext context) {
    final invoiceState = Provider.of<InvoiceState>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return ProductSearchDialog(
          products: invoiceState.products,
          onProductSelected: (product, quantity) {
            invoiceState.addItem(product, quantity);
          },
        );
      },
    );
  }
}

class InvoiceHistoryTab extends StatefulWidget {
  @override
  _InvoiceHistoryTabState createState() => _InvoiceHistoryTabState();
}

class _InvoiceHistoryTabState extends State<InvoiceHistoryTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Invoice> allInvoices = [];
  List<Invoice> recentInvoices = [];
  List<Invoice> filteredInvoices = [];
  bool isSearching = false;
  bool showRecent = false; // Toggle between All and Recent History

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterInvoices);
    _categorizeInvoices();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterInvoices);
    _searchController.dispose();
    super.dispose();
  }

  void _categorizeInvoices() {
    final invoiceState = Provider.of<InvoiceState>(context, listen: false);
    final now = DateTime.now();

    setState(() {
      // All invoices
      allInvoices = invoiceState.invoices;

      // Recent invoices (created within the last 25 minutes)
      recentInvoices = invoiceState.invoices.where((invoice) {
        final invoiceDate = DateTime.parse(invoice.date);
        return now.difference(invoiceDate).inMinutes <= 1800;
      }).toList();

      // Default filtered invoices
      filteredInvoices = allInvoices;
    });
  }

  void _filterInvoices() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredInvoices = showRecent ? recentInvoices : allInvoices;
        isSearching = false;
      } else {
        isSearching = true;
        final source = showRecent ? recentInvoices : allInvoices;
        filteredInvoices = source.where((invoice) {
          final invoiceId = invoice.invoiceNumber?.toLowerCase() ?? invoice.id?.toLowerCase() ?? '';
          final customerName = invoice.customer.name.toLowerCase();
          return invoiceId.contains(query) || customerName.contains(query);
        }).toList();
      }
    });
  }

  void _showPrintingDialog(BuildContext context, Invoice invoice) async {
    final pdf = await _generateInvoicePDF(invoice);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.95,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Invoice Preview',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const Divider(),

                // PDF Preview
                Expanded(
                  child: PdfPreview(
                    build: (format) => pdf.save(),
                    allowPrinting: false,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                  ),
                ),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save PDF'),
                      onPressed: () async {
                        try {
                          if (kIsWeb) {
                            // For Flutter Web
                            await Printing.sharePdf(
                              bytes: await pdf.save(),
                              filename: '${invoice.customer.name}_${invoice.date}.pdf',
                            );
                          } else {
                            // For Android, iOS, Desktop
                            final output = await getApplicationDocumentsDirectory();
                            final folderPath = '${output.path}/Invoices';
                            final folder = Directory(folderPath);

                            // Create the folder if it doesn't exist
                            if (!await folder.exists()) {
                              await folder.create(recursive: true);
                            }

                            // Save the file with customer name and date
                            final fileName = '${invoice.customer.name}_${invoice.date}.pdf'.replaceAll(' ', '_');
                            final file = File('$folderPath/$fileName');
                            await file.writeAsBytes(await pdf.save());

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invoice saved to ${file.path}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save PDF: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('Print Invoice'),
                      onPressed: () async {
                        try {
                          await Printing.layoutPdf(
                            onLayout: (format) async => pdf.save(),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to print: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceState = Provider.of<InvoiceState>(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Toggle Buttons for All History and Recent History
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('All History'),
                selected: !showRecent,
                onSelected: (selected) {
                  setState(() {
                    showRecent = !selected;
                    filteredInvoices = showRecent ? recentInvoices : allInvoices;
                  });
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Recent History'),
                selected: showRecent,
                onSelected: (selected) {
                  setState(() {
                    showRecent = selected;
                    filteredInvoices = showRecent ? recentInvoices : allInvoices;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by invoice ID or customer name',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),

         Expanded(
  child: invoiceState.isLoading
      ? ListView.builder(
          itemCount: 5, // Placeholder count
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            );
          },
        )
      : filteredInvoices.isEmpty
          ? Center(
              child: Text(
                showRecent ? 'No invoices found in Recent History' : 'No invoices found in All History',
              ),
            )
          : ListView.builder(
              itemCount: filteredInvoices.length,
              itemBuilder: (context, index) {
                final invoice = filteredInvoices[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('Invoice #${invoice.invoiceNumber ?? invoice.id}'),
                    subtitle: Text('Date: ${invoice.date} - Rs ${invoice.total.toStringAsFixed(2)}'),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('Print Receipt'),
                      onPressed: () {
                        _showPrintingDialog(context, invoice);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                );
              },
            ),
),
        ],
      ),
    );
  }

  

Future<pw.Document> _generateInvoicePDF(Invoice invoice) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape, // Enable landscape mode
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        // Header Section
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Durai Auto Parts',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('123 Auto Street, Chennai, India'),
                pw.Text('Phone: +91 9876543210'),
                pw.Text('Email: support@duraiautoparts.com'),
              ],
            ),
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        // Invoice Details
        pw.Text(
          'Invoice Number: ${invoice.invoiceNumber ?? invoice.id}',
          style: pw.TextStyle(fontSize: 16),
        ),
        pw.Text(
          'Date: ${invoice.date}',
          style: pw.TextStyle(fontSize: 16),
        ),
        pw.SizedBox(height: 16),

        // Customer Details
        pw.Text(
          'Bill To:',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Name: ${invoice.customer.name}'),
        pw.Text('Email: ${invoice.customer.email}'),
        pw.Text('Phone: ${invoice.customer.phone}'),
        pw.Text('Address: ${invoice.customer.address}'),
        pw.SizedBox(height: 16),

        // Invoice Items Table
        pw.Text(
          'Invoice Items:',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Table.fromTextArray(
          headers: ['Product', 'Quantity', 'Price (Rs)', 'Total (Rs)'],
          data: invoice.items.map((item) {
            return [
              item.product.name,
              item.quantity.toString(),
              item.price.toStringAsFixed(2),
              item.total.toStringAsFixed(2),
            ];
          }).toList(),
          border: pw.TableBorder.all(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 16),

        // Footer Section
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text('Subtotal: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs ${invoice.total.toStringAsFixed(2)}'),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Text('Tax (18%): ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs ${(invoice.total * 0.18).toStringAsFixed(2)}'),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  children: [
                    pw.Text('Grand Total: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text(
                      'Rs ${(invoice.total * 1.18).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        // Notes Section
        pw.Text(
          'Payment Terms:',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Please make the payment within 15 days.'),
        pw.Text('For any queries, contact us at support@duraiautoparts.com.'),
      ],
    ),
  );

  return pdf;
}
}
//   @override
//   Widget build(BuildContext context) {
//     final invoiceState = Provider.of<InvoiceState>(context);
//     final auth = Provider.of<AuthProvider>(context);
    
//     // Initialize filtered invoices if not already done
//     if (filteredInvoices.isEmpty && !isSearching) {
//       filteredInvoices = invoiceState.invoices;
//     }
    
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         return Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Invoice History',
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.refresh),
//                     onPressed: () async {
//                       await invoiceState.fetchInvoices(auth.token!);
//                       _filterInvoices(); // Update filtered list after refresh
//                     },
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               // Search bar
//               TextField(
//                 controller: _searchController,
//                 decoration: InputDecoration(
//                   hintText: 'Search by invoice ID or customer name',
//                   prefixIcon: Icon(Icons.search),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   suffixIcon: _searchController.text.isNotEmpty
//                     ? IconButton(
//                         icon: Icon(Icons.clear),
//                         onPressed: () {
//                           _searchController.clear();
//                         },
//                       )
//                     : null,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Expanded(
//                 child: invoiceState.isLoading
//                     ? const Center(child: CircularProgressIndicator())
//                     : invoiceState.invoices.isEmpty
//                         ? const Center(child: Text('No invoices found'))
//                         : filteredInvoices.isEmpty && isSearching
//                             ? Center(child: Text('No matching invoices found'))
//                             : ListView.builder(
//                                 shrinkWrap: true,
//                                 physics: const AlwaysScrollableScrollPhysics(),
//                                 itemCount: filteredInvoices.length,
//                                 itemBuilder: (context, index) {
//                                   final invoice = filteredInvoices[index];
//                                   return Card(
//                                     margin: const EdgeInsets.only(bottom: 16),
//                                     child: Column(
//                                       children: [
//                                         ExpansionTile(
//                                           title: Text('Invoice #${invoice.invoiceNumber ?? invoice.id}'),
//                                           subtitle: Text('Date: ${invoice.date} - \₹${invoice.total.toStringAsFixed(2)}'),
//                                           children: [
//                                             Padding(
//                                               padding: const EdgeInsets.all(16.0),
//                                               child: Column(
//                                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                                 children: [
//                                                   Text(
//                                                     'Customer: ${invoice.customer.name}',
//                                                     style: const TextStyle(fontWeight: FontWeight.bold),
//                                                   ),
//                                                   Text('Email: ${invoice.customer.email}'),
//                                                   Text('Phone: ${invoice.customer.phone}'),
//                                                   Text('Address: ${invoice.customer.address}'),
//                                                   const Divider(),
//                                                   const Text(
//                                                     'Items:',
//                                                     style: TextStyle(fontWeight: FontWeight.bold),
//                                                   ),
//                                                   const SizedBox(height: 8),
//                                                   ...invoice.items.map((item) {
//                                                     return Padding(
//                                                       padding: const EdgeInsets.only(bottom: 8.0),
//                                                       child: Row(
//                                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                                         children: [
//                                                           Expanded(
//                                                             child: Text('${item.product.name} (${item.quantity} x \₹${item.price.toStringAsFixed(2)})'),
//                                                           ),
//                                                           Text('\₹${item.total.toStringAsFixed(2)}'),
//                                                         ],
//                                                       ),
//                                                     );
//                                                   }).toList(),
//                                                   const Divider(),
//                                                   Row(
//                                                     mainAxisAlignment: MainAxisAlignment.end,
//                                                     children: [
//                                                       const Text(
//                                                         'Total: ',
//                                                         style: TextStyle(fontWeight: FontWeight.bold),
//                                                       ),
//                                                       Text(
//                                                         '\₹${invoice.total.toStringAsFixed(2)}',
//                                                         style: const TextStyle(fontWeight: FontWeight.bold),
//                                                       ),
//                                                     ],
//                                                   ),
//                                                 ],
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                         Padding(
//                                           padding: const EdgeInsets.only(bottom: 8.0, left: 16.0, right: 16.0),
//                                           child: Row(
//                                             mainAxisAlignment: MainAxisAlignment.end,
//                                             children: [
//                                               ElevatedButton.icon(
//                                                 icon: Icon(Icons.print),
//                                                 label: Text('Print Receipt'),
//                                                 onPressed: () {
//                                                   _showPrintingDialog(context, invoice);
//                                                 },
//                                                 style: ElevatedButton.styleFrom(
//                                                   backgroundColor: Colors.green,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   );
//                                 },
//                               ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

class AddCustomerScreen extends StatefulWidget {
  @override
  _AddCustomerScreenState createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final invoiceState = Provider.of<InvoiceState>(context);
    final auth = Provider.of<AuthProvider>(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add New Customer',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        if (invoiceState.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              invoiceState.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        Center(
                          child: ElevatedButton(
                            onPressed: invoiceState.isLoading
                                ? null
                                : () async {
                                    if (_formKey.currentState!.validate()) {
                                      final customer = Customer(
                                        id: '',
                                        name: _nameController.text,
                                        email: _emailController.text,
                                        phone: _phoneController.text,
                                        address: _addressController.text,
                                      );
                                      
                                      final success = await invoiceState.addCustomer(customer, auth.token!);
                                      
                                      if (success) {
                                        _formKey.currentState!.reset();
                                        _nameController.clear();
                                        _emailController.clear();
                                        _phoneController.clear();
                                        _addressController.clear();
                                        
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Customer added successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(invoiceState.error ?? 'Failed to add customer'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 12,
                              ),
                            ),
                            child: invoiceState.isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : const Text('Add Customer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AddProductScreen extends StatefulWidget {
  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  String? selectedCategory; // Use this for the dropdown value

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoiceState = Provider.of<InvoiceState>(context);
    final auth = Provider.of<AuthProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add New Product',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Product Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a product name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            border: OutlineInputBorder(),
                            prefixText: '\₹ ',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a price';
                            }
                            final price = double.tryParse(value);
                            if (price == null || price <= 0) {
                              return 'Please enter a valid price';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _stockController,
                          decoration: const InputDecoration(
                            labelText: 'Stock Quantity',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter stock quantity';
                            }
                            final stock = int.tryParse(value);
                            if (stock == null || stock < 0) {
                              return 'Please enter a valid stock quantity';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                           DropdownMenuItem(value: 'Engine Parts', child: Text('Engine Parts')),
DropdownMenuItem(value: 'Suspension and Steering', child: Text('Suspension and Steering')),
DropdownMenuItem(value: 'Braking System', child: Text('Braking System')),
DropdownMenuItem(value: 'Electrical Components', child: Text('Electrical Components')),
DropdownMenuItem(value: 'Oil', child: Text('Oil')),
DropdownMenuItem(value: 'Transmission and Drivetrain', child: Text('Transmission and Drivetrain')),
DropdownMenuItem(value: 'Cooling System', child: Text('Cooling System')),
DropdownMenuItem(value: 'Exhaust System', child: Text('Exhaust System')),
DropdownMenuItem(value: 'Body Parts', child: Text('Body Parts')),
DropdownMenuItem(value: 'Interior Components', child: Text('Interior Components')),
DropdownMenuItem(value: 'Filters', child: Text('Filters')),
DropdownMenuItem(value: 'Fuel System', child: Text('Fuel System')),
DropdownMenuItem(value: 'Wheels and Tires', child: Text('Wheels and Tires')),
DropdownMenuItem(value: 'Accessories', child: Text('Accessories')),
DropdownMenuItem(value: 'Maintenance Parts', child: Text('Maintenance Parts')),
DropdownMenuItem(value: 'Lighting and Electrical', child: Text('Lighting and Electrical')),
DropdownMenuItem(value: 'Heating and Air Conditioning', child: Text('Heating and Air Conditioning')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value; // Update the selected category
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a category';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        if (invoiceState.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              invoiceState.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        Center(
                          child: ElevatedButton(
                            onPressed: invoiceState.isLoading
                                ? null
                                : () async {
                                    if (_formKey.currentState!.validate()) {
                                      final product = Product(
                                        id: '',
                                        name: _nameController.text,
                                        description: _descriptionController.text,
                                        price: double.parse(_priceController.text),
                                        stock: int.parse(_stockController.text),
                                        category: selectedCategory!, // Use selectedCategory
                                      );

                                      final success = await invoiceState.addProduct(product, auth.token!);

                                      if (success) {
                                        _formKey.currentState!.reset();
                                        _nameController.clear();
                                        _descriptionController.clear();
                                        _priceController.clear();
                                        _stockController.clear();
                                        setState(() {
                                          selectedCategory = null; // Reset the selected category
                                        });

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Product added successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(invoiceState.error ?? 'Failed to add product'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 12,
                              ),
                            ),
                            child: invoiceState.isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : const Text('Add Product'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}
class _ProductListScreenState extends State<ProductListScreen> {
  String selectedCategory = 'All'; // Default category

  @override
  Widget build(BuildContext context) {
    final invoiceState = Provider.of<InvoiceState>(context);
    final auth = Provider.of<AuthProvider>(context);

    // Filter products by selected category
    final filteredProducts = selectedCategory == 'All'
        ? invoiceState.products
        : invoiceState.products
            .where((product) => product.category == selectedCategory)
            .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Refresh Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Products List',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await invoiceState.fetchProducts(auth.token!);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButton<String>(
                value: selectedCategory,
                items: ['All', ...invoiceState.categories]
                    .map((category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Product List
              Expanded(
                child: invoiceState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredProducts.isEmpty
                        ? const Center(child: Text('No products found'))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];

                              // Notify if stock is less than 20
                              if (product.stock < 20) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Low stock alert: ${product.name} has only ${product.stock} items left!'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                });
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Description: ${product.description}'),
                                      Text('Price: ₹${product.price.toStringAsFixed(2)}'),
                                      Text('Stock: ${product.stock}'),
                                      Text('Category: ${product.category}'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () {
                                          _showEditProductDialog(context, product);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          _showDeleteConfirmationDialog(context, product, auth.token!);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }


  // Delete Confirmation Dialog
  void _showDeleteConfirmationDialog(BuildContext context, Product product, String token) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text('Are you sure you want to delete ${product.name}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final invoiceState = Provider.of<InvoiceState>(context, listen: false);
                final success = await invoiceState.deleteProduct(product.id, token);

                if (success) {
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(invoiceState.error ?? 'Failed to delete product'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Edit Product Dialog
  void _showEditProductDialog(BuildContext context, Product product) {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController(text: product.name);
    final _descriptionController = TextEditingController(text: product.description);
    final _priceController = TextEditingController(text: product.price.toString());
    final _stockController = TextEditingController(text: product.stock.toString());
    final _categoryController = TextEditingController(text: product.category);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Product'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a product name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(labelText: 'Stock Quantity'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter stock quantity';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid stock quantity';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a category';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final updatedProduct = {
                    'name': _nameController.text,
                    'description': _descriptionController.text,
                    'price': double.parse(_priceController.text),
                    'stock': int.parse(_stockController.text),
                    'category': _categoryController.text,
                  };

                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final token = auth.token;

                  try {
                    final response = await http.put(
                      Uri.parse('${ApiConfig.baseUrl}/api/products/${product.id}'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $token',
                      },
                      body: jsonEncode(updatedProduct),
                    );

                    if (response.statusCode == 200) {
                      final invoiceState = Provider.of<InvoiceState>(context, listen: false);
                      await invoiceState.fetchProducts(token!); // Refresh product list
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Product updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      final errorData = json.decode(response.body);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorData['error'] ?? 'Failed to update product'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Network error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class LowStockAlertScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final invoiceState = Provider.of<InvoiceState>(context);

    // Filter products with stock less than 20
    final lowStockProducts = invoiceState.products.where((product) => product.stock < 20).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Low Stock Alerts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: lowStockProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No low stock products found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: lowStockProducts.length,
                    itemBuilder: (context, index) {
                      final product = lowStockProducts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Description: ${product.description}'),
                              Text('Price: ₹${product.price.toStringAsFixed(2)}'),
                              Text('Stock: ${product.stock}'),
                              Text('Category: ${product.category}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ReportsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final invoiceState = Provider.of<InvoiceState>(context);

    // Calculate daily and monthly income
    final dailyIncome = _calculateDailyIncome(invoiceState.invoices);
    final monthlyIncome = _calculateMonthlyIncome(invoiceState.invoices);

    // Calculate most and least bought products
    final productSales = _calculateProductSales(invoiceState.invoices);
    final mostBoughtProduct = productSales.isNotEmpty ? productSales.first : null;
    final leastBoughtProduct = productSales.isNotEmpty ? productSales.last : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income Reports'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Daily Income and Customers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SfCartesianChart(
  primaryXAxis: CategoryAxis(
    title: AxisTitle(text: 'Date'), // For Daily Income
    labelRotation: 0, // Rotate labels for better readability
    majorGridLines: const MajorGridLines(width: 0), // Remove grid lines
  ),
  primaryYAxis: NumericAxis(
    title: AxisTitle(text: 'Income (₹)'),
  ),
  tooltipBehavior: TooltipBehavior(enable: true),
  series: <CartesianSeries>[
    ColumnSeries<SalesData, String>(
      dataSource: dailyIncome, 
      xValueMapper: (SalesData sales, _) => sales.label,
      yValueMapper: (SalesData sales, _) => sales.value,
      color: Colors.blue, 
      name: 'Daily Income', 
      dataLabelSettings: DataLabelSettings(
        isVisible: true, 
        labelAlignment: ChartDataLabelAlignment.outer, 
        textStyle: const TextStyle(
          fontSize: 12,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ],
),
            const SizedBox(height: 32),
            const Text(
              'Monthly Income and Customers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SfCartesianChart(
              primaryXAxis: CategoryAxis(
                title: AxisTitle(text: 'Month'),
              ),
              primaryYAxis: NumericAxis(
                title: AxisTitle(text: 'Income (₹)'),
              ),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries>[
                ColumnSeries<SalesData, String>(
                  dataSource: monthlyIncome,
                  xValueMapper: (SalesData sales, _) => sales.label,
                  yValueMapper: (SalesData sales, _) => sales.value,
                  color: Colors.green,
                  name: 'Monthly Income',
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Most Bought Product',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            mostBoughtProduct != null
                ? _buildMostBoughtProductCard(mostBoughtProduct)
                : const Text('No data available'),
            const SizedBox(height: 16),
            const Text(
              'Least Bought Product',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            leastBoughtProduct != null
                ? _buildLeastBoughtProductTile(leastBoughtProduct)
                : const Text('No data available'),
          ],
        ),
      ),
    );
  }

  // Helper method to build a styled card for the most bought product
 // Helper method to build a styled card for the most bought product
Widget _buildMostBoughtProductCard(ProductSalesData productData) {
  return Card(
    elevation: 6,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade300, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.yellow, size: 28),
              const SizedBox(width: 8),
              const Text(
                'Most Bought Product',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Product: ${productData.product.name}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quantity Sold: ${productData.quantity} units',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Category: ${productData.product.category}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    ),
  );
}
  // Helper method to build a styled ListTile for the least bought product
  Widget _buildLeastBoughtProductTile(ProductSalesData productData) {
    return ListTile(
      tileColor: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: const Icon(Icons.shopping_cart, color: Colors.red),
      title: Text(
        productData.product.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quantity Sold: ${productData.quantity} units'),
          Text('Category: ${productData.product.category}'),
        ],
      ),
    );
  }

  // Calculate daily income and unique customer count
  List<SalesData> _calculateDailyIncome(List<Invoice> invoices) {
    final Map<String, double> dailyTotals = {};
    final Map<String, Set<String>> dailyCustomers = {};

    for (final invoice in invoices) {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.parse(invoice.date));
      dailyTotals[date] = (dailyTotals[date] ?? 0) + invoice.total;

      // Track unique customers for each day
      dailyCustomers.putIfAbsent(date, () => <String>{}).add(invoice.customer.id!);
    }

    // Sort by date for better chart readability
    final sortedEntries = dailyTotals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries
        .map((entry) {
          final customerCount = dailyCustomers[entry.key]?.length ?? 0;
          return SalesData('${entry.key} ($customerCount customers)', entry.value);
        })
        .toList();
  }

  // Calculate monthly income and unique customer count
  List<SalesData> _calculateMonthlyIncome(List<Invoice> invoices) {
    final Map<String, double> monthlyTotals = {};
    final Map<String, Set<String>> monthlyCustomers = {};

    for (final invoice in invoices) {
      final date = DateTime.parse(invoice.date);
      final month = DateFormat('MMM yyyy').format(DateTime(date.year, date.month));
      monthlyTotals[month] = (monthlyTotals[month] ?? 0) + invoice.total;

      // Track unique customers for each month
      monthlyCustomers.putIfAbsent(month, () => <String>{}).add(invoice.customer.id!);
    }

    // Sort by month for better chart readability
    final sortedEntries = monthlyTotals.entries.toList()
      ..sort((a, b) => DateFormat('MMM yyyy')
          .parse(a.key)
          .compareTo(DateFormat('MMM yyyy').parse(b.key)));

    return sortedEntries
        .map((entry) {
          final customerCount = monthlyCustomers[entry.key]?.length ?? 0;
          return SalesData('${entry.key} ($customerCount customers)', entry.value);
        })
        .toList();
  }

  // Calculate product sales
  List<ProductSalesData> _calculateProductSales(List<Invoice> invoices) {
    final Map<String, ProductSalesData> productSales = {};

    for (final invoice in invoices) {
      for (final item in invoice.items) {
        final productId = item.product.id;
        if (!productSales.containsKey(productId)) {
          productSales[productId] = ProductSalesData(product: item.product, quantity: 0);
        }
        productSales[productId]!.quantity += item.quantity;
      }
    }

    // Sort products by quantity sold in descending order
    final sortedProductSales = productSales.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    return sortedProductSales;
  }
}

class ProductSalesData {
  final Product product;
  int quantity;

  ProductSalesData({required this.product, required this.quantity});
}

class SalesData {
  final String label;
  final double value;

  SalesData(this.label, this.value);
}

