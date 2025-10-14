import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String? id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? address;
  final int loyaltyPoints;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final List<String> orderHistory; // List of service order IDs
  final double totalSpent;
  final int totalVisits;
  final DateTime? lastVisit;
  final String? notes;

  Customer({
    this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.address,
    this.loyaltyPoints = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
    this.orderHistory = const [],
    this.totalSpent = 0.0,
    this.totalVisits = 0,
    this.lastVisit,
    this.notes,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName';

  String get displayName {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    } else {
      return 'Unnamed Customer';
    }
  }

  String get primaryContact {
    if (phone != null && phone!.isNotEmpty) {
      return phone!;
    } else if (email != null && email!.isNotEmpty) {
      return email!;
    } else {
      return 'No contact info';
    }
  }

  // Factory constructor from Firestore document
  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'],
      phone: data['phone'],
      address: data['address'],
      loyaltyPoints: data['loyaltyPoints'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      orderHistory: List<String>.from(data['orderHistory'] ?? []),
      totalSpent: (data['totalSpent'] ?? 0).toDouble(),
      totalVisits: data['totalVisits'] ?? 0,
      lastVisit: (data['lastVisit'] as Timestamp?)?.toDate(),
      notes: data['notes'],
    );
  }

  // Factory constructor from Map
  factory Customer.fromMap(Map<String, dynamic> data, {String? id}) {
    return Customer(
      id: id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'],
      phone: data['phone'],
      address: data['address'],
      loyaltyPoints: data['loyaltyPoints'] ?? 0,
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
      isActive: data['isActive'] ?? true,
      orderHistory: List<String>.from(data['orderHistory'] ?? []),
      totalSpent: (data['totalSpent'] ?? 0).toDouble(),
      totalVisits: data['totalVisits'] ?? 0,
      lastVisit: data['lastVisit'] is Timestamp
          ? (data['lastVisit'] as Timestamp).toDate()
          : (data['lastVisit'] != null
                ? DateTime.parse(data['lastVisit'])
                : null),
      notes: data['notes'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'address': address,
      'loyaltyPoints': loyaltyPoints,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'orderHistory': orderHistory,
      'totalSpent': totalSpent,
      'totalVisits': totalVisits,
      'lastVisit': lastVisit != null ? Timestamp.fromDate(lastVisit!) : null,
      'notes': notes,
    };
  }

  // Create a copy with updated fields
  Customer copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? address,
    int? loyaltyPoints,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    List<String>? orderHistory,
    double? totalSpent,
    int? totalVisits,
    DateTime? lastVisit,
    String? notes,
  }) {
    return Customer(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
      orderHistory: orderHistory ?? this.orderHistory,
      totalSpent: totalSpent ?? this.totalSpent,
      totalVisits: totalVisits ?? this.totalVisits,
      lastVisit: lastVisit ?? this.lastVisit,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Customer{id: $id, name: $displayName, phone: $phone, email: $email, loyaltyPoints: $loyaltyPoints}';
  }
}
