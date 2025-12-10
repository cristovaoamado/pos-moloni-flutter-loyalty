import 'package:equatable/equatable.dart';

/// Entidade que representa um documento fiscal criado
class Document extends Equatable {
  const Document({
    required this.id,
    required this.documentSetId,
    required this.number,
    required this.ourReference,
    required this.yourReference,
    required this.date,
    required this.expirationDate,
    required this.customerId,
    required this.customerName,
    required this.customerVat,
    required this.netValue,
    required this.taxValue,
    required this.grossValue,
    required this.status,
    this.pdfUrl,
    this.products = const [],
    this.payments = const [],
    // Dados da empresa emissora (vindos do getOne)
    this.companyName,
    this.companyVat,
    this.companyAddress,
    this.companyCity,
    this.companyZipCode,
    this.companyCountry,
    this.companyPhone,
    this.companyEmail,
    // Dados adicionais do documento
    this.documentSetName,
    this.notes,
    this.currencySymbol,
    // Morada do cliente
    this.customerAddress,
    this.customerCity,
    this.customerZipCode,
    this.customerCountry,
    this.customerPhone,
    this.customerEmail,
    // ATCUD - Código único do documento (obrigatório em Portugal)
    this.atcud,
    // QR Code
    this.qrCode,
    // RSA Hash
    this.rsaHash,
    // ==================== DESCONTOS ====================
    this.deductionPercentage = 0,
    this.deductionValue = 0,
    this.comercialDiscountValue = 0,
  });

  final int id;
  final int documentSetId;
  final String number; // Ex: "FS 2024/1"
  final String ourReference;
  final String yourReference;
  final DateTime date;
  final DateTime expirationDate;
  final int customerId;
  final String customerName;
  final String customerVat;
  final double netValue; // Valor sem IVA (Total Ilíquido)
  final double taxValue; // Valor do IVA
  final double grossValue; // Valor total com IVA (Total a Pagar)
  final DocumentStatus status;
  final String? pdfUrl;
  final List<DocumentProduct> products;
  final List<DocumentPayment> payments;
  
  // Dados da empresa emissora
  final String? companyName;
  final String? companyVat;
  final String? companyAddress;
  final String? companyCity;
  final String? companyZipCode;
  final String? companyCountry;
  final String? companyPhone;
  final String? companyEmail;
  
  // Dados adicionais
  final String? documentSetName;
  final String? notes;
  final String? currencySymbol;
  
  // Morada do cliente
  final String? customerAddress;
  final String? customerCity;
  final String? customerZipCode;
  final String? customerCountry;
  final String? customerPhone;
  final String? customerEmail;
  
  // ATCUD - Código único do documento
  final String? atcud;
  
  // QR Code para impressão
  final String? qrCode;
  
  // RSA Hash (primeiros 4 chars usados no QR code campo Q)
  final String? rsaHash;
  
  // ==================== DESCONTOS (da API Moloni) ====================
  /// Percentagem do desconto global (0-100)
  final double deductionPercentage;
  
  /// Valor do desconto global em EUR
  final double deductionValue;
  
  /// Valor do desconto comercial (soma dos descontos de linha) em EUR
  final double comercialDiscountValue;

  /// Número formatado para exibição
  String get displayNumber => number;

  /// Data formatada
  String get formattedDate {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
  
  /// Data e hora formatada
  String get formattedDateTime {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  /// Valor total formatado
  String get formattedTotal => '${grossValue.toStringAsFixed(2)} €';
  
  /// Morada completa da empresa
  String get companyFullAddress {
    final parts = <String>[];
    if (companyAddress != null && companyAddress!.isNotEmpty) {
      parts.add(companyAddress!);
    }
    if (companyZipCode != null || companyCity != null) {
      final line = '${companyZipCode ?? ''} ${companyCity ?? ''}'.trim();
      if (line.isNotEmpty) parts.add(line);
    }
    return parts.join('\n');
  }
  
  /// Morada completa do cliente
  String get customerFullAddress {
    final parts = <String>[];
    if (customerAddress != null && customerAddress!.isNotEmpty) {
      parts.add(customerAddress!);
    }
    if (customerZipCode != null || customerCity != null) {
      final line = '${customerZipCode ?? ''} ${customerCity ?? ''}'.trim();
      if (line.isNotEmpty) parts.add(line);
    }
    return parts.join('\n');
  }
  
  /// Verifica se tem dados da empresa
  bool get hasCompanyData => companyName != null && companyName!.isNotEmpty;
  
  /// Verifica se tem desconto global
  bool get hasGlobalDiscount => deductionPercentage > 0 || deductionValue > 0;
  
  /// Verifica se tem descontos comerciais (de linha)
  bool get hasComercialDiscount => comercialDiscountValue > 0;
  
  /// Verifica se tem algum desconto
  bool get hasAnyDiscount => hasGlobalDiscount || hasComercialDiscount;
  
  /// Total de descontos (comercial + global)
  double get totalDiscountValue => comercialDiscountValue + deductionValue;

  @override
  List<Object?> get props => [
        id,
        documentSetId,
        number,
        date,
        customerId,
        grossValue,
        status,
      ];
}

/// Produto dentro de um documento
/// 
/// NOTA: Os valores vêm da API Moloni (getOne) e NÃO devem ser recalculados
class DocumentProduct extends Equatable {
  const DocumentProduct({
    required this.productId,
    required this.name,
    required this.reference,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.taxValue,
    required this.total,
    required this.lineTotal,
    this.taxes = const [],
  });

  final int productId;
  final String name;
  final String reference;
  final double quantity;
  /// PVP unitário (preço COM IVA) - como mostrado na fatura Moloni
  final double unitPrice;
  /// Percentagem de desconto (0-100)
  final double discount;
  /// Valor do IVA da linha (calculado pela API)
  final double taxValue;
  /// Total da linha SEM IVA (após desconto) - soma dos incidence_value
  final double total;
  /// Total da linha COM IVA - total + taxValue
  final double lineTotal;
  /// Lista de impostos aplicados (com incidence_value e total_value da API)
  final List<ProductTax> taxes;
  
  /// Taxa de IVA principal (primeira taxa da lista)
  double get taxRate => taxes.isNotEmpty ? taxes.first.value : 0;
  
  /// Verifica se tem desconto
  bool get hasDiscount => discount > 0;

  @override
  List<Object?> get props => [productId, quantity, total, lineTotal];
}

/// Imposto aplicado a um produto
/// 
/// Valores vindos directamente da API Moloni (getOne)
class ProductTax extends Equatable {
  const ProductTax({
    required this.taxId,
    required this.name,
    required this.value,
    this.incidenceValue = 0,
    this.totalValue = 0,
  });

  final int taxId;
  final String name;
  /// Taxa em percentagem (ex: 6, 13, 23)
  final double value;
  /// Valor de incidência (base tributável) - da API
  final double incidenceValue;
  /// Valor do imposto calculado - da API
  final double totalValue;

  @override
  List<Object?> get props => [taxId, value, incidenceValue, totalValue];
}

/// Pagamento associado ao documento
class DocumentPayment extends Equatable {
  const DocumentPayment({
    required this.paymentMethodId,
    required this.paymentMethodName,
    required this.value,
    this.notes,
  });

  final int paymentMethodId;
  final String paymentMethodName;
  final double value;
  final String? notes;

  @override
  List<Object?> get props => [paymentMethodId, value];
}

/// Estado do documento
enum DocumentStatus {
  draft(0, 'Rascunho'),
  closed(1, 'Fechado'),
  canceled(2, 'Anulado');

  const DocumentStatus(this.value, this.label);

  final int value;
  final String label;

  static DocumentStatus fromValue(int value) {
    return DocumentStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => DocumentStatus.draft,
    );
  }
}

/// Método de pagamento
class PaymentMethod extends Equatable {
  const PaymentMethod({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  /// Métodos de pagamento para POS (apenas Numerário e Multibanco)
  static const PaymentMethod cash = PaymentMethod(id: 1, name: 'Numerário');
  static const PaymentMethod card = PaymentMethod(id: 2, name: 'Multibanco');

  static List<PaymentMethod> get defaultMethods => [
        cash,
        card,
      ];

  @override
  List<Object?> get props => [id, name];
}
