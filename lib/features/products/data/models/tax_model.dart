import 'package:pos_moloni_app/features/products/domain/entities/tax.dart';

/// Model que estende Tax e adiciona serializacao JSON
class TaxModel extends Tax {
  const TaxModel({
    required super.id,
    required super.name,
    required super.value,
    super.order,
    super.cumulative,
  });

  /// Converte Entity para Model
  factory TaxModel.fromEntity(Tax entity) {
    return TaxModel(
      id: entity.id,
      name: entity.name,
      value: entity.value,
      order: entity.order,
      cumulative: entity.cumulative,
    );
  }

  /// Cria model a partir de JSON (API Moloni)
  /// 
  /// Estrutura da API:
  /// ```json
  /// {
  ///   "tax_id": 12345,
  ///   "value": 0,        // NAO usar este! E o valor aplicado, nao a taxa
  ///   "order": 0,
  ///   "cumulative": 0,
  ///   "tax": {
  ///     "tax_id": 12345,
  ///     "name": "IVA - Reduzida",
  ///     "value": 6.0      // USAR ESTE! E a percentagem de IVA
  ///   }
  /// }
  /// ```
  factory TaxModel.fromJson(Map<String, dynamic> json) {
    // A taxa de IVA real esta dentro do objecto "tax"
    final taxData = json['tax'] as Map<String, dynamic>? ?? {};
    
    // Obter o valor da taxa (percentagem) do objecto tax interno
    // Se nao existir, usar o value do nivel superior como fallback
    final taxValue = _parseDouble(taxData['value']) > 0 
        ? _parseDouble(taxData['value'])
        : _parseDouble(json['value']);
    
    // Obter o nome do imposto
    final taxName = taxData['name'] as String? ?? 'IVA';
    
    // Obter o ID (preferir do tax interno)
    final taxId = taxData['tax_id'] as int? ?? json['tax_id'] as int? ?? 0;

    return TaxModel(
      id: taxId,
      name: taxName,
      value: taxValue,
      order: json['order'] as int? ?? 0,
      cumulative: _parseBool(json['cumulative']),
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
      'tax_id': id,
      'value': value,
      'order': order,
      'cumulative': cumulative ? 1 : 0,
    };
  }

  /// Converte Model para Entity
  Tax toEntity() {
    return Tax(
      id: id,
      name: name,
      value: value,
      order: order,
      cumulative: cumulative,
    );
  }

  /// Cria copia com alteracoes
  TaxModel copyWith({
    int? id,
    String? name,
    double? value,
    int? order,
    bool? cumulative,
  }) {
    return TaxModel(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      order: order ?? this.order,
      cumulative: cumulative ?? this.cumulative,
    );
  }
}
