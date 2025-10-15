import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_order.dart';
import '../models/service_order_item.dart';
import '../models/customer.dart';
import '../services/firebase_service.dart';

enum PaymentMethod { cash, credit }

class ServiceOrderProvider with ChangeNotifier {
  ServiceOrder? _currentOrder;
  List<ServiceOrderItem> _orderItems = [];
  Customer? _selectedCustomer;
  String? _selectedTechnicianId;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _preSelectedTechnicianId;
  bool _showDiscountSection = false;

  // Discount tracking
  List<ServiceOrderDiscount> _appliedDiscounts = [];

  // Payment flow state
  bool _showPaymentOptions = false;
  double _amountPaid = 0.0;
  double _totalPaidSoFar = 0.0;
  List<double> _partialPayments = [];
  bool _isProcessingPayment = false;

  // Loyalty points settings
  double _pointsPerDollar = 1.0;
  int _loyaltyPointsToEarn = 0;

  // Getters
  ServiceOrder? get currentOrder => _currentOrder;
  List<ServiceOrderItem> get orderItems => _orderItems;
  Customer? get selectedCustomer => _selectedCustomer;
  String? get selectedTechnicianId => _selectedTechnicianId;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get preSelectedTechnicianId => _preSelectedTechnicianId;
  bool get showDiscountSection => _showDiscountSection;
  bool get showPaymentOptions => _showPaymentOptions;
  double get amountPaid => _amountPaid;
  double get totalPaidSoFar => _totalPaidSoFar;
  List<double> get partialPayments => _partialPayments;
  bool get isProcessingPayment => _isProcessingPayment;
  double get pointsPerDollar => _pointsPerDollar;
  int get loyaltyPointsToEarn => _loyaltyPointsToEarn;
  List<ServiceOrderDiscount> get appliedDiscounts => _appliedDiscounts;

  // Calculated properties
  double get subtotal {
    return _orderItems.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  double get discountAmount {
    return _appliedDiscounts.fold(
      0.0,
      (sum, discount) => sum + discount.calculateDiscount(subtotal),
    );
  }

  double get total => subtotal - discountAmount;

  // Remaining balance should never be negative - if overpaid, remaining is 0
  double get remainingBalance {
    final balance = total - _totalPaidSoFar;
    return balance > 0 ? balance : 0.0;
  }

  // Change amount is the amount customer should get back
  // This happens when current payment (_amountPaid) exceeds remaining balance
  double get changeAmount {
    final currentPaymentExcess = _amountPaid - remainingBalance;
    return currentPaymentExcess > 0 ? currentPaymentExcess : 0.0;
  }

  bool get isOrderFullyPaid => _totalPaidSoFar >= total;

  // Methods
  Future<void> initializeOrder({
    ServiceOrder? existingOrder,
    String? preSelectedTechnicianId,
  }) async {
    _isLoading = true;
    notifyListeners();

    _preSelectedTechnicianId = preSelectedTechnicianId;
    _selectedTechnicianId = preSelectedTechnicianId; // Set as default

    if (existingOrder != null) {
      _currentOrder = existingOrder;

      // Load associated customer if exists
      if (existingOrder.customerId != null) {
        await _loadCustomerForExistingOrder(existingOrder.customerId!);
      }

      // Set technician from existing order if available and no pre-selected technician
      if (preSelectedTechnicianId == null &&
          existingOrder.technicianIds.isNotEmpty) {
        _selectedTechnicianId = existingOrder.technicianIds.first;
      }

      // Restore payment state from existing order
      _totalPaidSoFar = existingOrder.totalPaidSoFar;
      _partialPayments = List<double>.from(existingOrder.partialPayments);

      // Restore applied discounts from existing order
      _appliedDiscounts = List<ServiceOrderDiscount>.from(
        existingOrder.appliedDiscounts,
      );

      // Show payment options if there are partial payments
      if (_totalPaidSoFar > 0) {
        _showPaymentOptions = true;
      }
    } else {
      // Creating a new order - reset all state
      _resetOrderState();
      final orderNumber = await FirebaseService.generateDailyOrderNumber();
      _currentOrder = ServiceOrder(orderNumber: orderNumber);
      _selectedTechnicianId =
          preSelectedTechnicianId; // Reset after state reset
    }

    _isLoading = false;
    notifyListeners();
  }

  // Helper method to reset order state when creating a new order
  void _resetOrderState() {
    _orderItems.clear();
    _selectedCustomer = null;
    _showDiscountSection = false;
    _showPaymentOptions = false;
    _totalPaidSoFar = 0.0;
    _amountPaid = 0.0;
    _partialPayments.clear();
    _appliedDiscounts.clear();
    _isProcessingPayment = false;
    _loyaltyPointsToEarn = 0;
    _currentOrder = null;
  }

  Future<void> _loadCustomerForExistingOrder(String customerId) async {
    try {
      final customers = await FirebaseService.getCustomers();
      final customer = customers.where((c) => c.id == customerId).firstOrNull;
      if (customer != null) {
        _selectedCustomer = customer;
      }
    } catch (e) {
      debugPrint('Error loading customer for existing order: $e');
    }
  }

  Future<void> loadOrderItems() async {
    if (_currentOrder?.id != null) {
      try {
        _orderItems = await FirebaseService.getServiceOrderItems(
          _currentOrder!.id!,
        );
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading order items: $e');
      }
    }
  }

  void setSelectedCustomer(Customer? customer) {
    _selectedCustomer = customer;
    if (_currentOrder != null) {
      _currentOrder = _currentOrder!.copyWith(customerId: customer?.id);
    }
    _calculateLoyaltyPoints();
    notifyListeners();
  }

  void addOrderItem(ServiceOrderItem item) {
    _orderItems.add(item);
    _calculateLoyaltyPoints();
    notifyListeners();
  }

  void removeOrderItem(int index) {
    if (index >= 0 && index < _orderItems.length) {
      _orderItems.removeAt(index);
      _calculateLoyaltyPoints();
      notifyListeners();
    }
  }

  void updateOrderItem(int index, ServiceOrderItem updatedItem) {
    if (index >= 0 && index < _orderItems.length) {
      _orderItems[index] = updatedItem;
      _calculateLoyaltyPoints();
      notifyListeners();
    }
  }

  void toggleDiscountSection() {
    _showDiscountSection = !_showDiscountSection;
    notifyListeners();
  }

  void applyDiscount(double discountAmount, {String? description}) {
    if (_orderItems.isEmpty || discountAmount <= 0) return;

    // Create discount description
    final discountDescription =
        description ?? 'Fixed \$${discountAmount.toStringAsFixed(2)} discount';

    // Add the discount to the applied discounts list
    final discount = ServiceOrderDiscount(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: discountDescription,
      type: DiscountType.fixedAmount,
      value: discountAmount,
      description: discountDescription,
    );

    _appliedDiscounts.add(discount);
    _calculateLoyaltyPoints();
    notifyListeners();
  }

  void applyPercentageDiscount(double percentage, {String? description}) {
    if (_orderItems.isEmpty || percentage <= 0) return;

    final discountDescription = description ?? '$percentage% discount';

    // Add the percentage discount to the applied discounts list
    final discount = ServiceOrderDiscount(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: discountDescription,
      type: DiscountType.percentage,
      value: percentage,
      description: discountDescription,
    );

    _appliedDiscounts.add(discount);
    _calculateLoyaltyPoints();
    notifyListeners();
  }

  void togglePaymentOptions() {
    _showPaymentOptions = !_showPaymentOptions;
    notifyListeners();
  }

  void setAmountPaid(double amount) {
    _amountPaid = amount;
    notifyListeners();
  }

  void addPartialPayment(double amount) {
    _partialPayments.add(amount);
    _totalPaidSoFar += amount;
    notifyListeners();
  }

  void removeDiscount(String discountId) {
    _appliedDiscounts.removeWhere((discount) => discount.id == discountId);
    _calculateLoyaltyPoints();
    notifyListeners();
  }

  void removeAllDiscounts() {
    _appliedDiscounts.clear();
    _calculateLoyaltyPoints();
    notifyListeners();
  }

  void removePartialPayment(int index) {
    if (index >= 0 && index < _partialPayments.length) {
      _totalPaidSoFar -= _partialPayments[index];
      _partialPayments.removeAt(index);
      notifyListeners();
    }
  }

  void clearAllPartialPayments() {
    _partialPayments.clear();
    _totalPaidSoFar = 0.0;
    notifyListeners();
  }

  void clearPaymentState() {
    _amountPaid = 0.0;
    _totalPaidSoFar = 0.0;
    _partialPayments.clear();
    _showPaymentOptions = false;
    notifyListeners();
  }

  void setProcessingPayment(bool processing) {
    _isProcessingPayment = processing;
    notifyListeners();
  }

  Future<void> loadLoyaltySettings() async {
    try {
      final config = await FirebaseService.getLoyaltyPointsConfig();
      _pointsPerDollar = config['pointsPerDollar']?.toDouble() ?? 1.0;
      _calculateLoyaltyPoints();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading loyalty settings: $e');
    }
  }

  void _calculateLoyaltyPoints() {
    _loyaltyPointsToEarn = FirebaseService.calculateLoyaltyPoints(
      total,
      _pointsPerDollar,
    );
  }

  Future<void> saveOrderForLater() async {
    if (_currentOrder == null) return;

    _isSaving = true;
    notifyListeners();

    try {
      // Collect technician IDs from order items and selected technician
      final technicianIds = <String>{};
      if (_selectedTechnicianId != null) {
        technicianIds.add(_selectedTechnicianId!);
      }
      for (final item in _orderItems) {
        technicianIds.add(item.technicianId);
      }

      // If order doesn't have an ID, create one
      String orderId =
          _currentOrder!.id ??
          FirebaseFirestore.instance.collection('service_orders').doc().id;

      // Update order with collected technician IDs, customer ID, calculated totals, and payment info
      final updatedOrder = _currentOrder!.copyWith(
        id: orderId,
        technicianIds: technicianIds.toList(),
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.displayName,
        subtotal: subtotal,
        appliedDiscounts: List<ServiceOrderDiscount>.from(_appliedDiscounts),
        discountAmount: discountAmount,
        total: total,
        totalPaidSoFar: _totalPaidSoFar,
        partialPayments: List<double>.from(_partialPayments),
        status: ServiceOrderStatus
            .inProgress, // Set status to in-progress when saving
      );

      // Save the order first
      await FirebaseService.saveServiceOrder(updatedOrder);
      _currentOrder = updatedOrder;

      // Update all order items with the correct serviceOrderId and save them
      final updatedOrderItems = <ServiceOrderItem>[];
      for (final item in _orderItems) {
        final updatedItem = item.copyWith(serviceOrderId: orderId);
        updatedOrderItems.add(updatedItem);
        await FirebaseService.saveServiceOrderItem(updatedItem);
      }

      // Update the local order items list with the correct serviceOrderId
      _orderItems.clear();
      _orderItems.addAll(updatedOrderItems);
    } catch (e) {
      debugPrint('Error saving order: $e');
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> completeOrder() async {
    if (_currentOrder == null) return;

    _isSaving = true;
    notifyListeners();

    try {
      // Collect technician IDs from order items and selected technician
      final technicianIds = <String>{};
      if (_selectedTechnicianId != null) {
        technicianIds.add(_selectedTechnicianId!);
      }
      for (final item in _orderItems) {
        technicianIds.add(item.technicianId);
      }

      // If order doesn't have an ID, create one
      String orderId =
          _currentOrder!.id ??
          FirebaseFirestore.instance.collection('service_orders').doc().id;

      final completedOrder = _currentOrder!.copyWith(
        id: orderId,
        status: ServiceOrderStatus.completed,
        completedAt: DateTime.now(),
        technicianIds: technicianIds.toList(),
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.displayName,
        subtotal: subtotal,
        appliedDiscounts: List<ServiceOrderDiscount>.from(_appliedDiscounts),
        discountAmount: discountAmount,
        total: total,
        totalPaidSoFar: _totalPaidSoFar,
        partialPayments: List<double>.from(_partialPayments),
        isPaid: true,
      );

      await FirebaseService.saveServiceOrder(completedOrder);

      // Update all order items with the correct serviceOrderId and save them
      final updatedOrderItems = <ServiceOrderItem>[];
      for (final item in _orderItems) {
        final updatedItem = item.copyWith(serviceOrderId: orderId);
        updatedOrderItems.add(updatedItem);
        await FirebaseService.saveServiceOrderItem(updatedItem);
      }

      // Update the local order items list and current order
      _orderItems.clear();
      _orderItems.addAll(updatedOrderItems);
      _currentOrder = completedOrder;
    } catch (e) {
      debugPrint('Error completing order: $e');
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void setSelectedTechnician(String? technicianId) {
    _selectedTechnicianId = technicianId;
    notifyListeners();
  }

  void clearOrder() {
    _currentOrder = null;
    _orderItems.clear();
    _selectedCustomer = null;
    _selectedTechnicianId = null;
    _showDiscountSection = false;
    clearPaymentState();
    notifyListeners();
  }
}
