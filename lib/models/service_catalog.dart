class ServiceCatalog {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;
  final String categoryId;
  final List<String> tags;
  final bool isActive;
  final bool requiresAppointment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ServiceCatalog({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.categoryId,
    this.tags = const [],
    this.isActive = true,
    this.requiresAppointment = false,
    required this.createdAt,
    this.updatedAt,
  });

  ServiceCatalog copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? durationMinutes,
    String? categoryId,
    List<String>? tags,
    bool? isActive,
    bool? requiresAppointment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceCatalog(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      requiresAppointment: requiresAppointment ?? this.requiresAppointment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;

    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  String get formattedPrice {
    return '\$${price.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'durationMinutes': durationMinutes,
      'categoryId': categoryId,
      'tags': tags,
      'isActive': isActive,
      'requiresAppointment': requiresAppointment,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory ServiceCatalog.fromMap(Map<String, dynamic> map) {
    return ServiceCatalog(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      durationMinutes: map['durationMinutes'] ?? 0,
      categoryId: map['categoryId'] ?? 'cat_other',
      tags: List<String>.from(map['tags'] ?? []),
      isActive: map['isActive'] ?? true,
      requiresAppointment: map['requiresAppointment'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }
}
