import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';

// ==================== PROVIDER DE ESTADO DO CARRINHO ====================

/// Estado do carrinho
class CartState {
  const CartState({
    this.items = const [],
    this.isProcessing = false,
    this.error,
  });

  final List<CartItem> items;
  final bool isProcessing;
  final String? error;

  /// Número total de itens
  int get itemCount => items.length;

  /// Quantidade total de produtos
  double get totalQuantity =>
      items.fold(0.0, (sum, item) => sum + item.quantity);

  /// Subtotal (sem IVA)
  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.subtotalWithDiscount);

  /// Total de descontos
  double get totalDiscount =>
      items.fold(0.0, (sum, item) => sum + item.discountValue);

  /// Total de IVA
  double get totalTax => items.fold(0.0, (sum, item) => sum + item.taxValue);

  /// Total geral (com IVA)
  double get total => items.fold(0.0, (sum, item) => sum + item.total);

  /// Subtotal formatado
  String get formattedSubtotal => '${subtotal.toStringAsFixed(2)} €';

  /// Total IVA formatado
  String get formattedTax => '${totalTax.toStringAsFixed(2)} €';

  /// Total formatado
  String get formattedTotal => '${total.toStringAsFixed(2)} €';

  /// Verifica se o carrinho está vazio
  bool get isEmpty => items.isEmpty;

  /// Verifica se o carrinho não está vazio
  bool get isNotEmpty => items.isNotEmpty;

  CartState copyWith({
    List<CartItem>? items,
    bool? isProcessing,
    String? error,
  }) {
    return CartState(
      items: items ?? this.items,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
    );
  }
}

/// Notifier para gestão do estado do carrinho
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  /// Adicionar produto ao carrinho
  void addProduct(Product product, {double quantity = 1.0}) {
    AppLogger.i('🛒 Adicionando ao carrinho: ${product.name} (x$quantity)');

    final existingIndex = state.items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // Produto já existe - incrementar quantidade
      final existingItem = state.items[existingIndex];
      final newQuantity = existingItem.quantity + quantity;

      AppLogger.d('📦 Produto já existe, nova quantidade: $newQuantity');

      final updatedItems = [...state.items];
      updatedItems[existingIndex] = existingItem.copyWith(quantity: newQuantity);

      state = state.copyWith(items: updatedItems, error: null);
    } else {
      // Novo produto
      final newItem = CartItem(
        product: product,
        quantity: quantity,
      );

      state = state.copyWith(
        items: [...state.items, newItem],
        error: null,
      );
    }

    AppLogger.i('✅ Carrinho: ${state.itemCount} itens, Total: ${state.formattedTotal}');
  }

  /// Remover item do carrinho
  void removeItem(int productId) {
    AppLogger.i('🗑️ Removendo produto ID: $productId');

    final updatedItems = state.items.where((item) => item.product.id != productId).toList();

    state = state.copyWith(items: updatedItems, error: null);

    AppLogger.i('✅ Carrinho: ${state.itemCount} itens');
  }

  /// Atualizar quantidade de um item
  void updateQuantity(int productId, double quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    AppLogger.i('📝 Atualizando quantidade do produto $productId: $quantity');

    final index = state.items.indexWhere((item) => item.product.id == productId);

    if (index >= 0) {
      final updatedItems = [...state.items];
      updatedItems[index] = state.items[index].copyWith(quantity: quantity);

      state = state.copyWith(items: updatedItems, error: null);
    }
  }

  /// Incrementar quantidade
  void incrementQuantity(int productId) {
    final item = state.items.firstWhere(
      (item) => item.product.id == productId,
      orElse: () => throw Exception('Item não encontrado'),
    );

    final increment = item.isUnitQuantity ? 1.0 : 0.1;
    updateQuantity(productId, item.quantity + increment);
  }

  /// Decrementar quantidade
  void decrementQuantity(int productId) {
    final item = state.items.firstWhere(
      (item) => item.product.id == productId,
      orElse: () => throw Exception('Item não encontrado'),
    );

    final decrement = item.isUnitQuantity ? 1.0 : 0.1;
    updateQuantity(productId, item.quantity - decrement);
  }

  /// Aplicar desconto a um item
  void applyDiscount(int productId, double discount) {
    AppLogger.i('💰 Aplicando desconto de $discount% ao produto $productId');

    final index = state.items.indexWhere((item) => item.product.id == productId);

    if (index >= 0) {
      final clampedDiscount = discount.clamp(0.0, 100.0);
      final updatedItems = [...state.items];
      updatedItems[index] = state.items[index].copyWith(discount: clampedDiscount);

      state = state.copyWith(items: updatedItems, error: null);
    }
  }

  /// Atualizar preço unitário de um item
  void updatePrice(int productId, double price) {
    AppLogger.i('💵 Atualizando preço do produto $productId para $price');

    final index = state.items.indexWhere((item) => item.product.id == productId);

    if (index >= 0 && price >= 0) {
      final updatedItems = [...state.items];
      updatedItems[index] = state.items[index].copyWith(customPrice: price);

      state = state.copyWith(items: updatedItems, error: null);
    }
  }

  /// Limpar carrinho
  void clearCart() {
    AppLogger.i('🗑️ Limpando carrinho');
    state = const CartState();
  }

  /// Definir estado de processamento
  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  /// Definir erro
  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  /// Limpar erro
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Obter item por ID do produto
  CartItem? getItem(int productId) {
    try {
      return state.items.firstWhere((item) => item.product.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Verificar se produto está no carrinho
  bool containsProduct(int productId) {
    return state.items.any((item) => item.product.id == productId);
  }
}

/// Provider do CartNotifier
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

/// Provider conveniente para verificar se o carrinho está vazio
final isCartEmptyProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isEmpty;
});

/// Provider conveniente para obter o total do carrinho
final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).total;
});

/// Provider conveniente para obter o número de itens
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});
