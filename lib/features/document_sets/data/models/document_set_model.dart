import 'package:pos_moloni_app/features/document_sets/domain/entities/document_set.dart';

/// Model que estende DocumentSet e adiciona serialização JSON
class DocumentSetModel extends DocumentSet {
  const DocumentSetModel({
    required super.id,
    required super.name,
    super.isDefault,
    super.activeByDefault,
  });

  /// Cria model a partir de JSON (API Moloni)
  factory DocumentSetModel.fromJson(Map<String, dynamic> json) {
    // Parse active_by_default - pode ser lista de document_type_id
    List<int>? activeByDefault;
    if (json['active_by_default'] != null) {
      if (json['active_by_default'] is List) {
        activeByDefault = (json['active_by_default'] as List)
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toList();
      }
    }

    return DocumentSetModel(
      id: json['document_set_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      isDefault: _parseBool(json['is_default']),
      activeByDefault: activeByDefault,
    );
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
      'document_set_id': id,
      'name': name,
      'is_default': isDefault ? 1 : 0,
      'active_by_default': activeByDefault,
    };
  }

  /// Converte Model para Entity
  DocumentSet toEntity() {
    return DocumentSet(
      id: id,
      name: name,
      isDefault: isDefault,
      activeByDefault: activeByDefault,
    );
  }

  /// Cria cópia com alterações
  DocumentSetModel copyWith({
    int? id,
    String? name,
    bool? isDefault,
    List<int>? activeByDefault,
  }) {
    return DocumentSetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      activeByDefault: activeByDefault ?? this.activeByDefault,
    );
  }
}
