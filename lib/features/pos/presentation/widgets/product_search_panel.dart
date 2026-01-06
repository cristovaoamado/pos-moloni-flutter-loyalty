import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:pos_moloni_app/features/favorites/data/models/favorite_product_model.dart';
import 'package:pos_moloni_app/features/favorites/presentation/providers/local_favorites_provider.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/domain/entities/tax.dart';
import 'package:pos_moloni_app/features/products/presentation/providers/product_provider.dart';

/// Painel de pesquisa e grid de produtos com paginação para desktop
/// Mostra favoritos locais inicialmente, pesquisa na API quando há query
class ProductSearchPanel extends ConsumerStatefulWidget {
  const ProductSearchPanel({
    super.key,
    required this.onProductTap,
    this.onSearchFocusLost,
  });

  final Function(Product) onProductTap;

  /// Callback quando o campo de pesquisa perde o foco
  final VoidCallback? onSearchFocusLost;

  @override
  ConsumerState<ProductSearchPanel> createState() => _ProductSearchPanelState();
}

class _ProductSearchPanelState extends ConsumerState<ProductSearchPanel> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isInitialized = false;

  // Paginação
  static const int _columns = 8;
  static const int _rows = 3;
  static const int _itemsPerPage = _columns * _rows; // 24 produtos por página
  
  int _currentFavoritesPage = 0;
  int _currentSearchPage = 0;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChange);
  }

  void _onSearchFocusChange() {
    if (!_searchFocusNode.hasFocus) {
      widget.onSearchFocusLost?.call();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.length >= 3) {
      _currentSearchPage = 0; // Reset página ao pesquisar
      ref.read(productProvider.notifier).searchProducts(query);
    } else if (query.isEmpty) {
      ref.read(productProvider.notifier).clearSearchResults();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _currentSearchPage = 0;
    ref.read(productProvider.notifier).clearSearchResults();
    setState(() {});
    // Focar na caixa de pesquisa após limpar para nova pesquisa rápida
    _searchFocusNode.requestFocus();
  }

  /// Converte FavoriteProductModel para Product
  Product _favoriteToProduct(FavoriteProductModel favorite) {
    final tax = Tax(
      id: 0,
      name: 'IVA ${favorite.taxRate.toStringAsFixed(0)}%',
      value: favorite.taxRate,
    );

    return Product(
      id: favorite.productId,
      name: favorite.name,
      reference: favorite.reference,
      ean: favorite.ean,
      price: favorite.price,
      image: favorite.image,
      categoryId: favorite.categoryId,
      measureUnit: favorite.measureUnit,
      taxes: [tax],
    );
  }

  void _onFavoriteTap(FavoriteProductModel favorite) {
    widget.onProductTap(_favoriteToProduct(favorite));
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final favoritesState = ref.watch(localFavoritesProvider);

    final bool showSearchResults = productState.isLoading ||
        productState.products.isNotEmpty ||
        productState.hasScannedProduct ||
        _searchController.text.length >= 3;

    return Column(
      children: [
        // Barra de pesquisa
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              labelText: 'Pesquisa de artigos',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {});
              _onSearch(value);
            },
            onSubmitted: _onSearch,
          ),
        ),

        // Conteúdo
        Expanded(
          child: showSearchResults
              ? _buildSearchContent(productState, favoritesState)
              : _buildFavoritesContent(favoritesState),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTEÚDO DOS FAVORITOS LOCAIS COM PAGINAÇÃO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFavoritesContent(LocalFavoritesState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.isEmpty) {
      return _buildEmptyFavoritesState();
    }

    final totalItems = state.favorites.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    
    // Garantir que a página actual é válida
    if (_currentFavoritesPage >= totalPages) {
      _currentFavoritesPage = totalPages - 1;
    }
    if (_currentFavoritesPage < 0) {
      _currentFavoritesPage = 0;
    }

    final startIndex = _currentFavoritesPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
    final pageItems = state.favorites.sublist(startIndex, endIndex);

    return Column(
      children: [
        // Cabeçalho dos favoritos
        _buildFavoritesHeader(state, totalPages),

        // Grid de favoritos (página actual)
        Expanded(
          child: _buildFavoritesGrid(pageItems),
        ),

        // Barra de paginação
        if (totalPages > 1)
          _buildPaginationBar(
            currentPage: _currentFavoritesPage,
            totalPages: totalPages,
            totalItems: totalItems,
            onPrevious: () {
              setState(() {
                _currentFavoritesPage--;
              });
            },
            onNext: () {
              setState(() {
                _currentFavoritesPage++;
              });
            },
            onFirst: () {
              setState(() {
                _currentFavoritesPage = 0;
              });
            },
            onLast: () {
              setState(() {
                _currentFavoritesPage = totalPages - 1;
              });
            },
          ),
      ],
    );
  }

  Widget _buildFavoritesHeader(LocalFavoritesState state, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.star, size: 20, color: Colors.amber),
          const SizedBox(width: 8),
          Text(
            'Favoritos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${state.count}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade800,
              ),
            ),
          ),
          const Spacer(),
          if (state.isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: state.isSyncing
                ? null
                : () => ref.read(localFavoritesProvider.notifier).syncFavorites(),
            tooltip: 'Actualizar preços',
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesGrid(List<FavoriteProductModel> favorites) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      physics: const NeverScrollableScrollPhysics(), // Sem scroll - paginação
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        return _FavoriteCard(
          favorite: favorites[index],
          onTap: () => _onFavoriteTap(favorites[index]),
        );
      },
    );
  }

  Widget _buildEmptyFavoritesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Sem favoritos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesquise produtos e adicione aos favoritos',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTEÚDO DA PESQUISA COM PAGINAÇÃO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchContent(ProductState productState, LocalFavoritesState favoritesState) {
    if (productState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (productState.hasScannedProduct) {
      return _buildScannedProductView(productState, favoritesState);
    }

    if (productState.products.isEmpty) {
      return _buildEmptySearchState();
    }

    final totalItems = productState.products.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    
    if (_currentSearchPage >= totalPages) {
      _currentSearchPage = totalPages - 1;
    }
    if (_currentSearchPage < 0) {
      _currentSearchPage = 0;
    }

    final startIndex = _currentSearchPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
    final pageItems = productState.products.sublist(startIndex, endIndex);

    return Column(
      children: [
        // Header com resultados
        _buildSearchHeader(totalItems, totalPages),

        // Grid de produtos (página actual)
        Expanded(
          child: _buildProductGrid(pageItems, favoritesState),
        ),

        // Barra de paginação
        if (totalPages > 1)
          _buildPaginationBar(
            currentPage: _currentSearchPage,
            totalPages: totalPages,
            totalItems: totalItems,
            onPrevious: () {
              setState(() {
                _currentSearchPage--;
              });
            },
            onNext: () {
              setState(() {
                _currentSearchPage++;
              });
            },
            onFirst: () {
              setState(() {
                _currentSearchPage = 0;
              });
            },
            onLast: () {
              setState(() {
                _currentSearchPage = totalPages - 1;
              });
            },
          ),
      ],
    );
  }

  Widget _buildSearchHeader(int totalItems, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$totalItems resultados',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Limpar'),
          ),
        ],
      ),
    );
  }

  Widget _buildScannedProductView(ProductState productState, LocalFavoritesState favoritesState) {
    final product = productState.scannedProduct!;
    final isFavorite = favoritesState.isFavorite(product.id);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.green.withOpacity(0.1),
          child: Row(
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Produto scaneado', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  ref.read(productProvider.notifier).clearScannedProduct();
                },
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Limpar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 200,
              height: 250,
              child: _ProductCard(
                product: product,
                onTap: () => widget.onProductTap(product),
                isFavorite: isFavorite,
                onFavoriteToggle: () => _toggleFavorite(product),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Nenhum produto encontrado',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products, LocalFavoritesState favoritesState) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isFavorite = favoritesState.isFavorite(product.id);
        return _ProductCard(
          product: product,
          onTap: () => widget.onProductTap(product),
          isFavorite: isFavorite,
          onFavoriteToggle: () => _toggleFavorite(product),
        );
      },
    );
  }

  void _toggleFavorite(Product product) {
    ref.read(localFavoritesProvider.notifier).toggleFavorite(product);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BARRA DE PAGINAÇÃO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    required VoidCallback onFirst,
    required VoidCallback onLast,
  }) {
    final hasPrevious = currentPage > 0;
    final hasNext = currentPage < totalPages - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Primeira página
          IconButton(
            onPressed: hasPrevious ? onFirst : null,
            icon: const Icon(Icons.first_page),
            tooltip: 'Primeira página',
            iconSize: 28,
          ),
          // Página anterior
          IconButton(
            onPressed: hasPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Página anterior',
            iconSize: 32,
          ),
          // Info da página
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Página ${currentPage + 1} de $totalPages',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          // Próxima página
          IconButton(
            onPressed: hasNext ? onNext : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Próxima página',
            iconSize: 32,
          ),
          // Última página
          IconButton(
            onPressed: hasNext ? onLast : null,
            icon: const Icon(Icons.last_page),
            tooltip: 'Última página',
            iconSize: 28,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARD DE FAVORITO
// ═══════════════════════════════════════════════════════════════════════════

class _FavoriteCard extends ConsumerWidget {
  const _FavoriteCard({
    required this.favorite,
    required this.onTap,
  });

  final FavoriteProductModel favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInCart = ref.watch(cartProvider.notifier).containsProduct(favorite.productId);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagem de fundo
            favorite.imageUrl != null
                ? Image.network(
                    favorite.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(context),
                  )
                : _buildPlaceholderImage(context),

            // Overlay com nome e preço
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.brown.withOpacity(0.8),
                      Colors.brown.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      favorite.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          favorite.formattedPriceWithTax,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        if (favorite.isWeighable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'kg',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Badge favorito
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.star, size: 10, color: Colors.white),
              ),
            ),

            // Badge carrinho
            if (isInCart)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.shopping_cart,
                    size: 10,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.inventory_2,
        size: 32,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARD DE PRODUTO (pesquisa)
// ═══════════════════════════════════════════════════════════════════════════

class _ProductCard extends ConsumerWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final Product product;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInCart = ref.watch(cartProvider.notifier).containsProduct(product.id);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onFavoriteToggle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagem de fundo
            product.hasImage
                ? Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(context),
                  )
                : _buildPlaceholderImage(context),

            // Overlay com nome e preço
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.brown.withOpacity(0.8),
                      Colors.brown.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.formattedPriceWithTax,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${product.totalTaxRate.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 9, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Botão favorito
            Positioned(
              top: 4,
              left: 4,
              child: GestureDetector(
                onTap: onFavoriteToggle,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isFavorite ? Colors.amber : Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Badge carrinho
            if (isInCart)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.shopping_cart,
                    size: 10,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.inventory_2,
        size: 32,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
