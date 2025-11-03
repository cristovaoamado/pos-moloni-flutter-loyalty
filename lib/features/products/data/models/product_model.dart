import 'package:pos_moloni_app/features/products/data/models/tax_model.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/domain/entities/tax.dart';

/// Model que estende Product e adiciona serialização JSON
class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.reference,
    super.ean,
    required super.price,
    super.summary,
    super.image,
    super.measureUnit,
    required super.categoryId,
    required super.taxes,
    super.hasStock,
    super.stock,
  });

  /// Converte Entity para Model
  factory ProductModel.fromEntity(Product entity) {
    return ProductModel(
      id: entity.id,
      name: entity.name,
      reference: entity.reference,
      ean: entity.ean,
      price: entity.price,
      summary: entity.summary,
      image: entity.image,
      measureUnit: entity.measureUnit,
      categoryId: entity.categoryId,
      taxes: entity.taxes,
      hasStock: entity.hasStock,
      stock: entity.stock,
    );
  }

  /// Cria model a partir de JSON (API Moloni)
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final taxesList = (json['taxes'] as List?)
            ?.map((tax) => TaxModel.fromJson(tax as Map<String, dynamic>))
            .cast<Tax>()
            .toList() ??
        [];

    return ProductModel(
      id: json['product_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      ean: json['ean'] as String?,
      price: _parseDouble(json['price']),
      summary: json['summary'] as String?,
      image: json['image'] as String?,
      measureUnit: json['measure_unit'] as String?,
      categoryId: json['category_id'] as int? ?? 0,
      taxes: taxesList,
      hasStock: json['has_stock'] as bool? ?? false,
      stock: _parseDouble(json['stock']),
    );
  }

  /// Helper para converter valores para double
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Converte model para JSON
  Map<String, dynamic> toJson() {
    return {
      'product_id': id,
      'name': name,
      'reference': reference,
      'ean': ean,
      'price': price,
      'summary': summary,
      'image': image,
      'measure_unit': measureUnit,
      'category_id': categoryId,
      'taxes': taxes.map((t) => (t as TaxModel).toJson()).toList(),
      'has_stock': hasStock,
      'stock': stock,
    };
  }

  /// Converte Model para Entity
  Product toEntity() {
    return Product(
      id: id,
      name: name,
      reference: reference,
      ean: ean,
      price: price,
      summary: summary,
      image: image,
      measureUnit: measureUnit,
      categoryId: categoryId,
      taxes: taxes,
      hasStock: hasStock,
      stock: stock,
    );
  }

  /// Cria cópia com alterações
  ProductModel copyWith({
    int? id,
    String? name,
    String? reference,
    String? ean,
    double? price,
    String? summary,
    String? image,
    String? measureUnit,
    int? categoryId,
    List<Tax>? taxes,
    bool? hasStock,
    double? stock,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      reference: reference ?? this.reference,
      ean: ean ?? this.ean,
      price: price ?? this.price,
      summary: summary ?? this.summary,
      image: image ?? this.image,
      measureUnit: measureUnit ?? this.measureUnit,
      categoryId: categoryId ?? this.categoryId,
      taxes: taxes ?? this.taxes,
      hasStock: hasStock ?? this.hasStock,
      stock: stock ?? this.stock,
    );
  }
}
