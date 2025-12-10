import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';

// =============================================================================
// RECEIPT GENERATOR - USA EXCLUSIVAMENTE VALORES DA API MOLONI
// =============================================================================
// Este gerador NÃO faz cálculos locais. Todos os valores vêm do Document
// que foi obtido via getOne da API Moloni:
//
// - document.netValue = Total Ilíquido (base tributável)
// - document.taxValue = Total IVA
// - document.grossValue = Total a Pagar
// - document.comercialDiscountValue = Soma dos descontos de linha
// - document.deductionPercentage = % do desconto global (financial_discount)
// - document.deductionValue = Valor do desconto global (financial_discount_value)
//
// Para cada produto:
// - product.unitPrice = PVP unitário (preço COM IVA)
// - product.quantity = Quantidade
// - product.discount = % desconto de linha
// - product.total = Total da linha SEM IVA (incidence_value)
// - product.lineTotal = Total da linha COM IVA
// - product.taxValue = Valor do IVA da linha
// - product.taxes[].incidenceValue = Base tributável por taxa
// - product.taxes[].totalValue = Valor do imposto por taxa
// =============================================================================

/// Dados da empresa para o talão
class CompanyReceiptData {
  final String name;
  final String businessName;
  final String vat;
  final String address;
  final String zipCode;
  final String city;
  final String country;
  final String? phone;
  final String? email;
  final String? imageUrl;
  Uint8List? imageBytes;

  CompanyReceiptData({
    required this.name,
    this.businessName = '',
    required this.vat,
    required this.address,
    required this.zipCode,
    required this.city,
    this.country = 'Portugal',
    this.phone,
    this.email,
    this.imageUrl,
    this.imageBytes,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  String get fullAddress {
    final parts = <String>[];
    if (address.isNotEmpty) parts.add(address);
    if (zipCode.isNotEmpty || city.isNotEmpty) {
      parts.add('$zipCode $city'.trim());
    }
    return parts.join('\n');
  }

  Future<void> loadImage() async {
    if (imageUrl == null || imageUrl!.isEmpty) return;
    
    try {
      AppLogger.d('loadImage: A carregar imagem da empresa: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl!));
      
      if (response.statusCode == 200) {
        imageBytes = response.bodyBytes;
        AppLogger.i('loadImage: Imagem da empresa carregada: ${imageBytes!.length} bytes');
      }
    } catch (e) {
      AppLogger.w('loadImage: Erro ao carregar imagem da empresa: $e');
    }
  }

  static Future<CompanyReceiptData?> fromStorage(FlutterSecureStorage storage) async {
    try {
      var name = await storage.read(key: ApiConstants.keyCompanyName);
      name ??= await storage.read(key: 'company_name');
      name ??= await storage.read(key: 'company_selected_name');
      
      if (name == null || name.isEmpty) return null;

      final vat = await storage.read(key: ApiConstants.keyCompanyVat) ?? 
                  await storage.read(key: 'company_vat') ?? '';
      final address = await storage.read(key: ApiConstants.keyCompanyAddress) ?? 
                      await storage.read(key: 'company_address') ?? '';
      final zipCode = await storage.read(key: ApiConstants.keyCompanyZipCode) ?? 
                      await storage.read(key: 'company_zip_code') ?? '';
      final city = await storage.read(key: ApiConstants.keyCompanyCity) ?? 
                   await storage.read(key: 'company_city') ?? '';
      final phone = await storage.read(key: ApiConstants.keyCompanyPhone) ?? 
                    await storage.read(key: 'company_phone');
      final email = await storage.read(key: ApiConstants.keyCompanyEmail) ?? 
                    await storage.read(key: 'company_email');
      final imageUrl = await storage.read(key: 'company_selected_image_url');

      final companyData = CompanyReceiptData(
        name: name,
        vat: vat,
        address: address,
        zipCode: zipCode,
        city: city,
        phone: phone,
        email: email,
        imageUrl: imageUrl,
      );

      if (companyData.hasImage) {
        await companyData.loadImage();
      }

      return companyData;
    } catch (e) {
      AppLogger.e('Erro ao carregar dados da empresa', error: e);
      return null;
    }
  }
}

/// Configurações do talão
class ReceiptConfig {
  final double paperWidthMm;
  final double marginMm;
  final bool showLogo;
  final String? terminalName;
  final String? operatorName;
  final String footerText;
  final String programCertification;

  const ReceiptConfig({
    this.paperWidthMm = 80,
    this.marginMm = 3,
    this.showLogo = false,
    this.terminalName,
    this.operatorName,
    this.footerText = 'Obrigado pela preferência.',
    this.programCertification = 'Processado por programa certificado N 2860/AT',
  });

  static const ReceiptConfig paper58mm = ReceiptConfig(paperWidthMm: 58, marginMm: 2);
  static const ReceiptConfig paper80mm = ReceiptConfig(paperWidthMm: 80, marginMm: 3);

  PdfPageFormat get pageFormat => PdfPageFormat(
    paperWidthMm * PdfPageFormat.mm,
    double.infinity,
    marginAll: marginMm * PdfPageFormat.mm,
  );
}

/// Resumo de IVA por taxa (agrupa valores da API)
class _TaxSummary {
  final String name;
  final double rate;
  double incidenceValue; // Soma dos incidence_value (base tributável)
  double taxValue;       // Soma dos total_value (valor do imposto)

  _TaxSummary({
    required this.name, 
    required this.rate,
    this.incidenceValue = 0,
    this.taxValue = 0,
  });

  String get displayName {
    if (rate <= 6) return 'IVA Reduzido';
    if (rate <= 13) return 'IVA Intermédio';
    if (rate <= 23) return 'IVA Normal';
    return 'IVA $rate%';
  }
}

/// Gerador de talões POS - Formato Moloni
/// 
/// IMPORTANTE: Este gerador usa EXCLUSIVAMENTE os valores retornados pela 
/// API Moloni (getOne). Não faz cálculos locais.
class ReceiptGenerator {
  final CompanyReceiptData? companyData;
  final ReceiptConfig config;

  ReceiptGenerator({
    this.companyData,
    this.config = const ReceiptConfig(),
  });

  /// Gera um talão PDF a partir do documento Moloni
  Future<Uint8List> generateFromDocument({
    required Document document,
    required String documentTypeName,
  }) async {
    // Log dos valores do documento (todos da API Moloni)
    AppLogger.d('═══════════════════════════════════════════════════════════');
    AppLogger.d('GERANDO TALÃO - VALORES DA API MOLONI');
    AppLogger.d('═══════════════════════════════════════════════════════════');
    AppLogger.d('Documento: ${document.number}');
    AppLogger.d('───────────────────────────────────────────────────────────');
    AppLogger.d('TOTAIS (da API):');
    AppLogger.d('  • Total Ilíquido (netValue): ${document.netValue.toStringAsFixed(2)} EUR');
    AppLogger.d('  • Total IVA (taxValue): ${document.taxValue.toStringAsFixed(2)} EUR');
    AppLogger.d('  • Total a Pagar (grossValue): ${document.grossValue.toStringAsFixed(2)} EUR');
    AppLogger.d('───────────────────────────────────────────────────────────');
    AppLogger.d('DESCONTOS (da API):');
    AppLogger.d('  • Desc. Comercial: ${document.comercialDiscountValue.toStringAsFixed(2)} EUR');
    AppLogger.d('  • Desc. Global: ${document.deductionPercentage.toStringAsFixed(1)}%');
    AppLogger.d('  • Valor Desc. Global: ${document.deductionValue.toStringAsFixed(2)} EUR');
    AppLogger.d('───────────────────────────────────────────────────────────');
    AppLogger.d('PRODUTOS:');
    for (final p in document.products) {
      AppLogger.d('  • ${p.name}');
      AppLogger.d('      Qtd: ${p.quantity} x PVP: ${p.unitPrice.toStringAsFixed(2)} EUR');
      AppLogger.d('      Desc: ${p.discount.toStringAsFixed(0)}%');
      AppLogger.d('      Total s/IVA: ${p.total.toStringAsFixed(2)} EUR');
      AppLogger.d('      Total c/IVA: ${p.lineTotal.toStringAsFixed(2)} EUR');
    }
    AppLogger.d('═══════════════════════════════════════════════════════════');

    final pdf = pw.Document();

    // Dados da empresa (preferir dados do documento, fallback para storage)
    final companyName = _firstNonEmpty([
      document.companyName,
      companyData?.name,
    ]);
    final companyVat = _firstNonEmpty([
      document.companyVat,
      companyData?.vat,
    ]);
    final companyAddress = _firstNonEmpty([
      document.companyAddress,
      companyData?.address,
    ]);
    final companyZipCode = document.companyZipCode ?? companyData?.zipCode ?? '';
    final companyCity = document.companyCity ?? companyData?.city ?? '';
    final companyPhone = document.companyPhone ?? companyData?.phone;
    final companyEmail = document.companyEmail ?? companyData?.email;

    // Agrupar impostos por taxa (usando valores da API)
    final taxSummaries = _groupTaxesByRate(document.products);

    // Estilos
    final titleStyle = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
    final headerStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    final normalStyle = const pw.TextStyle(fontSize: 8);
    final smallStyle = const pw.TextStyle(fontSize: 7);
    final tinyStyle = const pw.TextStyle(fontSize: 6);
    final discountStyle = pw.TextStyle(fontSize: 7, color: PdfColors.green800);
    final totalStyle = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.Page(
        pageFormat: config.pageFormat,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════════════════════
              // CABEÇALHO - LOGO E EMPRESA
              // ═══════════════════════════════════════════════════════════
              if (companyData?.imageBytes != null) ...[
                pw.Center(
                  child: pw.Container(
                    height: 50,
                    child: pw.Image(
                      pw.MemoryImage(companyData!.imageBytes!),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
              
              // Nome da empresa
              pw.Center(
                child: pw.Text(
                  companyName,
                  style: titleStyle,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 4),
              
              // Morada
              if (companyAddress.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    companyAddress,
                    style: smallStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              if (companyZipCode.isNotEmpty || companyCity.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    '$companyZipCode $companyCity'.trim(),
                    style: smallStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              
              // NIF da empresa
              pw.Center(child: pw.Text('NIF: $companyVat', style: smallStyle)),
              
              // Contactos
              if (companyPhone != null && companyPhone.isNotEmpty)
                pw.Center(child: pw.Text('Tel: $companyPhone', style: smallStyle)),
              if (companyEmail != null && companyEmail.isNotEmpty)
                pw.Center(child: pw.Text(companyEmail, style: smallStyle)),
              
              pw.SizedBox(height: 10),
              _buildDashedLine(),
              pw.SizedBox(height: 6),

              // ═══════════════════════════════════════════════════════════
              // TIPO E NÚMERO DO DOCUMENTO
              // ═══════════════════════════════════════════════════════════
              pw.Center(
                child: pw.Text(
                  documentTypeName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Center(
                child: pw.Text(document.number, style: headerStyle),
              ),
              
              // ATCUD
              if (document.atcud != null && document.atcud!.isNotEmpty)
                pw.Center(
                  child: pw.Text('ATCUD: ${document.atcud}', style: smallStyle),
                ),
              
              pw.SizedBox(height: 4),
              
              // Data e hora
              pw.Center(child: pw.Text(document.formattedDateTime, style: normalStyle)),
              
              // Indicador de desconto global (se existir)
              if (document.hasGlobalDiscount)
                pw.Center(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.only(top: 4),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.green800),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'DESCONTO ${document.deductionPercentage.toStringAsFixed(0)}%',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                  ),
                ),
              
              pw.SizedBox(height: 6),
              _buildDashedLine(),
              pw.SizedBox(height: 6),

              // ═══════════════════════════════════════════════════════════
              // CLIENTE (se não for Consumidor Final)
              // ═══════════════════════════════════════════════════════════
              if (_isValidCustomer(document)) ...[
                pw.Text('Cliente: ${document.customerName}', style: normalStyle),
                if (document.customerVat.isNotEmpty && document.customerVat != '999999990')
                  pw.Text('NIF: ${document.customerVat}', style: smallStyle),
                if (document.customerAddress != null && document.customerAddress!.isNotEmpty)
                  pw.Text(document.customerAddress!, style: smallStyle),
                pw.SizedBox(height: 6),
                _buildThinLine(),
                pw.SizedBox(height: 6),
              ],

              // ═══════════════════════════════════════════════════════════
              // CABEÇALHO DOS PRODUTOS
              // ═══════════════════════════════════════════════════════════
              pw.Row(
                children: [
                  pw.Expanded(flex: 4, child: pw.Text('Artigo', style: headerStyle)),
                  pw.SizedBox(width: 25, child: pw.Text('Qtd', style: headerStyle, textAlign: pw.TextAlign.right)),
                  pw.SizedBox(width: 40, child: pw.Text('PVP', style: headerStyle, textAlign: pw.TextAlign.right)),
                  pw.SizedBox(width: 25, child: pw.Text('IVA', style: headerStyle, textAlign: pw.TextAlign.right)),
                  pw.SizedBox(width: 50, child: pw.Text('Total', style: headerStyle, textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.SizedBox(height: 4),
              _buildThinLine(),
              pw.SizedBox(height: 4),

              // ═══════════════════════════════════════════════════════════
              // LISTA DE PRODUTOS (valores da API)
              // ═══════════════════════════════════════════════════════════
              ...document.products.map((product) => _buildProductRow(product, discountStyle, smallStyle)),
              
              pw.SizedBox(height: 4),
              _buildDashedLine(),
              pw.SizedBox(height: 6),

              // ═══════════════════════════════════════════════════════════
              // SECÇÃO DE DESCONTOS (valores da API)
              // ═══════════════════════════════════════════════════════════
              if (document.hasAnyDiscount) ...[
                pw.Text('DESCONTOS', style: headerStyle),
                pw.SizedBox(height: 4),
                
                // Desconto comercial (soma dos descontos de linha)
                if (document.hasComercialDiscount)
                  _buildDiscountRow(
                    'Desconto Comercial:',
                    document.comercialDiscountValue,
                    discountStyle,
                  ),
                
                // Desconto global/financeiro
                if (document.hasGlobalDiscount)
                  _buildDiscountRow(
                    'Desconto ${document.deductionPercentage.toStringAsFixed(0)}%:',
                    document.deductionValue,
                    discountStyle,
                  ),
                
                // Total de descontos (se ambos existirem)
                if (document.hasComercialDiscount && document.hasGlobalDiscount) ...[
                  pw.SizedBox(height: 2),
                  _buildDiscountRow(
                    'Total Descontos:',
                    document.totalDiscountValue,
                    pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                ],
                
                pw.SizedBox(height: 4),
                _buildThinLine(),
                pw.SizedBox(height: 6),
              ],

              // ═══════════════════════════════════════════════════════════
              // RESUMO DE IVA (valores da API)
              // ═══════════════════════════════════════════════════════════
              pw.Text('RESUMO IVA', style: headerStyle),
              pw.SizedBox(height: 4),
              
              // Cabeçalho da tabela de IVA
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Taxa', style: smallStyle)),
                  pw.Expanded(flex: 3, child: pw.Text('Incidência', style: smallStyle, textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 3, child: pw.Text('IVA', style: smallStyle, textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.SizedBox(height: 2),
              
              // Linhas de IVA por taxa
              ...taxSummaries.map((tax) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 1),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        '${tax.displayName} ${tax.rate.toStringAsFixed(0)}%',
                        style: smallStyle,
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        _formatCurrency(tax.incidenceValue),
                        style: smallStyle,
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        _formatCurrency(tax.taxValue),
                        style: smallStyle,
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              )),
              
              pw.SizedBox(height: 6),
              _buildDashedLine(),
              pw.SizedBox(height: 6),

              // ═══════════════════════════════════════════════════════════
              // TOTAIS (valores EXACTOS da API Moloni)
              // ═══════════════════════════════════════════════════════════
              _buildTotalRow('Total Ilíquido:', document.netValue, normalStyle),
              _buildTotalRow('Total IVA:', document.taxValue, normalStyle),
              pw.SizedBox(height: 4),
              
              // Total a pagar (destaque)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: _buildTotalRow('TOTAL:', document.grossValue, totalStyle),
              ),
              
              pw.SizedBox(height: 6),
              _buildThinLine(),
              pw.SizedBox(height: 6),

              // ═══════════════════════════════════════════════════════════
              // PAGAMENTOS
              // ═══════════════════════════════════════════════════════════
              if (document.payments.isNotEmpty) ...[
                pw.Text('PAGAMENTO', style: headerStyle),
                pw.SizedBox(height: 4),
                ...document.payments.map((payment) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(payment.paymentMethodName, style: normalStyle),
                      pw.Text(_formatCurrency(payment.value), style: normalStyle),
                    ],
                  ),
                )),
                pw.SizedBox(height: 6),
                _buildThinLine(),
                pw.SizedBox(height: 6),
              ],

              // ═══════════════════════════════════════════════════════════
              // QR CODE
              // ═══════════════════════════════════════════════════════════
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: document.qrCode ?? _buildQrCodeData(document, companyVat),
                  width: 80,
                  height: 80,
                ),
              ),
              pw.SizedBox(height: 6),

              // ═══════════════════════════════════════════════════════════
              // RODAPÉ
              // ═══════════════════════════════════════════════════════════
              _buildDashedLine(),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(config.footerText, style: normalStyle),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  config.programCertification,
                  style: tinyStyle,
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    AppLogger.i('✅ Talão gerado: ${bytes.length} bytes');
    return bytes;
  }

  // ===========================================================================
  // MÉTODOS AUXILIARES
  // ===========================================================================

  /// Agrupa impostos por taxa usando os valores da API
  List<_TaxSummary> _groupTaxesByRate(List<DocumentProduct> products) {
    final Map<double, _TaxSummary> summaries = {};
    
    for (final product in products) {
      for (final tax in product.taxes) {
        final rate = tax.value;
        
        if (!summaries.containsKey(rate)) {
          summaries[rate] = _TaxSummary(name: tax.name, rate: rate);
        }
        
        // Usar valores da API directamente (não calcular!)
        summaries[rate]!.incidenceValue += tax.incidenceValue;
        summaries[rate]!.taxValue += tax.totalValue;
      }
    }
    
    // Ordenar por taxa (menor para maior)
    return summaries.values.toList()
      ..sort((a, b) => a.rate.compareTo(b.rate));
  }

  /// Linha de produto (todos os valores da API)
  pw.Widget _buildProductRow(
    DocumentProduct product,
    pw.TextStyle discountStyle,
    pw.TextStyle smallStyle,
  ) {
    final normalStyle = const pw.TextStyle(fontSize: 8);
    
    // Taxa de IVA do produto
    final taxRate = product.taxes.isNotEmpty ? product.taxes.first.value : 23.0;
    
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Nome do produto
          pw.Text(product.name, style: normalStyle),
          
          // Detalhes: Qtd | PVP Unit. | IVA% | Total (com IVA)
          pw.Row(
            children: [
              pw.Expanded(flex: 4, child: pw.SizedBox()),
              pw.SizedBox(
                width: 25,
                child: pw.Text(
                  _formatQuantity(product.quantity),
                  style: smallStyle,
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.SizedBox(
                width: 40,
                child: pw.Text(
                  _formatCurrency(product.unitPrice), // PVP da API
                  style: smallStyle,
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.SizedBox(
                width: 25,
                child: pw.Text(
                  '${taxRate.toStringAsFixed(0)}%',
                  style: smallStyle,
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.SizedBox(
                width: 50,
                child: pw.Text(
                  _formatCurrency(product.lineTotal), // Total COM IVA da API
                  style: smallStyle,
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          
          // Linha de desconto (se existir)
          if (product.hasDiscount)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '  Desc. ${product.discount.toStringAsFixed(0)}%',
                      style: discountStyle,
                    ),
                  ),
                  pw.SizedBox(
                    width: 50,
                    child: pw.Text(
                      // Valor do desconto = (PVP * Qtd) - lineTotal
                      '-${_formatCurrency((product.unitPrice * product.quantity) - product.lineTotal)}',
                      style: discountStyle,
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Linha de total
  pw.Widget _buildTotalRow(String label, double value, pw.TextStyle style) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(label, style: style),
        pw.SizedBox(width: 20),
        pw.SizedBox(
          width: 70,
          child: pw.Text(
            _formatCurrency(value),
            style: style,
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Linha de desconto (valor negativo)
  pw.Widget _buildDiscountRow(String label, double value, pw.TextStyle style) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(label, style: style),
        pw.SizedBox(width: 20),
        pw.SizedBox(
          width: 70,
          child: pw.Text(
            '-${_formatCurrency(value)}',
            style: style,
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Linha tracejada
  pw.Widget _buildDashedLine() {
    return pw.Container(
      height: 1,
      child: pw.Row(
        children: List.generate(
          60,
          (index) => pw.Expanded(
            child: pw.Container(
              height: 0.5,
              color: index % 2 == 0 ? PdfColors.black : PdfColors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// Linha fina
  pw.Widget _buildThinLine() {
    return pw.Container(height: 0.5, color: PdfColors.grey600);
  }

  /// Formata valor monetário
  String _formatCurrency(double value) {
    return '${value.toStringAsFixed(2)} EUR';
  }

  /// Formata quantidade
  String _formatQuantity(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(qty < 1 ? 3 : 2);
  }

  /// Retorna a primeira string não vazia da lista
  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  /// Verifica se é um cliente válido (não é Consumidor Final)
  bool _isValidCustomer(Document document) {
    return document.customerName.isNotEmpty &&
           document.customerName != 'Consumidor Final' &&
           document.customerName != 'Cliente Final';
  }

  /// Constrói os dados do QR Code conforme especificação AT
  String _buildQrCodeData(Document document, String companyVat) {
    final nifEmitente = companyVat.replaceAll(RegExp(r'[^0-9]'), '');
    final nifCliente = document.customerVat.isNotEmpty && 
                       document.customerVat != '999999990'
        ? document.customerVat.replaceAll(RegExp(r'[^0-9]'), '')
        : '999999990';
    
    final data = document.date;
    final dataFormatada = '${data.year}'
        '${data.month.toString().padLeft(2, '0')}'
        '${data.day.toString().padLeft(2, '0')}';
    
    final hash4 = document.rsaHash != null && document.rsaHash!.length >= 4
        ? document.rsaHash!.substring(0, 4)
        : '';
    
    final parts = <String>[
      'A:$nifEmitente',
      'B:$nifCliente',
      'C:PT',
      'D:FS',
      'E:N',
      'F:$dataFormatada',
      'G:${document.number}',
      'H:${document.atcud ?? ''}',
      'I1:PT',
      'I7:${document.netValue.toStringAsFixed(2)}',
      'I8:${document.taxValue.toStringAsFixed(2)}',
      'N:${document.taxValue.toStringAsFixed(2)}',
      'O:${document.grossValue.toStringAsFixed(2)}',
      'Q:$hash4',
      'R:2860',
    ];
    
    // Métodos de pagamento
    if (document.payments.isNotEmpty) {
      final paymentParts = document.payments.map((p) {
        String metodo = 'OU'; // Outro
        final nome = p.paymentMethodName.toLowerCase();
        
        if (nome.contains('numer') || nome.contains('dinheiro') || nome.contains('cash')) {
          metodo = 'NU'; // Numerário
        } else if (nome.contains('multibanco') || nome.contains('card') || nome.contains('cartao')) {
          metodo = 'MB'; // Multibanco
        } else if (nome.contains('transfer')) {
          metodo = 'TR'; // Transferência
        } else if (nome.contains('cheque')) {
          metodo = 'CH'; // Cheque
        }
        
        return '$metodo;${p.value.toStringAsFixed(2)}';
      }).join(';');
      
      parts.add('S:$paymentParts');
    }
    
    return parts.join('*');
  }
}
