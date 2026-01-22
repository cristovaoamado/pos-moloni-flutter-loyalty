import 'coupon_models.dart';

/// DTO para registar uma venda (Passo 1: Confirmar)
class RegisterSaleRequest {
  final double amount;
  final String? cardBarcode;
  final String? paymentMethod;
  final String? posIdentifier;
  final int pointsToRedeem;
  final int? couponId;
  final List<CheckoutItem>? items;

  const RegisterSaleRequest({
    required this.amount,
    this.cardBarcode,
    this.paymentMethod,
    this.posIdentifier,
    this.pointsToRedeem = 0,
    this.couponId,
    this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      // CORRIGIDO: Backend espera 'cardIdentifier', não 'cardBarcode'
      if (cardBarcode != null) 'cardIdentifier': cardBarcode,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (posIdentifier != null) 'terminalId': posIdentifier,
      'pointsToRedeem': pointsToRedeem,
      if (couponId != null) 'couponId': couponId,
      if (items != null) 'items': items!.map((i) => i.toJson()).toList(),
    };
  }
}

/// Resultado do registo da venda
class RegisterSaleResult {
  final int saleId;
  final double amount;
  final double discountApplied;
  final double finalAmount;
  final int pointsEarned;
  final int pointsRedeemed;
  final int? newPointsBalance;
  final String? customerName;
  final String? tierName;
  final AppliedCoupon? couponApplied;
  final int bonusPointsFromCoupon;

  const RegisterSaleResult({
    required this.saleId,
    required this.amount,
    required this.discountApplied,
    required this.finalAmount,
    required this.pointsEarned,
    required this.pointsRedeemed,
    this.newPointsBalance,
    this.customerName,
    this.tierName,
    this.couponApplied,
    this.bonusPointsFromCoupon = 0,
  });

  factory RegisterSaleResult.fromJson(Map<String, dynamic> json) {
    // DEBUG: Log dos campos recebidos
    print('🔵 RegisterSaleResult.fromJson:');
    print('   saleId/transactionId: ${json['saleId'] ?? json['transactionId']}');
    print('   amount: ${json['amount']}');
    print('   discountApplied/discountFromPoints: ${json['discountApplied'] ?? json['discountFromPoints']}');
    print('   finalAmount: ${json['finalAmount']}');
    print('   pointsEarned: ${json['pointsEarned']}');
    print('   pointsRedeemed: ${json['pointsRedeemed']}');
    print('   newPointsBalance/newBalance: ${json['newPointsBalance'] ?? json['newBalance']}');
    print('   bonusPointsFromCoupon: ${json['bonusPointsFromCoupon']}');
    print('   couponApplied: ${json['couponApplied']}');
    
    // Parsing com múltiplos nomes de campo possíveis
    final saleId = json['saleId'] as int? ?? 
                   json['transactionId'] as int? ?? 
                   json['id'] as int? ?? 0;
    
    final amount = (json['amount'] as num?)?.toDouble() ?? 
                   (json['totalAmount'] as num?)?.toDouble() ?? 0;
    
    final discountApplied = (json['discountApplied'] as num?)?.toDouble() ??
                            (json['discountFromPoints'] as num?)?.toDouble() ??
                            (json['pointsDiscount'] as num?)?.toDouble() ?? 0;
    
    final finalAmount = (json['finalAmount'] as num?)?.toDouble() ??
                        (json['amountToPay'] as num?)?.toDouble() ??
                        (amount - discountApplied);
    
    final pointsEarned = json['pointsEarned'] as int? ?? 
                         json['points'] as int? ?? 0;
    
    final pointsRedeemed = json['pointsRedeemed'] as int? ??
                           json['pointsUsed'] as int? ?? 0;
    
    final newBalance = json['newPointsBalance'] as int? ?? 
                       json['newBalance'] as int? ??
                       json['balanceAfter'] as int?;
    
    final bonusPoints = json['bonusPointsFromCoupon'] as int? ??
                        json['bonusPoints'] as int? ?? 0;
    
    AppliedCoupon? coupon;
    if (json['couponApplied'] != null) {
      coupon = AppliedCoupon.fromJson(json['couponApplied'] as Map<String, dynamic>);
    } else if (json['appliedCoupon'] != null) {
      coupon = AppliedCoupon.fromJson(json['appliedCoupon'] as Map<String, dynamic>);
    }
    
    return RegisterSaleResult(
      saleId: saleId,
      amount: amount,
      discountApplied: discountApplied,
      finalAmount: finalAmount,
      pointsEarned: pointsEarned,
      pointsRedeemed: pointsRedeemed,
      newPointsBalance: newBalance,
      customerName: json['customerName'] as String?,
      tierName: json['tierName'] as String?,
      couponApplied: coupon,
      bonusPointsFromCoupon: bonusPoints,
    );
  }

  /// Total de desconto (pontos + cupão)
  double get totalDiscount => discountApplied + (couponApplied?.totalDiscount ?? 0);
  
  /// Total de pontos ganhos (base + bónus cupão)
  int get totalPointsEarned => pointsEarned + bonusPointsFromCoupon;
  
  @override
  String toString() {
    return 'RegisterSaleResult(saleId: $saleId, amount: $amount, finalAmount: $finalAmount, '
           'pointsEarned: $pointsEarned, pointsRedeemed: $pointsRedeemed, '
           'newBalance: $newPointsBalance, discount: $totalDiscount)';
  }
}

/// DTO para finalizar a venda (Passo 2: Finalizar)
class CompleteSaleRequest {
  final int saleId;
  final String? documentReference;
  final int? documentId;

  const CompleteSaleRequest({
    required this.saleId,
    this.documentReference,
    this.documentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'transactionId': saleId,
      if (documentReference != null) 'documentReference': documentReference,
      if (documentId != null) 'documentId': documentId,
    };
  }
}

/// DTO para cancelar uma venda
class CancelSaleRequest {
  final int saleId;
  final String? reason;

  const CancelSaleRequest({
    required this.saleId,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'transactionId': saleId,
      if (reason != null) 'reason': reason,
    };
  }
}

/// Resposta da API com dados da venda
class SaleResponse {
  final int id;
  final DateTime saleDate;
  final double amount;
  final int? cardId;
  final String? cardBarcode;
  final String? customerName;
  final int pointsEarned;
  final int pointsRedeemed;
  final double discountApplied;
  final String? documentReference;
  final int? documentId;
  final String? posIdentifier;
  final String? paymentMethod;
  final String status;
  final DateTime createdAt;

  const SaleResponse({
    required this.id,
    required this.saleDate,
    required this.amount,
    this.cardId,
    this.cardBarcode,
    this.customerName,
    required this.pointsEarned,
    required this.pointsRedeemed,
    required this.discountApplied,
    this.documentReference,
    this.documentId,
    this.posIdentifier,
    this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  factory SaleResponse.fromJson(Map<String, dynamic> json) {
    return SaleResponse(
      id: json['id'] as int,
      saleDate: DateTime.parse(json['saleDate'] as String),
      amount: (json['amount'] as num).toDouble(),
      cardId: json['cardId'] as int?,
      cardBarcode: json['cardBarcode'] as String?,
      customerName: json['customerName'] as String?,
      pointsEarned: json['pointsEarned'] as int? ?? 0,
      pointsRedeemed: json['pointsRedeemed'] as int? ?? 0,
      discountApplied: (json['discountApplied'] as num?)?.toDouble() ?? 0,
      documentReference: json['documentReference'] as String?,
      documentId: json['documentId'] as int?,
      posIdentifier: json['posIdentifier'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      status: json['status'] as String? ?? 'Pending',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isPending => status == 'Pending';
  bool get isCompleted => status == 'Completed';
  bool get isCancelled => status == 'Cancelled';
}
