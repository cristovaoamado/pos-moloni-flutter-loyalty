import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/theme/app_colors.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/favorites/data/models/favorite_product_model.dart';
import 'package:pos_moloni_app/features/favorites/presentation/providers/local_favorites_provider.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/presentation/providers/product_provider.dart';

/// Painel de pesquisa e seleção de produtos
/// Mostra favoritos locais inicialmente, pesquisa na API quando há query
class ProductSearchPanel extends ConsumerStatefulWidget {
  const ProductSearchPanel({
    super.key,
    required this.onProductTap,
    this.onSearchFocusLost,
  });

  final void Function(Product product) onProductTap;
  final VoidCallback? onSearchFocusLost;

  @override
  ConsumerState<ProductSearchPanel> createState() => _ProductSearchPanelState();
}

class _ProductSearchPanelState extends ConsumerState<ProductSearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    if (!_searchFocusNode.hasFocus && widget.onSearchFocusLost != null) {
      widget.onSearchFocusLost!();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Carregar mais produtos se estiver a pesquisar
      if (_showSearchResults) {
        ref.read(productProvider.notifier).loadMoreProducts();
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _showSearchResults = query.length >= 3;
    });

    if (_showSearchResults) {
      ref.read(productProvider.notifier).searchProducts(query);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showSearchResults = false;
    });
    ref.read(productProvider.notifier).clearSearchResults();
  }

  void _onProductTap(Product product) {
    widget.onProductTap(product);
  }

  /// CORRIGIDO: Converte favorito para Product usando toProduct()
  /// que inclui todos os dados dos impostos (tax_id, etc.)
  void _onFavoriteTap(FavoriteProductModel favorite) {
    // Verificar se o favorito tem taxes
    if (!favorite.hasTaxes) {
      AppLogger.w('⚠️ Favorito "${favorite.name}" não tem dados de impostos! Recomenda-se sincronizar.');
      // Mostrar aviso ao utilizador
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ "${favorite.name}" pode ter IVA incorreto. Sincronize os favoritos.'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Sincronizar',
            onPressed: () {
              ref.read(localFavoritesProvider.notifier).syncFavorites();
            },
          ),
        ),
      );
    }

    // Usar método toProduct() que converte correctamente as taxes
    final product = favorite.toProduct();
    
    AppLogger.d('🛒 Favorito convertido para Product:');
    AppLogger.d('   - id: ${product.id}');
    AppLogger.d('   - name: ${product.name}');
    AppLogger.d('   - price: ${product.price}');
    AppLogger.d('   - taxes: ${product.taxes.length}');
    for (final tax in product.taxes) {
      AppLogger.d('   - tax_id: ${tax.id}, name: ${tax.name}, value: ${tax.value}%');
    }
    
    widget.onProductTap(product);
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final favoritesState = ref.watch(localFavoritesProvider);

    return Column(
      children: [
        // Barra de pesquisa
        _buildSearchBar(),
        
        // Conteúdo
        Expanded(
          child: _showSearchResults
              ? _buildSearchResults(productState, favoritesState)
              : _buildFavoritesContent(favoritesState),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Pesquisar produtos...',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade600),
                  onPressed: _clearSearch,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FAVORITOS
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
        // Header
        _buildFavoritesHeader(state),
        // Grid
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: state.favorites.length,
            itemBuilder: (context, index) {
              return _buildFavoriteCard(state.favorites[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesHeader(LocalFavoritesState state) {
    // Contar favoritos sem taxes (dados antigos que precisam de sync)
    final favoritesWithoutTaxes = state.favorites.where((f) => !f.hasTaxes).length;
    final needsSync = favoritesWithoutTaxes > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: needsSync ? Colors.orange.shade50 : Colors.amber.shade50,
        border: Border(
          bottom: BorderSide(
            color: needsSync ? Colors.orange.shade200 : Colors.amber.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.star, 
            color: needsSync ? Colors.orange : Colors.amber, 
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'Favoritos',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: needsSync ? Colors.orange : Colors.amber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${state.count}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Aviso de sincronização necessária
          if (needsSync) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: '$favoritesWithoutTaxes favoritos precisam de sincronização',
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 18,
              ),
            ),
          ],
          const Spacer(),
          if (state.isSyncing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: Icon(
                Icons.sync, 
                size: 20,
                color: needsSync ? Colors.orange.shade700 : null,
              ),
              onPressed: () {
                ref.read(localFavoritesProvider.notifier).syncFavorites();
              },
              tooltip: needsSync 
                  ? 'Sincronizar ($favoritesWithoutTaxes precisam de actualização)'
                  : 'Actualizar preços',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(FavoriteProductModel favorite) {
    // Indicar visualmente se o favorito não tem taxes
    final needsSync = !favorite.hasTaxes;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: needsSync 
            ? BorderSide(color: Colors.orange.shade300, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _onFavoriteTap(favorite),
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagem
                  Expanded(
                    child: Center(
                      child: favorite.imageUrl != null
                          ? Image.network(
                              favorite.imageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
                            )
                          : _buildPlaceholderIcon(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Nome
                  Text(
                    favorite.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Preço e IVA
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          favorite.formattedPriceWithTax,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      // Badge de IVA
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: needsSync 
                              ? Colors.orange.shade100 
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${favorite.taxRate.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: needsSync 
                                ? Colors.orange.shade800 
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Badge de favorito
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 14,
                ),
              ),
            ),
            // Indicador de sync necessário
            if (needsSync)
              Positioned(
                top: 4,
                left: 4,
                child: Tooltip(
                  message: 'Sincronização necessária',
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sync_problem,
                      color: Colors.orange.shade700,
                      size: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
            color: Colors.grey.shade400,
          ),
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
            'Pesquise produtos e mantenha pressionado\npara adicionar aos favoritos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESULTADOS DA PESQUISA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchResults(ProductState productState, LocalFavoritesState favoritesState) {
    if (productState.isLoading && productState.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (productState.products.isEmpty) {
      return _buildEmptySearchState();
    }

    // Produto scaneado em destaque
    if (productState.hasScannedProduct) {
      return _buildScannedProductView(productState.scannedProduct!, favoritesState);
    }

    return Column(
      children: [
        // Header dos resultados
        _buildSearchResultsHeader(productState),
        // Grid
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: productState.products.length + (productState.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= productState.products.length) {
                return const Center(child: CircularProgressIndicator());
              }
              final product = productState.products[index];
              final isFavorite = favoritesState.isFavorite(product.id);
              return _buildProductCard(product, isFavorite);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsHeader(ProductState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '${state.products.length} resultados',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (state.hasMore) ...[
            Text(
              ' de ${state.totalCount}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Favoritos'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isFavorite) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isFavorite
            ? const BorderSide(color: Colors.amber, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _onProductTap(product),
        onLongPress: () => _toggleProductFavorite(product),
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagem
                  Expanded(
                    child: Center(
                      child: product.imageUrl != null
                          ? Image.network(
                              product.imageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
                            )
                          : _buildPlaceholderIcon(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Nome
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Preço
                  Text(
                    product.formattedPriceWithTax,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Badge de favorito
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _toggleProductFavorite(product),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isFavorite ? Colors.amber.shade100 : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : Colors.grey.shade500,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleProductFavorite(Product product) async {
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

  Widget _buildScannedProductView(Product product, LocalFavoritesState favoritesState) {
    final isFavorite = favoritesState.isFavorite(product.id);
    
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.green.shade50,
          child: Row(
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Produto encontrado',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
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
              width: 200,
              child: _buildProductCard(product, isFavorite),
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
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum produto encontrado',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
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

  Widget _buildPlaceholderIcon() {
    return Icon(
      Icons.inventory_2_outlined,
      size: 40,
      color: Colors.grey.shade400,
    );
  }
}
