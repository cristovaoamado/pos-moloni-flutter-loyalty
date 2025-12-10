import 'package:equatable/equatable.dart';

import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/domain/entities/tax.dart';

/// Entity que representa um item no carrinho
class CartItem extends Equatable {
  const CartItem({
    required this.product,
    required this.quantity,
    this.discount = 0.0,
    this.customPrice,
  });

  final Product product;
  final double quantity;
  final double discount; // Percentagem de desconto (0-100)
  final double? customPrice; // Preco customizado (se diferente do produto) - SEM IVA

  /// ID unico do item (baseado no produto)
  int get id => product.id;

  /// Nome do produto
  String get name => product.name;

  /// Preco unitario SEM IVA (para enviar a API)
  double get unitPrice => customPrice ?? product.price;

  /// Preco unitario COM IVA (para mostrar ao utilizador)
  double get unitPriceWithTax => unitPrice * (1 + taxRate / 100);

  /// Unidade de medida
  String get measureUnit => product.measureUnit ?? 'Un';

  /// Impostos do produto
  List<Tax> get taxes => product.taxes;

  /// Taxa total de IVA
  double get taxRate => product.totalTaxRate;

  /// Subtotal SEM IVA (preco * quantidade, sem desconto)
  double get subtotal => unitPrice * quantity;

  /// Valor do desconto (sobre o subtotal sem IVA)
  double get discountValue => subtotal * (discount / 100);

  /// Subtotal com desconto (sem IVA)
  double get subtotalWithDiscount => subtotal - discountValue;

  /// Valor do IVA
  double get taxValue => subtotalWithDiscount * (taxRate / 100);

  /// Total da linha COM IVA (para mostrar ao utilizador)
  double get total => subtotalWithDiscount + taxValue;

  /// Subtotal formatado (sem IVA)
  String get formattedSubtotal => '${subtotal.toStringAsFixed(2)} €';

  /// Desconto formatado
  String get formattedDiscount => '${discount.toStringAsFixed(0)}%';

  /// Total formatado (com IVA)
  String get formattedTotal => '${total.toStringAsFixed(2)} €';

  /// Preco unitario com IVA formatado (para mostrar no UI)
  String get formattedUnitPriceWithTax => '${unitPriceWithTax.toStringAsFixed(2)} €';

  /// Quantidade formatada (ate 3 casas decimais, sem zeros a direita)
  String get formattedQuantity {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    String formatted = quantity.toStringAsFixed(3);
    while (formatted.endsWith('0')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  /// Verifica se a quantidade e por unidade
  bool get isUnitQuantity =>
      measureUnit.toLowerCase() == 'un' || measureUnit.toLowerCase() == 'unidade';

  /// Cria uma copia com novos valores
  CartItem copyWith({
    Product? product,
    double? quantity,
    double? discount,
    double? customPrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      customPrice: customPrice ?? this.customPrice,
    );
  }

  @override
  List<Object?> get props => [product, quantity, discount, customPrice];

  @override
  String toString() => 'CartItem(${product.name}, qty: $quantity, discount: $discount%)';
}
