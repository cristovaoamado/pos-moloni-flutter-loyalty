import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/checkout/data/models/document_model.dart';
import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';
import 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';
import 'package:pos_moloni_app/features/document_sets/domain/entities/document_set.dart';

/// Request para criar documento
class CreateDocumentRequest {
  const CreateDocumentRequest({
    required this.documentTypeOption,
    required this.customer,
    required this.items,
    required this.payments,
    this.notes,
    this.status = 1, // 1 = Fechado
    this.globalDiscount = 0, // Desconto global em percentagem (0-100)
    this.specialDiscount = 0, // Desconto especial em valor monetário (€) - usado para pontos de fidelização
  });

  final DocumentTypeOption documentTypeOption;
  final Customer customer;
  final List<CartItem> items;
  final List<PaymentInfo> payments;
  final String? notes;
  final int status;
  /// Desconto global em percentagem (0-100)
  final double globalDiscount;
  /// Desconto especial em valor monetário (€) - usado para pontos de fidelização
  /// Este valor é deduzido directamente do total do documento
  final double specialDiscount;
}

/// Informação de pagamento
class PaymentInfo {
  const PaymentInfo({
    required this.methodId,
    required this.value,
    this.notes,
  });

  final int methodId;
  final double value;
  final String? notes;
}

/// Interface do datasource remoto de documentos
abstract class DocumentRemoteDataSource {
  /// Cria um novo documento
  Future<DocumentModel> createDocument(CreateDocumentRequest request);

  /// Obtém um documento pelo ID
  Future<DocumentModel> getDocument(int documentId, String endpoint);

  /// Obtém o PDF de um documento
  Future<Uint8List> getDocumentPdf(int documentId, String endpoint);

  /// Obtém os métodos de pagamento disponíveis
  Future<List<PaymentMethod>> getPaymentMethods();
}

/// Implementação usando Dio
class DocumentRemoteDataSourceImpl implements DocumentRemoteDataSource {
  DocumentRemoteDataSourceImpl({
    required this.dio,
    required this.storage,
  });

  final Dio dio;
  final FlutterSecureStorage storage;

  /// Busca cliente por NIF
  Future<int?> getCustomerIdByVat(String vat) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null || companyId == null) {
        return null;
      }

      final url = '$apiUrl/customers/getByVat/?access_token=$accessToken';

      AppLogger.moloniApi('customers/getByVat', data: {'vat': vat});

      final response = await dio.post(
        url,
        data: {
          'company_id': companyId,
          'vat': vat,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      AppLogger.d('📦 getByVat Response type: ${response.data.runtimeType}');
      AppLogger.d('📦 getByVat Response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data is Map && data.containsKey('customer_id')) {
          final customerId = data['customer_id'] as int?;
          if (customerId != null && customerId > 0) {
            AppLogger.i('✅ Cliente encontrado: ID $customerId (NIF: $vat)');
            return customerId;
          }
        }
        
        if (data is List && data.isNotEmpty && data.first is Map) {
          final customer = data.first as Map;
          final customerId = customer['customer_id'] as int?;
          if (customerId != null && customerId > 0) {
            AppLogger.i('✅ Cliente encontrado (lista): ID $customerId (NIF: $vat)');
            return customerId;
          }
        }
      }

      AppLogger.w('⚠️ Cliente não encontrado pelo NIF: $vat');
      return null;
    } catch (e) {
      AppLogger.w('⚠️ Erro ao buscar cliente pelo NIF: $vat', error: e);
      return null;
    }
  }

  /// Busca cliente por número (código)
  Future<int?> getCustomerIdByNumber(String number) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null || companyId == null) {
        return null;
      }

      final url = '$apiUrl/customers/getByNumber/?access_token=$accessToken';

      AppLogger.moloniApi('customers/getByNumber', data: {'number': number});

      final response = await dio.post(
        url,
        data: {
          'company_id': companyId,
          'number': number,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      AppLogger.d('📦 getByNumber Response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data is Map && data.containsKey('customer_id')) {
          final customerId = data['customer_id'] as int?;
          if (customerId != null && customerId > 0) {
            AppLogger.i('✅ Cliente encontrado por número: ID $customerId');
            return customerId;
          }
        }
      }

      return null;
    } catch (e) {
      AppLogger.w('⚠️ Erro ao buscar cliente pelo número: $number', error: e);
      return null;
    }
  }

  /// Cria cliente Consumidor Final
  Future<int?> createConsumidorFinal() async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null || companyId == null) {
        return null;
      }

      final url = '$apiUrl/customers/insert/?access_token=$accessToken';

      AppLogger.moloniApi('customers/insert', data: {'name': 'Consumidor Final'});

      final response = await dio.post(
        url,
        data: {
          'company_id': companyId,
          'vat': '999999990',
          'number': 'CF',
          'name': 'Consumidor Final',
          'language_id': '1',
          'country_id': '1',
          'maturity_date_id': '0',
          'payment_method_id': '0',
          'payment_day': '0',
          'discount': '0',
          'credit_limit': '0',
          'copies': '0',
          'salesman_id': '0',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      AppLogger.d('📦 createConsumidorFinal Response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data is Map && data.containsKey('customer_id')) {
          final customerId = data['customer_id'] as int;
          AppLogger.i('✅ Consumidor Final criado com ID: $customerId');
          return customerId;
        }
        
        if (data is int && data > 0) {
          AppLogger.i('✅ Consumidor Final criado com ID: $data');
          return data;
        }
      }

      return null;
    } catch (e) {
      AppLogger.e('❌ Erro ao criar Consumidor Final', error: e);
      return null;
    }
  }

  /// Obtém ou cria o cliente Consumidor Final
  Future<int?> getOrCreateConsumidorFinal() async {
    var customerId = await getCustomerIdByVat('999999990');
    
    if (customerId == null) {
      AppLogger.d('🔍 A tentar buscar por número 9999...');
      customerId = await getCustomerIdByNumber('9999');
    }
    
    if (customerId == null) {
      AppLogger.i('📝 A criar cliente Consumidor Final...');
      customerId = await createConsumidorFinal();
    }
    
    return customerId;
  }

  @override
  Future<DocumentModel> createDocument(CreateDocumentRequest request) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null) {
        throw const AuthenticationException('Token de acesso não encontrado');
      }

      if (companyId == null || companyId.isEmpty) {
        throw const AuthenticationException('Empresa não selecionada');
      }

      final endpoint = request.documentTypeOption.documentType.endpoint;
      
      // ==================== VALIDAÇÃO LIMITE FATURA SIMPLIFICADA ====================
      // Regra fiscal portuguesa: Faturas Simplificadas têm limite de:
      // - 100€ para empresas normais
      // - 1000€ para retalhistas/vendedores ambulantes
      // Usamos 1000€ assumindo que é um POS de retalho
      if (endpoint == 'simplifiedInvoices') {
        // Calcular total estimado dos produtos
        double totalEstimado = 0;
        for (final item in request.items) {
          final itemTotal = item.unitPrice * item.quantity * (1 - item.discount / 100);
          final taxRate = item.product.taxes.isNotEmpty ? item.product.taxes.first.value : 23.0;
          totalEstimado += itemTotal * (1 + taxRate / 100);
        }
        
        // Aplicar desconto global (percentagem) se existir
        if (request.globalDiscount > 0) {
          totalEstimado = totalEstimado * (1 - request.globalDiscount / 100);
        }
        
        // Aplicar desconto especial (valor em €) se existir - ex: pontos de fidelização
        if (request.specialDiscount > 0) {
          totalEstimado = totalEstimado - request.specialDiscount;
        }
        
        AppLogger.d('💰 Total estimado para Fatura Simplificada: ${totalEstimado.toStringAsFixed(2)} EUR');
        
        // Limite de 1000€ para Faturas Simplificadas (retalhistas/vendedores ambulantes)
        const limiteFS = 1000.0;
        if (totalEstimado > limiteFS) {
          throw ServerException(
            'Faturas Simplificadas têm limite de ${limiteFS.toStringAsFixed(0)}€. '
            'O total é ${totalEstimado.toStringAsFixed(2)}€. '
            'Use Fatura ou Fatura-Recibo para valores superiores.'
          );
        }
      }
      // ==============================================================================
      final url = '$apiUrl/$endpoint/insert/?access_token=$accessToken&json=true&human_errors=true';

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      AppLogger.d('📅 Data do documento: $dateStr');

      int? customerId = request.customer.id;
      
      if (customerId == 0 || request.customer.vat == '999999990') {
        AppLogger.d('🔍 A buscar/criar Consumidor Final...');
        final realCustomerId = await getOrCreateConsumidorFinal();
        if (realCustomerId != null) {
          customerId = realCustomerId;
          AppLogger.i('✅ Consumidor Final ID: $customerId');
        } else {
          throw const ServerException('Não foi possível obter/criar cliente Consumidor Final');
        }
      }

      // Construir produtos
      final products = <Map<String, dynamic>>[];
      for (final item in request.items) {
        final productTaxes = <Map<String, dynamic>>[];
        
        // Verificar se o produto tem IVA 0% (precisa de exemption_reason)
        bool hasZeroTax = false;
        String? exemptionReason;
        
        AppLogger.d('🔍 Analisando produto: ${item.product.name}');
        AppLogger.d('   - Número de taxes: ${item.product.taxes.length}');
        
        for (final tax in item.product.taxes) {
          AppLogger.d('   - Tax: id=${tax.id}, name="${tax.name}", value=${tax.value}');
          
          // Verificar se tax_id é válido (> 0)
          if (tax.id <= 0) {
            AppLogger.w('   ⚠️ tax_id INVÁLIDO: ${tax.id} - este produto pode falhar!');
            hasZeroTax = true; // Tratar como se não tivesse IVA
            exemptionReason ??= 'M07';
            continue; // Não adicionar tax inválida
          }
          
          // NOTA: Só enviar tax_id é suficiente para a maioria dos casos
          // O campo 'value' só é necessário quando o imposto é "definido por artigo"
          productTaxes.add({
            'tax_id': tax.id,
          });
          
          // Se IVA é 0%, marcar para adicionar exemption_reason
          // Usar comparação com tolerância para evitar problemas de floating point
          final taxValue = tax.value;
          if (taxValue == 0 || taxValue == 0.0 || taxValue.abs() < 0.001) {
            hasZeroTax = true;
            
            // Determinar o código de isenção baseado no nome do imposto
            // Usar null-safe e verificar se name não é vazio
            final taxName = tax.name;
            final taxNameLower = (taxName.isNotEmpty) ? taxName.toLowerCase() : '';
            
            AppLogger.d('   - IVA 0% detectado! taxName="$taxName", taxNameLower="$taxNameLower"');
            
            // Procurar código de isenção no nome do imposto
            if (taxNameLower.contains('m01')) {
              exemptionReason = 'M01';
            } else if (taxNameLower.contains('m02')) {
              exemptionReason = 'M02';
            } else if (taxNameLower.contains('m04')) {
              exemptionReason = 'M04';
            } else if (taxNameLower.contains('m05')) {
              exemptionReason = 'M05';
            } else if (taxNameLower.contains('m06')) {
              exemptionReason = 'M06';
            } else if (taxNameLower.contains('m07')) {
              exemptionReason = 'M07';
            } else if (taxNameLower.contains('m09')) {
              exemptionReason = 'M09';
            } else if (taxNameLower.contains('m10')) {
              exemptionReason = 'M10-1';
            } else if (taxNameLower.contains('m11')) {
              exemptionReason = 'M11';
            } else if (taxNameLower.contains('m12')) {
              exemptionReason = 'M12';
            } else if (taxNameLower.contains('m13')) {
              exemptionReason = 'M13';
            } else if (taxNameLower.contains('m14')) {
              exemptionReason = 'M14';
            } else if (taxNameLower.contains('m15')) {
              exemptionReason = 'M15';
            } else if (taxNameLower.contains('m16')) {
              exemptionReason = 'M16';
            } else if (taxNameLower.contains('m19')) {
              exemptionReason = 'M19';
            } else if (taxNameLower.contains('m20')) {
              exemptionReason = 'M20';
            } else if (taxNameLower.contains('m21')) {
              exemptionReason = 'M21';
            } else if (taxNameLower.contains('m25')) {
              exemptionReason = 'M25';
            } else if (taxNameLower.contains('m30')) {
              exemptionReason = 'M30';
            } else if (taxNameLower.contains('m31')) {
              exemptionReason = 'M31';
            } else if (taxNameLower.contains('m32')) {
              exemptionReason = 'M32';
            } else if (taxNameLower.contains('m33')) {
              exemptionReason = 'M33';
            } else if (taxNameLower.contains('m34')) {
              exemptionReason = 'M34';
            } else if (taxNameLower.contains('m40')) {
              exemptionReason = 'M40';
            } else if (taxNameLower.contains('m41')) {
              exemptionReason = 'M41';
            } else if (taxNameLower.contains('m42')) {
              exemptionReason = 'M42';
            } else if (taxNameLower.contains('m43')) {
              exemptionReason = 'M43';
            } else if (taxNameLower.contains('m44')) {
              exemptionReason = 'M44';
            } else if (taxNameLower.contains('m45')) {
              exemptionReason = 'M45';
            } else if (taxNameLower.contains('m46')) {
              exemptionReason = 'M46';
            } else if (taxNameLower.contains('m99')) {
              exemptionReason = 'M99';
            } else {
              // Código padrão para isenções genéricas
              // M07 = Isento artigo 9.º do CIVA (isenções nas operações internas)
              exemptionReason = 'M07';
              AppLogger.d('   - Usando código padrão M07');
            }
            
            AppLogger.d('   - exemption_reason determinado: $exemptionReason');
          }
        }
        
        // Se não tem impostos definidos, verificar se precisa de exemption_reason
        if (item.product.taxes.isEmpty) {
          hasZeroTax = true;
          exemptionReason = 'M07'; // Código padrão
          AppLogger.d('   - Produto sem impostos, usando exemption_reason padrão: M07');
        }
        
        // Se productTaxes ficou vazio (todos os tax_id eram inválidos), também precisa de exemption_reason
        if (productTaxes.isEmpty && item.product.taxes.isNotEmpty) {
          hasZeroTax = true;
          exemptionReason ??= 'M07';
          AppLogger.w('   ⚠️ productTaxes vazio após filtrar - todos os tax_id eram inválidos!');
        }
        
        // DEBUG: Log detalhado dos preços
        AppLogger.d('📦 Produto: ${item.product.name}');
        AppLogger.d('   - product.price (sem IVA): ${item.product.price}');
        AppLogger.d('   - product.priceWithTax: ${item.product.priceWithTax}');
        AppLogger.d('   - item.unitPrice: ${item.unitPrice}');
        AppLogger.d('   - item.customPrice: ${item.customPrice}');
        AppLogger.d('   - item.discount: ${item.discount}%');
        AppLogger.d('   - taxRate: ${item.taxRate}%');
        AppLogger.d('   - hasZeroTax: $hasZeroTax');
        AppLogger.d('   - exemptionReason: $exemptionReason');
        
        // Usar o preço SEM IVA (como a API Moloni espera)
        final priceToSend = double.parse(item.unitPrice.toStringAsFixed(4));
        AppLogger.d('   - priceToSend: $priceToSend');
        
        final productMap = <String, dynamic>{
          'product_id': item.product.id,
          'name': item.product.name,
          'reference': item.product.reference,
          'qty': item.quantity,
          'price': priceToSend,
          'discount': double.parse(item.discount.toStringAsFixed(2)),
          'taxes': productTaxes,
        };
        
        // Adicionar exemption_reason se IVA for 0%
        if (hasZeroTax && exemptionReason != null) {
          productMap['exemption_reason'] = exemptionReason;
          AppLogger.i('✅ exemption_reason ADICIONADO ao produto ${item.product.name}: $exemptionReason');
        }
        
        products.add(productMap);
      }

      // Construir pagamentos
      final paymentDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      final payments = <Map<String, dynamic>>[];
      for (final payment in request.payments) {
        final paymentMap = <String, dynamic>{
          'payment_method_id': payment.methodId,
          'date': paymentDateStr,
          'value': double.parse(payment.value.toStringAsFixed(2)),
        };
        if (payment.notes != null && payment.notes!.isNotEmpty) {
          paymentMap['notes'] = payment.notes;
        }
        payments.add(paymentMap);
      }

      // DEBUG: Log do DocumentTypeOption
      AppLogger.d('📋 DocumentTypeOption:');
      AppLogger.d('   - documentSet.id: ${request.documentTypeOption.documentSet.id}');
      AppLogger.d('   - documentSet.name: ${request.documentTypeOption.documentSet.name}');
      AppLogger.d('   - documentType.id: ${request.documentTypeOption.documentType.id}');
      AppLogger.d('   - documentType.code: ${request.documentTypeOption.documentType.code}');
      AppLogger.d('   - documentType.endpoint: ${request.documentTypeOption.documentType.endpoint}');

      final Map<String, dynamic> jsonBody = {
        'company_id': int.tryParse(companyId) ?? companyId,
        'document_set_id': request.documentTypeOption.documentSet.id,
        'customer_id': customerId,
        'date': dateStr,
        'expiration_date': dateStr,
        'status': request.status,
        'products': products,
        'payments': payments,
      };

      // ==================== DESCONTO GLOBAL ====================
      // Usar financial_discount para desconto global (percentagem 0-100)
      // NOTA: deduction/deduction_id é para outro tipo de dedução fiscal
      if (request.globalDiscount > 0) {
        jsonBody['financial_discount'] = double.parse(request.globalDiscount.toStringAsFixed(2));
        AppLogger.d('💰 Desconto global aplicado (financial_discount): ${request.globalDiscount}%');
      }
      
      // ==================== DESCONTO ESPECIAL (PONTOS FIDELIZAÇÃO) ====================
      // Usar special_discount para desconto em valor monetário (€)
      // Este campo é ideal para pontos de fidelização porque aceita valor em € directamente
      if (request.specialDiscount > 0) {
        jsonBody['special_discount'] = double.parse(request.specialDiscount.toStringAsFixed(2));
        AppLogger.d('💰 Desconto especial aplicado (special_discount): ${request.specialDiscount}€');
      }
      // ==========================================================

      // Adicionar notas se existirem
      if (request.notes != null && request.notes!.isNotEmpty) {
        jsonBody['notes'] = request.notes;
      }

      AppLogger.moloniApi('$endpoint/insert', data: {
        'company_id': companyId,
        'document_set_id': request.documentTypeOption.documentSet.id,
        'customer': request.customer.name,
        'products_count': request.items.length,
        'payments_count': request.payments.length,
        'global_discount': request.globalDiscount,
        'special_discount': request.specialDiscount,
      },);

      // Log detalhado de TODOS os produtos para debug
      AppLogger.i('📋 === PRODUTOS A ENVIAR PARA API ===');
      for (int i = 0; i < products.length; i++) {
        final p = products[i];
        AppLogger.i('   Produto $i: ${p['name']}');
        AppLogger.i('      - product_id: ${p['product_id']}');
        AppLogger.i('      - price: ${p['price']}');
        AppLogger.i('      - qty: ${p['qty']}');
        AppLogger.i('      - taxes: ${p['taxes']}');
        AppLogger.i('      - exemption_reason: ${p['exemption_reason'] ?? "NÃO DEFINIDO"}');
      }
      AppLogger.i('📋 === FIM PRODUTOS ===');

      AppLogger.d('📤 Request URL: $url');
      AppLogger.d('📅 date value in body: "${jsonBody['date']}"');
      AppLogger.d('📤 JSON BODY: $jsonBody');

      final response = await dio.post(
        url,
        data: jsonBody,
        options: Options(
          contentType: Headers.jsonContentType,
        ),
      );

      AppLogger.d('📦 Response status: ${response.statusCode}');
      AppLogger.d('📦 Response type: ${response.data.runtimeType}');
      AppLogger.d('📦 Response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // A API pode retornar uma lista de erros
        if (data is List && data.isNotEmpty) {
          final errors = data.map((e) => e.toString()).join(', ');
          AppLogger.e('❌ Erros da API Moloni: $errors');
          throw ServerException('Erros: $errors');
        }

        // A API retorna document_id em caso de sucesso
        if (data is Map && data.containsKey('document_id')) {
          final documentId = data['document_id'] as int;
          AppLogger.i('✅ Documento criado: ID $documentId');
          
          // Buscar documento completo com getOne
          return await getDocument(documentId, endpoint);
        }

        // Se data for um int, é o document_id directamente
        if (data is int && data > 0) {
          AppLogger.i('✅ Documento criado: ID $data');
          return await getDocument(data, endpoint);
        }
      }

      throw const ServerException('Erro ao criar documento: resposta inesperada');
    } on DioException catch (e) {
      AppLogger.e('❌ Erro Dio ao criar documento', error: e);
      AppLogger.d('Response: ${e.response?.data}');
      
      if (e.response?.statusCode == 401) {
        throw const TokenExpiredException();
      }
      
      // Tentar extrair mensagem de erro
      String errorMsg = 'Erro no servidor';
      if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        if (data.containsKey('error')) {
          errorMsg = data['error'].toString();
        } else if (data.containsKey('message')) {
          errorMsg = data['message'].toString();
        }
      } else if (e.response?.data is List) {
        errorMsg = (e.response!.data as List).join(', ');
      }
      
      throw ServerException(errorMsg, e.response?.statusCode.toString());
    } catch (e) {
      if (e is AppException) rethrow;
      AppLogger.e('❌ Erro ao criar documento', error: e);
      throw ServerException(e.toString());
    }
  }

  @override
  Future<DocumentModel> getDocument(int documentId, String endpoint) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null) {
        throw const AuthenticationException('Token de acesso não encontrado');
      }

      final url = '$apiUrl/$endpoint/getOne/?access_token=$accessToken&json=true';

      AppLogger.moloniApi('$endpoint/getOne', data: {
        'company_id': companyId,
        'document_id': documentId,
      },);

      final response = await dio.post(
        url,
        data: {
          'company_id': int.parse(companyId!),
          'document_id': documentId,
        },
        options: Options(
          contentType: Headers.jsonContentType,
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        
        AppLogger.d('📦 getOne response keys: ${data.keys.toList()}');
        
        if (data.containsKey('company')) {
          AppLogger.d('📦 Company data: ${data['company']}');
        }
        
        if (data.containsKey('entity')) {
          AppLogger.d('📦 Entity data: ${data['entity']}');
        }
        
        if (data.containsKey('products')) {
          final products = data['products'] as List?;
          AppLogger.d('📦 Products count: ${products?.length ?? 0}');
        }
        
        if (data.containsKey('payments')) {
          final payments = data['payments'] as List?;
          AppLogger.d('📦 Payments count: ${payments?.length ?? 0}');
        }
        
        // Log do desconto global se existir
        if (data.containsKey('deduction')) {
          AppLogger.d('💰 Deduction (desconto global): ${data['deduction']}');
        }
        
        // Log dos descontos financeiros
        if (data.containsKey('financial_discount')) {
          AppLogger.d('💰 Financial Discount: ${data['financial_discount']}%');
        }
        if (data.containsKey('financial_discount_value')) {
          AppLogger.d('💰 Financial Discount Value: ${data['financial_discount_value']}€');
        }
        if (data.containsKey('special_discount')) {
          AppLogger.d('💰 Special Discount (pontos): ${data['special_discount']}€');
        }
        
        return DocumentModel.fromJson(data);
      }

      throw const ServerException('Documento não encontrado');
    } on DioException catch (e) {
      AppLogger.e('Erro ao obter documento', error: e);
      if (e.response?.statusCode == 401) {
        throw const TokenExpiredException();
      }
      throw ServerException(
        e.response?.data?.toString() ?? 'Erro no servidor',
        e.response?.statusCode.toString(),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Uint8List> getDocumentPdf(int documentId, String endpoint) async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null) {
        throw const AuthenticationException('Token de acesso não encontrado');
      }

      final url = '$apiUrl/$endpoint/getPDFLink/?access_token=$accessToken&json=true';

      AppLogger.moloniApi('$endpoint/getPDFLink', data: {
        'company_id': companyId,
        'document_id': documentId,
      },);

      final linkResponse = await dio.post(
        url,
        data: {
          'company_id': int.parse(companyId!),
          'document_id': documentId,
        },
        options: Options(
          contentType: Headers.jsonContentType,
        ),
      );

      AppLogger.d('📄 getPDFLink response: ${linkResponse.data}');

      if (linkResponse.statusCode == 200 && linkResponse.data is Map) {
        final pdfUrl = linkResponse.data['url'] as String?;
        
        if (pdfUrl == null || pdfUrl.isEmpty) {
          AppLogger.e('❌ PDF URL vazio ou nulo');
          throw const ServerException('URL do PDF não disponível');
        }

        AppLogger.d('📄 PDF URL: $pdfUrl');

        final pdfResponse = await dio.get<List<int>>(
          pdfUrl,
          options: Options(responseType: ResponseType.bytes),
        );

        AppLogger.d('📄 PDF Response status: ${pdfResponse.statusCode}');

        if (pdfResponse.statusCode == 200 && pdfResponse.data != null) {
          final bytes = Uint8List.fromList(pdfResponse.data!);
          AppLogger.i('✅ PDF baixado: ${bytes.length} bytes');
          
          if (bytes.length > 4) {
            final header = String.fromCharCodes(bytes.sublist(0, 4));
            AppLogger.d('📄 PDF header: $header');
            if (!header.startsWith('%PDF')) {
              AppLogger.w('⚠️ Ficheiro não parece ser um PDF válido!');
            }
          }
          
          return bytes;
        }

        throw const ServerException('Erro ao baixar PDF');
      }

      AppLogger.e('❌ Resposta inesperada getPDFLink: ${linkResponse.data}');
      throw const ServerException('Erro ao obter link do PDF');
    } on DioException catch (e) {
      AppLogger.e('Erro ao obter PDF', error: e);
      throw ServerException(
        e.response?.data?.toString() ?? 'Erro ao obter PDF',
        e.response?.statusCode.toString(),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      final apiUrl = await storage.read(key: ApiConstants.keyApiUrl) ??
          ApiConstants.defaultMoloniApiUrl;
      final accessToken = await storage.read(key: ApiConstants.keyAccessToken);
      final companyId = await storage.read(key: ApiConstants.keyCompanyId);

      if (accessToken == null) {
        throw const AuthenticationException('Token de acesso não encontrado');
      }

      final url = '$apiUrl/paymentMethods/getAll/?access_token=$accessToken';

      AppLogger.moloniApi('paymentMethods/getAll');

      final response = await dio.post(
        url,
        data: {
          'company_id': int.parse(companyId!),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final allMethods = (response.data as List).map((json) {
          return PaymentMethod(
            id: json['payment_method_id'] as int? ?? 0,
            name: json['name'] as String? ?? '',
          );
        }).toList();

        final filteredMethods = allMethods.where((m) {
          final nameLower = m.name.toLowerCase();
          return nameLower.contains('numerário') || 
                 nameLower.contains('numerario') ||
                 nameLower.contains('dinheiro') ||
                 nameLower.contains('multibanco') ||
                 nameLower.contains('cartão') ||
                 nameLower.contains('cartao');
        }).toList();

        AppLogger.i('✅ ${filteredMethods.length} métodos de pagamento filtrados');
        
        if (filteredMethods.isEmpty) {
          return PaymentMethod.defaultMethods;
        }
        
        return filteredMethods;
      }

      return PaymentMethod.defaultMethods;
    } catch (e) {
      AppLogger.e('Erro ao obter métodos de pagamento', error: e);
      return PaymentMethod.defaultMethods;
    }
  }

  /// Guarda o PDF em ficheiro temporário e retorna o caminho
  Future<String> savePdfToTemp(Uint8List pdfBytes, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    AppLogger.d('📄 PDF guardado em: $filePath');
    return filePath;
  }
}
