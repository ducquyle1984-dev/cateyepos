import 'package:flutter/material.dart';
import '../models/service_order.dart';
import '../models/service_order_item.dart';
import '../models/service_catalog.dart';
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
  List<Employee> _availableEmployees = [];
  List<Customer> _customers = [];
  bool _isLoading = true;
  bool _isSaving = false;
  Customer? _selectedCustomer;

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
        FirebaseService.getEmployees(),
        FirebaseService.getCustomers(),
        if (widget.existingOrder != null)
          FirebaseService.getServiceOrderItems(_currentOrder.id!),
      ]);

      setState(() {
        _availableServices = futures[0] as List<ServiceCatalog>;
        _availableEmployees = futures[1] as List<Employee>;
        _customers = futures[2] as List<Customer>;
        if (futures.length > 3) {
          _orderItems = futures[3] as List<ServiceOrderItem>;
        }

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

  void _addServiceItem() {
    showDialog(
      context: context,
      builder: (context) => _AddServiceItemDialog(
        availableServices: _availableServices,
        availableEmployees: _availableEmployees,
        onAdd: (service, employee, quantity) {
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
      body: Column(
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
                              color: _getStatusColor(_currentOrder.status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Created: ${_formatDate(_currentOrder.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total: \$${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          '${_orderItems.length} items',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
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

          // Service Items List
          Expanded(
            child: _orderItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No services added yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to add services',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _orderItems.length,
                    itemBuilder: (context, index) {
                      final item = _orderItems[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              item.quantity.toString(),
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            item.serviceName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Technician: ${item.technicianName}'),
                              Text(
                                'Price: \$${item.originalPrice.toStringAsFixed(2)} each',
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${item.lineTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _updateItemQuantity(
                                      index,
                                      item.quantity - 1,
                                    ),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    iconSize: 20,
                                  ),
                                  Text(item.quantity.toString()),
                                  IconButton(
                                    onPressed: () => _updateItemQuantity(
                                      index,
                                      item.quantity + 1,
                                    ),
                                    icon: const Icon(Icons.add_circle_outline),
                                    iconSize: 20,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Order Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:', style: TextStyle(fontSize: 16)),
                    Text(
                      '\$${_subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                if (_currentOrder.orderDiscount != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discount (${_currentOrder.orderDiscount!.name}):',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        '-\$${_currentOrder.orderDiscount!.calculateDiscount(_subtotal).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, color: Colors.red),
                      ),
                    ],
                  ),
                ],
                if (_currentOrder.taxAmount > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax:', style: TextStyle(fontSize: 16)),
                      Text(
                        '\$${_currentOrder.taxAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
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
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addServiceItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Service'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _orderItems.isNotEmpty
                            ? _proceedToCheckout
                            : null,
                        icon: const Icon(Icons.payment),
                        label: const Text('Checkout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
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

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _AddServiceItemDialog extends StatefulWidget {
  final List<ServiceCatalog> availableServices;
  final List<Employee> availableEmployees;
  final Function(ServiceCatalog service, Employee employee, int quantity) onAdd;

  const _AddServiceItemDialog({
    required this.availableServices,
    required this.availableEmployees,
    required this.onAdd,
  });

  @override
  State<_AddServiceItemDialog> createState() => _AddServiceItemDialogState();
}

class _AddServiceItemDialogState extends State<_AddServiceItemDialog> {
  ServiceCatalog? _selectedService;
  Employee? _selectedEmployee;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Service Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Service Selection
          DropdownButtonFormField<ServiceCatalog>(
            value: _selectedService,
            decoration: const InputDecoration(
              labelText: 'Service',
              border: OutlineInputBorder(),
            ),
            items: widget.availableServices.map((service) {
              return DropdownMenuItem(
                value: service,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name),
                    Text(
                      '\$${service.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (service) {
              setState(() {
                _selectedService = service;
              });
            },
            validator: (value) =>
                value == null ? 'Please select a service' : null,
          ),
          const SizedBox(height: 16),

          // Employee Selection
          DropdownButtonFormField<Employee>(
            value: _selectedEmployee,
            decoration: const InputDecoration(
              labelText: 'Technician',
              border: OutlineInputBorder(),
            ),
            items: widget.availableEmployees.map((employee) {
              return DropdownMenuItem(
                value: employee,
                child: Text(employee.name),
              );
            }).toList(),
            onChanged: (employee) {
              setState(() {
                _selectedEmployee = employee;
              });
            },
            validator: (value) =>
                value == null ? 'Please select a technician' : null,
          ),
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
              Text(_quantity.toString()),
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
          onPressed: _selectedService != null && _selectedEmployee != null
              ? () {
                  widget.onAdd(
                    _selectedService!,
                    _selectedEmployee!,
                    _quantity,
                  );
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
