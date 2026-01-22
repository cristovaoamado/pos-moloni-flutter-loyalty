/// Enum para o tipo de scope do cupão
enum CouponScopeType {
  product(1),
  all(4);

  final int value;
  const CouponScopeType(this.value);

  static CouponScopeType fromInt(int value) {
    return CouponScopeType.values.firstWhere(
      (s) => s.value == value,
      orElse: () => CouponScopeType.all,
    );
  }

  String get displayName {
    switch (this) {
      case CouponScopeType.product:
        return 'Referências específicas';
      case CouponScopeType.all:
        return 'Todos os produtos';
    }
  }
}

/// Enum para o tipo de desconto/benefício do cupão
enum CouponDiscountType {
  percentage(1),
  bonusPoints(2);

  final int value;
  const CouponDiscountType(this.value);

  static CouponDiscountType fromInt(int value) {
    return CouponDiscountType.values.firstWhere(
      (s) => s.value == value,
      orElse: () => CouponDiscountType.percentage,
    );
  }

  String get displayName {
    switch (this) {
      case CouponDiscountType.percentage:
        return 'Desconto %';
      case CouponDiscountType.bonusPoints:
        return 'Pontos Bónus';
    }
  }

  bool get isPercentage => this == CouponDiscountType.percentage;
  bool get isBonusPoints => this == CouponDiscountType.bonusPoints;
}

/// Cupão disponível (retornado pela API ao identificar cliente)
class AvailableCoupon {
  final int id;
  final String code;
  final String name;
  final double discountPercent;
  final CouponDiscountType discountType;
  final String discountTypeName;
  final int bonusPoints;
  final CouponScopeType scopeType;
  final String scopeTypeName;
  final List<String> productReferences;
  final DateTime? validUntil;
  final bool isGlobal;
  final int remainingUses;

  const AvailableCoupon({
    required this.id,
    required this.code,
    required this.name,
    required this.discountPercent,
    required this.discountType,
    required this.discountTypeName,
    required this.bonusPoints,
    required this.scopeType,
    required this.scopeTypeName,
    required this.productReferences,
    this.validUntil,
    required this.isGlobal,
    required this.remainingUses,
  });

  factory AvailableCoupon.fromJson(Map<String, dynamic> json) {
    return AvailableCoupon(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
      discountType: CouponDiscountType.fromInt(json['discountType'] as int? ?? 1),
      discountTypeName: json['discountTypeName'] as String? ?? 'Desconto %',
      bonusPoints: json['bonusPoints'] as int? ?? 0,
      scopeType: CouponScopeType.fromInt(json['scopeType'] as int? ?? 4),
      scopeTypeName: json['scopeTypeName'] as String? ?? 'Todos',
      productReferences: (json['productReferences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      validUntil: json['validUntil'] != null
          ? DateTime.tryParse(json['validUntil'] as String)
          : null,
      isGlobal: json['isGlobal'] as bool? ?? false,
      remainingUses: json['remainingUses'] as int? ?? 0,
    );
  }

  /// Verifica se o cupão é de desconto percentual
  bool get isPercentageDiscount => discountType.isPercentage;

  /// Verifica se o cupão é de pontos bónus
  bool get isBonusPointsCoupon => discountType.isBonusPoints;

  /// Retorna o benefício formatado para exibição
  String get benefitDisplay {
    if (isBonusPointsCoupon) {
      return '+$bonusPoints pontos';
    } else {
      return '-${discountPercent.toStringAsFixed(0)}%';
    }
  }

  /// Verifica se o cupão é aplicável a uma referência de produto
  bool isApplicableToProduct(String productReference) {
    if (scopeType == CouponScopeType.all) return true;
    return productReferences.contains(productReference);
  }

  /// Verifica se o cupão é aplicável a uma lista de referências (carrinho)
  bool hasApplicableProducts(List<String> cartProductReferences) {
    if (scopeType == CouponScopeType.all) return true;
    return productReferences.any(
      (ref) => cartProductReferences.contains(ref),
    );
  }

  /// Retorna as referências do carrinho que são elegíveis para este cupão
  List<String> getEligibleProducts(List<String> cartProductReferences) {
    if (scopeType == CouponScopeType.all) return cartProductReferences;
    return cartProductReferences
        .where((ref) => productReferences.contains(ref))
        .toList();
  }

  bool get isValid => validUntil == null || validUntil!.isAfter(DateTime.now());
}

/// Item do checkout para enviar à API
class CheckoutItem {
  final String productReference;
  final String? productName;
  final int quantity;
  final double unitPrice;

  const CheckoutItem({
    required this.productReference,
    this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'productReference': productReference,
      if (productName != null) 'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}

/// Desconto aplicado a um item específico
class ItemDiscount {
  final String productReference;
  final String? productName;
  final double originalPrice;
  final double discount;
  final int bonusPoints;
  final double finalPrice;
  final String reason;

  const ItemDiscount({
    required this.productReference,
    this.productName,
    required this.originalPrice,
    required this.discount,
    required this.bonusPoints,
    required this.finalPrice,
    required this.reason,
  });

  factory ItemDiscount.fromJson(Map<String, dynamic> json) {
    return ItemDiscount(
      productReference: json['productReference'] as String? ?? '',
      productName: json['productName'] as String?,
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      bonusPoints: json['bonusPoints'] as int? ?? 0,
      finalPrice: (json['finalPrice'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
    );
  }
}

/// Resultado da aplicação de um cupão
class ApplyCouponResult {
  final bool applicable;
  final String? message;
  final CouponDiscountType discountType;
  final double totalDiscount;
  final int totalBonusPoints;
  final List<ItemDiscount> itemDiscounts;

  const ApplyCouponResult({
    required this.applicable,
    this.message,
    required this.discountType,
    required this.totalDiscount,
    required this.totalBonusPoints,
    required this.itemDiscounts,
  });

  factory ApplyCouponResult.fromJson(Map<String, dynamic> json) {
    return ApplyCouponResult(
      applicable: json['applicable'] as bool? ?? false,
      message: json['message'] as String?,
      discountType: CouponDiscountType.fromInt(json['discountType'] as int? ?? 1),
      totalDiscount: (json['totalDiscount'] as num?)?.toDouble() ?? 0,
      totalBonusPoints: json['totalBonusPoints'] as int? ?? 0,
      itemDiscounts: (json['itemDiscounts'] as List<dynamic>?)
              ?.map((e) => ItemDiscount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Verifica se é desconto percentual
  bool get isPercentageDiscount => discountType.isPercentage;

  /// Verifica se é pontos bónus
  bool get isBonusPoints => discountType.isBonusPoints;
}

/// Cupão aplicado (incluído no resultado da confirmação da venda)
class AppliedCoupon {
  final int couponId;
  final String code;
  final String name;
  final CouponDiscountType discountType;
  final double totalDiscount;
  final int totalBonusPoints;
  final List<ItemDiscount> itemDiscounts;

  const AppliedCoupon({
    required this.couponId,
    required this.code,
    required this.name,
    required this.discountType,
    required this.totalDiscount,
    required this.totalBonusPoints,
    required this.itemDiscounts,
  });

  factory AppliedCoupon.fromJson(Map<String, dynamic> json) {
    return AppliedCoupon(
      couponId: json['couponId'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      discountType: CouponDiscountType.fromInt(json['discountType'] as int? ?? 1),
      totalDiscount: (json['totalDiscount'] as num?)?.toDouble() ?? 0,
      totalBonusPoints: json['totalBonusPoints'] as int? ?? 0,
      itemDiscounts: (json['itemDiscounts'] as List<dynamic>?)
              ?.map((e) => ItemDiscount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Verifica se é desconto percentual
  bool get isPercentageDiscount => discountType.isPercentage;

  /// Verifica se é pontos bónus
  bool get isBonusPoints => discountType.isBonusPoints;
}
