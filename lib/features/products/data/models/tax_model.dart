import 'package:pos_moloni_app/features/products/domain/entities/tax.dart';

/// Model que estende Tax e adiciona serialização JSON
class TaxModel extends Tax {
  const TaxModel({
    required super.id,
    required super.value,
    super.order,
    super.cumulative,
  });

  /// Converte Entity para Model
  factory TaxModel.fromEntity(Tax entity) {
    return TaxModel(
      id: entity.id,
      value: entity.value,
      order: entity.order,
      cumulative: entity.cumulative,
    );
  }

  /// Cria model a partir de JSON (API Moloni)
  factory TaxModel.fromJson(Map<String, dynamic> json) {
    return TaxModel(
      id: json['tax_id'] as int? ?? json['id'] as int? ?? 0,
      value: _parseDouble(json['value']),
      order: json['order'] as int? ?? 0,
      cumulative: json['cumulative'] as bool? ?? false,
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
      'tax_id': id,
      'value': value,
      'order': order,
      'cumulative': cumulative,
    };
  }

  /// Converte Model para Entity
  Tax toEntity() {
    return Tax(
      id: id,
      value: value,
      order: order,
      cumulative: cumulative,
    );
  }

  /// Cria cópia com alterações
  TaxModel copyWith({
    int? id,
    double? value,
    int? order,
    bool? cumulative,
  }) {
    return TaxModel(
      id: id ?? this.id,
      value: value ?? this.value,
      order: order ?? this.order,
      cumulative: cumulative ?? this.cumulative,
    );
  }
}
