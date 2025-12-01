import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';
import 'package:pos_moloni_app/features/document_sets/domain/entities/document_set.dart';

/// Painel do talão de venda (lado direito)
class ReceiptPanel extends ConsumerWidget {
  const ReceiptPanel({
    super.key,
    required this.selectedDocumentOption,
    required this.selectedCustomer,
    required this.suspendedSalesCount,
    required this.isLoadingDocTypes,
    required this.onDocumentTypeTap,
    required this.onCustomerSearchTap,
    required this.onSuspendedSalesTap,
    required this.onItemTap,
    required this.onCancelTap,
    required this.onSuspendTap,
    required this.onFinalizeTap,
  });

  final DocumentTypeOption? selectedDocumentOption;
  final Customer selectedCustomer;
  final int suspendedSalesCount;
  final bool isLoadingDocTypes;
  final VoidCallback onDocumentTypeTap;
  final VoidCallback onCustomerSearchTap;
  final VoidCallback onSuspendedSalesTap;
  final Function(CartItem) onItemTap;
  final VoidCallback onCancelTap;
  final VoidCallback onSuspendTap;
  final VoidCallback onFinalizeTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // Botões de Opções
          _buildOptionsBar(context),
          const Divider(height: 1),

          // Tipo de documento e cliente
          _buildDocumentHeader(context),
          const Divider(height: 1),

          // Lista de itens
          Expanded(
            child: cart.isEmpty
                ? _buildEmptyCartState(context)
                : ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) => _CartItemTile(
                      item: cart.items[index],
                      onTap: () => onItemTap(cart.items[index]),
                    ),
                  ),
          ),

          // Totais e botões
          _buildCartFooter(context, cart),
        ],
      ),
    );
  }

  Widget _buildOptionsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _SmallButton(
              label: 'Vendas\nsuspensas',
              icon: Icons.pause_circle_outline,
              onPressed: onSuspendedSalesTap,
              badge: suspendedSalesCount > 0 ? suspendedSalesCount : null,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SmallButton(
              label: 'Pesquisar\nclientes',
              icon: Icons.person_search,
              onPressed: onCustomerSearchTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Tipo de documento
          InkWell(
            onTap: onDocumentTypeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (isLoadingDocTypes)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  else if (selectedDocumentOption != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2,),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        selectedDocumentOption!.code,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      selectedDocumentOption?.displayName ??
                          'Selecionar documento',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.onPrimary,),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Cliente
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selectedCustomer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),),
                      Text(
                        'NIF: ${selectedCustomer.vat}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onCustomerSearchTap,
                  tooltip: 'Alterar cliente',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline,),
          const SizedBox(height: 16),
          Text(
            'Não existem artigos adicionados',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildCartFooter(BuildContext context, CartState cart) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total a pagar',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                cart.formattedTotal,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: cart.isEmpty ? null : onCancelTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: cart.isEmpty ? null : onSuspendTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Suspender'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: cart.isEmpty ? null : onFinalizeTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tile de item do carrinho
class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.onTap,
  });

  final CartItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13,),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ref: ${item.product.reference}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,),
                  ),
                  Row(
                    children: [
                      Text(
                        '${item.formattedQuantity} x ${item.unitPrice.toStringAsFixed(2)}€',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline,),
                      ),
                      if (item.discount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1,),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '-${item.discount.toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 10, color: Colors.orange.shade800,),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.total.toStringAsFixed(2)}€',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão pequeno para a barra de opções
class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badge,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10),),
                ),
              ],
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle,),
              child: Text('$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 10),),
            ),
          ),
      ],
    );
  }
}
