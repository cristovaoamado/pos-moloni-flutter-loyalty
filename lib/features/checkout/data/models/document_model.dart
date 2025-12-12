import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';

/// Model para serialização de documentos
class DocumentModel extends Document {
  const DocumentModel({
    required super.id,
    required super.documentSetId,
    required super.number,
    required super.ourReference,
    required super.yourReference,
    required super.date,
    required super.expirationDate,
    required super.customerId,
    required super.customerName,
    required super.customerVat,
    required super.netValue,
    required super.taxValue,
    required super.grossValue,
    required super.status,
    super.pdfUrl,
    super.products,
    super.payments,
    // Dados da empresa emissora
    super.companyName,
    super.companyVat,
    super.companyAddress,
    super.companyCity,
    super.companyZipCode,
    super.companyCountry,
    super.companyPhone,
    super.companyEmail,
    // Dados adicionais
    super.documentSetName,
    super.notes,
    super.currencySymbol,
    // Morada do cliente
    super.customerAddress,
    super.customerCity,
    super.customerZipCode,
    super.customerCountry,
    super.customerPhone,
    super.customerEmail,
    // ATCUD
    super.atcud,
    // QR Code
    super.qrCode,
    // RSA Hash
    super.rsaHash,
    // Descontos
    super.deductionPercentage,
    super.deductionValue,
    super.comercialDiscountValue,
  });

  /// Cria model a partir de JSON da API Moloni (getOne)
  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    // Parsear produtos
    final productsJson = json['products'] as List? ?? [];
    final products = productsJson
        .map((p) => DocumentProductModel.fromJson(p as Map<String, dynamic>))
        .toList();

    // Parsear pagamentos
    final paymentsJson = json['payments'] as List? ?? [];
    final payments = paymentsJson
        .map((p) => DocumentPaymentModel.fromJson(p as Map<String, dynamic>))
        .toList();

    // Parsear dados da empresa (pode vir em 'company' ou campos directos)
    final companyData = json['company'] as Map<String, dynamic>? ?? {};
    
    // Parsear dados do cliente (pode vir em 'entity' ou campos directos)
    final entityData = json['entity'] as Map<String, dynamic>? ?? {};
    
    // Parsear document_set
    final documentSetData = json['document_set'] as Map<String, dynamic>? ?? {};

    // ==================== VALORES DA API MOLONI ====================
    // A API retorna os seguintes valores:
    // - gross_value: valor bruto (qtd * preço, sem descontos)
    // - comercial_discount_value: valor dos descontos de linha
    // - financial_discount: percentagem do desconto financeiro/global
    // - financial_discount_value: valor do desconto financeiro/global
    // - deduction_value: valor de deduções fiscais (outro tipo de dedução)
    // - taxes_value: valor total dos impostos
    // - net_value: valor final a pagar (após todos descontos e impostos)
    // ================================================================
    
    final comercialDiscountValue = _parseDouble(json['comercial_discount_value']);
    final financialDiscount = _parseDouble(json['financial_discount']);
    final financialDiscountValue = _parseDouble(json['financial_discount_value']);
    final taxesValue = _parseDouble(json['taxes_value']);
    final netValue = _parseDouble(json['net_value']);
    
    // Total Ilíquido = net_value - taxes_value (base tributável após descontos)
    final totalIliquido = netValue - taxesValue;

    return DocumentModel(
      id: json['document_id'] as int? ?? 0,
      documentSetId: json['document_set_id'] as int? ?? 0,
      number: _parseString(json['number']),
      ourReference: _parseString(json['our_reference']),
      yourReference: _parseString(json['your_reference']),
      date: _parseDate(json['date']),
      expirationDate: _parseDate(json['expiration_date']),
      customerId: json['customer_id'] as int? ?? 0,
      // Nome do cliente - tentar várias fontes
      customerName: _parseString(entityData['name']).isNotEmpty 
                   ? _parseString(entityData['name'])
                   : _parseString(json['entity_name']).isNotEmpty 
                     ? _parseString(json['entity_name'])
                     : _parseString(json['customer_name']),
      // NIF do cliente
      customerVat: _parseString(entityData['vat']).isNotEmpty
                  ? _parseString(entityData['vat'])
                  : _parseString(json['entity_vat']).isNotEmpty
                    ? _parseString(json['entity_vat'])
                    : _parseString(json['customer_vat']),
      // Morada do cliente
      customerAddress: _parseString(entityData['address']).isNotEmpty
                       ? _parseString(entityData['address'])
                       : _parseString(json['entity_address']),
      customerCity: _parseString(entityData['city']).isNotEmpty
                    ? _parseString(entityData['city'])
                    : _parseString(json['entity_city']),
      customerZipCode: _parseString(entityData['zip_code']).isNotEmpty
                       ? _parseString(entityData['zip_code'])
                       : _parseString(json['entity_zip_code']),
      customerCountry: _parseString(entityData['country']).isNotEmpty
                       ? _parseString(entityData['country'])
                       : _parseString(json['entity_country']),
      customerPhone: _parseString(entityData['phone']).isNotEmpty
                     ? _parseString(entityData['phone'])
                     : _parseString(json['entity_phone']),
      customerEmail: _parseString(entityData['email']).isNotEmpty
                     ? _parseString(entityData['email'])
                     : _parseString(json['entity_email']),
      // Valores calculados
      netValue: totalIliquido,  // Total ilíquido (base tributável)
      taxValue: taxesValue,     // Valor do IVA
      grossValue: netValue,     // Total a pagar (net_value da API)
      status: DocumentStatus.fromValue(json['status'] as int? ?? 0),
      pdfUrl: json['pdf_url']?.toString(),
      products: products,
      payments: payments,
      // Dados da empresa emissora
      companyName: _parseString(companyData['name']).isNotEmpty
                   ? _parseString(companyData['name'])
                   : _parseString(json['company_name']),
      companyVat: _parseString(companyData['vat']).isNotEmpty
                  ? _parseString(companyData['vat'])
                  : _parseString(json['company_vat']),
      companyAddress: _parseString(companyData['address']).isNotEmpty
                      ? _parseString(companyData['address'])
                      : _parseString(json['company_address']),
      companyCity: _parseString(companyData['city']).isNotEmpty
                   ? _parseString(companyData['city'])
                   : _parseString(json['company_city']),
      companyZipCode: _parseString(companyData['zip_code']).isNotEmpty
                      ? _parseString(companyData['zip_code'])
                      : _parseString(json['company_zip_code']),
      companyCountry: _parseString(companyData['country']).isNotEmpty
                      ? _parseString(companyData['country'])
                      : _parseString(json['company_country']),
      companyPhone: _parseString(companyData['phone']).isNotEmpty
                    ? _parseString(companyData['phone'])
                    : _parseString(json['company_phone']),
      companyEmail: _parseString(companyData['email']).isNotEmpty
                    ? _parseString(companyData['email'])
                    : _parseString(json['company_email']),
      // Dados adicionais
      documentSetName: _parseString(documentSetData['name']).isNotEmpty
                       ? _parseString(documentSetData['name'])
                       : _parseString(json['document_set_name']),
      notes: _parseString(json['notes']),
      currencySymbol: _parseString(json['currency_symbol']).isNotEmpty
                      ? _parseString(json['currency_symbol'])
                      : '€',
      // ATCUD - codigo unico do documento
      atcud: _parseString(json['atcud']).isNotEmpty
             ? _parseString(json['atcud'])
             : _parseString(json['rsa_hash']).isNotEmpty
               ? _parseString(json['rsa_hash'])
               : _parseString(json['hash']),
      // QR Code
      qrCode: _parseString(json['qr_code']).isNotEmpty
              ? _parseString(json['qr_code'])
              : null,
      // RSA Hash
      rsaHash: _parseString(json['rsa_hash']),
      // ==================== DESCONTOS ====================
      // financial_discount: percentagem do desconto global
      // financial_discount_value: valor do desconto global
      // comercial_discount_value: valor dos descontos de linha
      deductionPercentage: financialDiscount,
      deductionValue: financialDiscountValue,
      comercialDiscountValue: comercialDiscountValue,
    );
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Converte para JSON para enviar à API
  Map<String, dynamic> toJson() {
    return {
      'document_id': id,
      'document_set_id': documentSetId,
      'number': number,
      'our_reference': ourReference,
      'your_reference': yourReference,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'expiration_date': '${expirationDate.year}-${expirationDate.month.toString().padLeft(2, '0')}-${expirationDate.day.toString().padLeft(2, '0')}',
      'customer_id': customerId,
      'net_value': netValue,
      'taxes_value': taxValue,
      'gross_value': grossValue,
      'status': status.value,
    };
  }
}

class DocumentProductModel extends DocumentProduct {
  const DocumentProductModel({
    required super.productId,
    required super.name,
    required super.reference,
    required super.quantity,
    required super.unitPrice,
    required super.discount,
    required super.taxValue,
    required super.total,
    required super.lineTotal,
    super.taxes,
  });

  /// Cria a partir do JSON da API
  /// 
  /// Estrutura da API Moloni (getOne):
  /// ```json
  /// {
  ///   "product_id": 123,
  ///   "name": "Cafe",
  ///   "reference": "CAF001",
  ///   "price": 0.70,        // PVP unitário (COM IVA incluído)
  ///   "qty": 10,
  ///   "discount": 10,       // Desconto em %
  ///   "taxes": [
  ///     {
  ///       "tax_id": 1,
  ///       "name": "IVA - Reduzida",
  ///       "value": 6.0,           // Taxa em %
  ///       "incidence_value": 5.94, // Valor base (sem IVA) após desconto
  ///       "total_value": 0.36      // Valor do imposto
  ///     }
  ///   ]
  /// }
  /// ```
  factory DocumentProductModel.fromJson(Map<String, dynamic> json) {
    // Parsear impostos do produto
    final taxesJson = json['taxes'] as List? ?? [];
    
    double totalTaxValue = 0;
    double totalIncidenceValue = 0;
    
    final taxes = taxesJson.map((t) {
      final taxMap = t as Map<String, dynamic>;
      final incidenceValue = _parseDouble(taxMap['incidence_value']);
      final taxTotalValue = _parseDouble(taxMap['total_value']);
      
      totalTaxValue += taxTotalValue;
      totalIncidenceValue += incidenceValue;
      
      return ProductTax(
        taxId: taxMap['tax_id'] as int? ?? 0,
        name: _parseString(taxMap['name']),
        value: _parseDouble(taxMap['value']),
        incidenceValue: incidenceValue,
        totalValue: taxTotalValue,
      );
    }).toList();

    // IMPORTANTE: O campo 'price' da API é o PVP (preço COM IVA)
    final unitPrice = _parseDouble(json['price']); // PVP unitário
    final quantity = _parseDouble(json['qty']);
    final discount = _parseDouble(json['discount']);
    
    // Total SEM IVA = soma dos incidence_value dos impostos
    // (já vem calculado pela API com descontos aplicados)
    final totalWithoutTax = totalIncidenceValue;
    
    // Total COM IVA = total sem IVA + valor dos impostos
    final lineTotal = totalWithoutTax + totalTaxValue;

    return DocumentProductModel(
      productId: json['product_id'] as int? ?? 0,
      name: _parseString(json['name']),
      reference: _parseString(json['reference']),
      quantity: quantity,
      unitPrice: unitPrice, // PVP (COM IVA)
      discount: discount,
      taxValue: totalTaxValue,
      total: totalWithoutTax, // Total SEM IVA
      lineTotal: lineTotal, // Total COM IVA
      taxes: taxes,
    );
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'reference': reference,
      'qty': quantity,
      'price': unitPrice,
      'discount': discount,
    };
  }
}

class DocumentPaymentModel extends DocumentPayment {
  const DocumentPaymentModel({
    required super.paymentMethodId,
    required super.paymentMethodName,
    required super.value,
    super.notes,
  });

  factory DocumentPaymentModel.fromJson(Map<String, dynamic> json) {
    return DocumentPaymentModel(
      paymentMethodId: json['payment_method_id'] as int? ?? 0,
      paymentMethodName: _parseString(json['payment_method_name']),
      value: _parseDouble(json['value']),
      notes: json['notes']?.toString(),
    );
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_method_id': paymentMethodId,
      'value': value,
      if (notes != null) 'notes': notes,
    };
  }
}
