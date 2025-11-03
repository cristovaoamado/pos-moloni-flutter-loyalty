import 'package:equatable/equatable.dart';

import 'package:pos_moloni_app/features/products/domain/entities/tax.dart';

/// Entity que representa um produto
class Product extends Equatable {

  const Product({
    required this.id,
    required this.name,
    required this.reference,
    this.ean,
    required this.price,
    this.summary,
    this.image,
    this.measureUnit,
    required this.categoryId,
    required this.taxes,
    this.hasStock = false,
    this.stock = 0,
  });
  final int id;
  final String name;
  final String reference;
  final String? ean;
  final double price;
  final String? summary;
  final String? image;
  final String? measureUnit;
  final int categoryId;
  final List<Tax> taxes;
  final bool hasStock;
  final double stock;

  /// URL completa da imagem
  String? get imageUrl {
    if (image == null || image!.isEmpty) return null;
    return 'https://www.moloni.pt/_imagens/?img=$image';
  }

  /// Preço formatado
  String get formattedPrice => '${price.toStringAsFixed(2)} €';

  /// IVA total do produto
  double get totalTaxRate {
    return taxes.fold(0.0, (sum, tax) => sum + tax.value);
  }

  /// Preço com IVA
  double get priceWithTax {
    return price * (1 + totalTaxRate / 100);
  }

  /// Verifica se tem imagem
  bool get hasImage => image != null && image!.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        name,
        reference,
        ean,
        price,
        summary,
        image,
        measureUnit,
        categoryId,
        taxes,
        hasStock,
        stock,
      ];

  @override
  String toString() => 'Product(id: $id, name: $name, price: $price)';
}
