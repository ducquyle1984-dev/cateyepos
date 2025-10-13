enum CommissionType { percentage, fixedAmount, tiered }

class Commission {
  final String id;
  final String name;
  final String description;
  final CommissionType type;
  final double rate; // For percentage or fixed amount
  final List<CommissionTier>? tiers; // For tiered commissions
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Commission({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.rate,
    this.tiers,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Commission copyWith({
    String? id,
    String? name,
    String? description,
    CommissionType? type,
    double? rate,
    List<CommissionTier>? tiers,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Commission(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      rate: rate ?? this.rate,
      tiers: tiers ?? this.tiers,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'rate': rate,
      'tiers': tiers?.map((tier) => tier.toMap()).toList(),
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory Commission.fromMap(Map<String, dynamic> map) {
    return Commission(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: CommissionType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => CommissionType.percentage,
      ),
      rate: (map['rate'] ?? 0.0).toDouble(),
      tiers: map['tiers'] != null
          ? List<CommissionTier>.from(
              map['tiers'].map((tier) => CommissionTier.fromMap(tier)),
            )
          : null,
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }
}

class CommissionTier {
  final double minAmount;
  final double maxAmount;
  final double rate;

  CommissionTier({
    required this.minAmount,
    required this.maxAmount,
    required this.rate,
  });

  Map<String, dynamic> toMap() {
    return {'minAmount': minAmount, 'maxAmount': maxAmount, 'rate': rate};
  }

  factory CommissionTier.fromMap(Map<String, dynamic> map) {
    return CommissionTier(
      minAmount: (map['minAmount'] ?? 0.0).toDouble(),
      maxAmount: (map['maxAmount'] ?? 0.0).toDouble(),
      rate: (map['rate'] ?? 0.0).toDouble(),
    );
  }
}
