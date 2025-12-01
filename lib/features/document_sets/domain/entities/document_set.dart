import 'package:equatable/equatable.dart';

/// Tipo de documento na API Moloni
enum DocumentTypeId {
  invoice(1, 'FT', 'Fatura', 'invoices'),
  invoiceReceipt(3, 'FR', 'Fatura-Recibo', 'invoiceReceipts'),
  simplifiedInvoice(4, 'FS', 'Fatura Simplificada', 'simplifiedInvoices'),
  receipt(5, 'RC', 'Recibo', 'receipts'),
  creditNote(6, 'NC', 'Nota de Crédito', 'creditNotes'),
  debitNote(7, 'ND', 'Nota de Débito', 'debitNotes');

  const DocumentTypeId(this.id, this.code, this.name, this.endpoint);
  
  final int id;
  final String code;
  final String name;
  final String endpoint;

  static DocumentTypeId? fromId(int id) {
    try {
      return DocumentTypeId.values.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Entidade que representa uma série de documentos
class DocumentSet extends Equatable {
  const DocumentSet({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.activeByDefault,
  });

  final int id;
  final String name;
  final bool isDefault;
  final List<int>? activeByDefault; // IDs dos tipos de documento para os quais esta série é default

  @override
  List<Object?> get props => [id, name, isDefault, activeByDefault];
}

/// Combinação de Série + Tipo de Documento para usar no POS
class DocumentTypeOption extends Equatable {
  const DocumentTypeOption({
    required this.documentSet,
    required this.documentType,
  });

  final DocumentSet documentSet;
  final DocumentTypeId documentType;

  /// ID único para esta combinação
  String get uniqueId => '${documentSet.id}_${documentType.id}';

  /// Nome para exibição (ex: "Fatura Simplificada - Série A")
  String get displayName => '${documentType.name} - ${documentSet.name}';

  /// Nome curto (ex: "FS - Série A")
  String get shortName => '${documentType.code} - ${documentSet.name}';

  /// Código do tipo (ex: "FS")
  String get code => documentType.code;

  /// Nome do tipo (ex: "Fatura Simplificada")
  String get typeName => documentType.name;

  @override
  List<Object?> get props => [documentSet, documentType];
}
