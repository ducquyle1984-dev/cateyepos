import 'package:cloud_firestore/cloud_firestore.dart';

enum ServiceOrderStatus {
  newOrder('New'),
  inProgress('In Progress'),
  completed('Completed'),
  cancelled('Cancelled');

  const ServiceOrderStatus(this.displayName);
  final String displayName;

  static ServiceOrderStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return ServiceOrderStatus.newOrder;
      case 'in progress':
      case 'inprogress':
        return ServiceOrderStatus.inProgress;
      case 'completed':
        return ServiceOrderStatus.completed;
      case 'cancelled':
        return ServiceOrderStatus.cancelled;
      default:
        return ServiceOrderStatus.newOrder;
    }
  }
}

enum DiscountType {
  percentage('Percentage'),
  fixedAmount('Fixed Amount');

  const DiscountType(this.displayName);
  final String displayName;

  static DiscountType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'percentage':
        return DiscountType.percentage;
      case 'fixed amount':
      case 'fixedamount':
        return DiscountType.fixedAmount;
      default:
        return DiscountType.percentage;
    }
  }
}

class ServiceOrderDiscount {
  final String name;
  final DiscountType type;
  final double value;
  final String? description;

  ServiceOrderDiscount({
    required this.name,
    required this.type,
    required this.value,
    this.description,
  });

  double calculateDiscount(double amount) {
    switch (type) {
      case DiscountType.percentage:
        return amount * (value / 100);
      case DiscountType.fixedAmount:
        return value > amount ? amount : value;
    }
  }

  factory ServiceOrderDiscount.fromMap(Map<String, dynamic> data) {
    return ServiceOrderDiscount(
      name: data['name'] ?? '',
      type: DiscountType.fromString(data['type'] ?? 'percentage'),
      value: (data['value'] ?? 0).toDouble(),
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.displayName,
      'value': value,
      'description': description,
    };
  }
}

class ServiceOrder {
  final String? id;
  final String orderNumber;
  final ServiceOrderStatus status;
  final String? customerId;
  final String? customerName; // Denormalized for quick display
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final List<String>
  serviceOrderItemIds; // References to ServiceOrderItem documents
  final double subtotal;
  final ServiceOrderDiscount? orderDiscount;
  final double discountAmount;
  final double taxAmount;
  final double total;
  final String? notes;
  final List<String> technicianIds; // All technicians involved in this order
  final bool isPaid;
  final String? paymentMethod; // 'cash', 'credit', 'debit', etc.
  final DateTime? paidAt;
  final int loyaltyPointsEarned;
  final int loyaltyPointsUsed;

  ServiceOrder({
    this.id,
    required this.orderNumber,
    this.status = ServiceOrderStatus.newOrder,
    this.customerId,
    this.customerName,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
    this.serviceOrderItemIds = const [],
    this.subtotal = 0.0,
    this.orderDiscount,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.total = 0.0,
    this.notes,
    this.technicianIds = const [],
    this.isPaid = false,
    this.paymentMethod,
    this.paidAt,
    this.loyaltyPointsEarned = 0,
    this.loyaltyPointsUsed = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Duration get timeOpen {
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(createdAt);
  }

  String get formattedTimeOpen {
    final duration = timeOpen;
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  bool get isNew => status == ServiceOrderStatus.newOrder;
  bool get isInProgress => status == ServiceOrderStatus.inProgress;
  bool get isCompleted => status == ServiceOrderStatus.completed;
  bool get isCancelled => status == ServiceOrderStatus.cancelled;

  String get displayCustomer => customerName ?? 'Walk-in Customer';

  // Factory constructor from Firestore document
  factory ServiceOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceOrder(
      id: doc.id,
      orderNumber: data['orderNumber'] ?? '',
      status: ServiceOrderStatus.fromString(data['status'] ?? 'new'),
      customerId: data['customerId'],
      customerName: data['customerName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      serviceOrderItemIds: List<String>.from(data['serviceOrderItemIds'] ?? []),
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      orderDiscount: data['orderDiscount'] != null
          ? ServiceOrderDiscount.fromMap(data['orderDiscount'])
          : null,
      discountAmount: (data['discountAmount'] ?? 0).toDouble(),
      taxAmount: (data['taxAmount'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      notes: data['notes'],
      technicianIds: List<String>.from(data['technicianIds'] ?? []),
      isPaid: data['isPaid'] ?? false,
      paymentMethod: data['paymentMethod'],
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      loyaltyPointsEarned: data['loyaltyPointsEarned'] ?? 0,
      loyaltyPointsUsed: data['loyaltyPointsUsed'] ?? 0,
    );
  }

  // Factory constructor from Map
  factory ServiceOrder.fromMap(Map<String, dynamic> data, {String? id}) {
    return ServiceOrder(
      id: id,
      orderNumber: data['orderNumber'] ?? '',
      status: ServiceOrderStatus.fromString(data['status'] ?? 'new'),
      customerId: data['customerId'],
      customerName: data['customerName'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
              data['createdAt'] ?? DateTime.now().toIso8601String(),
            ),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(
              data['updatedAt'] ?? DateTime.now().toIso8601String(),
            ),
      completedAt: data['completedAt'] is Timestamp
          ? (data['completedAt'] as Timestamp).toDate()
          : (data['completedAt'] != null
                ? DateTime.parse(data['completedAt'])
                : null),
      serviceOrderItemIds: List<String>.from(data['serviceOrderItemIds'] ?? []),
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      orderDiscount: data['orderDiscount'] != null
          ? ServiceOrderDiscount.fromMap(data['orderDiscount'])
          : null,
      discountAmount: (data['discountAmount'] ?? 0).toDouble(),
      taxAmount: (data['taxAmount'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      notes: data['notes'],
      technicianIds: List<String>.from(data['technicianIds'] ?? []),
      isPaid: data['isPaid'] ?? false,
      paymentMethod: data['paymentMethod'],
      paidAt: data['paidAt'] is Timestamp
          ? (data['paidAt'] as Timestamp).toDate()
          : (data['paidAt'] != null ? DateTime.parse(data['paidAt']) : null),
      loyaltyPointsEarned: data['loyaltyPointsEarned'] ?? 0,
      loyaltyPointsUsed: data['loyaltyPointsUsed'] ?? 0,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber,
      'status': status.displayName,
      'customerId': customerId,
      'customerName': customerName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'serviceOrderItemIds': serviceOrderItemIds,
      'subtotal': subtotal,
      'orderDiscount': orderDiscount?.toMap(),
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'total': total,
      'notes': notes,
      'technicianIds': technicianIds,
      'isPaid': isPaid,
      'paymentMethod': paymentMethod,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'loyaltyPointsEarned': loyaltyPointsEarned,
      'loyaltyPointsUsed': loyaltyPointsUsed,
    };
  }

  // Create a copy with updated fields
  ServiceOrder copyWith({
    String? id,
    String? orderNumber,
    ServiceOrderStatus? status,
    String? customerId,
    String? customerName,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    List<String>? serviceOrderItemIds,
    double? subtotal,
    ServiceOrderDiscount? orderDiscount,
    double? discountAmount,
    double? taxAmount,
    double? total,
    String? notes,
    List<String>? technicianIds,
    bool? isPaid,
    String? paymentMethod,
    DateTime? paidAt,
    int? loyaltyPointsEarned,
    int? loyaltyPointsUsed,
  }) {
    return ServiceOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      completedAt: completedAt ?? this.completedAt,
      serviceOrderItemIds: serviceOrderItemIds ?? this.serviceOrderItemIds,
      subtotal: subtotal ?? this.subtotal,
      orderDiscount: orderDiscount ?? this.orderDiscount,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      notes: notes ?? this.notes,
      technicianIds: technicianIds ?? this.technicianIds,
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAt: paidAt ?? this.paidAt,
      loyaltyPointsEarned: loyaltyPointsEarned ?? this.loyaltyPointsEarned,
      loyaltyPointsUsed: loyaltyPointsUsed ?? this.loyaltyPointsUsed,
    );
  }

  static String generateOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(6);
    return 'SO$timestamp';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServiceOrder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ServiceOrder{id: $id, orderNumber: $orderNumber, status: ${status.displayName}, customer: $displayCustomer, total: \$${total.toStringAsFixed(2)}}';
  }
}
