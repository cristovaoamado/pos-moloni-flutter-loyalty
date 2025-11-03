import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/features/products/presentation/providers/product_provider.dart';

/// Barra de pesquisa de produtos
class ProductSearchBar extends ConsumerStatefulWidget {
  const ProductSearchBar({
    super.key,
    this.onProductSelected,
    this.hintText = 'Pesquisar produto...',
    this.enableBarcodeSearch = true,
  });

  final Function(dynamic)? onProductSelected;
  final String hintText;
  final bool enableBarcodeSearch;

  @override
  ConsumerState<ProductSearchBar> createState() => _ProductSearchBarState();
}

class _ProductSearchBarState extends ConsumerState<ProductSearchBar> {
  late final TextEditingController _controller;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();

    // Listener para debounce de pesquisa
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _controller.text.trim();

    if (query.isEmpty) {
      ref.read(productProvider.notifier).clearSearchResults();
      setState(() => _isSearching = false);
      return;
    }

    // Verificar se é um código de barras (típico: números, 8-14 dígitos)
    final isBarcode = RegExp(r'^[0-9]{8,14}$').hasMatch(query);

    if (isBarcode && widget.enableBarcodeSearch) {
      _searchByBarcode(query);
    } else if (query.length >= 3) {
      _searchProducts(query);
    }
  }

  Future<void> _searchProducts(String query) async {
    setState(() => _isSearching = true);

    // Debounce: aguardar 500ms antes de pesquisar
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    ref.read(productProvider.notifier).searchProducts(query);

    setState(() => _isSearching = false);
  }

  Future<void> _searchByBarcode(String barcode) async {
    setState(() => _isSearching = true);

    final product = await ref.read(productProvider.notifier).searchByBarcode(barcode);

    if (!mounted) return;

    if (product != null) {
      _controller.clear();
      setState(() => _isSearching = false);

      // Callback
      widget.onProductSelected?.call(product);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Produto adicionado: ${product.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);

    return Column(
      children: [
        // Campo de pesquisa
        SearchBar(
          controller: _controller,
          hintText: widget.hintText,
          leading: const Icon(Icons.search),
          trailing: [
            // Indicador de carregamento ou botão limpar
            if (_isSearching || productState.isLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              )
            else if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  ref.read(productProvider.notifier).clearSearchResults();
                },
              ),
          ],
          onChanged: (value) {
            setState(() {}); // Atualizar UI
          },
        ),

        // Mensagem de erro (se houver)
        if (productState.error != null && _controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    productState.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Dica sobre pesquisa
        if (_controller.text.isEmpty && !_isSearching) ...[
          const SizedBox(height: 8),
          Text(
            widget.enableBarcodeSearch
                ? 'Digite produto ou escaneie código de barras'
                : 'Digite pelo menos 3 caracteres',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],

        // Lista de resultados
        if (productState.products.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: ListView.builder(
              itemCount: productState.products.length,
              itemBuilder: (context, index) {
                final product = productState.products[index];
                return _ProductSearchResultItem(
                  product: product,
                  onTap: () {
                    _controller.clear();
                    ref.read(productProvider.notifier).clearSearchResults();
                    widget.onProductSelected?.call(product);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Item de resultado de pesquisa
class _ProductSearchResultItem extends StatelessWidget {
  const _ProductSearchResultItem({
    required this.product,
    required this.onTap,
  });

  final dynamic product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: product.hasImage
            ? Image.network(
                product.imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.image_not_supported,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              )
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ref: ${product.reference}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (product.ean != null)
              Text(
                'EAN: ${product.ean}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        trailing: Text(
          product.formattedPrice,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        onTap: onTap,
      ),
    );
  }
}
