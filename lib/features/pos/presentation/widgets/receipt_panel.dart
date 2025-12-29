import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';
import 'package:pos_moloni_app/features/document_sets/domain/entities/document_set.dart';

/// Painel do talão de venda (lado direito)
class ReceiptPanel extends ConsumerStatefulWidget {
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
    this.onOpenDrawerTap,
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
  final VoidCallback? onOpenDrawerTap;

  @override
  ConsumerState<ReceiptPanel> createState() => _ReceiptPanelState();
}

class _ReceiptPanelState extends ConsumerState<ReceiptPanel> {
  final ScrollController _scrollController = ScrollController();
  int _previousItemCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll para o fim da lista
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Scroll para o topo da lista
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Scroll para cima (uma página)
  void _scrollUp() {
    if (_scrollController.hasClients) {
      final newOffset = (_scrollController.offset - 200).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  /// Scroll para baixo (uma página)
  void _scrollDown() {
    if (_scrollController.hasClients) {
      final newOffset = (_scrollController.offset + 200).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    // Auto-scroll para o fim quando um novo item é adicionado
    if (cart.items.length > _previousItemCount && cart.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    _previousItemCount = cart.items.length;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // Botões de Opções
          _buildOptionsBar(context, ref, cart),
          const Divider(height: 1),

          // Tipo de documento e cliente
          _buildDocumentHeader(context),
          const Divider(height: 1),

          // Lista de itens COM botões de scroll
          Expanded(
            child: cart.isEmpty
                ? _buildEmptyCartState(context)
                : _buildCartListWithScrollButtons(context, cart),
          ),

          // Totais e botões
          _buildCartFooter(context, ref, cart),
        ],
      ),
    );
  }

  /// Lista de itens com botões de scroll para ecrãs touch
  Widget _buildCartListWithScrollButtons(BuildContext context, CartState cart) {
    return Column(
      children: [
        // Botão scroll para cima
        _buildScrollButton(
          context: context,
          icon: Icons.keyboard_arrow_up,
          onPressed: _scrollUp,
          onLongPress: _scrollToTop,
          tooltip: 'Scroll para cima (manter para ir ao topo)',
        ),

        // Lista de itens
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: cart.items.length,
            itemBuilder: (context, index) => _CartItemTile(
              item: cart.items[index],
              onTap: () => widget.onItemTap(cart.items[index]),
            ),
          ),
        ),

        // Botão scroll para baixo
        _buildScrollButton(
          context: context,
          icon: Icons.keyboard_arrow_down,
          onPressed: _scrollDown,
          onLongPress: _scrollToBottom,
          tooltip: 'Scroll para baixo (manter para ir ao fim)',
        ),
      ],
    );
  }

  /// Botão de scroll estilizado para touch
  Widget _buildScrollButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onPressed,
    required VoidCallback onLongPress,
    required String tooltip,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onPressed,
        onLongPress: onLongPress,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsBar(BuildContext context, WidgetRef ref, CartState cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _SmallButton(
              label: 'Vendas\nsuspensas',
              icon: Icons.pause_circle_outline,
              onPressed: widget.onSuspendedSalesTap,
              badge: widget.suspendedSalesCount > 0 ? widget.suspendedSalesCount : null,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SmallButton(
              label: 'Pesquisar\nclientes',
              icon: Icons.person_search,
              onPressed: widget.onCustomerSearchTap,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SmallButton(
              label: cart.hasGlobalDiscount
                  ? 'Desc.\n${cart.formattedGlobalDiscount}'
                  : 'Desconto\nglobal',
              icon: Icons.percent,
              onPressed: cart.isEmpty
                  ? null
                  : () => _showGlobalDiscountDialog(
                      context, ref, cart.globalDiscount),
              isActive: cart.hasGlobalDiscount,
            ),
          ),
        ],
      ),
    );
  }

  void _showGlobalDiscountDialog(
      BuildContext context, WidgetRef ref, double currentDiscount) {
    showDialog(
      context: context,
      builder: (context) => _GlobalDiscountDialog(
        currentDiscount: currentDiscount,
        onApply: (discount) {
          ref.read(cartProvider.notifier).applyGlobalDiscount(discount);
        },
        onRemove: () {
          ref.read(cartProvider.notifier).removeGlobalDiscount();
        },
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
            onTap: widget.onDocumentTypeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (widget.isLoadingDocTypes)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  else if (widget.selectedDocumentOption != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.selectedDocumentOption!.code,
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
                      widget.selectedDocumentOption?.displayName ??
                          'Selecionar documento',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.onPrimary),
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
                      .withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.selectedCustomer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        'NIF: ${widget.selectedCustomer.vat}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: widget.onCustomerSearchTap,
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
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Não existem artigos adicionados',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildCartFooter(BuildContext context, WidgetRef ref, CartState cart) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Mostrar subtotal se houver descontos
          if (cart.hasAnyDiscount) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${cart.itemsTotal.toStringAsFixed(2)} EUR',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Mostrar desconto de itens
          if (cart.itemsDiscount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Desc. artigos',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '-${cart.itemsDiscount.toStringAsFixed(2)} EUR',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Mostrar desconto global
          if (cart.hasGlobalDiscount) ...[
            InkWell(
              onTap: () =>
                  _showGlobalDiscountDialog(context, ref, cart.globalDiscount),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.percent,
                          size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Desc. ${cart.formattedGlobalDiscount}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '-${cart.globalDiscountValue.toStringAsFixed(2)} EUR',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Total
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
          // Número de produtos/referências
          if (cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${cart.itemCount} ${cart.itemCount == 1 ? 'referência' : 'referências'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  Text(
                    '${cart.totalQuantity.toStringAsFixed(cart.totalQuantity.truncateToDouble() == cart.totalQuantity ? 0 : 2)} ${cart.totalQuantity == 1 ? 'unidade' : 'unidades'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          // Botão da gaveta (linha separada)
          if (widget.onOpenDrawerTap != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onOpenDrawerTap,
                icon: const Icon(Icons.point_of_sale, size: 18),
                label: const Text('Abrir Gaveta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueGrey,
                  side: const BorderSide(color: Colors.blueGrey),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: cart.isEmpty ? null : widget.onCancelTap,
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
                  onPressed: cart.isEmpty ? null : widget.onSuspendTap,
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
                  onPressed: cart.isEmpty ? null : widget.onFinalizeTap,
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
                  Theme.of(context).colorScheme.outline.withOpacity(0.2)),
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
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ref: ${item.product.reference}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  Row(
                    children: [
                      Text(
                        '${item.formattedQuantity} x ${item.unitPriceWithTax.toStringAsFixed(2)}€',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                      if (item.discount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '-${item.discount.toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 10, color: Colors.orange.shade800),
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
    this.isActive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final int? badge;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              backgroundColor: isActive ? Colors.green.shade50 : null,
              side: BorderSide(
                color: isActive
                    ? Colors.green
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: isActive ? Colors.green : null),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? Colors.green.shade700 : null,
                      fontWeight: isActive ? FontWeight.bold : null,
                    ),
                  ),
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
                  color: Colors.red, shape: BoxShape.circle),
              child: Text('$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
      ],
    );
  }
}

/// Diálogo para aplicar desconto global
class _GlobalDiscountDialog extends StatefulWidget {
  const _GlobalDiscountDialog({
    required this.currentDiscount,
    required this.onApply,
    required this.onRemove,
  });

  final double currentDiscount;
  final Function(double) onApply;
  final VoidCallback onRemove;

  @override
  State<_GlobalDiscountDialog> createState() => _GlobalDiscountDialogState();
}

class _GlobalDiscountDialogState extends State<_GlobalDiscountDialog> {
  late TextEditingController _controller;
  final List<double> _quickDiscounts = [5, 10, 15, 20, 25, 30, 50];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentDiscount > 0
          ? widget.currentDiscount.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyDiscount(double discount) {
    widget.onApply(discount);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.percent, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Desconto Global'),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Campo de texto para valor personalizado
            TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Percentagem de desconto',
                suffixText: '%',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
                helperText: 'Introduza um valor entre 0 e 100',
              ),
              autofocus: true,
              onSubmitted: (value) {
                final discount = double.tryParse(value) ?? 0;
                if (discount > 0 && discount <= 100) {
                  _applyDiscount(discount);
                }
              },
            ),
            const SizedBox(height: 20),

            // Botões de desconto rápido
            Text(
              'Descontos rápidos',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickDiscounts.map((discount) {
                final isSelected = widget.currentDiscount == discount;
                return SizedBox(
                  width: 70,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => _applyDiscount(discount),
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          isSelected ? Colors.green.shade100 : null,
                      side: BorderSide(
                        color: isSelected
                            ? Colors.green
                            : Theme.of(context).colorScheme.outline,
                        width: isSelected ? 2 : 1,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      '${discount.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.green.shade700 : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        // Remover desconto (se existir)
        if (widget.currentDiscount > 0)
          TextButton.icon(
            onPressed: () {
              widget.onRemove();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final discount = double.tryParse(_controller.text) ?? 0;
            if (discount > 0 && discount <= 100) {
              _applyDiscount(discount);
            } else if (discount == 0) {
              widget.onRemove();
              Navigator.pop(context);
            }
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
