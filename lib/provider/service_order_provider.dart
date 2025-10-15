import 'package:flutter/foundation.dart';
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

  // Calculated properties
  double get subtotal {
    return _orderItems.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  double get discountAmount {
    return _orderItems.fold(0.0, (sum, item) => sum + item.discountAmount);
  }

  double get total => subtotal - discountAmount;

  double get remainingBalance => total - _totalPaidSoFar;

  double get changeAmount => _amountPaid - remainingBalance;

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
    } else {
      final orderNumber = await FirebaseService.generateDailyOrderNumber();
      _currentOrder = ServiceOrder(orderNumber: orderNumber);
    }

    _isLoading = false;
    notifyListeners();
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

  void applyDiscount(double discountAmount) {
    if (_orderItems.isEmpty) return;

    // First, clear any existing discounts
    for (int i = 0; i < _orderItems.length; i++) {
      _orderItems[i] = _orderItems[i].copyWith(discountAmount: 0.0);
    }

    // Apply new discount proportionally across all items
    if (discountAmount > 0 && subtotal > 0) {
      double remainingDiscount = discountAmount;

      for (int i = 0; i < _orderItems.length; i++) {
        final item = _orderItems[i];
        final itemSubtotal = item.originalPrice * item.quantity;

        // Calculate proportional discount for this item
        double itemDiscount;
        if (i == _orderItems.length - 1) {
          // For the last item, use remaining discount to avoid rounding errors
          itemDiscount = remainingDiscount;
        } else {
          itemDiscount = (itemSubtotal / subtotal) * discountAmount;
          remainingDiscount -= itemDiscount;
        }

        // Ensure item discount doesn't exceed item subtotal
        itemDiscount = itemDiscount > itemSubtotal
            ? itemSubtotal
            : itemDiscount;

        _orderItems[i] = item.copyWith(discountAmount: itemDiscount);
      }
    }

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
      await FirebaseService.saveServiceOrder(_currentOrder!);
      // Save each order item separately
      for (final item in _orderItems) {
        await FirebaseService.saveServiceOrderItem(item);
      }
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
      final completedOrder = _currentOrder!.copyWith(
        status: ServiceOrderStatus.completed,
        completedAt: DateTime.now(),
      );

      await FirebaseService.saveServiceOrder(completedOrder);
      // Save each order item separately
      for (final item in _orderItems) {
        await FirebaseService.saveServiceOrderItem(item);
      }
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
