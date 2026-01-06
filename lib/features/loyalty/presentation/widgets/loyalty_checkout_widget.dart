import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/loyalty_customer.dart';
import '../providers/loyalty_provider.dart';

/// Widget de fidelização para o checkout (coluna direita)
class LoyaltyCheckoutWidget extends ConsumerStatefulWidget {
  final double cartTotal;
  final ValueChanged<int>? onPointsToRedeemChanged;

  const LoyaltyCheckoutWidget({
    super.key,
    required this.cartTotal,
    this.onPointsToRedeemChanged,
  });

  @override
  ConsumerState<LoyaltyCheckoutWidget> createState() => _LoyaltyCheckoutWidgetState();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildCustomerInfo(LoyaltyCustomer customer, LoyaltyState loyaltyState) {
    final card = customer.card;
    if (card == null) return const SizedBox.shrink();

    final pointsToEarn = loyaltyState.calculatePointsToEarn(widget.cartTotal);
    final maxDiscount = loyaltyState.calculateMaxDiscount(widget.cartTotal);
    final maxPoints = (maxDiscount * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info do cliente
        Container(
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
        ),
        
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
                    max: maxPoints.toDouble().clamp(0, card.pointsBalance.toDouble()),
                    divisions: maxPoints > 0 ? (maxPoints ~/ 10).clamp(1, 100) : 1,
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

        // Pontos a ganhar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
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
              '${card.pointsBalance - _pointsToRedeem + pointsToEarn} pontos',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
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

  const LoyaltySaleResultWidget({
    super.key,
    required this.pointsEarned,
    required this.pointsRedeemed,
    required this.discountApplied,
    this.newBalance,
    this.customerName,
    this.tierName,
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
              label: 'Desconto',
              value: '-${discountApplied.toStringAsFixed(2)} €',
            ),
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
