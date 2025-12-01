import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_moloni_app/features/pos/presentation/models/pos_models.dart';
import 'package:pos_moloni_app/features/suspended_sales/presentation/providers/suspended_sales_provider.dart';

/// Diálogo para listar e gerir vendas suspensas
class SuspendedSalesDialog extends ConsumerStatefulWidget {
  const SuspendedSalesDialog({
    super.key,
    required this.onRestore,
  });

  final Function(SuspendedSale) onRestore;

  @override
  ConsumerState<SuspendedSalesDialog> createState() =>
      _SuspendedSalesDialogState();
}

class _SuspendedSalesDialogState extends ConsumerState<SuspendedSalesDialog> {
  // null = mostrar todas, false = só memória, true = só guardadas
  bool? _filterPersistent;

  List<SuspendedSale> _getFilteredSales(List<SuspendedSale> allSales) {
    if (_filterPersistent == null) return allSales;
    return allSales.where((s) => s.isPersistent == _filterPersistent).toList();
  }

  @override
  Widget build(BuildContext context) {
    final suspendedState = ref.watch(suspendedSalesProvider);
    final dateFormat = DateFormat('dd/MM HH:mm');
    final filteredSales = _getFilteredSales(suspendedState.sales);

    // Contagens para os badges
    final memoryCount =
        suspendedState.sales.where((s) => !s.isPersistent).length;
    final persistentCount =
        suspendedState.sales.where((s) => s.isPersistent).length;

    return Dialog(
      child: Container(
        width: 500,
        height: 500,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pause_circle_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Vendas Suspensas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${suspendedState.sales.length} venda${suspendedState.sales.length != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ],
              ),
            ),

            // Filtros clicáveis
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Filtro: Todas
                  _FilterChip(
                    label: 'Todas',
                    count: suspendedState.sales.length,
                    icon: Icons.list,
                    isSelected: _filterPersistent == null,
                    onTap: () => setState(() => _filterPersistent = null),
                  ),
                  const SizedBox(width: 8),
                  // Filtro: Memória
                  _FilterChip(
                    label: 'Memória',
                    count: memoryCount,
                    icon: Icons.memory,
                    isSelected: _filterPersistent == false,
                    onTap: memoryCount > 0
                        ? () => setState(() => _filterPersistent = false)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // Filtro: Guardadas
                  _FilterChip(
                    label: 'Guardadas',
                    count: persistentCount,
                    icon: Icons.save,
                    isSelected: _filterPersistent == true,
                    color: Theme.of(context).colorScheme.primary,
                    onTap: persistentCount > 0
                        ? () => setState(() => _filterPersistent = true)
                        : null,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Lista de vendas
            Expanded(
              child: suspendedState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredSales.isEmpty
                      ? _buildEmptyState(context, suspendedState.sales.isEmpty)
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: filteredSales.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final sale = filteredSales[index];
                            return _SuspendedSaleCard(
                              sale: sale,
                              dateFormat: dateFormat,
                              onRestore: () {
                                Navigator.of(context).pop();
                                widget.onRestore(sale);
                              },
                              onTogglePersistence: () {
                                ref
                                    .read(suspendedSalesProvider.notifier)
                                    .togglePersistence(sale.id);
                              },
                              onDelete: () {
                                _confirmDelete(context, ref, sale);
                              },
                            );
                          },
                        ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool noSalesAtAll) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noSalesAtAll ? Icons.inbox_outlined : Icons.filter_list_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            noSalesAtAll
                ? 'Sem vendas suspensas'
                : 'Nenhuma venda com este filtro',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          if (!noSalesAtAll) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _filterPersistent = null),
              child: const Text('Mostrar todas'),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SuspendedSale sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar venda?'),
        content: Text(
          'A venda de ${sale.customer.name} com ${sale.items.length} '
          'artigo${sale.items.length != 1 ? 's' : ''} será eliminada permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(suspendedSalesProvider.notifier).deleteSale(sale.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

/// Chip de filtro clicável
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.outline;
    final isDisabled = onTap == null;

    return Material(
      color: isSelected
          ? effectiveColor.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? effectiveColor
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isDisabled
                    ? Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3)
                    : isSelected
                        ? effectiveColor
                        : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDisabled
                          ? Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3)
                          : isSelected
                              ? effectiveColor
                              : Theme.of(context).colorScheme.outline,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? effectiveColor
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.outline,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Card de venda suspensa individual
class _SuspendedSaleCard extends StatelessWidget {
  const _SuspendedSaleCard({
    required this.sale,
    required this.dateFormat,
    required this.onRestore,
    required this.onTogglePersistence,
    required this.onDelete,
  });

  final SuspendedSale sale;
  final DateFormat dateFormat;
  final VoidCallback onRestore;
  final VoidCallback onTogglePersistence;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onRestore,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: cliente + hora
              Row(
                children: [
                  // Indicador de persistência
                  IconButton(
                    onPressed: onTogglePersistence,
                    icon: Icon(
                      sale.isPersistent ? Icons.save : Icons.memory,
                      size: 20,
                    ),
                    color: sale.isPersistent
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    tooltip: sale.isPersistent
                        ? 'Guardada (clique para remover)'
                        : 'Em memória (clique para guardar)',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.customer.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (sale.note != null && sale.note!.isNotEmpty)
                          Text(
                            sale.note!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    dateFormat.format(sale.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Itens resumidos
              Row(
                children: [
                  // Tipo de documento
                  if (sale.documentOption != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2,),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sale.documentOption!.documentType.code,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Quantidade de itens
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${sale.items.length} artigo${sale.items.length != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),

                  const Spacer(),

                  // Botão eliminar
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: 'Eliminar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                  const SizedBox(width: 12),

                  // Total
                  Text(
                    '${sale.total.toStringAsFixed(2)} €',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo para suspender venda com opções
class SuspendSaleDialog extends StatefulWidget {
  const SuspendSaleDialog({
    super.key,
    required this.itemCount,
    required this.total,
  });

  final int itemCount;
  final double total;

  @override
  State<SuspendSaleDialog> createState() => _SuspendSaleDialogState();
}

class _SuspendSaleDialogState extends State<SuspendSaleDialog> {
  final _noteController = TextEditingController();
  bool _isPersistent = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.pause_circle_outline),
          SizedBox(width: 12),
          Text('Suspender Venda'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.itemCount} artigo${widget.itemCount != 1 ? 's' : ''} • ${widget.total.toStringAsFixed(2)} €',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // Nota opcional
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              hintText: 'Ex: Mesa 5, Cliente aguarda...',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 16),

          // Opção de persistência
          CheckboxListTile(
            value: _isPersistent,
            onChanged: (value) =>
                setState(() => _isPersistent = value ?? false),
            title: const Text('Guardar permanentemente'),
            subtitle: Text(
              _isPersistent
                  ? 'A venda será mantida após fechar a aplicação'
                  : 'A venda será perdida ao fechar a aplicação',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            secondary: Icon(
              _isPersistent ? Icons.save : Icons.memory,
              color: _isPersistent
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop(SuspendSaleResult(
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              isPersistent: _isPersistent,
            ),);
          },
          icon: const Icon(Icons.pause),
          label: const Text('Suspender'),
        ),
      ],
    );
  }
}

/// Resultado do diálogo de suspender venda
class SuspendSaleResult {
  const SuspendSaleResult({
    this.note,
    this.isPersistent = false,
  });

  final String? note;
  final bool isPersistent;
}
