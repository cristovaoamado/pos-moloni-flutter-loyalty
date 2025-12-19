import 'package:pos_moloni_app/core/utils/logger.dart';
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
    super.posFavorite,
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
      posFavorite: entity.posFavorite,
    );
  }

  /// Cria model a partir de JSON (API Moloni)
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // ═══════════════════════════════════════════════════════════════════════
    // PARSING ROBUSTO DAS TAXES
    // A API pode retornar: List, null, ou até String vazia
    // ═══════════════════════════════════════════════════════════════════════
    List<Tax> taxesList = [];
    try {
      final taxesData = json['taxes'];
      if (taxesData != null && taxesData is List && taxesData.isNotEmpty) {
        taxesList = taxesData
            .whereType<Map<String, dynamic>>()
            .map((tax) => TaxModel.fromJson(tax))
            .cast<Tax>()
            .toList();
      }
    } catch (e) {
      AppLogger.w('⚠️ Erro ao fazer parsing das taxes: $e');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PARSING ROBUSTO DO measurement_unit
    // A API pode retornar: Map, String, ou null
    // ═══════════════════════════════════════════════════════════════════════
    String? measureUnit;
    try {
      final measurementUnit = json['measurement_unit'];
      if (measurementUnit is Map<String, dynamic>) {
        measureUnit = measurementUnit['name'] as String?;
      } else if (measurementUnit is String) {
        measureUnit = measurementUnit;
      }
      // Fallback para measure_unit
      measureUnit ??= json['measure_unit'] as String?;
    } catch (e) {
      AppLogger.w('⚠️ Erro ao fazer parsing do measurement_unit: $e');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PARSING DO pos_favorite
    // A API Moloni pode retornar: 1, 0, "1", "0", true, false, ou null
    // ═══════════════════════════════════════════════════════════════════════
    final posFavoriteValue = json['pos_favorite'];
    final isPOSFavorite = _parseBool(posFavoriteValue);
    
    // DEBUG: Log para verificar o valor (remover depois de confirmar que funciona)
    if (isPOSFavorite) {
      AppLogger.d('⭐ Produto FAVORITO: ${json['name']} (pos_favorite=$posFavoriteValue)');
    }

    return ProductModel(
      id: json['product_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      ean: json['ean'] as String?,
      price: _parseDouble(json['price']),
      summary: json['summary'] as String?,
      image: json['image'] as String?,
      measureUnit: measureUnit,
      categoryId: json['category_id'] as int? ?? 0,
      taxes: taxesList,
      hasStock: _parseBool(json['has_stock']),
      stock: _parseDouble(json['stock']),
      posFavorite: isPOSFavorite,
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

  /// Helper para converter valores para bool
  /// A API Moloni retorna 0/1 ou "0"/"1" em vez de true/false
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
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
      'taxes': taxes.map((t) {
        if (t is TaxModel) {
          return t.toJson();
        }
        // Fallback para Tax entity
        return {
          'tax_id': t.id,
          'name': t.name,
          'value': t.value,
        };
      }).toList(),
      'has_stock': hasStock ? 1 : 0,
      'stock': stock,
      'pos_favorite': posFavorite ? 1 : 0,
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
      posFavorite: posFavorite,
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
    bool? posFavorite,
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
      posFavorite: posFavorite ?? this.posFavorite,
    );
  }
}
