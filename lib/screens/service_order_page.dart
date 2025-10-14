import 'package:flutter/material.dart';
import '../models/service_order.dart';
import '../models/service_order_item.dart';
import '../models/service_catalog.dart';
import '../models/category.dart';
import '../models/employee.dart';
import '../models/customer.dart';
import '../services/firebase_service.dart';

enum PaymentMethod { cash, credit, debit }

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

  // Loyalty points settings
  double _pointsPerDollar = 1.0;
  int _loyaltyPointsToEarn = 0;
  @override
  void initState() {
    super.initState();
    _initializeOrder();
    _loadData();
    _loadLoyaltySettings();
  }

  void _initializeOrder() async {
    if (widget.existingOrder != null) {
      _currentOrder = widget.existingOrder!;
    } else {
      // Generate proper daily sequential order number
      final orderNumber = await FirebaseService.generateDailyOrderNumber();
      _currentOrder = ServiceOrder(orderNumber: orderNumber);
      setState(() {}); // Refresh UI with the new order number
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
      // Update order with current items and total
      final updatedOrder = _currentOrder.copyWith(
        subtotal: _subtotal,
        total: _total,
      );

      if (updatedOrder.id == null) {
        final orderId = await FirebaseService.addServiceOrder(updatedOrder);
        _currentOrder = updatedOrder.copyWith(id: orderId);
      } else {
        await FirebaseService.saveServiceOrder(updatedOrder);
        _currentOrder = updatedOrder;
      }

      // Save all order items
      for (final item in _orderItems) {
        final updatedItem = item.copyWith(serviceOrderId: _currentOrder.id!);
        await FirebaseService.saveServiceOrderItem(updatedItem);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order saved successfully'),
            backgroundColor: Colors.green,
          ),
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

  Future<void> _saveOrderForLater() async {
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one service item')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Save order with "in progress" status for later completion
      final orderToSave = _currentOrder.copyWith(
        status: ServiceOrderStatus.inProgress,
        subtotal: _subtotal,
        total: _total,
      );

      if (orderToSave.id == null) {
        final orderId = await FirebaseService.addServiceOrder(orderToSave);
        _currentOrder = orderToSave.copyWith(id: orderId);
      } else {
        await FirebaseService.saveServiceOrder(orderToSave);
        _currentOrder = orderToSave;
      }

      // Save all order items
      for (final item in _orderItems) {
        final updatedItem = item.copyWith(serviceOrderId: _currentOrder.id!);
        await FirebaseService.saveServiceOrderItem(updatedItem);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order saved for later completion'),
            backgroundColor: Colors.blue,
          ),
        );
        // Navigate back to dashboard
        Navigator.of(context).pop();
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

  // Show delete confirmation dialog
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Service Order'),
          content: Text(
            'Are you sure you want to delete Order #${_currentOrder.orderNumber}?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteServiceOrder();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Delete service order
  Future<void> _deleteServiceOrder() async {
    try {
      setState(() {
        _isSaving = true;
      });

      await FirebaseService.deleteServiceOrder(_currentOrder.id!);

      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${_currentOrder.orderNumber} deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Go back to previous screen
      }
    } catch (e) {
      print('Error deleting service order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete service order'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
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

    // Calculate loyalty points for checkout
    _calculateLoyaltyPoints();

    // Show checkout modal dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CheckoutDialog(
        currentOrder: _currentOrder,
        orderItems: _orderItems,
        selectedCustomer: _selectedCustomer,
        loyaltyPointsToEarn: _loyaltyPointsToEarn,
        onPaymentComplete: () {
          // Update the current order status to completed
          setState(() {
            _currentOrder = _currentOrder.copyWith(
              status: ServiceOrderStatus.completed,
              completedAt: DateTime.now(),
            );
          });
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pop(); // Return to dashboard
        },
      ),
    );
  } // Checkout-related methods

  Future<void> _loadLoyaltySettings() async {
    try {
      final config = await FirebaseService.getLoyaltyPointsConfig();
      setState(() {
        _pointsPerDollar = config['pointsPerDollar']?.toDouble() ?? 1.0;
      });
      _calculateLoyaltyPoints();
    } catch (e) {
      print('Error loading loyalty settings: $e');
    }
  }

  void _calculateLoyaltyPoints() {
    final totalAmount = _total;
    _loyaltyPointsToEarn = FirebaseService.calculateLoyaltyPoints(
      totalAmount,
      _pointsPerDollar,
    );
    setState(() {});
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
          else ...[
            // Delete button - only show for existing orders
            if (_currentOrder.id != null)
              IconButton(
                onPressed: _showDeleteConfirmation,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete Order',
              ),
            // Save button - saves order for later
            IconButton(
              onPressed: _saveOrderForLater,
              icon: const Icon(Icons.save),
              tooltip: 'Save for Later',
            ),
            // Checkout button - only show if order has items and isn't completed
            if (_orderItems.isNotEmpty &&
                _currentOrder.status != ServiceOrderStatus.completed)
              TextButton.icon(
                onPressed: _proceedToCheckout,
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                label: const Text(
                  'Checkout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ],
      ),
      body: _buildOrderCreationUI(),
    );
  }

  Widget _buildOrderCreationUI() {
    return Row(
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
                                'Order #${_currentOrder.orderNumber}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Status: ${_currentOrder.status.name}',
                                style: TextStyle(
                                  color: _getStatusColor(_currentOrder.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_currentOrder.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _currentOrder.status.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Customer>(
                            decoration: const InputDecoration(
                              labelText: 'Select Customer',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedCustomer,
                            items: _customers.map((customer) {
                              return DropdownMenuItem(
                                value: customer,
                                child: Text(customer.displayName),
                              );
                            }).toList(),
                            onChanged: (Customer? customer) {
                              setState(() {
                                _selectedCustomer = customer;
                                _currentOrder = _currentOrder.copyWith(
                                  customerId: customer?.id,
                                );
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
                                  if (selected) _filterServicesByCategory(null);
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
                                        _filterServicesByCategory(category.id);
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
                              'Select services to add them',
                              style: TextStyle(
                                fontSize: 12,
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
                          return _buildReceiptItem(_orderItems[index], index);
                        },
                      ),
              ),

              // Receipt Summary
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal (${_orderItems.length} items):',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          '\$${_subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_currentOrder.orderDiscount != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                            ),
                          ),
                          Text(
                            '-\$${_currentOrder.orderDiscount!.calculateDiscount(_subtotal).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_currentOrder.taxAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tax:', style: TextStyle(fontSize: 12)),
                          Text(
                            '\$${_currentOrder.taxAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Order Status Display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          _currentOrder.status,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getStatusColor(_currentOrder.status),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getStatusIcon(_currentOrder.status),
                            color: _getStatusColor(_currentOrder.status),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status: ${_currentOrder.status.displayName}',
                            style: TextStyle(
                              color: _getStatusColor(_currentOrder.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons
                    if (_currentOrder.status ==
                        ServiceOrderStatus.completed) ...[
                      // Show completion info for completed orders
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order Completed',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_currentOrder.completedAt != null)
                              Text(
                                'Completed on ${_formatDateTime(_currentOrder.completedAt!)}',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Show checkout button for incomplete orders
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _removeOrderItem(index),
                color: Colors.red.shade600,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.technicianName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.quantity}x \$${item.originalPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '\$${item.lineTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addServiceWithTechnician(ServiceCatalog service) {
    showDialog(
      context: context,
      builder: (context) => _TechnicianSelectionDialog(
        service: service,
        availableEmployees: _availableEmployees,
        onAdd: (employee, quantity) {
          _addServiceOrderItem(service, employee, quantity);
        },
      ),
    );
  }

  void _addServiceOrderItem(
    ServiceCatalog service,
    Employee employee,
    int quantity,
  ) {
    final item = ServiceOrderItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      serviceOrderId: _currentOrder.id ?? '',
      serviceCatalogId: service.id,
      serviceName: service.name,
      serviceDescription: service.description,
      originalPrice: service.price,
      quantity: quantity,
      technicianId: employee.id,
      technicianName: employee.name,
      discountAmount: 0.0,
      status: ServiceOrderItemStatus.pending,
      createdAt: DateTime.now(),
    );

    setState(() {
      _orderItems.add(item);
    });
  }

  void _removeOrderItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text(
          'Are you sure you want to remove "${_orderItems[index].serviceName}" from this order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _orderItems.removeAt(index);
              });
              Navigator.of(context).pop();
            },
            child: const Text('Remove'),
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

  IconData _getStatusIcon(ServiceOrderStatus status) {
    switch (status) {
      case ServiceOrderStatus.newOrder:
        return Icons.fiber_new;
      case ServiceOrderStatus.inProgress:
        return Icons.hourglass_bottom;
      case ServiceOrderStatus.completed:
        return Icons.check_circle;
      case ServiceOrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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

class _CheckoutDialog extends StatefulWidget {
  final ServiceOrder currentOrder;
  final List<ServiceOrderItem> orderItems;
  final Customer? selectedCustomer;
  final int loyaltyPointsToEarn;
  final VoidCallback onPaymentComplete;

  const _CheckoutDialog({
    required this.currentOrder,
    required this.orderItems,
    this.selectedCustomer,
    required this.loyaltyPointsToEarn,
    required this.onPaymentComplete,
  });

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  bool _isProcessing = false;

  double get _subtotal {
    return widget.orderItems.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  double get _total {
    return _subtotal; // Simplified for now, can add tax/discount logic later
  }

  Future<void> _processPayment() async {
    // If cash is selected, show cash input dialog first
    if (_selectedPaymentMethod == PaymentMethod.cash) {
      final cashReceived = await showDialog<double>(
        context: context,
        builder: (context) => _CashInputDialog(defaultAmount: _total),
      );

      if (cashReceived == null) return; // User cancelled

      if (cashReceived < _total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient cash received')),
        );
        return;
      }

      // Process with the received cash amount
      await _completePayment(cashReceived);
    } else {
      // Process non-cash payments directly
      await _completePayment(null);
    }
  }

  Future<void> _completePayment(double? cashReceived) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Update order with final details
      final finalOrder = widget.currentOrder.copyWith(
        status: ServiceOrderStatus.completed,
        subtotal: _subtotal,
        total: _total,
        paymentMethod: _selectedPaymentMethod.name,
        completedAt: DateTime.now(),
      );

      // Save order and items
      await FirebaseService.saveServiceOrder(finalOrder);

      // Update items
      for (final item in widget.orderItems) {
        await FirebaseService.saveServiceOrderItem(item);
      }

      // Update customer loyalty points if customer is selected
      if (widget.selectedCustomer != null) {
        final updatedCustomer = widget.selectedCustomer!.copyWith(
          loyaltyPoints:
              widget.selectedCustomer!.loyaltyPoints +
              widget.loyaltyPointsToEarn,
          totalSpent: widget.selectedCustomer!.totalSpent + _total,
        );
        await FirebaseService.saveCustomer(updatedCustomer);
      }

      if (mounted) {
        // Show success message
        String successMessage = 'Payment processed successfully!';

        // Show change notification popup if there's change due
        if (cashReceived != null && cashReceived > _total) {
          final change = cashReceived - _total;
          _showChangeNotification(change);
          successMessage += ' Change: \$${change.toStringAsFixed(2)}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );

        widget.onPaymentComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing payment: $e')));
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showChangeNotification(double changeAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Change Due',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '\$${changeAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please give this amount to the customer',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    // Auto-close after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Checkout - ${widget.currentOrder.orderNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Info
                    if (widget.selectedCustomer != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(widget.selectedCustomer!.displayName),
                              Text(
                                'Loyalty Points: ${widget.selectedCustomer!.loyaltyPoints}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Order Summary
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Order Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...widget.orderItems.map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.quantity}x ${item.serviceName}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      '\$${item.lineTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const Divider(),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Method
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Method',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...PaymentMethod.values.map((method) {
                              return RadioListTile<PaymentMethod>(
                                title: Text(method.name.toUpperCase()),
                                value: method,
                                groupValue: _selectedPaymentMethod,
                                onChanged: (PaymentMethod? value) {
                                  setState(() {
                                    _selectedPaymentMethod = value!;
                                  });
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (widget.selectedCustomer != null &&
                        widget.loyaltyPointsToEarn > 0)
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.stars, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Loyalty Points to Earn: ${widget.loyaltyPointsToEarn}',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
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

            // Footer with buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Processing...'),
                              ],
                            )
                          : Text(
                              'Process Payment - \$${_total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashInputDialog extends StatefulWidget {
  final double defaultAmount;

  const _CashInputDialog({required this.defaultAmount});

  @override
  State<_CashInputDialog> createState() => _CashInputDialogState();
}

class _CashInputDialogState extends State<_CashInputDialog> {
  String _amount = '';
  String _displayAmount = '0.00';

  @override
  void initState() {
    super.initState();
    // Start with empty input
    _amount = '';
    _displayAmount = '0.00';
  }

  void _onNumberPressed(String number) {
    setState(() {
      // If amount is empty or just "0", start fresh
      if (_amount.isEmpty || _amount == '0') {
        _amount = number;
      } else {
        _amount += number;
      }
      _updateDisplay();
    });
  }

  void _onDecimalPressed() {
    setState(() {
      if (_amount.isEmpty) {
        _amount = '0.';
      } else if (!_amount.contains('.')) {
        _amount += '.';
      }
      _updateDisplay();
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_amount.isNotEmpty) {
        _amount = _amount.substring(0, _amount.length - 1);
        _updateDisplay();
      }
    });
  }

  void _onClearPressed() {
    setState(() {
      _amount = '';
      _displayAmount = '0.00';
    });
  }

  void _onFullAmountPressed() {
    setState(() {
      _amount = widget.defaultAmount.toString();
      _updateDisplay();
    });
  }

  void _updateDisplay() {
    if (_amount.isEmpty) {
      _displayAmount = '0.00';
      return;
    }

    final parsed = double.tryParse(_amount);
    if (parsed != null) {
      _displayAmount = parsed.toStringAsFixed(2);
    } else {
      // Show partial input (like "12." while typing)
      _displayAmount = _amount;
    }
  }

  double get _changeAmount {
    if (_amount.isEmpty) return -widget.defaultAmount;
    final received = double.tryParse(_amount) ?? 0.0;
    return received - widget.defaultAmount;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'Cash Received',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 20),

            // Order total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Order Total:', style: TextStyle(fontSize: 16)),
                  Text(
                    '\$${widget.defaultAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Cash amount display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '\$',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _displayAmount,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Change/Error display
            if (_amount.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _changeAmount >= 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _changeAmount >= 0
                          ? Icons.account_balance_wallet
                          : Icons.warning,
                      color: _changeAmount >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _changeAmount >= 0
                          ? 'Change: \$${_changeAmount.toStringAsFixed(2)}'
                          : 'Insufficient amount: \$${(-_changeAmount).toStringAsFixed(2)} more needed',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _changeAmount >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Quick action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _onFullAmountPressed,
                    icon: const Icon(Icons.money, size: 18),
                    label: Text(
                      'Full Amount (\$${widget.defaultAmount.toStringAsFixed(2)})',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _onClearPressed,
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Number pad
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Row 1: 7, 8, 9
                  Row(
                    children: [
                      _buildNumberButton('7'),
                      _buildNumberButton('8'),
                      _buildNumberButton('9'),
                    ],
                  ),
                  // Row 2: 4, 5, 6
                  Row(
                    children: [
                      _buildNumberButton('4'),
                      _buildNumberButton('5'),
                      _buildNumberButton('6'),
                    ],
                  ),
                  // Row 3: 1, 2, 3
                  Row(
                    children: [
                      _buildNumberButton('1'),
                      _buildNumberButton('2'),
                      _buildNumberButton('3'),
                    ],
                  ),
                  // Row 4: ., 0, Backspace
                  Row(
                    children: [
                      _buildActionButton('.', Icons.circle, _onDecimalPressed),
                      _buildNumberButton('0'),
                      _buildActionButton(
                        '⌫',
                        Icons.backspace,
                        _onBackspacePressed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _changeAmount >= 0 && _amount.isNotEmpty
                        ? () {
                            final amount = double.tryParse(_amount) ?? 0.0;
                            if (amount >= widget.defaultAmount) {
                              Navigator.of(context).pop(amount);
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Expanded(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: TextButton(
          onPressed: () => _onNumberPressed(number),
          style: TextButton.styleFrom(shape: const RoundedRectangleBorder()),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            shape: const RoundedRectangleBorder(),
            backgroundColor: Colors.grey.shade50,
          ),
          child: Icon(icon, size: 24, color: Colors.black87),
        ),
      ),
    );
  }
}
