import 'package:hive_flutter/hive_flutter.dart';

part 'favorite_tax_model.g.dart';

/// Modelo de imposto guardado localmente para favoritos
/// Guarda os dados essenciais do imposto para enviar à API Moloni
@HiveType(typeId: 21)
class FavoriteTaxModel extends HiveObject {
  FavoriteTaxModel({
    required this.taxId,
    required this.name,
    required this.value,
    this.order = 0,
    this.cumulative = false,
  });

  /// ID do imposto no Moloni (OBRIGATÓRIO para a API)
  @HiveField(0)
  final int taxId;

  /// Nome do imposto (ex: "IVA - Reduzida")
  @HiveField(1)
  final String name;

  /// Percentagem do imposto (ex: 6.0, 13.0, 23.0)
  @HiveField(2)
  final double value;

  /// Ordem de aplicação
  @HiveField(3)
  final int order;

  /// Se é cumulativo
  @HiveField(4)
  final bool cumulative;

  /// Taxa formatada (ex: "6%")
  String get formattedRate => '${value.toStringAsFixed(0)}%';

  @override
  String toString() => 'FavoriteTax(id: $taxId, name: $name, value: $value%)';
}
