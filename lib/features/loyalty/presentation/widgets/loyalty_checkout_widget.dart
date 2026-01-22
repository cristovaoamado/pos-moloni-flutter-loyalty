import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/loyalty_customer.dart';
import '../../data/models/coupon_models.dart';
import '../providers/loyalty_provider.dart';

/// Widget de fidelização para o checkout (coluna direita)
class LoyaltyCheckoutWidget extends ConsumerStatefulWidget {
  final double cartTotal;
  final List<String> cartProductReferences;
  final List<CheckoutItem> checkoutItems;
  final ValueChanged<int>? onPointsToRedeemChanged;
  final ValueChanged<AvailableCoupon?>? onCouponChanged;

  const LoyaltyCheckoutWidget({
    super.key,
    required this.cartTotal,
    required this.cartProductReferences,
    required this.checkoutItems,
    this.onPointsToRedeemChanged,
    this.onCouponChanged,
  });

  @override
  ConsumerState<LoyaltyCheckoutWidget> createState() =>
      _LoyaltyCheckoutWidgetState();
}

class _LoyaltyCheckoutWidgetState extends ConsumerState<LoyaltyCheckoutWidget> {
  bool _usePoints = false;
  int _pointsToRedeem = 0;

  @override
  Widget build(BuildContext context) {
    final loyaltyState = ref.watch(loyaltyProvider);
    final customer = loyaltyState.currentCustomer;

    if (!loyaltyState.isEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.loyalty,
                  color: customer != null ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Fidelização',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: customer != null ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            if (customer != null)
              _buildCustomerInfo(customer, loyaltyState)
            else
              _buildNoCustomer(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCustomer() {
    return Column(
      children: [
        Icon(
          Icons.person_add_outlined,
          size: 48,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 8),
        Text(
          'Sem cartão fidelização',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Passe o cartão no leitor ou\npesquise pelo código',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfo(
      LoyaltyCustomer customer, LoyaltyState loyaltyState) {
    final card = customer.card;
    if (card == null) return const SizedBox.shrink();

    final pointsToEarn = loyaltyState.calculatePointsToEarn(widget.cartTotal);
    final maxDiscount = loyaltyState.calculateMaxDiscount(widget.cartTotal);
    final maxPoints = (maxDiscount * 100).toInt();

    // Cupões aplicáveis ao carrinho
    final applicableCoupons =
        loyaltyState.getApplicableCoupons(widget.cartProductReferences);

    // Pontos bónus do cupão seleccionado
    final couponBonusPoints = loyaltyState.couponBonusPoints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info do cliente
        _buildCustomerCard(customer, card),

        const SizedBox(height: 16),

        // Saldo de pontos
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Saldo actual:'),
            Text(
              '${card.pointsBalance} pontos',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Text(
          '(equivale a ${card.pointsValueInEuros.toStringAsFixed(2)} €)',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),

        const Divider(height: 24),

        // Usar pontos
        if (card.pointsBalance > 0) ...[
          CheckboxListTile(
            value: _usePoints,
            onChanged: (value) {
              setState(() {
                _usePoints = value ?? false;
                if (!_usePoints) {
                  _pointsToRedeem = 0;
                  widget.onPointsToRedeemChanged?.call(0);
                } else {
                  _pointsToRedeem = maxPoints.clamp(0, card.pointsBalance);
                  widget.onPointsToRedeemChanged?.call(_pointsToRedeem);
                }
              });
            },
            title: const Text('Usar pontos como desconto'),
            subtitle: Text(
              'Máximo: $maxPoints pts = ${maxDiscount.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 12),
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_usePoints) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _pointsToRedeem.toDouble(),
                    min: 0,
                    max: maxPoints
                        .toDouble()
                        .clamp(0, card.pointsBalance.toDouble()),
                    divisions:
                        maxPoints > 0 ? (maxPoints ~/ 10).clamp(1, 100) : 1,
                    label: '$_pointsToRedeem pts',
                    onChanged: (value) {
                      setState(() {
                        _pointsToRedeem = value.toInt();
                      });
                      widget.onPointsToRedeemChanged?.call(_pointsToRedeem);
                    },
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '-${(_pointsToRedeem / 100).toStringAsFixed(2)} €',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
        ],

        // CUPÕES
        if (applicableCoupons.isNotEmpty) ...[
          _buildCouponsSection(applicableCoupons, loyaltyState),
          const Divider(height: 24),
        ],

        // Pontos a ganhar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Text('Vai ganhar:'),
                  const Spacer(),
                  Text(
                    '+$pointsToEarn pontos',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              // Mostrar pontos bónus do cupão se aplicável
              if (couponBonusPoints > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Text('Bónus cupão:'),
                    const Spacer(),
                    Text(
                      '+$couponBonusPoints pontos',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text('Total:'),
                    const Spacer(),
                    Text(
                      '+${pointsToEarn + couponBonusPoints} pontos',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        if (card.tier.multiplier > 1) ...[
          const SizedBox(height: 4),
          Text(
            '(${card.tier.name}: ${((card.tier.multiplier - 1) * 100).toInt()}% bónus)',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        // Novo saldo
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Novo saldo:'),
            Text(
              '${card.pointsBalance - _pointsToRedeem + pointsToEarn + couponBonusPoints} pontos',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerCard(LoyaltyCustomer customer, LoyaltyCard card) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getTierColor(card.tier).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getTierColor(card.tier).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                size: 20,
                color: _getTierColor(card.tier),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getTierColor(card.tier),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${card.tier.emoji} ${card.tier.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.credit_card,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                card.cardNumber,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponsSection(
      List<AvailableCoupon> coupons, LoyaltyState loyaltyState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_offer, size: 20, color: Colors.orange),
            const SizedBox(width: 8),
            const Text(
              'Cupões Disponíveis',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${coupons.length}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Lista de cupões
        ...coupons.map((coupon) => _buildCouponTile(coupon, loyaltyState)),

        // Resultado do cálculo do cupão
        if (loyaltyState.couponCalculation != null &&
            loyaltyState.selectedCoupon != null)
          _buildCouponCalculationResult(loyaltyState),
      ],
    );
  }

  Widget _buildCouponTile(AvailableCoupon coupon, LoyaltyState loyaltyState) {
    final isSelected = loyaltyState.selectedCoupon?.id == coupon.id;
    final eligibleProducts =
        coupon.getEligibleProducts(widget.cartProductReferences);

    // Cores diferentes para tipo de cupão
    final Color couponColor = coupon.isBonusPointsCoupon 
        ? Colors.purple 
        : Colors.orange;
    final Color benefitColor = coupon.isBonusPointsCoupon 
        ? Colors.purple 
        : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? couponColor.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? couponColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onCouponTap(coupon, isSelected),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Checkbox/Radio visual
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? couponColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? couponColor : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Info do cupão
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: couponColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                coupon.code,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Ícone do tipo de cupão
                            Icon(
                              coupon.isBonusPointsCoupon 
                                  ? Icons.star 
                                  : Icons.percent,
                              size: 16,
                              color: benefitColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              coupon.benefitDisplay,
                              style: TextStyle(
                                color: benefitColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          coupon.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        // Badge do tipo de cupão
                        if (coupon.isBonusPointsCoupon) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Colors.purple.withOpacity(0.3)),
                            ),
                            child: const Text(
                              '⭐ Pontos Bónus',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Produtos elegíveis
              if (eligibleProducts.isNotEmpty &&
                  coupon.scopeType == CouponScopeType.product) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: eligibleProducts.take(5).map((ref) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Text(
                        ref,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green[700],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (eligibleProducts.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${eligibleProducts.length - 5} mais',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],

              // Validade
              if (coupon.validUntil != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Válido até ${_formatDate(coupon.validUntil!)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCouponCalculationResult(LoyaltyState loyaltyState) {
    final calculation = loyaltyState.couponCalculation!;
    final coupon = loyaltyState.selectedCoupon!;

    if (!calculation.applicable) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                calculation.message ?? 'Cupão não aplicável',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Resultado para cupão de PONTOS BÓNUS
    if (calculation.isBonusPoints) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Cupão ${coupon.code} aplicado!',
                  style: const TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '+${calculation.totalBonusPoints} pontos',
                  style: const TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (calculation.itemDiscounts.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...calculation.itemDiscounts.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.productName ?? item.productReference,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '+${item.bonusPoints} pts',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.purple[700],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      );
    }

    // Resultado para cupão de DESCONTO PERCENTUAL
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Cupão ${coupon.code} aplicado!',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '-${calculation.totalDiscount.toStringAsFixed(2)} €',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (calculation.itemDiscounts.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...calculation.itemDiscounts.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName ?? item.productReference,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '-${item.discount.toStringAsFixed(2)} €',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _onCouponTap(AvailableCoupon coupon, bool isSelected) {
    if (isSelected) {
      // Desselecionar
      ref.read(loyaltyProvider.notifier).clearCoupon();
      widget.onCouponChanged?.call(null);
    } else {
      // Selecionar e calcular
      ref
          .read(loyaltyProvider.notifier)
          .selectCoupon(coupon, widget.checkoutItems);
      widget.onCouponChanged?.call(coupon);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _getTierColor(LoyaltyTier tier) {
    switch (tier) {
      case LoyaltyTier.bronze:
        return const Color(0xFFCD7F32);
      case LoyaltyTier.silver:
        return const Color(0xFF808080);
      case LoyaltyTier.gold:
        return const Color(0xFFDAA520);
      case LoyaltyTier.platinum:
        return const Color(0xFF4A4A4A);
    }
  }
}

/// Widget compacto para mostrar resultado após registar venda
class LoyaltySaleResultWidget extends StatelessWidget {
  final int pointsEarned;
  final int pointsRedeemed;
  final double discountApplied;
  final int? newBalance;
  final String? customerName;
  final String? tierName;
  final AppliedCoupon? couponApplied;

  const LoyaltySaleResultWidget({
    super.key,
    required this.pointsEarned,
    required this.pointsRedeemed,
    required this.discountApplied,
    this.newBalance,
    this.customerName,
    this.tierName,
    this.couponApplied,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Venda registada',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          if (customerName != null) ...[
            const SizedBox(height: 8),
            Text(
              '$customerName ${tierName != null ? "($tierName)" : ""}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const Divider(height: 16),
          if (pointsEarned > 0)
            _buildRow(
              icon: Icons.add_circle,
              color: Colors.green,
              label: 'Pontos ganhos',
              value: '+$pointsEarned',
            ),
          if (pointsRedeemed > 0)
            _buildRow(
              icon: Icons.remove_circle,
              color: Colors.orange,
              label: 'Pontos usados',
              value: '-$pointsRedeemed',
            ),
          if (discountApplied > 0)
            _buildRow(
              icon: Icons.local_offer,
              color: Colors.blue,
              label: 'Desc. pontos',
              value: '-${discountApplied.toStringAsFixed(2)} €',
            ),
          if (couponApplied != null) ...[
            if (couponApplied!.isPercentageDiscount)
              _buildRow(
                icon: Icons.confirmation_number,
                color: Colors.orange,
                label: 'Cupão ${couponApplied!.code}',
                value: '-${couponApplied!.totalDiscount.toStringAsFixed(2)} €',
              ),
            if (couponApplied!.isBonusPoints)
              _buildRow(
                icon: Icons.star,
                color: Colors.purple,
                label: 'Bónus ${couponApplied!.code}',
                value: '+${couponApplied!.totalBonusPoints} pts',
              ),
          ],
          if (newBalance != null)
            _buildRow(
              icon: Icons.account_balance_wallet,
              color: Colors.purple,
              label: 'Novo saldo',
              value: '$newBalance pts',
            ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
