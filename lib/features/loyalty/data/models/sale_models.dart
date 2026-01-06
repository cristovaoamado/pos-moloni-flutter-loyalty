/// DTO para registar uma venda (Passo 1: Confirmar)
class RegisterSaleRequest {
  final double amount;
  final String? cardBarcode;
  final String? paymentMethod;
  final String? posIdentifier;
  final int pointsToRedeem;

  const RegisterSaleRequest({
    required this.amount,
    this.cardBarcode,
    this.paymentMethod,
    this.posIdentifier,
    this.pointsToRedeem = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      if (cardBarcode != null) 'cardBarcode': cardBarcode,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (posIdentifier != null) 'posIdentifier': posIdentifier,
      'pointsToRedeem': pointsToRedeem,
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
  });

  factory RegisterSaleResult.fromJson(Map<String, dynamic> json) {
    return RegisterSaleResult(
      saleId: json['saleId'] as int,
      amount: (json['amount'] as num).toDouble(),
      discountApplied: (json['discountApplied'] as num?)?.toDouble() ?? 0,
      finalAmount: (json['finalAmount'] as num).toDouble(),
      pointsEarned: json['pointsEarned'] as int? ?? 0,
      pointsRedeemed: json['pointsRedeemed'] as int? ?? 0,
      newPointsBalance: json['newPointsBalance'] as int?,
      customerName: json['customerName'] as String?,
      tierName: json['tierName'] as String?,
    );
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
      'saleId': saleId,
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
      'saleId': saleId,
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
