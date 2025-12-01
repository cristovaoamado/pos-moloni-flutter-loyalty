import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/services/storage_service.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/cart/domain/entities/cart_item.dart';
import 'package:pos_moloni_app/features/checkout/data/datasources/document_remote_datasource.dart';
import 'package:pos_moloni_app/features/checkout/domain/entities/document.dart';
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
  });

  final CheckoutStatus status;
  final Document? document;
  final Uint8List? pdfBytes;
  final String? pdfPath;
  final List<PaymentMethod> paymentMethods;
  final String? error;
  final String? lastEndpoint;

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
  }) {
    return CheckoutState(
      status: status ?? this.status,
      document: document ?? this.document,
      pdfBytes: pdfBytes ?? this.pdfBytes,
      pdfPath: pdfPath ?? this.pdfPath,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      error: error,
      lastEndpoint: lastEndpoint ?? this.lastEndpoint,
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
    _loadPaymentMethods();
  }

  final DocumentRemoteDataSource _dataSource;

  /// Carrega métodos de pagamento
  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await _dataSource.getPaymentMethods();
      state = state.copyWith(paymentMethods: methods);
    } catch (e) {
      AppLogger.e('Erro ao carregar métodos de pagamento', error: e);
      // Usar métodos padrão
      state = state.copyWith(paymentMethods: PaymentMethod.defaultMethods);
    }
  }

  /// Processa o checkout
  Future<bool> processCheckout({
    required DocumentTypeOption documentTypeOption,
    required Customer customer,
    required List<CartItem> items,
    required List<PaymentInfo> payments,
    String? notes,
  }) async {
    AppLogger.i('🛒 Iniciando checkout...');
    AppLogger.d('   - Tipo: ${documentTypeOption.displayName}');
    AppLogger.d('   - Cliente: ${customer.name}');
    AppLogger.d('   - Items: ${items.length}');
    AppLogger.d('   - Pagamentos: ${payments.length}');

    state = state.copyWith(
      status: CheckoutStatus.processing,
      error: null,
      document: null,
      pdfBytes: null,
      pdfPath: null,
      lastEndpoint: documentTypeOption.documentType.endpoint,
    );

    try {
      // Criar documento
      final request = CreateDocumentRequest(
        documentTypeOption: documentTypeOption,
        customer: customer,
        items: items,
        payments: payments,
        notes: notes,
        status: 1, // Fechado
      );

      final document = await _dataSource.createDocument(request);

      AppLogger.i('✅ Documento criado: ${document.number}');

      state = state.copyWith(
        status: CheckoutStatus.success,
        document: document,
      );

      // Tentar obter PDF em background
      _loadPdf(document.id, documentTypeOption.documentType.endpoint);

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

  /// Carrega o PDF do documento
  Future<void> _loadPdf(int documentId, String endpoint) async {
    try {
      AppLogger.d('📄 A carregar PDF...');
      
      final pdfBytes = await _dataSource.getDocumentPdf(documentId, endpoint);
      
      // Guardar em ficheiro temporário
      final pdfPath = await (_dataSource as DocumentRemoteDataSourceImpl)
          .savePdfToTemp(pdfBytes, 'doc_$documentId');

      state = state.copyWith(
        pdfBytes: pdfBytes,
        pdfPath: pdfPath,
      );

      AppLogger.i('✅ PDF carregado: $pdfPath');
    } catch (e) {
      AppLogger.e('⚠️ Erro ao carregar PDF', error: e);
      // Não falhar o checkout se o PDF falhar
    }
  }

  /// Recarrega o PDF
  Future<void> reloadPdf() async {
    if (state.document == null) return;
    
    final endpoint = state.lastEndpoint ?? 'simplifiedInvoices';
    await _loadPdf(state.document!.id, endpoint);
  }

  /// Limpa o estado
  void reset() {
    state = CheckoutState(paymentMethods: state.paymentMethods, lastEndpoint: null);
  }

  /// Actualiza métodos de pagamento
  Future<void> refreshPaymentMethods() async {
    await _loadPaymentMethods();
  }
}

/// Provider para obter apenas os métodos de pagamento
final paymentMethodsProvider = Provider<List<PaymentMethod>>((ref) {
  return ref.watch(checkoutProvider).paymentMethods;
});
