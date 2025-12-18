import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:pos_moloni_app/features/favorites/data/models/favorite_product_model.dart';
import 'package:pos_moloni_app/features/favorites/presentation/providers/local_favorites_provider.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
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
      ref.read(productProvider.notifier).searchProducts(query);
    } else if (query.isEmpty) {
      ref.read(productProvider.notifier).clearSearchResults();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(productProvider.notifier).clearSearchResults();
    setState(() {});
  }

  /// Converte FavoriteProductModel para Product
  Product _favoriteToProduct(FavoriteProductModel favorite) {
    return Product(
      id: favorite.productId,
      name: favorite.name,
      reference: favorite.reference,
      ean: favorite.ean,
      price: favorite.price,
      image: favorite.image,
      categoryId: favorite.categoryId,
      taxes: [], // Não temos os detalhes das taxes
    );
  }

  void _onFavoriteTap(FavoriteProductModel favorite) {
    widget.onProductTap(_favoriteToProduct(favorite));
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final favoritesState = ref.watch(localFavoritesProvider);

    // Determinar o que mostrar:
    // 1. Se está a pesquisar ou tem resultados de pesquisa -> mostrar pesquisa
    // 2. Se não está a pesquisar -> mostrar favoritos locais
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

        // Barra de paginação (se houver resultados na grid de pesquisa)
        if (showSearchResults && productState.products.isNotEmpty && !productState.hasScannedProduct)
          _buildPaginationBar(productState),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTEÚDO DOS FAVORITOS LOCAIS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFavoritesContent(LocalFavoritesState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.isEmpty) {
      return _buildEmptyFavoritesState();
    }

    return Column(
      children: [
        // Cabeçalho dos favoritos
        _buildFavoritesHeader(state),
        
        // Grid de favoritos
        Expanded(
          child: _buildFavoritesGrid(state.favorites),
        ),
      ],
    );
  }

  Widget _buildFavoritesHeader(LocalFavoritesState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.star,
            size: 20,
            color: Colors.amber,
          ),
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
          // Indicador de sincronização
          if (state.isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          // Botão refresh
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
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
          Icon(
            Icons.star_border,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Sem favoritos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesquise produtos ou aceda ao ecrã de favoritos\npara adicionar produtos aos favoritos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTEÚDO DA PESQUISA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchContent(ProductState productState, LocalFavoritesState favoritesState) {
    if (productState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (productState.error != null) {
      return _buildErrorState(productState.error!);
    }
    
    if (productState.hasScannedProduct) {
      return _buildScannedProductView(productState.scannedProduct!, favoritesState);
    }
    
    if (productState.products.isEmpty) {
      return _buildEmptySearchState();
    }
    
    return Column(
      children: [
        // Header com resultados e botão voltar
        _buildSearchHeader(productState),
        // Grid
        Expanded(
          child: _buildProductGrid(productState.products, favoritesState),
        ),
      ],
    );
  }

  Widget _buildSearchHeader(ProductState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '${state.products.length} resultados',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (state.hasMore) ...[
            Text(
              ' de ${state.totalCount}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Favoritos'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products, LocalFavoritesState favoritesState) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
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
          isFavorite: isFavorite,
          onTap: () => widget.onProductTap(product),
          onFavoriteToggle: () => _toggleFavorite(product),
        );
      },
    );
  }

  void _toggleFavorite(Product product) async {
    final wasAdded = await ref.read(localFavoritesProvider.notifier).toggleFavorite(product);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasAdded 
                ? '⭐ ${product.name} adicionado aos favoritos'
                : '${product.name} removido dos favoritos',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADOS ESPECIAIS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildScannedProductView(Product product, LocalFavoritesState favoritesState) {
    final isFavorite = favoritesState.isFavorite(product.id);
    
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.green.shade200),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Produto encontrado',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Favoritos'),
              ),
            ],
          ),
        ),
        // Produto em destaque
        Expanded(
          child: Center(
            child: SizedBox(
              width: 180,
              height: 220,
              child: _ProductCard(
                product: product,
                isFavorite: isFavorite,
                onTap: () => widget.onProductTap(product),
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
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum produto encontrado',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar aos favoritos'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Erro: $error',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar aos favoritos'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar(ProductState productState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            productState.hasMore
                ? '${productState.products.length}+ produtos'
                : '${productState.products.length} produto${productState.products.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (productState.hasMore)
            ElevatedButton.icon(
              onPressed: productState.isLoadingMore
                  ? null
                  : () => ref.read(productProvider.notifier).loadMoreProducts(),
              icon: productState.isLoadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add, size: 18),
              label: Text(productState.isLoadingMore ? 'A carregar...' : 'Carregar mais'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            )
          else
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Todos carregados',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
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
                        fontSize: 12,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      favorite.formattedPriceWithTax,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Badge favorito
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
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
                child: const Icon(
                  Icons.star,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),

            // Badge carrinho
            if (isInCart)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(6),
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
                    size: 14,
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
        size: 48,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
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
                        fontSize: 12,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.formattedPriceWithTax,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${product.totalTaxRate.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Botão favorito (clicável)
            Positioned(
              top: 6,
              left: 6,
              child: GestureDetector(
                onTap: onFavoriteToggle,
                child: Container(
                  padding: const EdgeInsets.all(4),
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
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Badge carrinho
            if (isInCart)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(6),
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
                    size: 14,
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
        size: 48,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
