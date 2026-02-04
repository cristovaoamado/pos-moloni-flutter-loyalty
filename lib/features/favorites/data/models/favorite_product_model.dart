import 'package:hive_flutter/hive_flutter.dart';

import 'package:pos_moloni_app/features/favorites/data/models/favorite_tax_model.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/domain/entities/tax.dart';

part 'favorite_product_model.g.dart';

/// Modelo de produto favorito guardado localmente
/// Guarda os dados essenciais do produto INCLUINDO os impostos completos
@HiveType(typeId: 20)
class FavoriteProductModel extends HiveObject {
  FavoriteProductModel({
    required this.productId,
    required this.name,
    required this.reference,
    this.ean,
    required this.price,
    this.image,
    required this.categoryId,
    this.taxRate = 23.0,
    this.measureUnit,
    this.taxes,
    DateTime? addedAt,
    DateTime? lastUpdated,
  })  : addedAt = addedAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

  /// Cria a partir de um Product
  factory FavoriteProductModel.fromProduct(Product product) {
    // Converter taxes do Product para FavoriteTaxModel
    final favoriteTaxes = product.taxes.map((tax) => FavoriteTaxModel(
      taxId: tax.id,
      name: tax.name,
      value: tax.value,
      order: tax.order,
      cumulative: tax.cumulative,
    )).toList();

    return FavoriteProductModel(
      productId: product.id,
      name: product.name,
      reference: product.reference,
      ean: product.ean,
      price: product.price,
      image: product.image,
      categoryId: product.categoryId,
      taxRate: product.totalTaxRate,
      measureUnit: product.measureUnit,
      taxes: favoriteTaxes,
    );
  }

  @HiveField(0)
  final int productId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String reference;

  @HiveField(3)
  final String? ean;

  @HiveField(4)
  final double price;

  @HiveField(5)
  final String? image;

  @HiveField(6)
  final int categoryId;

  /// Taxa total de IVA (para compatibilidade e cálculos rápidos)
  @HiveField(7)
  final double taxRate;

  @HiveField(8)
  final DateTime addedAt;

  @HiveField(9)
  DateTime lastUpdated;

  /// Unidade de medida (kg, un, etc.)
  @HiveField(10)
  final String? measureUnit;

  /// Lista completa de impostos (NOVO - necessário para a API Moloni)
  @HiveField(11)
  final List<FavoriteTaxModel>? taxes;

  /// URL completa da imagem
  String? get imageUrl {
    if (image == null || image!.isEmpty) return null;
    return 'https://www.moloni.pt/_imagens/?img=$image';
  }

  /// Preço com IVA
  double get priceWithTax => price * (1 + taxRate / 100);

  /// Preço formatado com IVA
  String get formattedPriceWithTax => '${priceWithTax.toStringAsFixed(2)} €';

  /// Verifica se o produto é vendido ao peso
  bool get isWeighable {
    if (measureUnit == null) return false;
    final unit = measureUnit!.toLowerCase();
    return unit.contains('kg') ||
        unit.contains('g') ||
        unit == 'quilograma' ||
        unit == 'quilogramas' ||
        unit == 'grama' ||
        unit == 'gramas';
  }

  /// Verifica se tem impostos válidos guardados
  bool get hasTaxes => taxes != null && taxes!.isNotEmpty;

  /// Converte para Product (para usar no carrinho)
  Product toProduct() {
    // Converter FavoriteTaxModel para Tax
    final productTaxes = taxes?.map((favTax) => Tax(
      id: favTax.taxId,
      name: favTax.name,
      value: favTax.value,
      order: favTax.order,
      cumulative: favTax.cumulative,
    )).toList() ?? [];

    return Product(
      id: productId,
      name: name,
      reference: reference,
      ean: ean,
      price: price,
      image: image,
      categoryId: categoryId,
      measureUnit: measureUnit,
      taxes: productTaxes,
      posFavorite: true,
    );
  }

  /// Actualiza os dados do produto (mantém addedAt original)
  FavoriteProductModel copyWithUpdatedData({
    String? name,
    String? reference,
    String? ean,
    double? price,
    String? image,
    int? categoryId,
    double? taxRate,
    String? measureUnit,
    List<FavoriteTaxModel>? taxes,
  }) {
    return FavoriteProductModel(
      productId: productId,
      name: name ?? this.name,
      reference: reference ?? this.reference,
      ean: ean ?? this.ean,
      price: price ?? this.price,
      image: image ?? this.image,
      categoryId: categoryId ?? this.categoryId,
      taxRate: taxRate ?? this.taxRate,
      measureUnit: measureUnit ?? this.measureUnit,
      taxes: taxes ?? this.taxes,
      addedAt: addedAt,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  String toString() => 'FavoriteProduct(id: $productId, name: $name, taxes: ${taxes?.length ?? 0})';
}
