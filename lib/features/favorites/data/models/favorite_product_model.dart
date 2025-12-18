import 'package:hive_flutter/hive_flutter.dart';

part 'favorite_product_model.g.dart';

/// Modelo de produto favorito guardado localmente
/// Guarda apenas os dados essenciais do produto
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
    DateTime? addedAt,
    DateTime? lastUpdated,
  })  : addedAt = addedAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

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

  @HiveField(7)
  final double taxRate;

  @HiveField(8)
  final DateTime addedAt;

  @HiveField(9)
  DateTime lastUpdated;

  /// URL completa da imagem
  String? get imageUrl {
    if (image == null || image!.isEmpty) return null;
    return 'https://www.moloni.pt/_imagens/?img=$image';
  }

  /// Preço com IVA
  double get priceWithTax => price * (1 + taxRate / 100);

  /// Preço formatado com IVA
  String get formattedPriceWithTax => '${priceWithTax.toStringAsFixed(2)} €';

  /// Cria a partir de um Product
  factory FavoriteProductModel.fromProduct({
    required int productId,
    required String name,
    required String reference,
    String? ean,
    required double price,
    String? image,
    required int categoryId,
    double taxRate = 23.0,
  }) {
    return FavoriteProductModel(
      productId: productId,
      name: name,
      reference: reference,
      ean: ean,
      price: price,
      image: image,
      categoryId: categoryId,
      taxRate: taxRate,
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
      addedAt: addedAt,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  String toString() => 'FavoriteProduct(id: $productId, name: $name)';
}
