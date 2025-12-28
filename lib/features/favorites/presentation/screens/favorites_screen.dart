import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/theme/app_colors.dart';
import 'package:pos_moloni_app/features/favorites/data/models/favorite_product_model.dart';
import 'package:pos_moloni_app/features/favorites/presentation/providers/local_favorites_provider.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/presentation/providers/product_provider.dart';

/// Ecrã para gerir produtos favoritos
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Carregar favoritos ao iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localFavoritesProvider.notifier).loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.length >= 3;
    });

    if (_isSearching) {
      ref.read(productProvider.notifier).searchProducts(query);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
    ref.read(productProvider.notifier).clearSearchResults();
  }

  Future<void> _syncFavorites() async {
    await ref.read(localFavoritesProvider.notifier).syncFavorites();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favoritos actualizados'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleFavorite(Product product) async {
    final wasAdded =
        await ref.read(localFavoritesProvider.notifier).toggleFavorite(product);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasAdded
                ? '${product.name} adicionado aos favoritos'
                : '${product.name} removido dos favoritos',
          ),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              ref.read(localFavoritesProvider.notifier).toggleFavorite(product);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesState = ref.watch(localFavoritesProvider);
    final productState = ref.watch(productProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Contador de favoritos
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${favoritesState.count}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          // Botão de sincronização
          IconButton(
            icon: favoritesState.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Actualizar favoritos',
            onPressed: favoritesState.isSyncing ? null : _syncFavorites,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de pesquisa
          _buildSearchBar(),

          // Info da última sincronização
          if (favoritesState.lastSync != null && !_isSearching)
            _buildLastSyncInfo(favoritesState.lastSync!),

          // Conteúdo principal
          Expanded(
            child: _isSearching
                ? _buildSearchResults(productState, favoritesState)
                : _buildFavoritesList(favoritesState),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        decoration: InputDecoration(
          hintText: 'Pesquisar produtos para adicionar...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildLastSyncInfo(DateTime lastSync) {
    final now = DateTime.now();
    final diff = now.difference(lastSync);

    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'agora mesmo';
    } else if (diff.inMinutes < 60) {
      timeAgo = 'há ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      timeAgo = 'há ${diff.inHours}h';
    } else {
      timeAgo = 'há ${diff.inDays} dias';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Icon(Icons.update, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            'Última actualização: $timeAgo',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(LocalFavoritesState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: state.favorites.length,
      itemBuilder: (context, index) {
        final favorite = state.favorites[index];
        return _buildFavoriteCard(favorite);
      },
    );
  }

  Widget _buildFavoriteCard(FavoriteProductModel favorite) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _confirmRemoveFavorite(favorite),
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
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
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                            )
                          : Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Nome
                  Text(
                    favorite.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Preço
                  Text(
                    favorite.formattedPriceWithTax,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Estrela de favorito
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveFavorite(FavoriteProductModel favorite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover favorito?'),
        content: Text('Remover "${favorite.name}" dos favoritos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(localFavoritesProvider.notifier)
                  .removeFavorite(favorite.productId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
      ProductState productState, LocalFavoritesState favoritesState,) {
    if (productState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (productState.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Nenhum produto encontrado',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar aos favoritos'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header com resultados
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.primary.withOpacity(0.1),
          child: Row(
            children: [
              Text(
                '${productState.products.length} resultados',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Voltar'),
              ),
            ],
          ),
        ),
        // Grid de produtos
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: productState.products.length,
            itemBuilder: (context, index) {
              final product = productState.products[index];
              final isFavorite = favoritesState.isFavorite(product.id);
              return _buildProductCard(product, isFavorite);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product, bool isFavorite) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isFavorite
            ? const BorderSide(color: Colors.amber, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _toggleFavorite(product),
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
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
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                            )
                          : Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Nome
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Estrela de favorito
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color:
                      isFavorite ? Colors.amber.shade100 : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? Colors.amber : Colors.grey.shade500,
                  size: 20,
                ),
              ),
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
            Icons.star_border,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Sem favoritos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesquise produtos acima para adicionar aos favoritos',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _searchFocusNode.requestFocus();
            },
            icon: const Icon(Icons.search),
            label: const Text('Pesquisar produtos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
