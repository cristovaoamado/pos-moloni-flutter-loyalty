import '../../domain/entities/loyalty_customer.dart';

/// Modelo para deserialização do cliente da API
class LoyaltyCustomerModel {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? nif;
  final DateTime? birthDate;
  final LoyaltyCardModel? card;

  const LoyaltyCustomerModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.nif,
    this.birthDate,
    this.card,
  });

  factory LoyaltyCustomerModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyCustomerModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      nif: json['nif'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'] as String)
          : null,
      card: json['card'] != null
          ? LoyaltyCardModel.fromJson(json['card'] as Map<String, dynamic>)
          : null,
    );
  }

  LoyaltyCustomer toEntity() {
    return LoyaltyCustomer(
      id: id,
      name: name,
      email: email,
      phone: phone,
      nif: nif,
      birthDate: birthDate,
      card: card?.toEntity(),
    );
  }
}

/// Modelo para deserialização do cartão da API
class LoyaltyCardModel {
  final int id;
  final String cardNumber;
  final String? barcode;
  final int pointsBalance;
  final int totalPointsEarned;
  final int totalPointsRedeemed;
  final int tier;
  final int status;
  final DateTime? lastUsedAt;
  final String? customerName;

  const LoyaltyCardModel({
    required this.id,
    required this.cardNumber,
    this.barcode,
    required this.pointsBalance,
    required this.totalPointsEarned,
    required this.totalPointsRedeemed,
    required this.tier,
    required this.status,
    this.lastUsedAt,
    this.customerName,
  });

  factory LoyaltyCardModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyCardModel(
      id: json['id'] as int,
      cardNumber: json['cardNumber'] as String? ?? '',
      barcode: json['barcode'] as String?,
      pointsBalance: json['pointsBalance'] as int? ?? 0,
      totalPointsEarned: json['totalPointsEarned'] as int? ?? 0,
      totalPointsRedeemed: json['totalPointsRedeemed'] as int? ?? 0,
      tier: json['tier'] as int? ?? 1,
      status: json['status'] as int? ?? 1,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'] as String)
          : null,
      customerName: json['customerName'] as String?,
    );
  }

  LoyaltyCard toEntity() {
    return LoyaltyCard(
      id: id,
      cardNumber: cardNumber,
      barcode: barcode,
      pointsBalance: pointsBalance,
      totalPointsEarned: totalPointsEarned,
      totalPointsRedeemed: totalPointsRedeemed,
      tier: LoyaltyTier.fromInt(tier),
      status: CardStatus.fromInt(status),
      lastUsedAt: lastUsedAt,
    );
  }
}

/// Modelo para resposta de info do cartão (endpoint /api/pos/card/{barcode})
class CardInfoResponse {
  final int cardId;
  final String cardNumber;
  final String? barcode;
  final int customerId;
  final String customerName;
  final int pointsBalance;
  final int tier;
  final String tierName;
  final double pointsMultiplier;
  final bool isActive;

  const CardInfoResponse({
    required this.cardId,
    required this.cardNumber,
    this.barcode,
    required this.customerId,
    required this.customerName,
    required this.pointsBalance,
    required this.tier,
    required this.tierName,
    required this.pointsMultiplier,
    required this.isActive,
  });

  factory CardInfoResponse.fromJson(Map<String, dynamic> json) {
    return CardInfoResponse(
      cardId: json['cardId'] as int? ?? json['id'] as int? ?? 0,
      cardNumber: json['cardNumber'] as String? ?? '',
      barcode: json['barcode'] as String?,
      customerId: json['customerId'] as int? ?? 0,
      customerName: json['customerName'] as String? ?? '',
      pointsBalance: json['pointsBalance'] as int? ?? 0,
      tier: json['tier'] as int? ?? 1,
      tierName: json['tierName'] as String? ?? 'Bronze',
      pointsMultiplier: (json['pointsMultiplier'] as num?)?.toDouble() ?? 1.0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  LoyaltyCustomer toEntity() {
    return LoyaltyCustomer(
      id: customerId,
      name: customerName,
      card: LoyaltyCard(
        id: cardId,
        cardNumber: cardNumber,
        barcode: barcode,
        pointsBalance: pointsBalance,
        totalPointsEarned: 0,
        totalPointsRedeemed: 0,
        tier: LoyaltyTier.fromInt(tier),
        status: isActive ? CardStatus.active : CardStatus.inactive,
      ),
    );
  }
}
