import 'package:cloud_firestore/cloud_firestore.dart';
import 'service_order.dart'; // Import to use DiscountType

class ServiceOrderItemDiscount {
  final String name;
  final DiscountType type;
  final double value;
  final String? description;

  ServiceOrderItemDiscount({
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

  factory ServiceOrderItemDiscount.fromMap(Map<String, dynamic> data) {
    return ServiceOrderItemDiscount(
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

enum ServiceOrderItemStatus {
  pending('Pending'),
  inProgress('In Progress'),
  completed('Completed'),
  cancelled('Cancelled');

  const ServiceOrderItemStatus(this.displayName);
  final String displayName;

  static ServiceOrderItemStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ServiceOrderItemStatus.pending;
      case 'in progress':
      case 'inprogress':
        return ServiceOrderItemStatus.inProgress;
      case 'completed':
        return ServiceOrderItemStatus.completed;
      case 'cancelled':
        return ServiceOrderItemStatus.cancelled;
      default:
        return ServiceOrderItemStatus.pending;
    }
  }
}

class ServiceOrderItem {
  final String? id;
  final String serviceOrderId;
  final String serviceCatalogId;
  final String serviceName; // Denormalized for quick display
  final String? serviceDescription;
  final double originalPrice;
  final int quantity;
  final String technicianId;
  final String technicianName; // Denormalized for quick display
  final ServiceOrderItemStatus status;
  final ServiceOrderItemDiscount? itemDiscount;
  final double discountAmount;
  final double finalPrice; // After discount
  final double lineTotal; // finalPrice * quantity
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  final int estimatedDurationMinutes;
  final int? actualDurationMinutes;

  ServiceOrderItem({
    this.id,
    required this.serviceOrderId,
    required this.serviceCatalogId,
    required this.serviceName,
    this.serviceDescription,
    required this.originalPrice,
    this.quantity = 1,
    required this.technicianId,
    required this.technicianName,
    this.status = ServiceOrderItemStatus.pending,
    this.itemDiscount,
    this.discountAmount = 0.0,
    double? finalPrice,
    double? lineTotal,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.estimatedDurationMinutes = 0,
    this.actualDurationMinutes,
  }) : finalPrice =
           finalPrice ??
           (originalPrice -
               (itemDiscount?.calculateDiscount(originalPrice) ?? 0.0)),
       lineTotal =
           lineTotal ??
           ((finalPrice ??
                   (originalPrice -
                       (itemDiscount?.calculateDiscount(originalPrice) ??
                           0.0))) *
               quantity),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get isPending => status == ServiceOrderItemStatus.pending;
  bool get isInProgress => status == ServiceOrderItemStatus.inProgress;
  bool get isCompleted => status == ServiceOrderItemStatus.completed;
  bool get isCancelled => status == ServiceOrderItemStatus.cancelled;

  Duration? get actualDuration {
    if (startedAt != null && completedAt != null) {
      return completedAt!.difference(startedAt!);
    }
    return null;
  }

  Duration? get currentDuration {
    if (startedAt != null) {
      final endTime = completedAt ?? DateTime.now();
      return endTime.difference(startedAt!);
    }
    return null;
  }

  String get formattedDuration {
    final duration = actualDuration ?? currentDuration;
    if (duration == null) return 'Not started';

    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  // Factory constructor from Firestore document
  factory ServiceOrderItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceOrderItem(
      id: doc.id,
      serviceOrderId: data['serviceOrderId'] ?? '',
      serviceCatalogId: data['serviceCatalogId'] ?? '',
      serviceName: data['serviceName'] ?? '',
      serviceDescription: data['serviceDescription'],
      originalPrice: (data['originalPrice'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 1,
      technicianId: data['technicianId'] ?? '',
      technicianName: data['technicianName'] ?? '',
      status: ServiceOrderItemStatus.fromString(data['status'] ?? 'pending'),
      itemDiscount: data['itemDiscount'] != null
          ? ServiceOrderItemDiscount.fromMap(data['itemDiscount'])
          : null,
      discountAmount: (data['discountAmount'] ?? 0).toDouble(),
      finalPrice: (data['finalPrice'] ?? 0).toDouble(),
      lineTotal: (data['lineTotal'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      notes: data['notes'],
      estimatedDurationMinutes: data['estimatedDurationMinutes'] ?? 0,
      actualDurationMinutes: data['actualDurationMinutes'],
    );
  }

  // Factory constructor from Map
  factory ServiceOrderItem.fromMap(Map<String, dynamic> data, {String? id}) {
    return ServiceOrderItem(
      id: id,
      serviceOrderId: data['serviceOrderId'] ?? '',
      serviceCatalogId: data['serviceCatalogId'] ?? '',
      serviceName: data['serviceName'] ?? '',
      serviceDescription: data['serviceDescription'],
      originalPrice: (data['originalPrice'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 1,
      technicianId: data['technicianId'] ?? '',
      technicianName: data['technicianName'] ?? '',
      status: ServiceOrderItemStatus.fromString(data['status'] ?? 'pending'),
      itemDiscount: data['itemDiscount'] != null
          ? ServiceOrderItemDiscount.fromMap(data['itemDiscount'])
          : null,
      discountAmount: (data['discountAmount'] ?? 0).toDouble(),
      finalPrice: (data['finalPrice'] ?? 0).toDouble(),
      lineTotal: (data['lineTotal'] ?? 0).toDouble(),
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
      startedAt: data['startedAt'] is Timestamp
          ? (data['startedAt'] as Timestamp).toDate()
          : (data['startedAt'] != null
                ? DateTime.parse(data['startedAt'])
                : null),
      completedAt: data['completedAt'] is Timestamp
          ? (data['completedAt'] as Timestamp).toDate()
          : (data['completedAt'] != null
                ? DateTime.parse(data['completedAt'])
                : null),
      notes: data['notes'],
      estimatedDurationMinutes: data['estimatedDurationMinutes'] ?? 0,
      actualDurationMinutes: data['actualDurationMinutes'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'serviceOrderId': serviceOrderId,
      'serviceCatalogId': serviceCatalogId,
      'serviceName': serviceName,
      'serviceDescription': serviceDescription,
      'originalPrice': originalPrice,
      'quantity': quantity,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'status': status.displayName,
      'itemDiscount': itemDiscount?.toMap(),
      'discountAmount': discountAmount,
      'finalPrice': finalPrice,
      'lineTotal': lineTotal,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'notes': notes,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'actualDurationMinutes': actualDurationMinutes,
    };
  }

  // Create a copy with updated fields
  ServiceOrderItem copyWith({
    String? id,
    String? serviceOrderId,
    String? serviceCatalogId,
    String? serviceName,
    String? serviceDescription,
    double? originalPrice,
    int? quantity,
    String? technicianId,
    String? technicianName,
    ServiceOrderItemStatus? status,
    ServiceOrderItemDiscount? itemDiscount,
    double? discountAmount,
    double? finalPrice,
    double? lineTotal,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? notes,
    int? estimatedDurationMinutes,
    int? actualDurationMinutes,
  }) {
    final newOriginalPrice = originalPrice ?? this.originalPrice;
    final newItemDiscount = itemDiscount ?? this.itemDiscount;
    final newQuantity = quantity ?? this.quantity;
    final newDiscountAmount = discountAmount ?? this.discountAmount;
    final newFinalPrice =
        finalPrice ??
        (newOriginalPrice -
            (newItemDiscount?.calculateDiscount(newOriginalPrice) ??
                newDiscountAmount));
    final newLineTotal = lineTotal ?? (newFinalPrice * newQuantity);

    return ServiceOrderItem(
      id: id ?? this.id,
      serviceOrderId: serviceOrderId ?? this.serviceOrderId,
      serviceCatalogId: serviceCatalogId ?? this.serviceCatalogId,
      serviceName: serviceName ?? this.serviceName,
      serviceDescription: serviceDescription ?? this.serviceDescription,
      originalPrice: newOriginalPrice,
      quantity: newQuantity,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      status: status ?? this.status,
      itemDiscount: newItemDiscount,
      discountAmount: newDiscountAmount,
      finalPrice: newFinalPrice,
      lineTotal: newLineTotal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServiceOrderItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ServiceOrderItem{id: $id, service: $serviceName, technician: $technicianName, status: ${status.displayName}, lineTotal: \$${lineTotal.toStringAsFixed(2)}}';
  }
}
