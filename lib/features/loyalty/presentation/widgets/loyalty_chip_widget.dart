import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/loyalty_customer.dart';
import '../providers/loyalty_provider.dart';

/// Widget chip de fidelização para mostrar no header do POS
class LoyaltyChipWidget extends ConsumerWidget {
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const LoyaltyChipWidget({
    super.key,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loyaltyState = ref.watch(loyaltyProvider);

    // Se não está activo, não mostrar nada
    if (!loyaltyState.isEnabled) {
      return const SizedBox.shrink();
    }

    final customer = loyaltyState.currentCustomer;
    final isLoading = loyaltyState.isLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          constraints: const BoxConstraints(minWidth: 150), // Largura mínima para caber tudo
          decoration: BoxDecoration(
            color: customer != null
                ? _getTierColor(customer.card?.tier).withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: customer != null
                  ? _getTierColor(customer.card?.tier)
                  : Colors.grey,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  customer != null ? Icons.loyalty : Icons.loyalty_outlined,
                  size: 18,
                  color: customer != null
                      ? _getTierColor(customer.card?.tier)
                      : Colors.grey,
                ),
              const SizedBox(width: 8),
              if (customer != null) ...[
                // Layout numa só linha quando há cliente
                Text(
                  _truncateName(customer.name),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getTierColor(customer.card?.tier),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getTierColor(customer.card?.tier).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${customer.card?.pointsBalance ?? 0} pts',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _getTierColor(customer.card?.tier),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        customer.card?.tier.emoji ?? '🥉',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (onClear != null)
                  InkWell(
                    onTap: onClear,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: _getTierColor(customer.card?.tier),
                      ),
                    ),
                  ),
              ] else
                const Text(
                  'Cartão de Cliente',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _truncateName(String name) {
    if (name.length <= 15) return name;
    return '${name.substring(0, 12)}...';
  }

  Color _getTierColor(LoyaltyTier? tier) {
    if (tier == null) return Colors.grey;
    
    switch (tier) {
      case LoyaltyTier.bronze:
        return const Color(0xFFCD7F32);
      case LoyaltyTier.silver:
        return const Color(0xFFC0C0C0);
      case LoyaltyTier.gold:
        return const Color(0xFFFFD700);
      case LoyaltyTier.platinum:
        return const Color(0xFFE5E4E2);
    }
  }
}

/// Dialog para pesquisar cliente de fidelização
class LoyaltySearchDialog extends ConsumerStatefulWidget {
  const LoyaltySearchDialog({super.key});

  @override
  ConsumerState<LoyaltySearchDialog> createState() => _LoyaltySearchDialogState();
}

class _LoyaltySearchDialogState extends ConsumerState<LoyaltySearchDialog> {
  final _searchController = TextEditingController();
  final _barcodeController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loyaltyState = ref.watch(loyaltyProvider);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.loyalty, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('Identificar Cliente'),
          const Spacer(),
          if (loyaltyState.isConnected)
            const Icon(Icons.check_circle, color: Colors.green, size: 20)
          else
            const Icon(Icons.warning, color: Colors.orange, size: 20),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Campo para código de barras
            TextField(
              controller: _barcodeController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Código do cartão',
                hintText: 'Passe o cartão ou digite o código',
                prefixIcon: const Icon(Icons.credit_card),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchByBarcode,
                ),
              ),
              onSubmitted: (_) => _searchByBarcode(),
            ),
            
            const SizedBox(height: 16),
            
            // Erro
            if (loyaltyState.error != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loyaltyState.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Loading
            if (loyaltyState.isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),

            // Cliente identificado
            if (loyaltyState.currentCustomer != null)
              _buildCustomerCard(loyaltyState.currentCustomer!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        if (loyaltyState.currentCustomer != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Confirmar'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
      ],
    );
  }

  void _searchByBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    final success = await ref.read(loyaltyProvider.notifier)
        .identifyCustomerByBarcode(barcode);
    
    if (success && mounted) {
      // Fecha o dialog automaticamente após identificar
      Navigator.of(context).pop(true);
    }
  }

  Widget _buildCustomerCard(LoyaltyCustomer customer) {
    final card = customer.card;
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                customer.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (card != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoChip(
                  icon: Icons.credit_card,
                  label: card.cardNumber,
                ),
                _buildInfoChip(
                  icon: Icons.star,
                  label: '${card.pointsBalance} pts',
                ),
                _buildInfoChip(
                  icon: Icons.workspace_premium,
                  label: '${card.tier.emoji} ${card.tier.name}',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Mostra dialog de pesquisa de cliente
Future<bool?> showLoyaltySearchDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const LoyaltySearchDialog(),
  );
}
