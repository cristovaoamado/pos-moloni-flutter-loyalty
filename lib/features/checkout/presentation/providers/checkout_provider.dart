import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pos_moloni_app/core/services/storage_service.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/checkout/data/datasources/document_remote_datasource.dart';
import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';
import 'package:pos_moloni_app/features/checkout/services/receipt_generator.dart';
import 'package:pos_moloni_app/features/customers/domain/entities/customer.dart';
import 'package:pos_moloni_app/features/document_sets/domain/entities/document_set.dart';

/// Estado do checkout
class CheckoutState {
  const CheckoutState({
    this.status = CheckoutStatus.idle,
    this.document,
    this.pdfBytes,
    this.pdfPath,
    this.paymentMethods = const [],
    this.error,
    this.lastEndpoint,
    this.documentTypeName,
    this.globalDiscount = 0,
    this.globalDiscountValue = 0,
  });

  final CheckoutStatus status;
  final Document? document;
  final Uint8List? pdfBytes;
  final String? pdfPath;
  final List<PaymentMethod> paymentMethods;
  final String? error;
  final String? lastEndpoint;
  final String? documentTypeName;
  final double globalDiscount;
  final double globalDiscountValue;

  bool get isLoading => status == CheckoutStatus.processing;
  bool get isSuccess => status == CheckoutStatus.success;
  bool get hasError => status == CheckoutStatus.error;
  bool get hasPdf => pdfBytes != null;

  CheckoutState copyWith({
    CheckoutStatus? status,
    Document? document,
    Uint8List? pdfBytes,
    String? pdfPath,
    List<PaymentMethod>? paymentMethods,
    String? error,
    String? lastEndpoint,
    String? documentTypeName,
    double? globalDiscount,
    double? globalDiscountValue,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      document: document ?? this.document,
      pdfBytes: pdfBytes ?? this.pdfBytes,
      pdfPath: pdfPath ?? this.pdfPath,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      error: error,
      lastEndpoint: lastEndpoint ?? this.lastEndpoint,
      documentTypeName: documentTypeName ?? this.documentTypeName,
      globalDiscount: globalDiscount ?? this.globalDiscount,
      globalDiscountValue: globalDiscountValue ?? this.globalDiscountValue,
    );
  }
}

/// Status do processo de checkout
enum CheckoutStatus {
  idle,
  processing,
  success,
  error,
  printing,
}

/// Provider do datasource
final documentDataSourceProvider = Provider<DocumentRemoteDataSource>((ref) {
  return DocumentRemoteDataSourceImpl(
    dio: Dio(),
    storage: PlatformStorage.instance,
  );
});

/// Provider principal de checkout
final checkoutProvider = StateNotifierProvider<CheckoutNotifier, CheckoutState>((ref) {
  final dataSource = ref.watch(documentDataSourceProvider);
  return CheckoutNotifier(dataSource);
});

/// Notifier para gerir o checkout
class CheckoutNotifier extends StateNotifier<CheckoutState> {
  CheckoutNotifier(this._dataSource) : super(const CheckoutState()) {
    loadPaymentMethods();
  }

  final DocumentRemoteDataSource _dataSource;

  /// Carrega métodos de pagamento
  Future<void> loadPaymentMethods() async {
    try {
      AppLogger.d('💳 A carregar métodos de pagamento...');
      final methods = await _dataSource.getPaymentMethods();
      state = state.copyWith(paymentMethods: methods);
      AppLogger.i('✅ ${methods.length} métodos de pagamento carregados');
    } catch (e) {
      AppLogger.e('Erro ao carregar métodos de pagamento', error: e);
      state = state.copyWith(paymentMethods: PaymentMethod.defaultMethods);
    }
  }

  /// Processa o checkout
  /// [globalDiscount] - Percentagem do desconto global (0-100)
  /// [globalDiscountValue] - Valor do desconto global em EUR
  Future<bool> processCheckout({
    required DocumentTypeOption documentTypeOption,
    required Customer customer,
    required List<CartItem> items,
    required List<PaymentInfo> payments,
    String? notes,
    double globalDiscount = 0,
    double globalDiscountValue = 0,
  }) async {
    AppLogger.i('🛒 Iniciando checkout...');
    AppLogger.d('   - Tipo: ${documentTypeOption.displayName}');
    AppLogger.d('   - Cliente: ${customer.name}');
    AppLogger.d('   - Items: ${items.length}');
    AppLogger.d('   - Pagamentos: ${payments.length}');
    AppLogger.d('   - Desconto Global: $globalDiscount% = $globalDiscountValue EUR');

    state = state.copyWith(
      status: CheckoutStatus.processing,
      error: null,
      document: null,
      pdfBytes: null,
      pdfPath: null,
      lastEndpoint: documentTypeOption.documentType.endpoint,
      documentTypeName: documentTypeOption.displayName,
      globalDiscount: globalDiscount,
      globalDiscountValue: globalDiscountValue,
    );

    try {
      // Criar documento (com desconto global)
      final request = CreateDocumentRequest(
        documentTypeOption: documentTypeOption,
        customer: customer,
        items: items,
        payments: payments,
        notes: notes,
        status: 1, // Fechado
        globalDiscount: globalDiscount, // Passa desconto global para a API Moloni
      );

      final document = await _dataSource.createDocument(request);

      AppLogger.i('✅ Documento criado: ${document.number}');

      state = state.copyWith(
        status: CheckoutStatus.success,
        document: document,
      );

      // Gerar talão POS localmente (valores de desconto vêm no Document)
      _generateReceipt(
        document, 
        documentTypeOption.displayName,
      );

      return true;
    } catch (e) {
      AppLogger.e('❌ Erro no checkout', error: e);
      
      state = state.copyWith(
        status: CheckoutStatus.error,
        error: e.toString(),
      );

      return false;
    }
  }

  /// Gera o talão POS localmente
  /// 
  /// NOTA: Os valores de desconto já vêm incluídos no Document (da API Moloni)
  Future<void> _generateReceipt(
    Document document, 
    String documentTypeName,
  ) async {
    try {
      AppLogger.d('A gerar talao POS...');
      AppLogger.d('   - Documento: ${document.number}');
      AppLogger.d('   - Desconto comercial: ${document.comercialDiscountValue} EUR');
      AppLogger.d('   - Desconto global: ${document.deductionPercentage}% = ${document.deductionValue} EUR');
      
      // Carregar dados da empresa
      final companyData = await CompanyReceiptData.fromStorage(PlatformStorage.instance);
      
      AppLogger.d('DEBUG - CompanyData carregado: ${companyData != null}');
      if (companyData != null) {
        AppLogger.d('DEBUG - Empresa: ${companyData.name}');
        AppLogger.d('DEBUG - ImageUrl: ${companyData.imageUrl}');
        AppLogger.d('DEBUG - ImageBytes: ${companyData.imageBytes?.length ?? 0} bytes');
      }
      
      // Criar gerador de talão (80mm por defeito)
      final generator = ReceiptGenerator(
        companyData: companyData,
        config: ReceiptConfig.paper80mm,
      );
      
      // Gerar PDF do talão (todos os valores vêm do Document da API Moloni)
      final pdfBytes = await generator.generateFromDocument(
        document: document,
        documentTypeName: documentTypeName,
      );
      
      // Guardar em ficheiro temporário
      final pdfPath = await (_dataSource as DocumentRemoteDataSourceImpl)
          .savePdfToTemp(pdfBytes, 'talao_${document.id}');

      state = state.copyWith(
        pdfBytes: pdfBytes,
        pdfPath: pdfPath,
      );

      AppLogger.i('Talao gerado: $pdfPath');
    } catch (e) {
      AppLogger.e('Erro ao gerar talao', error: e);
    }
  }

  /// Carrega o PDF do documento da API (fallback)
  Future<void> _loadPdf(int documentId, String endpoint) async {
    try {
      AppLogger.d('📄 A carregar PDF da API...');
      
      final pdfBytes = await _dataSource.getDocumentPdf(documentId, endpoint);
      
      final pdfPath = await (_dataSource as DocumentRemoteDataSourceImpl)
          .savePdfToTemp(pdfBytes, 'doc_$documentId');

      state = state.copyWith(
        pdfBytes: pdfBytes,
        pdfPath: pdfPath,
      );

      AppLogger.i('✅ PDF carregado: $pdfPath');
    } catch (e) {
      AppLogger.e('⚠️ Erro ao carregar PDF', error: e);
    }
  }

  /// Recarrega/regenera o talão
  Future<void> reloadPdf() async {
    if (state.document == null) return;
    
    final docTypeName = state.documentTypeName ?? 'Fatura Simplificada';
    await _generateReceipt(
      state.document!, 
      docTypeName,
    );
  }

  /// Tenta carregar o PDF A4 da API Moloni
  Future<void> loadA4Pdf() async {
    if (state.document == null) return;
    
    final endpoint = state.lastEndpoint ?? 'simplifiedInvoices';
    await _loadPdf(state.document!.id, endpoint);
  }

  /// Limpa o estado
  void reset() {
    state = CheckoutState(
      paymentMethods: state.paymentMethods, 
      lastEndpoint: null,
      documentTypeName: null,
      globalDiscount: 0,
      globalDiscountValue: 0,
    );
  }

  /// Actualiza métodos de pagamento
  Future<void> refreshPaymentMethods() async {
    await loadPaymentMethods();
  }
}

/// Provider para obter apenas os métodos de pagamento
final paymentMethodsProvider = Provider<List<PaymentMethod>>((ref) {
  return ref.watch(checkoutProvider).paymentMethods;
});
