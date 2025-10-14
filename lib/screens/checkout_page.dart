import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/service_order.dart';
import '../models/service_order_item.dart';
import '../models/customer.dart';
import '../services/firebase_service.dart';

enum PaymentMethod { cash, credit, debit }

class CheckoutPage extends StatefulWidget {
  final ServiceOrder serviceOrder;
  final List<ServiceOrderItem> orderItems;
  final Customer? customer;

  const CheckoutPage({
    super.key,
    required this.serviceOrder,
    required this.orderItems,
    this.customer,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _discountController = TextEditingController();
  final _taxRateController = TextEditingController(text: '8.25');
  final _tipController = TextEditingController(text: '0.00');
  final _cashReceivedController = TextEditingController();

  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  DiscountType _discountType = DiscountType.percentage;
  bool _applyToEntireOrder = true;
  int _selectedItemIndex = 0;
  bool _isProcessing = false;

  // Loyalty points settings
  double _pointsPerDollar = 1.0;
  int _loyaltyPointsToEarn = 0;
  int _loyaltyPointsToUse = 0;
  final _loyaltyPointsController = TextEditingController(text: '0');

  late ServiceOrder _workingOrder;
  late List<ServiceOrderItem> _workingItems;

  @override
  void initState() {
    super.initState();
    _workingOrder = widget.serviceOrder;
    _workingItems = List.from(widget.orderItems);
    _loadLoyaltySettings();
  }

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
    final totalAmount = _calculateTotal();
    _loyaltyPointsToEarn = FirebaseService.calculateLoyaltyPoints(
      totalAmount,
      _pointsPerDollar,
    );
    setState(() {});
  }

  double get _subtotal {
    return _workingItems.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  double get _orderDiscountAmount {
    if (_workingOrder.orderDiscount != null) {
      return _workingOrder.orderDiscount!.calculateDiscount(_subtotal);
    }
    return 0.0;
  }

  double get _itemsDiscountAmount {
    return _workingItems.fold(
      0.0,
      (sum, item) =>
          sum +
          (item.itemDiscount?.calculateDiscount(
                item.originalPrice * item.quantity,
              ) ??
              0.0),
    );
  }

  double get _totalDiscountAmount {
    return _orderDiscountAmount + _itemsDiscountAmount;
  }

  double get _taxRate {
    return double.tryParse(_taxRateController.text) ?? 0.0;
  }

  double get _taxAmount {
    final taxableAmount = _subtotal - _totalDiscountAmount;
    return taxableAmount * (_taxRate / 100);
  }

  double get _tipAmount {
    return double.tryParse(_tipController.text) ?? 0.0;
  }

  double _calculateTotal() {
    return _subtotal - _totalDiscountAmount + _taxAmount + _tipAmount;
  }

  double get _cashReceived {
    return double.tryParse(_cashReceivedController.text) ?? 0.0;
  }

  double get _changeAmount {
    return _selectedPaymentMethod == PaymentMethod.cash
        ? _cashReceived - _calculateTotal()
        : 0.0;
  }

  void _applyDiscount() {
    if (_discountController.text.isEmpty) return;

    final discountValue = double.tryParse(_discountController.text) ?? 0.0;
    if (discountValue <= 0) return;

    final discount = ServiceOrderDiscount(
      name: _discountType == DiscountType.percentage
          ? '${discountValue.toStringAsFixed(1)}% Off'
          : '\$${discountValue.toStringAsFixed(2)} Off',
      type: _discountType,
      value: discountValue,
      description: 'Manual discount applied at checkout',
    );

    setState(() {
      if (_applyToEntireOrder) {
        _workingOrder = _workingOrder.copyWith(orderDiscount: discount);
      } else {
        // Apply to selected item
        final itemDiscount = ServiceOrderItemDiscount(
          name: discount.name,
          type: discount.type,
          value: discount.value,
          description: discount.description,
        );
        _workingItems[_selectedItemIndex] = _workingItems[_selectedItemIndex]
            .copyWith(itemDiscount: itemDiscount);
      }
    });

    _calculateLoyaltyPoints();
  }

  void _removeOrderDiscount() {
    setState(() {
      _workingOrder = _workingOrder.copyWith(orderDiscount: null);
    });
    _calculateLoyaltyPoints();
  }

  void _removeItemDiscount(int index) {
    setState(() {
      _workingItems[index] = _workingItems[index].copyWith(itemDiscount: null);
    });
    _calculateLoyaltyPoints();
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPaymentMethod == PaymentMethod.cash && _changeAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient cash received')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Update order with final details
      final finalOrder = _workingOrder.copyWith(
        status: ServiceOrderStatus.completed,
        subtotal: _subtotal,
        discountAmount: _totalDiscountAmount,
        taxAmount: _taxAmount,
        total: _calculateTotal(),
        isPaid: true,
        paymentMethod: _selectedPaymentMethod.name,
        paidAt: DateTime.now(),
        completedAt: DateTime.now(),
        loyaltyPointsEarned: _loyaltyPointsToEarn,
        loyaltyPointsUsed: _loyaltyPointsToUse,
      );

      // Save order
      await FirebaseService.saveServiceOrder(finalOrder);

      // Save all order items
      for (final item in _workingItems) {
        await FirebaseService.saveServiceOrderItem(item);
      }

      // Update customer loyalty points if customer exists
      if (widget.customer != null && _loyaltyPointsToEarn > 0) {
        await FirebaseService.updateCustomerLoyaltyPoints(
          widget.customer!.id!,
          _loyaltyPointsToEarn - _loyaltyPointsToUse,
          _calculateTotal(),
        );
      }

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Payment Processed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order: ${finalOrder.orderNumber}'),
                Text('Total: \$${finalOrder.total.toStringAsFixed(2)}'),
                Text('Payment: ${_selectedPaymentMethod.name.toUpperCase()}'),
                if (_selectedPaymentMethod == PaymentMethod.cash &&
                    _changeAmount > 0)
                  Text(
                    'Change: \$${_changeAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (_loyaltyPointsToEarn > 0)
                  Text('Loyalty Points Earned: $_loyaltyPointsToEarn'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to service order
                  Navigator.of(context).pop(); // Go back to main screen
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Checkout - ${widget.serviceOrder.orderNumber}'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Info
              if (widget.customer != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(widget.customer!.displayName),
                        Text(
                          'Loyalty Points: ${widget.customer!.loyaltyPoints}',
                        ),
                        Text(
                          'Total Spent: \$${widget.customer!.totalSpent.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Order Items
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._workingItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${item.quantity}x ${item.serviceName}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.technicianName} • \$${item.originalPrice.toStringAsFixed(2)} each',
                              ),
                              if (item.itemDiscount != null)
                                Text(
                                  'Discount: ${item.itemDiscount!.name}',
                                  style: const TextStyle(color: Colors.red),
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
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.itemDiscount != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeItemDiscount(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Discount Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Discounts',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_workingOrder.orderDiscount != null)
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: _removeOrderDiscount,
                            ),
                        ],
                      ),
                      if (_workingOrder.orderDiscount != null) ...[
                        Text(
                          'Order Discount: ${_workingOrder.orderDiscount!.name}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _discountController,
                              decoration: const InputDecoration(
                                labelText: 'Discount Amount',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<DiscountType>(
                            value: _discountType,
                            items: DiscountType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type == DiscountType.percentage ? '%' : '\$',
                                ),
                              );
                            }).toList(),
                            onChanged: (type) =>
                                setState(() => _discountType = type!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Entire Order'),
                              value: true,
                              groupValue: _applyToEntireOrder,
                              onChanged: (value) =>
                                  setState(() => _applyToEntireOrder = value!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Single Item'),
                              value: false,
                              groupValue: _applyToEntireOrder,
                              onChanged: (value) =>
                                  setState(() => _applyToEntireOrder = value!),
                            ),
                          ),
                        ],
                      ),
                      if (!_applyToEntireOrder) ...[
                        DropdownButtonFormField<int>(
                          value: _selectedItemIndex,
                          decoration: const InputDecoration(
                            labelText: 'Select Item',
                            border: OutlineInputBorder(),
                          ),
                          items: _workingItems.asMap().entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(
                                '${entry.value.quantity}x ${entry.value.serviceName}',
                              ),
                            );
                          }).toList(),
                          onChanged: (index) =>
                              setState(() => _selectedItemIndex = index!),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ElevatedButton(
                        onPressed: _applyDiscount,
                        child: const Text('Apply Discount'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tax and Tip
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tax & Tip',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _taxRateController,
                              decoration: const InputDecoration(
                                labelText: 'Tax Rate (%)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  setState(() => _calculateLoyaltyPoints()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _tipController,
                              decoration: const InputDecoration(
                                labelText: 'Tip (\$)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  setState(() => _calculateLoyaltyPoints()),
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
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...PaymentMethod.values.map((method) {
                        return RadioListTile<PaymentMethod>(
                          title: Text(method.name.toUpperCase()),
                          value: method,
                          groupValue: _selectedPaymentMethod,
                          onChanged: (value) =>
                              setState(() => _selectedPaymentMethod = value!),
                        );
                      }),
                      if (_selectedPaymentMethod == PaymentMethod.cash) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _cashReceivedController,
                          decoration: const InputDecoration(
                            labelText: 'Cash Received (\$)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final cash = double.tryParse(value ?? '') ?? 0.0;
                            if (cash < _calculateTotal()) {
                              return 'Insufficient cash amount';
                            }
                            return null;
                          },
                          onChanged: (value) => setState(() {}),
                        ),
                        if (_cashReceived > 0 && _changeAmount >= 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Change: \$${_changeAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Loyalty Points
              if (widget.customer != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Loyalty Points',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Points to Earn: $_loyaltyPointsToEarn'),
                        Text(
                          'Rate: ${_pointsPerDollar.toStringAsFixed(1)} points per \$1',
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _loyaltyPointsController,
                          decoration: InputDecoration(
                            labelText:
                                'Points to Use (Max: ${widget.customer!.loyaltyPoints})',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _loyaltyPointsToUse = int.tryParse(value) ?? 0;
                            if (_loyaltyPointsToUse >
                                widget.customer!.loyaltyPoints) {
                              _loyaltyPointsToUse =
                                  widget.customer!.loyaltyPoints;
                              _loyaltyPointsController.text =
                                  _loyaltyPointsToUse.toString();
                            }
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Order Summary
              Card(
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      _buildSummaryRow('Subtotal', _subtotal),
                      if (_totalDiscountAmount > 0)
                        _buildSummaryRow(
                          'Discount',
                          -_totalDiscountAmount,
                          color: Colors.red,
                        ),
                      if (_taxAmount > 0)
                        _buildSummaryRow(
                          'Tax (${_taxRate.toStringAsFixed(2)}%)',
                          _taxAmount,
                        ),
                      if (_tipAmount > 0) _buildSummaryRow('Tip', _tipAmount),
                      const Divider(),
                      _buildSummaryRow(
                        'Total',
                        _calculateTotal(),
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Process Payment Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Process Payment - \$${_calculateTotal().toStringAsFixed(2)}',
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

  Widget _buildSummaryRow(
    String label,
    double amount, {
    Color? color,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isTotal ? Colors.green : null),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _discountController.dispose();
    _taxRateController.dispose();
    _tipController.dispose();
    _cashReceivedController.dispose();
    _loyaltyPointsController.dispose();
    super.dispose();
  }
}
