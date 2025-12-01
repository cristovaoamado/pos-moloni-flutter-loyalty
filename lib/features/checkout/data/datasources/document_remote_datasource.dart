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
  });

  final DocumentTypeOption documentTypeOption;
  final Customer customer;
  final List<CartItem> items;
  final List<PaymentInfo> payments;
  final String? notes;
  final int status;
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
        
        // Resposta pode ser um Map com customer_id
        if (data is Map && data.containsKey('customer_id')) {
          final customerId = data['customer_id'] as int?;
          if (customerId != null && customerId > 0) {
            AppLogger.i('✅ Cliente encontrado: ID $customerId (NIF: $vat)');
            return customerId;
          }
        }
        
        // Resposta pode ser uma lista com um cliente
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
        
        // A API pode retornar o customer_id diretamente
        if (data is Map && data.containsKey('customer_id')) {
          final customerId = data['customer_id'] as int;
          AppLogger.i('✅ Consumidor Final criado com ID: $customerId');
          return customerId;
        }
        
        // Ou pode retornar como int
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
    // Primeiro tenta encontrar por NIF
    var customerId = await getCustomerIdByVat('999999990');
    
    // Se não encontrar por NIF, tenta por número/código
    if (customerId == null) {
      AppLogger.d('🔍 A tentar buscar por número 9999...');
      customerId = await getCustomerIdByNumber('9999');
    }
    
    // Se não encontrar, cria
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

      // Determinar endpoint baseado no tipo de documento
      final endpoint = request.documentTypeOption.documentType.endpoint;
      // IMPORTANTE: Adicionar json=true para enviar dados em JSON (muito mais simples!)
      final url = '$apiUrl/$endpoint/insert/?access_token=$accessToken&json=true&human_errors=true';

      // Data atual no formato YYYY-MM-DD (formato esperado pela API Moloni)
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      AppLogger.d('📅 Data do documento: $dateStr');

      // Obter customer_id correcto
      int? customerId = request.customer.id;
      
      // Se for consumidor final (id = 0), buscar ou criar o cliente
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

      // Construir body como JSON (estrutura nativa, muito mais limpa!)
      // Construir produtos
      final products = <Map<String, dynamic>>[];
      for (final item in request.items) {
        final productTaxes = <Map<String, dynamic>>[];
        for (final tax in item.product.taxes) {
          productTaxes.add({
            'tax_id': tax.id,
            'value': tax.value,
          });
        }
        products.add({
          'product_id': item.product.id,
          'name': item.product.name,
          'reference': item.product.reference,
          'qty': item.quantity,
          'price': double.parse(item.unitPrice.toStringAsFixed(4)),
          'discount': double.parse(item.discount.toStringAsFixed(2)),
          'taxes': productTaxes,
        });
      }

      // Construir pagamentos - NOTA: date é OBRIGATÓRIO no payments!
      // Formato datetime: YYYY-MM-DD HH:MM:SS
      final paymentDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      final payments = <Map<String, dynamic>>[];
      for (final payment in request.payments) {
        final paymentMap = <String, dynamic>{
          'payment_method_id': payment.methodId,
          'date': paymentDateStr,  // OBRIGATÓRIO!
          'value': double.parse(payment.value.toStringAsFixed(2)),
        };
        if (payment.notes != null && payment.notes!.isNotEmpty) {
          paymentMap['notes'] = payment.notes;
        }
        payments.add(paymentMap);
      }

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
      },);

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
        if (data is List) {
          // Se a lista contém strings, pode ser erro
          if (data.isNotEmpty && data.first is String) {
            // Erro da API - lista contém mensagens de erro
            final errorMsg = data.join(', ');
            AppLogger.e('❌ Erro da API: $errorMsg');
            throw ServerException('Erro da API: $errorMsg');
          }
          
          // Se a lista contém um Map com document_id
          if (data.isNotEmpty && data.first is Map) {
            final firstItem = data.first as Map;
            if (firstItem.containsKey('document_id')) {
              final documentId = firstItem['document_id'] as int;
              AppLogger.i('✅ Documento criado com ID (lista): $documentId');
              return await getDocument(documentId, endpoint);
            }
          }
          
          // Lista vazia ou formato desconhecido
          AppLogger.w('⚠️ Resposta inesperada (lista): $data');
          throw const ServerException('Resposta inválida do servidor');
        }
        
        // A API pode retornar apenas o document_id como int
        if (data is int) {
          final documentId = data;
          AppLogger.i('✅ Documento criado com ID (int): $documentId');
          return await getDocument(documentId, endpoint);
        }
        
        // A API retorna o document_id do documento criado
        if (data is Map && data.containsKey('document_id')) {
          final documentId = data['document_id'] as int;
          
          AppLogger.i('✅ Documento criado com ID: $documentId');
          
          // Obter documento completo
          return await getDocument(documentId, endpoint);
        }
        
        // Se a resposta já contém os dados completos (tem 'number' por exemplo)
        if (data is Map<String, dynamic> && data.containsKey('number')) {
          return DocumentModel.fromJson(data);
        }
        
        // Tentar converter qualquer Map para documento
        if (data is Map<String, dynamic>) {
          // Se tem document_id dentro de outro campo
          if (data.values.any((v) => v is int)) {
            for (var entry in data.entries) {
              if (entry.value is int && entry.key.contains('id')) {
                AppLogger.i('✅ Documento criado com ID (${entry.key}): ${entry.value}');
                return await getDocument(entry.value as int, endpoint);
              }
            }
          }
          return DocumentModel.fromJson(data);
        }

        AppLogger.w('⚠️ Resposta inesperada: $data');
        throw ServerException('Resposta inválida do servidor: ${data.runtimeType}');
      }

      if (response.data is Map && (response.data as Map).containsKey('error')) {
        throw ServerException(
          response.data['error_description'] ?? 'Erro desconhecido',
          response.statusCode.toString(),
        );
      }

      throw ServerException(
        'Erro ao criar documento',
        response.statusCode.toString(),
      );
    } on DioException catch (e) {
      AppLogger.e('Erro ao criar documento', error: e);
      AppLogger.d('📦 Response data: ${e.response?.data}');

      if (e.response?.statusCode == 401) {
        throw const TokenExpiredException();
      }

      final errorMsg = e.response?.data?['error_description'] ?? 
                       e.response?.data?.toString() ?? 
                       'Erro no servidor';
      throw ServerException(errorMsg, e.response?.statusCode.toString());
    } catch (e) {
      AppLogger.e('Erro inesperado ao criar documento', error: e);
      if (e is AppException) rethrow;
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

      final url = '$apiUrl/$endpoint/getOne/?access_token=$accessToken';

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
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        return DocumentModel.fromJson(response.data as Map<String, dynamic>);
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

      // Usar json=true para consistência
      final url = '$apiUrl/$endpoint/getPDFLink/?access_token=$accessToken&json=true';

      AppLogger.moloniApi('$endpoint/getPDFLink', data: {
        'company_id': companyId,
        'document_id': documentId,
      },);

      // Primeiro obter o link do PDF
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

        // Baixar o PDF
        final pdfResponse = await dio.get<List<int>>(
          pdfUrl,
          options: Options(responseType: ResponseType.bytes),
        );

        AppLogger.d('📄 PDF Response status: ${pdfResponse.statusCode}');
        AppLogger.d('📄 PDF Response headers: ${pdfResponse.headers.map}');

        if (pdfResponse.statusCode == 200 && pdfResponse.data != null) {
          final bytes = Uint8List.fromList(pdfResponse.data!);
          AppLogger.i('✅ PDF baixado: ${bytes.length} bytes');
          
          // Verificar se começa com %PDF (magic bytes do PDF)
          if (bytes.length > 4) {
            final header = String.fromCharCodes(bytes.sublist(0, 4));
            AppLogger.d('📄 PDF header: $header');
            if (!header.startsWith('%PDF')) {
              AppLogger.w('⚠️ Ficheiro não parece ser um PDF válido!');
              // Log dos primeiros bytes para debug
              AppLogger.d('📄 Primeiros 100 bytes: ${String.fromCharCodes(bytes.sublist(0, bytes.length > 100 ? 100 : bytes.length))}');
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
      AppLogger.d('Response: ${e.response?.data}');
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

        // Filtrar apenas Numerário e Multibanco
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
        
        // Se não encontrou nenhum, usar defaults
        if (filteredMethods.isEmpty) {
          return PaymentMethod.defaultMethods;
        }
        
        return filteredMethods;
      }

      // Retornar métodos padrão se a API falhar
      return PaymentMethod.defaultMethods;
    } catch (e) {
      AppLogger.e('Erro ao obter métodos de pagamento', error: e);
      // Retornar métodos padrão
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
