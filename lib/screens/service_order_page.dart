import 'package:flutter/material.dart';
import '../models/service_order.dart';
import '../models/service_order_item.dart';
import '../models/service_catalog.dart';
import '../models/category.dart';
import '../models/employee.dart';
import '../models/customer.dart';
import '../services/firebase_service.dart';
import 'checkout_page.dart';

class ServiceOrderPage extends StatefulWidget {
  final ServiceOrder? existingOrder;

  const ServiceOrderPage({super.key, this.existingOrder});

  @override
  State<ServiceOrderPage> createState() => _ServiceOrderPageState();
}

class _ServiceOrderPageState extends State<ServiceOrderPage> {
  late ServiceOrder _currentOrder;
  List<ServiceOrderItem> _orderItems = [];
  List<ServiceCatalog> _availableServices = [];
  List<ServiceCatalog> _filteredServices = [];
  List<Category> _categories = [];
  List<Employee> _availableEmployees = [];
  List<Customer> _customers = [];
  bool _isLoading = true;
  bool _isSaving = false;
  Customer? _selectedCustomer;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _initializeOrder();
    _loadData();
  }

  void _initializeOrder() {
    if (widget.existingOrder != null) {
      _currentOrder = widget.existingOrder!;
    } else {
      _currentOrder = ServiceOrder(
        orderNumber: ServiceOrder.generateOrderNumber(),
      );
    }
  }

  Future<void> _loadData() async {
    try {
      final futures = await Future.wait([
        FirebaseService.getServices(),
        FirebaseService.getCategories(),
        FirebaseService.getEmployees(),
        FirebaseService.getCustomers(),
        if (widget.existingOrder != null)
          FirebaseService.getServiceOrderItems(_currentOrder.id!),
      ]);

      setState(() {
        _availableServices = futures[0] as List<ServiceCatalog>;
        _categories = futures[1] as List<Category>;
        _availableEmployees = futures[2] as List<Employee>;
        _customers = futures[3] as List<Customer>;
        if (futures.length > 4) {
          _orderItems = futures[4] as List<ServiceOrderItem>;
        }

        // Initialize filtered services
        _filteredServices = _availableServices;

        // Set selected customer if order has one
        if (_currentOrder.customerId != null) {
          _selectedCustomer = _customers.firstWhere(
            (c) => c.id == _currentOrder.customerId,
            orElse: () => _customers.first,
          );
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  void _filterServicesByCategory(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      if (categoryId == null) {
        _filteredServices = _availableServices;
      } else {
        _filteredServices = _availableServices
            .where((service) => service.categoryId == categoryId)
            .toList();
      }
    });
  }

  double get _subtotal {
    return _orderItems.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  double get _total {
    double subtotal = _subtotal;
    double discount =
        _currentOrder.orderDiscount?.calculateDiscount(subtotal) ?? 0.0;
    return subtotal - discount + _currentOrder.taxAmount;
  }

  Future<void> _saveOrder() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Update order totals
      final updatedOrder = _currentOrder.copyWith(
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.displayName,
        subtotal: _subtotal,
        discountAmount:
            _currentOrder.orderDiscount?.calculateDiscount(_subtotal) ?? 0.0,
        total: _total,
        technicianIds: _orderItems
            .map((item) => item.technicianId)
            .toSet()
            .toList(),
        serviceOrderItemIds: _orderItems.map((item) => item.id!).toList(),
      );

      if (_currentOrder.id == null) {
        // Create new order
        final orderId = await FirebaseService.addServiceOrder(updatedOrder);
        _currentOrder = updatedOrder.copyWith(id: orderId);

        // Save all order items with the order ID
        for (var item in _orderItems) {
          final updatedItem = item.copyWith(serviceOrderId: orderId);
          final itemId = await FirebaseService.addServiceOrderItem(updatedItem);
          // Update local item with ID
          final index = _orderItems.indexOf(item);
          _orderItems[index] = updatedItem.copyWith(id: itemId);
        }
      } else {
        // Update existing order
        await FirebaseService.saveServiceOrder(updatedOrder);
        _currentOrder = updatedOrder;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving order: $e')));
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _addServiceWithTechnician(ServiceCatalog service) {
    showDialog(
      context: context,
      builder: (context) => _TechnicianSelectionDialog(
        service: service,
        availableEmployees: _availableEmployees,
        onAdd: (employee, quantity) {
          setState(() {
            final item = ServiceOrderItem(
              serviceOrderId: _currentOrder.id ?? '',
              serviceCatalogId: service.id,
              serviceName: service.name,
              serviceDescription: service.description,
              originalPrice: service.price,
              quantity: quantity,
              technicianId: employee.id,
              technicianName: employee.name,
              estimatedDurationMinutes: service.durationMinutes,
            );
            _orderItems.add(item);
          });
        },
      ),
    );
  }

  void _removeServiceItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
    });
  }

  void _updateItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeServiceItem(index);
      return;
    }

    setState(() {
      _orderItems[index] = _orderItems[index].copyWith(quantity: newQuantity);
    });
  }

  void _proceedToCheckout() async {
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one service item')),
      );
      return;
    }

    // Save order first
    await _saveOrder();

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CheckoutPage(
            serviceOrder: _currentOrder,
            orderItems: _orderItems,
            customer: _selectedCustomer,
          ),
        ),
      );
    }
  }

  Widget _buildServiceCard(ServiceCatalog service) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _addServiceWithTechnician(service),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.content_cut,
                      color: Colors.blue.shade700,
                      size: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '\$${service.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                service.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (service.description.isNotEmpty)
                Text(
                  service.description,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${service.durationMinutes} min',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptItem(ServiceOrderItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.serviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeServiceItem(index),
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.person, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                item.technicianName,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        _updateItemQuantity(index, item.quantity - 1),
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      item.quantity.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        _updateItemQuantity(index, item.quantity + 1),
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              Text(
                '\$${item.lineTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Service Order'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentOrder.id == null
              ? 'New Service Order'
              : 'Order ${_currentOrder.orderNumber}',
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
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
              onPressed: _saveOrder,
              icon: const Icon(Icons.save),
              tooltip: 'Save Order',
            ),
        ],
      ),
      body: Row(
        children: [
          // Left side - Service Selection
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Order Header
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.grey.shade100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order: ${_currentOrder.orderNumber}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Status: ${_currentOrder.status.displayName}',
                                  style: TextStyle(
                                    color: _getStatusColor(
                                      _currentOrder.status,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Customer Selection
                      Row(
                        children: [
                          const Text(
                            'Customer: ',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Expanded(
                            child: DropdownButton<Customer?>(
                              value: _selectedCustomer,
                              hint: const Text('Select Customer (Optional)'),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<Customer?>(
                                  value: null,
                                  child: Text('Walk-in Customer'),
                                ),
                                ..._customers.map(
                                  (customer) => DropdownMenuItem<Customer?>(
                                    value: customer,
                                    child: Text(customer.displayName),
                                  ),
                                ),
                              ],
                              onChanged: (customer) {
                                setState(() {
                                  _selectedCustomer = customer;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Service Selection Cards
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Services',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Category Filter Chips
                        if (_categories.isNotEmpty)
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                FilterChip(
                                  label: const Text('All'),
                                  selected: _selectedCategoryId == null,
                                  onSelected: (selected) {
                                    if (selected)
                                      _filterServicesByCategory(null);
                                  },
                                ),
                                const SizedBox(width: 8),
                                ..._categories.map((category) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: FilterChip(
                                      label: Text(category.name),
                                      selected:
                                          _selectedCategoryId == category.id,
                                      onSelected: (selected) {
                                        if (selected) {
                                          _filterServicesByCategory(
                                            category.id,
                                          );
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1.2,
                                ),
                            itemCount: _filteredServices.length,
                            itemBuilder: (context, index) {
                              final service = _filteredServices[index];
                              return _buildServiceCard(service);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right side - Running Receipt
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Receipt Header
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.blue.shade700,
                  child: const Row(
                    children: [
                      Icon(Icons.receipt, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Order Receipt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Receipt Items
                Expanded(
                  child: _orderItems.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No items added',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'Select services to add them here',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _orderItems.length,
                          itemBuilder: (context, index) {
                            final item = _orderItems[index];
                            return _buildReceiptItem(item, index);
                          },
                        ),
                ),

                // Receipt Total
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:'),
                          Text('\$${_subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total (${_orderItems.length} items):',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${_total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _orderItems.isNotEmpty
                              ? _proceedToCheckout
                              : null,
                          icon: const Icon(Icons.payment),
                          label: const Text('Proceed to Checkout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Color _getStatusColor(ServiceOrderStatus status) {
    switch (status) {
      case ServiceOrderStatus.newOrder:
        return Colors.blue;
      case ServiceOrderStatus.inProgress:
        return Colors.orange;
      case ServiceOrderStatus.completed:
        return Colors.green;
      case ServiceOrderStatus.cancelled:
        return Colors.red;
    }
  }
}

class _TechnicianSelectionDialog extends StatefulWidget {
  final ServiceCatalog service;
  final List<Employee> availableEmployees;
  final Function(Employee employee, int quantity) onAdd;

  const _TechnicianSelectionDialog({
    required this.service,
    required this.availableEmployees,
    required this.onAdd,
  });

  @override
  State<_TechnicianSelectionDialog> createState() =>
      _TechnicianSelectionDialogState();
}

class _TechnicianSelectionDialogState
    extends State<_TechnicianSelectionDialog> {
  Employee? _selectedEmployee;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.service.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.service.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text('\$${widget.service.price.toStringAsFixed(2)}'),
                Text('Duration: ${widget.service.durationMinutes} minutes'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Employee Selection
          const Text(
            'Select Technician:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          ...widget.availableEmployees.map((employee) {
            return RadioListTile<Employee>(
              title: Text(employee.name),
              subtitle: Text(employee.email),
              value: employee,
              groupValue: _selectedEmployee,
              onChanged: (Employee? value) {
                setState(() {
                  _selectedEmployee = value;
                });
              },
            );
          }),
          const SizedBox(height: 16),

          // Quantity Selection
          Row(
            children: [
              const Text('Quantity: '),
              IconButton(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                _quantity.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedEmployee != null
              ? () {
                  widget.onAdd(_selectedEmployee!, _quantity);
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Add to Order'),
        ),
      ],
    );
  }
}
