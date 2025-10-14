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
  final String? preSelectedTechnicianId;

  const ServiceOrderPage({
    super.key,
    this.existingOrder,
    this.preSelectedTechnicianId,
  });

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
  String? _preSelectedTechnicianId; // Track pre-selected technician from dashboard

  // Loyalty points settings
  double _pointsPerDollar = 1.0;
  int _loyaltyPointsToEarn = 0;

  @override
  void initState() {
    super.initState();
    _preSelectedTechnicianId = widget.preSelectedTechnicianId;
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
  }

  // Checkout-related methods
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

              // Technician Selector
              Container(
                padding: const EdgeInsets.all(16.0),
                child: _buildTechnicianSelector(),
              ),

              // Service Selection
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
                                  if (selected) {
                                    _filterServicesByCategory(null);
                                  }
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

                      // Service Grid
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
                child: Container(
                  constraints: const BoxConstraints(minHeight: 100),
                  child: _buildGroupedReceiptItems(),
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
                    // Subtotal
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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Order discount display
                    if (_currentOrder.orderDiscount != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount (${_currentOrder.orderDiscount!.name}):',
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

                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Total
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
                    const SizedBox(height: 16),

                    // Quick Discount Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_offer,
                                size: 16,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Quick Discounts',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Percentage presets
                          const Text(
                            'Percentage:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              _buildQuickDiscountButton('5%', 5, true),
                              _buildQuickDiscountButton('10%', 10, true),
                              _buildQuickDiscountButton('15%', 15, true),
                              _buildQuickDiscountButton('20%', 20, true),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Fixed amount presets
                          const Text(
                            'Fixed Amount:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              _buildQuickDiscountButton('\$5', 5, false),
                              _buildQuickDiscountButton('\$10', 10, false),
                              _buildQuickDiscountButton('\$20', 20, false),
                              _buildQuickDiscountButton('\$50', 50, false),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Apply to options
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _orderItems.isNotEmpty
                                      ? () => _showSimpleDiscountDialog(false)
                                      : null,
                                  icon: const Icon(Icons.receipt, size: 14),
                                  label: const Text(
                                    'Order',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade100,
                                    foregroundColor: Colors.green.shade700,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _orderItems.isNotEmpty
                                      ? () => _showSimpleDiscountDialog(true)
                                      : null,
                                  icon: const Icon(Icons.list, size: 14),
                                  label: const Text(
                                    'Item',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade100,
                                    foregroundColor: Colors.orange.shade700,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                  // Show technician indicator if pre-selected
                  if (_preSelectedTechnicianId != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 10,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Auto',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedReceiptItems() {
    // Handle empty state
    if (_orderItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No items added',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Text(
              'Select services to add them',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Group items by technician
    final Map<String, List<ServiceOrderItem>> groupedItems = {};
    for (final item in _orderItems) {
      if (!groupedItems.containsKey(item.technicianId)) {
        groupedItems[item.technicianId] = [];
      }
      groupedItems[item.technicianId]!.add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: groupedItems.length,
      itemBuilder: (context, groupIndex) {
        final technicianId = groupedItems.keys.elementAt(groupIndex);
        final items = groupedItems[technicianId]!;
        final technicianName = items.first.technicianName;
        final groupTotal = items.fold(0.0, (sum, item) => sum + item.lineTotal);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Technician Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        technicianName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                    Text(
                      '\$${groupTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              // Services for this technician
              ...items.asMap().entries.map((entry) {
                final itemIndex = _orderItems.indexOf(entry.value);
                return _buildReceiptItem(entry.value, itemIndex);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReceiptItem(ServiceOrderItem item, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              // Discount button for individual items
              SizedBox(
                width: 80, // Fixed width to prevent layout issues
                child: TextButton.icon(
                  icon: Icon(
                    Icons.local_offer_outlined,
                    size: 14,
                    color: item.itemDiscount != null
                        ? Colors.green.shade600
                        : Colors.blue.shade600,
                  ),
                  label: Text(
                    item.itemDiscount != null ? 'Edit' : 'Disc',
                    style: TextStyle(
                      fontSize: 10,
                      color: item.itemDiscount != null
                          ? Colors.green.shade600
                          : Colors.blue.shade600,
                    ),
                  ),
                  onPressed: () => _showItemDiscountDialog(item, index),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _removeOrderItem(index),
                color: Colors.red.shade600,
              ),
            ],
          ),
          if (item.itemDiscount != null) ...[
            const SizedBox(height: 4),
            Text(
              'Discount: ${item.itemDiscount!.name} (-\$${item.itemDiscount!.calculateDiscount(item.originalPrice).toStringAsFixed(2)})',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.quantity}x \$${item.originalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      decoration: item.itemDiscount != null
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.itemDiscount != null
                          ? Colors.grey.shade600
                          : null,
                    ),
                  ),
                  if (item.itemDiscount != null)
                    Text(
                      '${item.quantity}x \$${item.finalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
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

  Widget _buildTechnicianSelector() {
    final currentTechnician = _preSelectedTechnicianId != null
        ? _availableEmployees.firstWhere(
            (emp) => emp.id == _preSelectedTechnicianId,
            orElse: () => _availableEmployees.first,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 8),
          Text(
            'Selected Technician: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade800,
            ),
          ),
          Expanded(
            child: Text(
              currentTechnician?.name ?? 'None',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          TextButton(
            onPressed: _showTechnicianChangeDialog,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showTechnicianChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Technician'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableEmployees.length,
            itemBuilder: (context, index) {
              final employee = _availableEmployees[index];
              return RadioListTile<String>(
                title: Text(employee.name),
                value: employee.id,
                groupValue: _preSelectedTechnicianId,
                onChanged: (value) {
                  setState(() {
                    _preSelectedTechnicianId = value;
                  });
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showOrderDiscountDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController valueController = TextEditingController();
    DiscountType selectedType = DiscountType.percentage;

    // Pre-fill if there's an existing discount
    if (_currentOrder.orderDiscount != null) {
      nameController.text = _currentOrder.orderDiscount!.name;
      valueController.text = _currentOrder.orderDiscount!.value.toString();
      selectedType = _currentOrder.orderDiscount!.type;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Order Discount'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Discount Name',
                    hintText: 'e.g., Senior Discount, Loyalty',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: valueController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: selectedType == DiscountType.percentage
                              ? 'Percentage'
                              : 'Amount',
                          hintText: selectedType == DiscountType.percentage
                              ? '10'
                              : '5.00',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<DiscountType>(
                      value: selectedType,
                      items: DiscountType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedType = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_currentOrder.orderDiscount != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentOrder = _currentOrder.copyWith(
                          orderDiscount: null,
                        );
                      });
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Remove Discount'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final valueText = valueController.text.trim();

                if (name.isEmpty || valueText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }

                final value = double.tryParse(valueText);
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid discount value'),
                    ),
                  );
                  return;
                }

                final discount = ServiceOrderDiscount(
                  name: name,
                  type: selectedType,
                  value: value,
                );

                setState(() {
                  _currentOrder = _currentOrder.copyWith(
                    orderDiscount: discount,
                  );
                });
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDiscountDialog(ServiceOrderItem item, int index) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController valueController = TextEditingController();
    DiscountType selectedType = DiscountType.percentage;

    // Pre-fill if there's an existing discount
    if (item.itemDiscount != null) {
      nameController.text = item.itemDiscount!.name;
      valueController.text = item.itemDiscount!.value.toString();
      selectedType = item.itemDiscount!.type;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Discount for ${item.serviceName}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Discount Name',
                    hintText: 'e.g., First Time, Student',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: valueController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: selectedType == DiscountType.percentage
                              ? 'Percentage'
                              : 'Amount',
                          hintText: selectedType == DiscountType.percentage
                              ? '10'
                              : '5.00',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<DiscountType>(
                      value: selectedType,
                      items: DiscountType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedType = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (item.itemDiscount != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _orderItems[index] = _orderItems[index].copyWith(
                          itemDiscount: null,
                        );
                      });
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Remove Discount'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final valueText = valueController.text.trim();

                if (name.isEmpty || valueText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }

                final value = double.tryParse(valueText);
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid discount value'),
                    ),
                  );
                  return;
                }

                final discount = ServiceOrderItemDiscount(
                  name: name,
                  type: selectedType,
                  value: value,
                );

                setState(() {
                  _orderItems[index] = _orderItems[index].copyWith(
                    itemDiscount: discount,
                  );
                });
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _addServiceWithTechnician(ServiceCatalog service) {
    // If there's a pre-selected technician, use it directly
    if (_preSelectedTechnicianId != null) {
      final preSelectedEmployee = _availableEmployees.firstWhere(
        (emp) => emp.id == _preSelectedTechnicianId,
        orElse: () => _availableEmployees.first,
      );
      _addServiceOrderItem(
        service,
        preSelectedEmployee,
        1,
      ); // Default quantity of 1
      return;
    }

    // Otherwise, show technician selection dialog
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

  Widget _buildQuickDiscountButton(
    String label,
    double amount,
    bool isPercentage,
  ) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: () => _applyQuickDiscount(amount, isPercentage),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade100,
          foregroundColor: Colors.blue.shade700,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _applyQuickDiscount(double amount, bool isPercentage) {
    if (_orderItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Apply ${isPercentage ? "$amount%" : "\$${amount.toStringAsFixed(0)}"} Discount',
        ),
        content: const Text('Where would you like to apply this discount?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _applyOrderDiscount(amount, isPercentage);
            },
            child: const Text('Entire Order'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showItemSelectionForDiscount(amount, isPercentage);
            },
            child: const Text('Select Item'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _applyOrderDiscount(double amount, bool isPercentage) {
    setState(() {
      _currentOrder = _currentOrder.copyWith(
        orderDiscount: ServiceOrderDiscount(
          name: isPercentage
              ? '$amount% Off'
              : '\$${amount.toStringAsFixed(0)} Off',
          type: isPercentage
              ? DiscountType.percentage
              : DiscountType.fixedAmount,
          value: amount,
        ),
      );
    });
  }

  void _showItemSelectionForDiscount(double amount, bool isPercentage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Item for Discount'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _orderItems.length,
            itemBuilder: (context, index) {
              final item = _orderItems[index];
              return ListTile(
                title: Text(item.serviceName),
                subtitle: Text('\$${item.originalPrice.toStringAsFixed(2)}'),
                onTap: () {
                  Navigator.pop(context);
                  _applyItemDiscount(index, amount, isPercentage);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _applyItemDiscount(int itemIndex, double amount, bool isPercentage) {
    setState(() {
      _orderItems[itemIndex] = _orderItems[itemIndex].copyWith(
        itemDiscount: ServiceOrderItemDiscount(
          name: isPercentage
              ? '$amount% Off'
              : '\$${amount.toStringAsFixed(0)} Off',
          type: isPercentage
              ? DiscountType.percentage
              : DiscountType.fixedAmount,
          value: amount,
        ),
      );
    });
  }

  void _showSimpleDiscountDialog(bool forItem) {
    double discountAmount = 0;
    bool isPercentage = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(forItem ? 'Apply Item Discount' : 'Apply Order Discount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Percentage'),
                      value: true,
                      groupValue: isPercentage,
                      onChanged: (value) {
                        setDialogState(() {
                          isPercentage = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Fixed Amount'),
                      value: false,
                      groupValue: isPercentage,
                      onChanged: (value) {
                        setDialogState(() {
                          isPercentage = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: isPercentage ? 'Percentage (%)' : 'Amount (\$)',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  discountAmount = double.tryParse(value) ?? 0;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (forItem) {
                  _showItemSelectionForDiscount(discountAmount, isPercentage);
                } else {
                  _applyOrderDiscount(discountAmount, isPercentage);
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog classes would be added here but I'll need the checkout dialog content
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
          child: const Text('Add Service'),
        ),
      ],
    );
  }
}

// Placeholder for checkout dialog - would need complete implementation
class _CheckoutDialog extends StatefulWidget {
  final ServiceOrder currentOrder;
  final List<ServiceOrderItem> orderItems;
  final Customer? selectedCustomer;
  final int loyaltyPointsToEarn;
  final VoidCallback onPaymentComplete;

  const _CheckoutDialog({
    required this.currentOrder,
    required this.orderItems,
    required this.selectedCustomer,
    required this.loyaltyPointsToEarn,
    required this.onPaymentComplete,
  });

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Checkout'),
      content: const Text('Checkout functionality would be implemented here'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onPaymentComplete();
          },
          child: const Text('Complete Payment'),
        ),
      ],
    );
  }
}