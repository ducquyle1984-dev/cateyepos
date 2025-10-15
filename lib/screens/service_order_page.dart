import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_order.dart';
import '../models/service_order_item.dart';
import '../models/service_catalog.dart';

import '../models/customer.dart';
import '../provider/service_order_provider.dart';
import '../provider/catalog_provider.dart';

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
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initializeProviders() async {
    final serviceOrderProvider = Provider.of<ServiceOrderProvider>(
      context,
      listen: false,
    );
    final catalogProvider = Provider.of<CatalogProvider>(
      context,
      listen: false,
    );

    // Load catalog data first
    await catalogProvider.loadAllData();

    // Initialize order
    await serviceOrderProvider.initializeOrder(
      existingOrder: widget.existingOrder,
      preSelectedTechnicianId: widget.preSelectedTechnicianId,
    );

    // Load existing order items if editing
    if (widget.existingOrder != null) {
      await serviceOrderProvider.loadOrderItems();
    }

    // Load loyalty settings
    await serviceOrderProvider.loadLoyaltySettings();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ServiceOrderProvider, CatalogProvider>(
      builder: (context, orderProvider, catalogProvider, child) {
        if (orderProvider.isLoading || catalogProvider.isLoading) {
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
              orderProvider.currentOrder?.id == null
                  ? 'New Service Order'
                  : 'Order ${orderProvider.currentOrder!.orderNumber}',
            ),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            actions: [
              if (orderProvider.isSaving)
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
                // Save button
                IconButton(
                  onPressed: () => _saveOrderForLater(orderProvider),
                  icon: const Icon(Icons.save),
                  tooltip: 'Save for Later',
                ),
                // Checkout button
                if (orderProvider.orderItems.isNotEmpty &&
                    orderProvider.currentOrder?.status !=
                        ServiceOrderStatus.completed)
                  TextButton.icon(
                    onPressed: () => _proceedToCheckout(orderProvider),
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    label: const Text(
                      'Checkout',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ],
          ),
          body: _buildOrderCreationUI(orderProvider, catalogProvider),
        );
      },
    );
  }

  Widget _buildOrderCreationUI(
    ServiceOrderProvider orderProvider,
    CatalogProvider catalogProvider,
  ) {
    return Row(
      children: [
        // Left side - Service Selection
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Order Header
              _buildOrderHeader(orderProvider, catalogProvider),

              // Service Selection Area
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
                      if (catalogProvider.categories.isNotEmpty)
                        _buildCategoryFilter(catalogProvider),

                      const SizedBox(height: 16),

                      // Services Grid
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.2,
                              ),
                          itemCount: catalogProvider.filteredServices.length,
                          itemBuilder: (context, index) {
                            final service =
                                catalogProvider.filteredServices[index];
                            return _buildServiceCard(
                              service,
                              orderProvider,
                              catalogProvider,
                            );
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

        // Right side - Order Summary
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
          child: _buildOrderSummary(orderProvider, catalogProvider),
        ),
      ],
    );
  }

  Widget _buildOrderHeader(
    ServiceOrderProvider orderProvider,
    CatalogProvider catalogProvider,
  ) {
    return Container(
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
                      'Order #${orderProvider.currentOrder?.orderNumber ?? 'New'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (orderProvider.currentOrder != null)
                      Text(
                        'Status: ${orderProvider.currentOrder!.status.displayName}',
                        style: TextStyle(
                          color: _getStatusColor(
                            orderProvider.currentOrder!.status,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (orderProvider.currentOrder != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(orderProvider.currentOrder!.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    orderProvider.currentOrder!.status.displayName
                        .toUpperCase(),
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
          _buildCustomerSearchSection(orderProvider, catalogProvider),
          const SizedBox(height: 16),
          _buildTechnicianSelectionSection(orderProvider, catalogProvider),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(CatalogProvider catalogProvider) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: const Text('All'),
            selected: catalogProvider.selectedCategoryId == null,
            onSelected: (selected) {
              if (selected) catalogProvider.filterServicesByCategory(null);
            },
          ),
          const SizedBox(width: 8),
          ...catalogProvider.categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(category.name),
                selected: catalogProvider.selectedCategoryId == category.id,
                onSelected: (selected) {
                  if (selected) {
                    catalogProvider.filterServicesByCategory(category.id);
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    ServiceCatalog service,
    ServiceOrderProvider orderProvider,
    CatalogProvider catalogProvider,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () =>
            _addServiceImmediately(service, orderProvider, catalogProvider),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(
    ServiceOrderProvider orderProvider,
    CatalogProvider catalogProvider,
  ) {
    return Column(
      children: [
        // Receipt Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(0),
              topRight: Radius.circular(0),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'Order Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Items: ${orderProvider.orderItems.length}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),

        // Order Items List
        Expanded(
          child: orderProvider.orderItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text('No items selected'),
                      Text('Select services to add to order'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: orderProvider.orderItems.length,
                  itemBuilder: (context, index) {
                    final item = orderProvider.orderItems[index];
                    return _buildOrderItemCard(
                      item,
                      index,
                      orderProvider,
                      catalogProvider,
                    );
                  },
                ),
        ),

        // Order Total Section
        if (orderProvider.orderItems.isNotEmpty)
          _buildOrderTotals(orderProvider),

        // Payment Section
        if (orderProvider.showPaymentOptions)
          _buildPaymentSection(orderProvider),
      ],
    );
  }

  Widget _buildOrderItemCard(
    ServiceOrderItem item,
    int index,
    ServiceOrderProvider orderProvider,
    CatalogProvider catalogProvider,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.serviceName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => orderProvider.removeOrderItem(index),
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(children: [Text('Technician: ${item.technicianName}')]),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Qty: ${item.quantity}'),
                const Spacer(),
                Text(
                  '\$${item.lineTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTotals(ServiceOrderProvider orderProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Subtotal:', style: TextStyle(fontSize: 16)),
              const Spacer(),
              Text(
                '\$${orderProvider.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          if (orderProvider.discountAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Discount:', style: TextStyle(fontSize: 16)),
                const Spacer(),
                Text(
                  '-\$${orderProvider.discountAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(),
          Row(
            children: [
              const Text(
                'Total:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '\$${orderProvider.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (orderProvider.selectedCustomer != null &&
              orderProvider.loyaltyPointsToEarn > 0)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.orange.shade600, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Loyalty Points: +${orderProvider.loyaltyPointsToEarn}',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Checkout and Discount buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showDiscountDialog(orderProvider),
                  icon: const Icon(Icons.percent),
                  label: const Text('Apply Discount'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: orderProvider.orderItems.isNotEmpty
                      ? () => _proceedToCheckout(orderProvider)
                      : null,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Proceed to Checkout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(ServiceOrderProvider orderProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border(top: BorderSide(color: Colors.green.shade200)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Payment Options',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => orderProvider.togglePaymentOptions(),
                icon: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showCashPaymentModal(orderProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cash'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _processCreditPayment(orderProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Credit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Event Handlers
  Future<void> _saveOrderForLater(ServiceOrderProvider orderProvider) async {
    try {
      await orderProvider.saveOrderForLater();
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
    }
  }

  void _proceedToCheckout(ServiceOrderProvider orderProvider) {
    orderProvider.togglePaymentOptions();
  }

  void _showDiscountDialog(ServiceOrderProvider orderProvider) {
    final TextEditingController discountController = TextEditingController();
    bool isPercentage = true;
    String displayValue = '0';

    void updateDisplay(String value) {
      discountController.text = value;
      displayValue = value;
    }

    void addDigit(String digit) {
      if (displayValue == '0') {
        updateDisplay(digit);
      } else {
        updateDisplay(displayValue + digit);
      }
    }

    void addDecimal() {
      if (!displayValue.contains('.')) {
        updateDisplay(displayValue + '.');
      }
    }

    void clearInput() {
      updateDisplay('0');
    }

    void removeLastDigit() {
      if (displayValue.length > 1) {
        updateDisplay(displayValue.substring(0, displayValue.length - 1));
      } else {
        updateDisplay('0');
      }
    }

    void applyPresetDiscount(double percentage) {
      final discountAmount = (orderProvider.subtotal * percentage) / 100;
      orderProvider.applyDiscount(discountAmount);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$percentage% discount (\$${discountAmount.toStringAsFixed(2)}) applied',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
              maxHeight: 950,
              minWidth: 450,
              minHeight: 700,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Header
                    Row(
                      children: [
                        const Text(
                          'Apply Discount',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(),

                    // Preset discount buttons
                    const Text(
                      'Quick Discounts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => applyPresetDiscount(5),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade100,
                              foregroundColor: Colors.orange.shade800,
                            ),
                            child: const Text('5%'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => applyPresetDiscount(10),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade200,
                              foregroundColor: Colors.orange.shade800,
                            ),
                            child: const Text('10%'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => applyPresetDiscount(15),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade300,
                              foregroundColor: Colors.orange.shade800,
                            ),
                            child: const Text('15%'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Custom discount section
                    Row(
                      children: [
                        const Text('Custom Discount Type:'),
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: const Text('Percentage'),
                          selected: isPercentage,
                          onSelected: (selected) {
                            setState(() {
                              isPercentage = true;
                              clearInput();
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Amount'),
                          selected: !isPercentage,
                          onSelected: (selected) {
                            setState(() {
                              isPercentage = false;
                              clearInput();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Display field
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${isPercentage ? '' : '\$'}$displayValue${isPercentage ? '%' : ''}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Numpad
                    SizedBox(
                      height: 480,
                      child: GridView.count(
                        crossAxisCount: 3,
                        childAspectRatio: 1.4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        children: [
                          _buildNumpadButton(
                            '1',
                            () => setState(() => addDigit('1')),
                          ),
                          _buildNumpadButton(
                            '2',
                            () => setState(() => addDigit('2')),
                          ),
                          _buildNumpadButton(
                            '3',
                            () => setState(() => addDigit('3')),
                          ),
                          _buildNumpadButton(
                            '4',
                            () => setState(() => addDigit('4')),
                          ),
                          _buildNumpadButton(
                            '5',
                            () => setState(() => addDigit('5')),
                          ),
                          _buildNumpadButton(
                            '6',
                            () => setState(() => addDigit('6')),
                          ),
                          _buildNumpadButton(
                            '7',
                            () => setState(() => addDigit('7')),
                          ),
                          _buildNumpadButton(
                            '8',
                            () => setState(() => addDigit('8')),
                          ),
                          _buildNumpadButton(
                            '9',
                            () => setState(() => addDigit('9')),
                          ),
                          _buildNumpadButton(
                            '.',
                            () => setState(() => addDecimal()),
                          ),
                          _buildNumpadButton(
                            '0',
                            () => setState(() => addDigit('0')),
                          ),
                          _buildNumpadButton(
                            '⌫',
                            () => setState(() => removeLastDigit()),
                            isDelete: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              orderProvider.applyDiscount(0);
                              Navigator.of(context).pop();
                            },
                            child: const Text('Remove Discount'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final input = displayValue;
                              if (input.isNotEmpty && input != '0') {
                                final value = double.tryParse(input);
                                if (value != null && value > 0) {
                                  double discountAmount;
                                  if (isPercentage) {
                                    discountAmount =
                                        (orderProvider.subtotal * value) / 100;
                                  } else {
                                    discountAmount = value;
                                  }

                                  if (discountAmount > orderProvider.subtotal) {
                                    discountAmount = orderProvider.subtotal;
                                  }

                                  orderProvider.applyDiscount(discountAmount);
                                  Navigator.of(context).pop();
                                }
                              }
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
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

  void _addServiceImmediately(
    ServiceCatalog service,
    ServiceOrderProvider orderProvider,
    CatalogProvider catalogProvider,
  ) {
    // Check if a technician is selected
    if (orderProvider.selectedTechnicianId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a technician first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Find the selected technician
    final selectedTechnician = catalogProvider.employees
        .where((emp) => emp.id == orderProvider.selectedTechnicianId)
        .firstOrNull;

    if (selectedTechnician == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected technician not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Add service immediately with quantity 1
    final orderItem = ServiceOrderItem(
      serviceOrderId: orderProvider.currentOrder?.id ?? '',
      serviceCatalogId: service.id,
      serviceName: service.name,
      serviceDescription: service.description,
      originalPrice: service.price,
      quantity: 1, // Default quantity of 1
      technicianId: selectedTechnician.id,
      technicianName: selectedTechnician.name,
      estimatedDurationMinutes: service.durationMinutes,
    );

    orderProvider.addOrderItem(orderItem);
  }

  void _showCashPaymentModal(ServiceOrderProvider orderProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 480,
                  maxHeight: 800,
                  minWidth: 400,
                  minHeight: 600,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Header
                      Row(
                        children: [
                          const Text(
                            'Cash Payment',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Divider(),

                      // Order total display
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Due:',
                              style: TextStyle(fontSize: 18),
                            ),
                            Text(
                              '\$${orderProvider.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Amount received display
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Amount Received',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${orderProvider.amountPaid.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (orderProvider.amountPaid >= orderProvider.total)
                              Text(
                                'Change: \$${orderProvider.changeAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Number pad
                      Expanded(
                        child: _buildModalNumPad(setModalState, orderProvider),
                      ),

                      const SizedBox(height: 20),

                      // Pay Exact Amount button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              _payExactAmount(setModalState, orderProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Pay Exact Amount (\$${orderProvider.total.toStringAsFixed(2)})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

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
                              onPressed:
                                  orderProvider.amountPaid >=
                                      orderProvider.total
                                  ? () =>
                                        _handlePaymentCompletion(orderProvider)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Complete Payment'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalNumPad(
    StateSetter setModalState,
    ServiceOrderProvider orderProvider,
  ) {
    return Column(
      children: [
        // Row 1: 1, 2, 3
        Row(
          children: [
            Expanded(
              child: _buildModalNumButton('1', setModalState, orderProvider),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModalNumButton('2', setModalState, orderProvider),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModalNumButton('3', setModalState, orderProvider),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: 4, 5, 6
        Row(
          children: [
            Expanded(
              child: _buildModalNumButton('4', setModalState, orderProvider),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModalNumButton('5', setModalState, orderProvider),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModalNumButton('6', setModalState, orderProvider),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 3: 7, 8, 9
        Row(
          children: [
            Expanded(
              child: _buildModalNumButton('7', setModalState, orderProvider),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModalNumButton('8', setModalState, orderProvider),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModalNumButton('9', setModalState, orderProvider),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 4: 0, 00, Delete
        Row(
          children: [
            Expanded(
              child: _buildModalNumButton('0', setModalState, orderProvider),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModalNumButton('00', setModalState, orderProvider),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: orderProvider.amountPaid > 0
                      ? () =>
                            _modalBackspaceAmount(setModalState, orderProvider)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orderProvider.amountPaid > 0
                        ? Colors.red.shade100
                        : Colors.grey.shade200,
                    foregroundColor: orderProvider.amountPaid > 0
                        ? Colors.red.shade700
                        : Colors.grey.shade500,
                  ),
                  child: const Icon(Icons.backspace, size: 24),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Clear button
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: orderProvider.amountPaid > 0
                      ? () => _modalClearAmount(setModalState, orderProvider)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orderProvider.amountPaid > 0
                        ? Colors.orange.shade100
                        : Colors.grey.shade200,
                    foregroundColor: orderProvider.amountPaid > 0
                        ? Colors.orange.shade700
                        : Colors.grey.shade500,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModalNumButton(
    String value,
    StateSetter setModalState,
    ServiceOrderProvider orderProvider,
  ) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: () => _modalAddToAmount(value, setModalState, orderProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _modalAddToAmount(
    String value,
    StateSetter setModalState,
    ServiceOrderProvider orderProvider,
  ) {
    String currentAmount = orderProvider.amountPaid
        .toStringAsFixed(2)
        .replaceAll('.00', '');
    if (currentAmount == '0') currentAmount = '';

    String newAmount = currentAmount + value;
    double amount = double.tryParse(newAmount) ?? 0.0;

    orderProvider.setAmountPaid(amount);
    setModalState(() {});
  }

  void _modalBackspaceAmount(
    StateSetter setModalState,
    ServiceOrderProvider orderProvider,
  ) {
    String currentAmount = orderProvider.amountPaid
        .toStringAsFixed(2)
        .replaceAll('.00', '');
    if (currentAmount.isNotEmpty) {
      String newAmount = currentAmount.substring(0, currentAmount.length - 1);
      double amount = double.tryParse(newAmount) ?? 0.0;
      orderProvider.setAmountPaid(amount);
      setModalState(() {});
    }
  }

  void _modalClearAmount(
    StateSetter setModalState,
    ServiceOrderProvider orderProvider,
  ) {
    orderProvider.setAmountPaid(0.0);
    setModalState(() {});
  }

  Widget _buildNumpadButton(
    String value,
    VoidCallback onPressed, {
    bool isDelete = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDelete ? Colors.red.shade100 : Colors.white,
        foregroundColor: isDelete ? Colors.red.shade700 : Colors.black87,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: isDelete
          ? const Icon(Icons.backspace, size: 20)
          : Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
    );
  }

  void _payExactAmount(
    StateSetter setModalState,
    ServiceOrderProvider orderProvider,
  ) {
    orderProvider.setAmountPaid(orderProvider.total);
    setModalState(() {});
  }

  Future<void> _handlePaymentCompletion(
    ServiceOrderProvider orderProvider,
  ) async {
    // Check if change is required and show confirmation dialog
    if (orderProvider.changeAmount > 0.01) {
      final confirmed = await _showChangeConfirmationDialog(
        orderProvider.changeAmount,
      );
      if (!confirmed) return;
    }

    // Close the payment modal
    Navigator.of(context).pop();

    try {
      await orderProvider.completeOrder();
      orderProvider.addPartialPayment(orderProvider.amountPaid);

      if (mounted) {
        // Show change dialog if needed
        if (orderProvider.changeAmount > 0.01) {
          _showChangeDialog(orderProvider.changeAmount);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment completed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error completing payment: $e')));
      }
    }
  }

  Future<bool> _showChangeConfirmationDialog(double changeAmount) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                const Text('Confirm Payment'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The customer paid more than the total amount.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Change Due:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${changeAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please confirm that you will give the correct change to the customer.',
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm & Complete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _processCreditPayment(ServiceOrderProvider orderProvider) {
    // Placeholder for credit payment processing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Credit payment processing not implemented yet'),
      ),
    );
  }

  void _showChangeDialog(double changeAmount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Due'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: Colors.green,
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
            const Text('Please give this amount to the customer'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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

  Widget _buildCustomerSearchSection(
    ServiceOrderProvider orderProvider,
    CatalogProvider catalogProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Selection',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 8),
        // Combined search and selection field
        Autocomplete<Customer>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return catalogProvider.customers;
            }
            final query = textEditingValue.text.toLowerCase();
            return catalogProvider.customers.where((customer) {
              return customer.displayName.toLowerCase().contains(query) ||
                  (customer.phone?.contains(query) ?? false);
            });
          },
          displayStringForOption: (Customer customer) => customer.displayName,
          onSelected: (Customer customer) {
            orderProvider.setSelectedCustomer(customer);
          },
          fieldViewBuilder:
              (context, controller, focusNode, onEditingComplete) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  onEditingComplete: onEditingComplete,
                  decoration: InputDecoration(
                    labelText: 'Search or Select Customer',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Type name or phone number',
                    suffixIcon: orderProvider.selectedCustomer != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              orderProvider.setSelectedCustomer(null);
                              controller.clear();
                            },
                          )
                        : null,
                  ),
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: 300,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final customer = options.elementAt(index);
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(customer.displayName),
                        subtitle: Text(customer.phone ?? 'No phone'),
                        trailing: Text('${customer.loyaltyPoints} pts'),
                        onTap: () => onSelected(customer),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // Selected customer display with loyalty points
        if (orderProvider.selectedCustomer != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orderProvider.selectedCustomer!.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (orderProvider.selectedCustomer!.phone != null)
                        Text(
                          'Phone: ${orderProvider.selectedCustomer!.phone}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      if (orderProvider.selectedCustomer!.birthday != null)
                        Text(
                          'Birthday: ${orderProvider.selectedCustomer!.birthday} 🎂',
                          style: TextStyle(color: Colors.grey.shade600),
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
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${orderProvider.selectedCustomer!.loyaltyPoints} pts',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
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

  Widget _buildTechnicianSelectionSection(
    ServiceOrderProvider orderProvider,
    CatalogProvider catalogProvider,
  ) {
    final selectedTechnician = catalogProvider.employees
        .where((emp) => emp.id == orderProvider.selectedTechnicianId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Technician Assignment',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.purple.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: selectedTechnician != null
              ? Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.purple.shade600,
                      child: Text(
                        selectedTechnician.name.isNotEmpty
                            ? selectedTechnician.name[0]
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedTechnician.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            selectedTechnician.email,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          if (selectedTechnician.position.isNotEmpty)
                            Text(
                              selectedTechnician.position,
                              style: TextStyle(
                                color: Colors.purple.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showTechnicianChangeDialog(
                        orderProvider,
                        catalogProvider,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade100,
                        foregroundColor: Colors.purple.shade800,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Change'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(Icons.person_pin, color: Colors.purple),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No technician selected',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showTechnicianChangeDialog(
                        orderProvider,
                        catalogProvider,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Select'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _showTechnicianChangeDialog(
    ServiceOrderProvider orderProvider,
    CatalogProvider catalogProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Technician'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: catalogProvider.employees.length,
            itemBuilder: (context, index) {
              final employee = catalogProvider.employees[index];
              final isSelected =
                  employee.id == orderProvider.selectedTechnicianId;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? Colors.purple.shade600
                      : Colors.purple.shade200,
                  child: Text(
                    employee.name.isNotEmpty ? employee.name[0] : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  employee.name,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  employee.position.isNotEmpty
                      ? '${employee.email} • ${employee.position}'
                      : employee.email,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: Colors.green.shade600)
                    : null,
                onTap: () {
                  orderProvider.setSelectedTechnician(employee.id);
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
}
