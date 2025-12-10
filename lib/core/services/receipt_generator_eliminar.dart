// import 'dart:typed_data';

// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:http/http.dart' as http;
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;

// import 'package:pos_moloni_app/core/constants/api_constants.dart';
// import 'package:pos_moloni_app/core/utils/logger.dart';
// import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';

// /// Dados da empresa para o talão
// class CompanyReceiptData {
//   final String name;
//   final String businessName;
//   final String vat;
//   final String address;
//   final String zipCode;
//   final String city;
//   final String country;
//   final String? phone;
//   final String? email;
//   final String? imageUrl;
//   Uint8List? imageBytes;

//   CompanyReceiptData({
//     required this.name,
//     this.businessName = '',
//     required this.vat,
//     required this.address,
//     required this.zipCode,
//     required this.city,
//     this.country = 'Portugal',
//     this.phone,
//     this.email,
//     this.imageUrl,
//     this.imageBytes,
//   });

//   bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

//   String get fullAddress {
//     final parts = <String>[];
//     if (address.isNotEmpty) parts.add(address);
//     if (zipCode.isNotEmpty || city.isNotEmpty) {
//       parts.add('$zipCode $city'.trim());
//     }
//     return parts.join('\n');
//   }

//   Future<void> loadImage() async {
//     if (imageUrl == null || imageUrl!.isEmpty) return;
    
//     try {
//       AppLogger.d('loadImage: A carregar imagem da empresa: $imageUrl');
//       final response = await http.get(Uri.parse(imageUrl!));
      
//       if (response.statusCode == 200) {
//         imageBytes = response.bodyBytes;
//         AppLogger.i('loadImage: Imagem da empresa carregada: ${imageBytes!.length} bytes');
//       }
//     } catch (e) {
//       AppLogger.w('loadImage: Erro ao carregar imagem da empresa: $e');
//     }
//   }

//   static Future<CompanyReceiptData?> fromStorage(FlutterSecureStorage storage) async {
//     try {
//       var name = await storage.read(key: ApiConstants.keyCompanyName);
//       name ??= await storage.read(key: 'company_name');
//       name ??= await storage.read(key: 'company_selected_name');
      
//       if (name == null || name.isEmpty) return null;

//       final vat = await storage.read(key: ApiConstants.keyCompanyVat) ?? 
//                   await storage.read(key: 'company_vat') ?? '';
//       final address = await storage.read(key: ApiConstants.keyCompanyAddress) ?? 
//                       await storage.read(key: 'company_address') ?? '';
//       final zipCode = await storage.read(key: ApiConstants.keyCompanyZipCode) ?? 
//                       await storage.read(key: 'company_zip_code') ?? '';
//       final city = await storage.read(key: ApiConstants.keyCompanyCity) ?? 
//                    await storage.read(key: 'company_city') ?? '';
//       final phone = await storage.read(key: ApiConstants.keyCompanyPhone) ?? 
//                     await storage.read(key: 'company_phone');
//       final email = await storage.read(key: ApiConstants.keyCompanyEmail) ?? 
//                     await storage.read(key: 'company_email');
//       final imageUrl = await storage.read(key: 'company_selected_image_url');

//       final companyData = CompanyReceiptData(
//         name: name,
//         vat: vat,
//         address: address,
//         zipCode: zipCode,
//         city: city,
//         phone: phone,
//         email: email,
//         imageUrl: imageUrl,
//       );

//       if (companyData.hasImage) {
//         await companyData.loadImage();
//       }

//       return companyData;
//     } catch (e) {
//       AppLogger.e('Erro ao carregar dados da empresa', error: e);
//       return null;
//     }
//   }
// }

// /// Configurações do talão
// class ReceiptConfig {
//   final double paperWidthMm;
//   final double marginMm;
//   final bool showLogo;
//   final String? terminalName;
//   final String? operatorName;
//   final String footerText;
//   final String programCertification;

//   const ReceiptConfig({
//     this.paperWidthMm = 80,
//     this.marginMm = 3,
//     this.showLogo = false,
//     this.terminalName,
//     this.operatorName,
//     this.footerText = 'Obrigado.',
//     this.programCertification = 'Processado por programa certificado N 2860/AT',
//   });

//   static const ReceiptConfig paper58mm = ReceiptConfig(paperWidthMm: 58, marginMm: 2);
//   static const ReceiptConfig paper80mm = ReceiptConfig(paperWidthMm: 80, marginMm: 3);

//   PdfPageFormat get pageFormat => PdfPageFormat(
//     paperWidthMm * PdfPageFormat.mm,
//     double.infinity,
//     marginAll: marginMm * PdfPageFormat.mm,
//   );
// }

// /// Classe para agrupar impostos
// class TaxSummary {
//   final String name;
//   final double rate;
//   double baseValue = 0;
//   double taxValue = 0;

//   TaxSummary({required this.name, required this.rate});

//   String get displayName {
//     if (rate <= 6) return 'IVA Reduzido';
//     if (rate <= 13) return 'IVA Intermedio';
//     if (rate <= 23) return 'IVA Normal';
//     return 'IVA $rate%';
//   }
// }

// /// Informação de desconto para o resumo
// class DiscountInfo {
//   final String productName;
//   final double discountPercent;
//   final double discountValue;

//   DiscountInfo({
//     required this.productName,
//     required this.discountPercent,
//     required this.discountValue,
//   });
// }

// /// Gerador de talões POS - Formato Moloni
// class ReceiptGenerator {
//   final CompanyReceiptData? companyData;
//   final ReceiptConfig config;

//   ReceiptGenerator({
//     this.companyData,
//     this.config = const ReceiptConfig(),
//   });

//   /// Gera um talão PDF
//   Future<Uint8List> generateFromDocument({
//     required Document document,
//     required String documentTypeName,
//     double globalDiscount = 0,
//     double globalDiscountValue = 0,
//   }) async {
//     AppLogger.d('Gerando talao para documento ${document.number}');

//     final pdf = pw.Document();

//     // Dados da empresa
//     final companyName = document.companyName?.isNotEmpty == true 
//         ? document.companyName! 
//         : companyData?.name ?? '';
//     final companyVat = document.companyVat?.isNotEmpty == true 
//         ? document.companyVat! 
//         : companyData?.vat ?? '';
//     final companyAddress = document.companyAddress?.isNotEmpty == true 
//         ? document.companyAddress! 
//         : companyData?.address ?? '';
//     final companyZipCode = document.companyZipCode ?? companyData?.zipCode ?? '';
//     final companyCity = document.companyCity ?? companyData?.city ?? '';
//     final companyPhone = document.companyPhone ?? companyData?.phone;
//     final companyEmail = document.companyEmail ?? companyData?.email;

//     // Calcular resumo de impostos
//     final taxSummaries = _calculateTaxSummaries(document.products);
    
//     // Calcular descontos
//     final discountInfos = _calculateDiscounts(document.products);
//     final hasItemDiscounts = discountInfos.isNotEmpty;
//     final hasGlobalDiscount = globalDiscount > 0 && globalDiscountValue > 0;
//     final hasAnyDiscount = hasItemDiscounts || hasGlobalDiscount;
    
//     // Total de descontos de itens
//     final itemsDiscountTotal = discountInfos.fold<double>(0, (sum, d) => sum + d.discountValue);
//     final totalDiscountValue = itemsDiscountTotal + globalDiscountValue;

//     // Estilos
//     final titleStyle = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
//     final headerStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
//     final normalStyle = const pw.TextStyle(fontSize: 8);
//     final smallStyle = const pw.TextStyle(fontSize: 7);
//     final discountStyle = pw.TextStyle(fontSize: 7, color: PdfColors.green800);

//     pdf.addPage(
//       pw.Page(
//         pageFormat: config.pageFormat,
//         build: (context) {
//           return pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               // ========== CABEÇALHO - LOGO E EMPRESA ==========
//               if (companyData?.imageBytes != null)
//                 pw.Center(
//                   child: pw.Container(
//                     height: 50,
//                     child: pw.Image(
//                       pw.MemoryImage(companyData!.imageBytes!),
//                       fit: pw.BoxFit.contain,
//                     ),
//                   ),
//                 ),
//               if (companyData?.imageBytes != null)
//                 pw.SizedBox(height: 6),
              
//               pw.Center(
//                 child: pw.Text(companyName, style: titleStyle, textAlign: pw.TextAlign.center),
//               ),
//               pw.SizedBox(height: 8),
//               _buildDashedLine(),
//               pw.SizedBox(height: 6),

//               // ========== DADOS DA EMPRESA ==========
//               pw.Text(companyName, style: headerStyle),
//               pw.Text('Contribuinte: $companyVat', style: normalStyle),
//               pw.Text(companyAddress, style: normalStyle),
//               pw.Text('$companyZipCode $companyCity Portugal', style: normalStyle),
//               if (companyEmail != null && companyEmail.isNotEmpty)
//                 pw.Text(
//                   'E-mail: $companyEmail${companyPhone != null ? ', Tel: $companyPhone' : ''}',
//                   style: normalStyle,
//                 ),
//               if (companyEmail == null && companyPhone != null)
//                 pw.Text('Tel: $companyPhone', style: normalStyle),
              
//               pw.SizedBox(height: 10),

//               // ========== DADOS DO DOCUMENTO ==========
//               pw.Text('Original', style: normalStyle),
//               pw.Text('$documentTypeName ${document.number}', style: headerStyle),
//               if (config.terminalName != null)
//                 pw.Text('Terminal: ${config.terminalName}', style: normalStyle),
//               if (config.operatorName != null)
//                 pw.Text('Operador: ${config.operatorName}', style: normalStyle),
//               pw.Text('Data: ${document.formattedDateTime}', style: normalStyle),
              
//               pw.SizedBox(height: 8),

//               // ========== CLIENTE ==========
//               pw.Text(
//                 'Contribuinte: ${document.customerVat.isNotEmpty && document.customerVat != '999999990' ? document.customerVat : "Consumidor Final"}',
//                 style: normalStyle,
//               ),
//               if (document.customerName.isNotEmpty && document.customerVat != '999999990')
//                 pw.Text(document.customerName, style: normalStyle),
              
//               pw.SizedBox(height: 10),

//               // ========== ARTIGOS - CABEÇALHO ==========
//               pw.Text('Artigos', style: headerStyle),
//               pw.SizedBox(height: 2),
//               pw.Row(
//                 children: [
//                   pw.Expanded(flex: 4, child: pw.Text('', style: smallStyle)),
//                   pw.SizedBox(width: 30, child: pw.Text('Qtd.', style: smallStyle, textAlign: pw.TextAlign.right)),
//                   pw.SizedBox(width: 40, child: pw.Text('P.Unit.', style: smallStyle, textAlign: pw.TextAlign.right)),
//                   pw.SizedBox(width: 25, child: pw.Text('IVA', style: smallStyle, textAlign: pw.TextAlign.right)),
//                   pw.SizedBox(width: 45, child: pw.Text('Total', style: smallStyle, textAlign: pw.TextAlign.right)),
//                 ],
//               ),
//               _buildThinLine(),
//               pw.SizedBox(height: 4),

//               // ========== LISTA DE ARTIGOS (com descontos de linha) ==========
//               ...document.products.map((product) => _buildProductRow(product, discountStyle)),

//               _buildThinLine(),
//               pw.SizedBox(height: 6),

//               // ========== TOTAIS ==========
//               // Subtotal bruto (antes de descontos)
//               if (hasAnyDiscount)
//                 _buildSummaryRow('Subtotal', document.netValue + totalDiscountValue, normalStyle),
              
//               // Total de descontos (se existir)
//               if (hasAnyDiscount)
//                 _buildSummaryRowColored('Descontos', -totalDiscountValue, discountStyle),
              
//               // Total Ilíquido (sem IVA, após descontos)
//               _buildSummaryRow('Total Iliq.', document.netValue, normalStyle),
              
//               // Linhas de IVA por taxa
//               ...taxSummaries.map((tax) => _buildSummaryRow(
//                 tax.displayName,
//                 tax.taxValue,
//                 normalStyle,
//               )),
              
//               pw.SizedBox(height: 4),
              
//               // Total com IVA
//               _buildSummaryRow('Total', document.grossValue, headerStyle),
              
//               pw.SizedBox(height: 12),

//               // ========== IMPOSTOS ==========
//               pw.Text('Impostos', style: headerStyle),
//               pw.SizedBox(height: 2),
//               pw.Row(
//                 children: [
//                   pw.Expanded(flex: 3, child: pw.Text('', style: smallStyle)),
//                   pw.SizedBox(width: 35, child: pw.Text('Taxa', style: smallStyle, textAlign: pw.TextAlign.right)),
//                   pw.SizedBox(width: 45, child: pw.Text('Incidencia', style: smallStyle, textAlign: pw.TextAlign.right)),
//                   pw.SizedBox(width: 40, child: pw.Text('Valor', style: smallStyle, textAlign: pw.TextAlign.right)),
//                 ],
//               ),
//               _buildThinLine(),
//               ...taxSummaries.map((tax) => pw.Padding(
//                 padding: const pw.EdgeInsets.symmetric(vertical: 1),
//                 child: pw.Row(
//                   children: [
//                     pw.Expanded(flex: 3, child: pw.Text(tax.displayName, style: normalStyle)),
//                     pw.SizedBox(width: 35, child: pw.Text('${tax.rate.toStringAsFixed(2)}%', style: normalStyle, textAlign: pw.TextAlign.right)),
//                     pw.SizedBox(width: 45, child: pw.Text(_formatCurrency(tax.baseValue), style: normalStyle, textAlign: pw.TextAlign.right)),
//                     pw.SizedBox(width: 40, child: pw.Text(_formatCurrency(tax.taxValue), style: normalStyle, textAlign: pw.TextAlign.right)),
//                   ],
//                 ),
//               )),
              
//               pw.SizedBox(height: 12),

//               // ========== DESCONTOS APLICADOS (se existirem) ==========
//               if (hasAnyDiscount) ...[
//                 pw.Text('Descontos Aplicados', style: headerStyle),
//                 pw.SizedBox(height: 2),
//                 _buildThinLine(),
//                 pw.SizedBox(height: 4),
                
//                 // Descontos por item
//                 ...discountInfos.map((d) => pw.Padding(
//                   padding: const pw.EdgeInsets.symmetric(vertical: 1),
//                   child: pw.Row(
//                     children: [
//                       pw.Expanded(
//                         child: pw.Text(
//                           d.productName.length > 25 
//                               ? '${d.productName.substring(0, 25)}...' 
//                               : d.productName,
//                           style: smallStyle,
//                         ),
//                       ),
//                       pw.Text(
//                         '${d.discountPercent.toStringAsFixed(0)}%',
//                         style: smallStyle,
//                       ),
//                       pw.SizedBox(width: 10),
//                       pw.SizedBox(
//                         width: 50,
//                         child: pw.Text(
//                           '-${_formatCurrency(d.discountValue)}',
//                           style: discountStyle,
//                           textAlign: pw.TextAlign.right,
//                         ),
//                       ),
//                     ],
//                   ),
//                 )),
                
//                 // Desconto global
//                 if (hasGlobalDiscount)
//                   pw.Padding(
//                     padding: const pw.EdgeInsets.symmetric(vertical: 1),
//                     child: pw.Row(
//                       children: [
//                         pw.Expanded(
//                           child: pw.Text('Desconto Global', style: smallStyle),
//                         ),
//                         pw.Text(
//                           '${globalDiscount.toStringAsFixed(0)}%',
//                           style: smallStyle,
//                         ),
//                         pw.SizedBox(width: 10),
//                         pw.SizedBox(
//                           width: 50,
//                           child: pw.Text(
//                             '-${_formatCurrency(globalDiscountValue)}',
//                             style: discountStyle,
//                             textAlign: pw.TextAlign.right,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
                
//                 // Total de descontos
//                 pw.SizedBox(height: 4),
//                 _buildThinLine(),
//                 pw.Padding(
//                   padding: const pw.EdgeInsets.symmetric(vertical: 2),
//                   child: pw.Row(
//                     mainAxisAlignment: pw.MainAxisAlignment.end,
//                     children: [
//                       pw.Text('Total Descontos: ', style: headerStyle),
//                       pw.SizedBox(
//                         width: 60,
//                         child: pw.Text(
//                           '-${_formatCurrency(totalDiscountValue)}',
//                           style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
//                           textAlign: pw.TextAlign.right,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
                
//                 pw.SizedBox(height: 12),
//               ],

//               // ========== PAGAMENTOS ==========
//               pw.Text('Pagamentos', style: headerStyle),
//               pw.SizedBox(height: 2),
//               pw.Row(
//                 children: [
//                   pw.Expanded(child: pw.Text('', style: smallStyle)),
//                   pw.SizedBox(width: 50, child: pw.Text('Valor', style: smallStyle, textAlign: pw.TextAlign.right)),
//                 ],
//               ),
//               _buildThinLine(),
//               ...document.payments.map((payment) => pw.Padding(
//                 padding: const pw.EdgeInsets.symmetric(vertical: 2),
//                 child: pw.Row(
//                   children: [
//                     pw.Expanded(
//                       child: pw.Text(
//                         payment.paymentMethodName.isNotEmpty ? payment.paymentMethodName : 'Numerario',
//                         style: normalStyle,
//                       ),
//                     ),
//                     pw.SizedBox(
//                       width: 50,
//                       child: pw.Text(
//                         _formatCurrency(payment.value),
//                         style: normalStyle,
//                         textAlign: pw.TextAlign.right,
//                       ),
//                     ),
//                   ],
//                 ),
//               )),
              
//               pw.SizedBox(height: 8),
//               _buildDashedLine(),
//               pw.SizedBox(height: 6),

//               // ========== RESUMO ==========
//               pw.Text('Linhas de artigos: ${document.products.length}', style: normalStyle),
//               pw.Text(
//                 'Qtd. artigos: ${_formatQuantity(document.products.fold<double>(0, (sum, p) => sum + p.quantity))}',
//                 style: normalStyle,
//               ),
              
//               pw.SizedBox(height: 8),

//               // ========== TEXTO LEGAL ==========
//               pw.Text(
//                 'Os Artigos e/ou Servicos faturados foram colocados a disposicao do adquirente na data do documento.',
//                 style: smallStyle,
//               ),
              
//               pw.SizedBox(height: 8),

//               // ========== OBRIGADO ==========
//               pw.Center(child: pw.Text(config.footerText, style: normalStyle)),
              
//               pw.SizedBox(height: 12),

//               // ========== ATCUD ==========
//               if (document.atcud != null && document.atcud!.isNotEmpty)
//                 pw.Center(
//                   child: pw.Text('ATCUD: ${document.atcud}', style: smallStyle),
//                 ),
              
//               pw.SizedBox(height: 8),

//               // ========== QR CODE ==========
//               if (document.qrCode != null && document.qrCode!.isNotEmpty)
//                 pw.Center(
//                   child: pw.BarcodeWidget(
//                     barcode: pw.Barcode.qrCode(),
//                     data: document.qrCode!,
//                     width: 80,
//                     height: 80,
//                   ),
//                 )
//               else if (document.atcud != null && document.atcud!.isNotEmpty)
//                 pw.Center(
//                   child: pw.BarcodeWidget(
//                     barcode: pw.Barcode.qrCode(),
//                     data: _buildQrCodeData(document, companyVat),
//                     width: 80,
//                     height: 80,
//                   ),
//                 ),
              
//               pw.SizedBox(height: 12),

//               // ========== CERTIFICAÇÃO ==========
//               pw.Center(
//                 child: pw.Text(config.programCertification, style: smallStyle),
//               ),
//               pw.Center(
//                 child: pw.Text('Emitido por Moloni | moloni.pt', style: smallStyle),
//               ),
              
//               pw.SizedBox(height: 20),
//             ],
//           );
//         },
//       ),
//     );

//     final bytes = await pdf.save();
//     AppLogger.i('Talao gerado: ${bytes.length} bytes');
//     return bytes;
//   }

//   /// Calcula descontos dos produtos
//   List<DiscountInfo> _calculateDiscounts(List<DocumentProduct> products) {
//     final discounts = <DiscountInfo>[];
    
//     for (final product in products) {
//       if (product.discount > 0) {
//         // Calcular valor do desconto
//         final grossBeforeDiscount = product.unitPrice * product.quantity;
//         final discountValue = grossBeforeDiscount * (product.discount / 100);
        
//         discounts.add(DiscountInfo(
//           productName: product.name,
//           discountPercent: product.discount,
//           discountValue: discountValue,
//         ));
//       }
//     }
    
//     return discounts;
//   }

//   /// Calcula o resumo de impostos agrupados por taxa
//   List<TaxSummary> _calculateTaxSummaries(List<DocumentProduct> products) {
//     final Map<double, TaxSummary> summaries = {};
    
//     for (final product in products) {
//       if (product.taxes.isNotEmpty) {
//         for (final tax in product.taxes) {
//           final rate = tax.value;
//           if (!summaries.containsKey(rate)) {
//             summaries[rate] = TaxSummary(name: tax.name, rate: rate);
//           }
//           summaries[rate]!.baseValue += tax.incidenceValue;
//           summaries[rate]!.taxValue += tax.totalValue;
//         }
//       } else {
//         const defaultRate = 23.0;
//         if (!summaries.containsKey(defaultRate)) {
//           summaries[defaultRate] = TaxSummary(name: 'IVA Normal', rate: defaultRate);
//         }
//         final productNetValue = _roundToTwoDecimals(product.total / 1.23);
//         final productTaxValue = _roundToTwoDecimals(product.lineTotal - productNetValue);
//         summaries[defaultRate]!.baseValue += productNetValue;
//         summaries[defaultRate]!.taxValue += productTaxValue;
//       }
//     }
    
//     return summaries.values.toList()..sort((a, b) => a.rate.compareTo(b.rate));
//   }

//   /// Linha de produto (com desconto de linha se existir)
//   pw.Widget _buildProductRow(DocumentProduct product, pw.TextStyle discountStyle) {
//     final normalStyle = const pw.TextStyle(fontSize: 8);
//     final smallStyle = const pw.TextStyle(fontSize: 7);

//     final taxRate = product.taxes.isNotEmpty ? product.taxes.first.value : 23.0;
//     final unitPriceWithTax = product.unitPrice * (1 + taxRate / 100);
//     final hasDiscount = product.discount > 0;

//     return pw.Padding(
//       padding: const pw.EdgeInsets.only(bottom: 3),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           // Nome do produto
//           pw.Text(product.name, style: normalStyle),
//           // Detalhes: Qtd, Preço Unit (com IVA), IVA%, Total (com IVA)
//           pw.Row(
//             children: [
//               pw.Expanded(flex: 4, child: pw.SizedBox()),
//               pw.SizedBox(
//                 width: 30,
//                 child: pw.Text(_formatQuantity(product.quantity), style: smallStyle, textAlign: pw.TextAlign.right),
//               ),
//               pw.SizedBox(
//                 width: 40,
//                 child: pw.Text(_formatCurrency(unitPriceWithTax), style: smallStyle, textAlign: pw.TextAlign.right),
//               ),
//               pw.SizedBox(
//                 width: 25,
//                 child: pw.Text('${taxRate.toStringAsFixed(0)}%', style: smallStyle, textAlign: pw.TextAlign.right),
//               ),
//               pw.SizedBox(
//                 width: 45,
//                 child: pw.Text(_formatCurrency(product.lineTotal), style: smallStyle, textAlign: pw.TextAlign.right),
//               ),
//             ],
//           ),
//           // Linha de desconto (se existir)
//           if (hasDiscount)
//             pw.Padding(
//               padding: const pw.EdgeInsets.only(top: 1),
//               child: pw.Row(
//                 children: [
//                   pw.Expanded(
//                     child: pw.Text(
//                       '  Desc. ${product.discount.toStringAsFixed(0)}%',
//                       style: discountStyle,
//                     ),
//                   ),
//                   pw.SizedBox(
//                     width: 45,
//                     child: pw.Text(
//                       '-${_formatCurrency(product.unitPrice * product.quantity * product.discount / 100)}',
//                       style: discountStyle,
//                       textAlign: pw.TextAlign.right,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   /// Linha de resumo (label + valor)
//   pw.Widget _buildSummaryRow(String label, double value, pw.TextStyle style) {
//     return pw.Row(
//       mainAxisAlignment: pw.MainAxisAlignment.end,
//       children: [
//         pw.Text(label, style: style),
//         pw.SizedBox(width: 20),
//         pw.SizedBox(
//           width: 60,
//           child: pw.Text(_formatCurrency(value), style: style, textAlign: pw.TextAlign.right),
//         ),
//       ],
//     );
//   }

//   /// Linha de resumo colorida (para descontos)
//   pw.Widget _buildSummaryRowColored(String label, double value, pw.TextStyle style) {
//     return pw.Row(
//       mainAxisAlignment: pw.MainAxisAlignment.end,
//       children: [
//         pw.Text(label, style: style),
//         pw.SizedBox(width: 20),
//         pw.SizedBox(
//           width: 60,
//           child: pw.Text(_formatCurrency(value), style: style, textAlign: pw.TextAlign.right),
//         ),
//       ],
//     );
//   }

//   pw.Widget _buildDashedLine() {
//     return pw.Container(
//       height: 1,
//       child: pw.Row(
//         children: List.generate(
//           60,
//           (index) => pw.Expanded(
//             child: pw.Container(
//               height: 0.5,
//               color: index % 2 == 0 ? PdfColors.black : PdfColors.white,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   pw.Widget _buildThinLine() {
//     return pw.Container(height: 0.5, color: PdfColors.grey600);
//   }

//   String _formatCurrency(double value) {
//     return '${value.toStringAsFixed(2)} EUR';
//   }

//   String _formatQuantity(double qty) {
//     if (qty == qty.truncateToDouble()) return qty.toInt().toString();
//     return qty.toStringAsFixed(qty < 1 ? 3 : 2);
//   }

//   double _roundToTwoDecimals(double value) {
//     return (value * 100).round() / 100;
//   }

//   String _buildQrCodeData(Document document, String companyVat) {
//     final nifEmitente = companyVat.replaceAll(RegExp(r'[^0-9]'), '');
//     final nifCliente = document.customerVat.isNotEmpty && document.customerVat != '999999990'
//         ? document.customerVat.replaceAll(RegExp(r'[^0-9]'), '')
//         : '999999990';
    
//     final data = document.date;
//     final dataFormatada = '${data.year}${data.month.toString().padLeft(2, '0')}${data.day.toString().padLeft(2, '0')}';
    
//     final hash4 = document.rsaHash != null && document.rsaHash!.length >= 4
//         ? document.rsaHash!.substring(0, 4)
//         : '';
    
//     final parts = <String>[
//       'A:$nifEmitente',
//       'B:$nifCliente', 
//       'C:PT',
//       'D:FS',
//       'E:N',
//       'F:$dataFormatada',
//       'G:${document.number}',
//       'H:${document.atcud ?? ''}',
//       'I1:PT',
//       'I7:${document.netValue.toStringAsFixed(2)}',
//       'I8:${document.taxValue.toStringAsFixed(2)}',
//       'N:${document.taxValue.toStringAsFixed(2)}',
//       'O:${document.grossValue.toStringAsFixed(2)}',
//       'Q:$hash4',
//       'R:2860',
//     ];
    
//     if (document.payments.isNotEmpty) {
//       final paymentParts = document.payments.map((p) {
//         String metodo = 'OU';
//         final nome = p.paymentMethodName.toLowerCase();
//         if (nome.contains('numer') || nome.contains('dinheiro') || nome.contains('cash')) {
//           metodo = 'NU';
//         } else if (nome.contains('multibanco') || nome.contains('card') || nome.contains('cartao')) {
//           metodo = 'MB';
//         } else if (nome.contains('transfer')) {
//           metodo = 'TR';
//         } else if (nome.contains('cheque')) {
//           metodo = 'CH';
//         }
//         return '$metodo;${p.value.toStringAsFixed(2)}';
//       }).join(';');
//       parts.add('S:$paymentParts');
//     }
    
//     return parts.join('*');
//   }
// }
