import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../provider/catalog_provider.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CatalogProvider>(context, listen: false).loadAllData();
    });
  }

  List<Customer> _getFilteredCustomers(List<Customer> customers) {
    if (_searchQuery.isEmpty) return customers;

    return customers.where((customer) {
      final query = _searchQuery.toLowerCase();
      return customer.firstName.toLowerCase().contains(query) ||
          customer.lastName.toLowerCase().contains(query) ||
          (customer.email?.toLowerCase().contains(query) ?? false) ||
          (customer.phone?.contains(query) ?? false);
    }).toList();
  }

  void _addCustomer() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const CustomerEditPage()))
        .then((result) {
          if (result == true) {
            Provider.of<CatalogProvider>(context, listen: false).loadAllData();
          }
        });
  }

  void _editCustomer(Customer customer) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => CustomerEditPage(customer: customer),
          ),
        )
        .then((result) {
          if (result == true) {
            Provider.of<CatalogProvider>(context, listen: false).loadAllData();
          }
        });
  }

  void _deleteCustomer(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete ${customer.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await Provider.of<CatalogProvider>(
                  context,
                  listen: false,
                ).deleteCustomer(customer.id!);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Customer deleted successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting customer: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CatalogProvider>(
      builder: (context, catalogProvider, child) {
        final filteredCustomers = _getFilteredCustomers(
          catalogProvider.customers,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Customer Management'),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                onPressed: _addCustomer,
                icon: const Icon(Icons.person_add),
                tooltip: 'Add Customer',
              ),
            ],
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // Customer Count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(
                      '${filteredCustomers.length} customers',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty) ...[
                      Text(
                        ' (filtered from ${catalogProvider.customers.length})',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Customer List
              Expanded(
                child: catalogProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No customers found'
                                  : 'No customers yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (_searchQuery.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Tap the + button to add your first customer',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => catalogProvider.loadAllData(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = filteredCustomers[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    customer.firstName.isNotEmpty
                                        ? customer.firstName[0].toUpperCase()
                                        : customer.lastName.isNotEmpty
                                        ? customer.lastName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  customer.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(customer.primaryContact),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.stars,
                                          size: 16,
                                          color: Colors.amber.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${customer.loyaltyPoints} points',
                                        ),
                                        const SizedBox(width: 16),
                                        Icon(
                                          Icons.attach_money,
                                          size: 16,
                                          color: Colors.green.shade600,
                                        ),
                                        Text(
                                          '\$${customer.totalSpent.toStringAsFixed(2)}',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _editCustomer(customer);
                                        break;
                                      case 'delete':
                                        _deleteCustomer(customer);
                                        break;
                                    }
                                  },
                                ),
                                onTap: () => _editCustomer(customer),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _addCustomer,
            backgroundColor: Colors.blue.shade700,
            child: const Icon(Icons.person_add, color: Colors.white),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class CustomerEditPage extends StatefulWidget {
  final Customer? customer;

  const CustomerEditPage({super.key, this.customer});

  @override
  State<CustomerEditPage> createState() => _CustomerEditPageState();
}

class _CustomerEditPageState extends State<CustomerEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _loyaltyPointsController = TextEditingController();

  bool _isLoading = false;
  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _firstNameController.text = widget.customer!.firstName;
      _lastNameController.text = widget.customer!.lastName;
      _emailController.text = widget.customer!.email ?? '';
      _phoneController.text = widget.customer!.phone ?? '';
      _addressController.text = widget.customer!.address ?? '';
      _notesController.text = widget.customer!.notes ?? '';
      _birthdayController.text = widget.customer!.birthday ?? '';
      _loyaltyPointsController.text = widget.customer!.loyaltyPoints.toString();
    } else {
      _loyaltyPointsController.text = '0';
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final customer = Customer(
        id: widget.customer?.id,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        birthday: _birthdayController.text.trim().isEmpty
            ? null
            : _birthdayController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        loyaltyPoints: int.tryParse(_loyaltyPointsController.text) ?? 0,
        createdAt: widget.customer?.createdAt ?? DateTime.now(),
        totalSpent: widget.customer?.totalSpent ?? 0.0,
        totalVisits: widget.customer?.totalVisits ?? 0,
        orderHistory: widget.customer?.orderHistory ?? [],
        lastVisit: widget.customer?.lastVisit,
      );

      if (_isEditing) {
        await Provider.of<CatalogProvider>(
          context,
          listen: false,
        ).updateCustomer(customer);
      } else {
        await Provider.of<CatalogProvider>(
          context,
          listen: false,
        ).addCustomer(customer);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Customer updated successfully'
                  : 'Customer added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving customer: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Customer' : 'Add Customer'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              onPressed: _saveCustomer,
              icon: const Icon(Icons.save),
              tooltip: 'Save Customer',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Info Section
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
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'First Name *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'First name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Last Name *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Last name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value.trim())) {
                              return 'Please enter a valid email address';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone *',
                          border: OutlineInputBorder(),
                          helperText: 'Required for customer identification',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _birthdayController,
                        decoration: const InputDecoration(
                          labelText: 'Birthday (MM-DD) *',
                          border: OutlineInputBorder(),
                          helperText:
                              'Format: MM-DD (e.g., 03-15 for March 15th)',
                        ),
                        keyboardType: TextInputType.datetime,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Birthday is required for promotions';
                          }
                          final birthday = value.trim();
                          if (!RegExp(r'^\d{2}-\d{2}$').hasMatch(birthday)) {
                            return 'Please use MM-DD format (e.g., 03-15)';
                          }
                          final parts = birthday.split('-');
                          final month = int.tryParse(parts[0]);
                          final day = int.tryParse(parts[1]);
                          if (month == null || month < 1 || month > 12) {
                            return 'Month must be between 01 and 12';
                          }
                          if (day == null || day < 1 || day > 31) {
                            return 'Day must be between 01 and 31';
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
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Loyalty Points Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loyalty Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _loyaltyPointsController,
                        decoration: const InputDecoration(
                          labelText: 'Loyalty Points',
                          border: OutlineInputBorder(),
                          helperText:
                              'Adjust customer loyalty points manually if needed',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final points = int.tryParse(value ?? '');
                          if (points == null || points < 0) {
                            return 'Please enter a valid number of points';
                          }
                          return null;
                        },
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Spent',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '\$${widget.customer!.totalSpent.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Visits',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${widget.customer!.totalVisits}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.customer!.lastVisit != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Last Visit: ${_formatDate(widget.customer!.lastVisit!)}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Notes',
                          border: OutlineInputBorder(),
                          helperText: 'Any special notes about this customer',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCustomer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isEditing ? 'Update Customer' : 'Add Customer',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _loyaltyPointsController.dispose();
    super.dispose();
  }
}
