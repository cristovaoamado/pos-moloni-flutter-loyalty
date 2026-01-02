import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/data/models/product_model.dart';

/// Ecrã que lista todos os produtos com IVA 0% ou sem IVA definido
class ZeroTaxProductsScreen extends ConsumerStatefulWidget {
  const ZeroTaxProductsScreen({super.key});

  @override
  ConsumerState<ZeroTaxProductsScreen> createState() => _ZeroTaxProductsScreenState();
}

class _ZeroTaxProductsScreenState extends ConsumerState<ZeroTaxProductsScreen> {
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'zero', 'none'
  List<Product> _allProducts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProductsFromCache();
  }

  Future<void> _loadProductsFromCache() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final box = await Hive.openBox('products_cache');
      
      if (box.isEmpty) {
        setState(() {
          _allProducts = [];
          _isLoading = false;
          _error = 'Cache de produtos vazio. Faça uma pesquisa no POS primeiro.';
        });
        return;
      }

      final products = box.values
          .whereType<Map<dynamic, dynamic>>()
          .map((json) {
            try {
              return ProductModel.fromJson(Map<String, dynamic>.from(json)).toEntity();
            } catch (e) {
              return null;
            }
          })
          .whereType<Product>()
          .toList();

      setState(() {
        _allProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erro ao carregar produtos: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar produtos com IVA 0% ou sem IVA
    final zeroTaxProducts = _getZeroTaxProducts(_allProducts);
    final filteredProducts = _applyFilters(zeroTaxProducts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos sem IVA / IVA 0%'),
        actions: [
          // Contador
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange),
              ),
              child: Text(
                '${filteredProducts.length} produtos',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ),
          // Botão refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProductsFromCache,
            tooltip: 'Recarregar do cache',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de pesquisa e filtros
          _buildSearchAndFilters(zeroTaxProducts),
          
          // Resumo
          if (!_isLoading && _error == null)
            _buildSummary(zeroTaxProducts),
          
          const Divider(height: 1),
          
          // Lista de produtos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : filteredProducts.isEmpty
                        ? _buildEmptyState()
                        : _buildProductList(filteredProducts),
          ),
        ],
      ),
    );
  }

  /// Obtém produtos com IVA 0% ou sem IVA
  List<_ZeroTaxProductInfo> _getZeroTaxProducts(List<Product> products) {
    final result = <_ZeroTaxProductInfo>[];
    
    for (final product in products) {
      if (product.taxes.isEmpty) {
        // Produto sem IVA definido
        result.add(_ZeroTaxProductInfo(
          product: product,
          type: _ZeroTaxType.noTax,
          taxName: null,
        ));
      } else {
        // Verificar se algum imposto é 0%
        for (final tax in product.taxes) {
          if (tax.value == 0 || tax.value == 0.0) {
            result.add(_ZeroTaxProductInfo(
              product: product,
              type: _ZeroTaxType.zeroTax,
              taxName: tax.name,
            ));
            break;
          }
        }
      }
    }
    
    // Ordenar por nome
    result.sort((a, b) => a.product.name.compareTo(b.product.name));
    
    return result;
  }

  /// Aplica filtros de pesquisa e tipo
  List<_ZeroTaxProductInfo> _applyFilters(List<_ZeroTaxProductInfo> products) {
    var filtered = products;
    
    // Filtro por tipo
    if (_filterType == 'zero') {
      filtered = filtered.where((p) => p.type == _ZeroTaxType.zeroTax).toList();
    } else if (_filterType == 'none') {
      filtered = filtered.where((p) => p.type == _ZeroTaxType.noTax).toList();
    }
    
    // Filtro por pesquisa
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.product.name.toLowerCase().contains(query) ||
               p.product.reference.toLowerCase().contains(query) ||
               (p.product.ean?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    
    return filtered;
  }

  Widget _buildSearchAndFilters(List<_ZeroTaxProductInfo> allProducts) {
    final zeroCount = allProducts.where((p) => p.type == _ZeroTaxType.zeroTax).length;
    final noneCount = allProducts.where((p) => p.type == _ZeroTaxType.noTax).length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          // Info do total de produtos em cache
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '${_allProducts.length} produtos em cache',
                  style: const TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ],
            ),
          ),
          
          // Campo de pesquisa
          TextField(
            decoration: InputDecoration(
              hintText: 'Pesquisar por nome, referência ou EAN...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          
          const SizedBox(height: 12),
          
          // Filtros por tipo
          Row(
            children: [
              _buildFilterChip(
                label: 'Todos (${allProducts.length})',
                value: 'all',
                icon: Icons.list,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'IVA 0% ($zeroCount)',
                value: 'zero',
                icon: Icons.percent,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Sem IVA ($noneCount)',
                value: 'none',
                icon: Icons.warning_amber,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final isSelected = _filterType == value;
    final chipColor = color ?? Theme.of(context).colorScheme.primary;
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : chipColor,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterType = value),
      selectedColor: chipColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildSummary(List<_ZeroTaxProductInfo> products) {
    if (products.isEmpty) return const SizedBox.shrink();
    
    final zeroCount = products.where((p) => p.type == _ZeroTaxType.zeroTax).length;
    final noneCount = products.where((p) => p.type == _ZeroTaxType.noTax).length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.percent,
              title: 'IVA 0%',
              count: zeroCount,
              color: Colors.orange,
              description: 'Produtos com taxa de IVA definida como 0%',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.warning_amber,
              title: 'Sem IVA',
              count: noneCount,
              color: Colors.red,
              description: 'Produtos sem imposto configurado',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber,
              size: 80,
              color: Colors.orange[300],
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Erro desconhecido',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProductsFromCache,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green[300],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Nenhum produto encontrado'
                : 'Nenhum produto com IVA 0% ou sem IVA',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Tente uma pesquisa diferente'
                : 'Todos os produtos têm IVA configurado correctamente',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(List<_ZeroTaxProductInfo> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final info = products[index];
        return _buildProductCard(info, index + 1);
      },
    );
  }

  Widget _buildProductCard(_ZeroTaxProductInfo info, int index) {
    final product = info.product;
    final isNoTax = info.type == _ZeroTaxType.noTax;
    final statusColor = isNoTax ? Colors.red : Colors.orange;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: product.hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.inventory_2,
                      color: statusColor,
                    ),
                  ),
                )
              : Icon(
                  Icons.inventory_2,
                  color: statusColor,
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                isNoTax ? 'SEM IVA' : 'IVA 0%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Ref: ${product.reference}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (product.ean != null && product.ean!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(
                    'EAN: ${product.ean}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // Preço
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.formattedPrice,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Info do imposto
                if (info.taxName != null)
                  Expanded(
                    child: Text(
                      'Imposto: ${info.taxName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Text(
                    'Nenhum imposto configurado',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '#$index',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              isNoTax ? Icons.error_outline : Icons.info_outline,
              color: statusColor,
              size: 20,
            ),
          ],
        ),
        onTap: () => _showProductDetails(info),
      ),
    );
  }

  void _showProductDetails(_ZeroTaxProductInfo info) {
    final product = info.product;
    final isNoTax = info.type == _ZeroTaxType.noTax;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isNoTax ? Icons.warning_amber : Icons.info_outline,
              color: isNoTax ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                product.name,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', product.id.toString()),
              _buildDetailRow('Referência', product.reference),
              if (product.ean != null && product.ean!.isNotEmpty)
                _buildDetailRow('EAN', product.ean!),
              _buildDetailRow('Preço (s/ IVA)', product.formattedPrice),
              _buildDetailRow('Preço (c/ IVA)', product.formattedPriceWithTax),
              const Divider(),
              _buildDetailRow(
                'Estado IVA',
                isNoTax ? 'Sem imposto configurado' : 'IVA 0%',
                valueColor: isNoTax ? Colors.red : Colors.orange,
              ),
              if (info.taxName != null)
                _buildDetailRow('Nome do Imposto', info.taxName!),
              const Divider(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Código de Isenção',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Este produto precisa de um código de isenção (exemption_reason) '
                      'para ser facturado. O sistema usa M07 por defeito.',
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Códigos comuns:\n'
                      '• M07 - Isento art. 9.º CIVA\n'
                      '• M01 - Art. 16.º n.º 6 CIVA\n'
                      '• M99 - Não sujeito/tributado',
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tipo de produto sem IVA
enum _ZeroTaxType {
  zeroTax,  // IVA definido como 0%
  noTax,    // Sem imposto configurado
}

/// Informação de produto com IVA 0%
class _ZeroTaxProductInfo {
  const _ZeroTaxProductInfo({
    required this.product,
    required this.type,
    this.taxName,
  });

  final Product product;
  final _ZeroTaxType type;
  final String? taxName;
}

