/// Entidade que representa um cliente de fidelização
class LoyaltyCustomer {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? nif;
  final DateTime? birthDate;
  final LoyaltyCard? card;

  const LoyaltyCustomer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.nif,
    this.birthDate,
    this.card,
  });

  bool get hasCard => card != null;
  bool get hasBirthdayToday =>
      birthDate != null &&
      birthDate!.month == DateTime.now().month &&
      birthDate!.day == DateTime.now().day;
}

/// Entidade que representa um cartão de fidelização
class LoyaltyCard {
  final int id;
  final String cardNumber;
  final String? barcode;
  final int pointsBalance;
  final int totalPointsEarned;
  final int totalPointsRedeemed;
  final LoyaltyTier tier;
  final CardStatus status;
  final DateTime? lastUsedAt;

  const LoyaltyCard({
    required this.id,
    required this.cardNumber,
    this.barcode,
    required this.pointsBalance,
    required this.totalPointsEarned,
    required this.totalPointsRedeemed,
    required this.tier,
    required this.status,
    this.lastUsedAt,
  });

  bool get isActive => status == CardStatus.active;
  bool get canRedeemPoints => isActive && pointsBalance > 0;

  /// Calcula o valor em euros dos pontos (100 pts = 1€)
  double get pointsValueInEuros => pointsBalance / 100;
}

/// Níveis de fidelização
enum LoyaltyTier {
  bronze(1, 'Bronze', 1.0, '🥉'),
  silver(2, 'Prata', 1.1, '🥈'),
  gold(3, 'Ouro', 1.25, '🥇'),
  platinum(4, 'Platina', 1.5, '💎');

  final int level;
  final String name;
  final double multiplier;
  final String emoji;

  const LoyaltyTier(this.level, this.name, this.multiplier, this.emoji);

  static LoyaltyTier fromInt(int value) {
    return LoyaltyTier.values.firstWhere(
      (t) => t.level == value,
      orElse: () => LoyaltyTier.bronze,
    );
  }
}

/// Estado do cartão
enum CardStatus {
  active(1),
  inactive(2),
  blocked(3),
  lost(4);

  final int value;
  const CardStatus(this.value);

  static CardStatus fromInt(int value) {
    return CardStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => CardStatus.inactive,
    );
  }
}
