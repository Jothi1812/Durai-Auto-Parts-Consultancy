import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Import from your main.dart
// This is a separate component for customer search

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
    filteredCustomers = widget.customers;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredCustomers = widget.customers;
      } else {
        filteredCustomers = widget.customers
            .where((customer) =>
                customer.name.toLowerCase().contains(query.toLowerCase()) ||
                customer.email.toLowerCase().contains(query.toLowerCase()) ||
                customer.phone.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Customer'),
      content: Container(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Customers',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _filterCustomers,
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: filteredCustomers.length,
                itemBuilder: (context, index) {
                  final customer = filteredCustomers[index];
                  return ListTile(
                    title: Text(customer.name),
                    subtitle: Text('${customer.email} • ${customer.phone}'),
                    onTap: () {
                      widget.onCustomerSelected(customer);
                      Navigator.of(context).pop();
                    },
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
