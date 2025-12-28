import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/document_sets/data/datasources/document_set_remote_datasource.dart';
import 'package:pos_moloni_app/features/document_sets/domain/entities/document_set.dart';

/// Estado das séries de documentos
class DocumentSetState {
  const DocumentSetState({
    this.documentSets = const [],
    this.documentTypeOptions = const [],
    this.selectedOption,
    this.isLoading = false,
    this.error,
  });

  final List<DocumentSet> documentSets;
  final List<DocumentTypeOption> documentTypeOptions;
  final DocumentTypeOption? selectedOption;
  final bool isLoading;
  final String? error;

  DocumentSetState copyWith({
    List<DocumentSet>? documentSets,
    List<DocumentTypeOption>? documentTypeOptions,
    DocumentTypeOption? selectedOption,
    bool? isLoading,
    String? error,
    bool clearSelectedOption = false,
  }) {
    return DocumentSetState(
      documentSets: documentSets ?? this.documentSets,
      documentTypeOptions: documentTypeOptions ?? this.documentTypeOptions,
      selectedOption: clearSelectedOption ? null : (selectedOption ?? this.selectedOption),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider do datasource
final documentSetDataSourceProvider = Provider<DocumentSetRemoteDataSource>((ref) {
  final dio = Dio();
  final secureStorage = ref.watch(secureStorageProvider);
  return DocumentSetRemoteDataSourceImpl(dio: dio, secureStorage: secureStorage);
});

/// Provider principal de séries de documentos
final documentSetProvider = StateNotifierProvider<DocumentSetNotifier, DocumentSetState>((ref) {
  final dataSource = ref.watch(documentSetDataSourceProvider);
  return DocumentSetNotifier(dataSource);
});

/// Notifier para gerir estado das séries de documentos
class DocumentSetNotifier extends StateNotifier<DocumentSetState> {
  DocumentSetNotifier(this._dataSource) : super(const DocumentSetState());

  final DocumentSetRemoteDataSource _dataSource;

  /// Tipos de documento suportados no POS
  static const List<DocumentTypeId> _supportedTypes = [
    DocumentTypeId.simplifiedInvoice,  // FS - Fatura Simplificada
    DocumentTypeId.invoice,            // FT - Fatura
    DocumentTypeId.invoiceReceipt,     // FR - Fatura-Recibo
  ];

  /// Carrega as séries de documentos
  Future<void> loadDocumentSets() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      AppLogger.i('📄 A carregar séries de documentos...');

      final sets = await _dataSource.getAll();

      AppLogger.i('✅ Carregadas ${sets.length} séries');

      if (sets.isEmpty) {
        AppLogger.w('⚠️ Nenhuma série de documentos encontrada');
        state = state.copyWith(
          documentSets: [],
          documentTypeOptions: [],
          isLoading: false,
        );
        return;
      }

      // Encontrar a série default ou a primeira série disponível
      DocumentSet? defaultSet;
      for (final docSet in sets) {
        if (docSet.isDefault) {
          defaultSet = docSet;
          break;
        }
      }
      defaultSet ??= sets.first;

      AppLogger.d('📄 Série default: "${defaultSet.name}" (ID: ${defaultSet.id})');

      // Criar opções para TODOS os tipos suportados em cada série
      final options = <DocumentTypeOption>[];

      // Primeiro adicionar opções da série default
      for (final docType in _supportedTypes) {
        final option = DocumentTypeOption(
          documentSet: defaultSet,
          documentType: docType,
        );
        options.add(option);
        AppLogger.d('   ✓ ${option.displayName}');
      }

      // Depois adicionar opções das outras séries
      for (final docSet in sets) {
        if (docSet.id == defaultSet.id) continue;

        AppLogger.d('📄 Série adicional: "${docSet.name}" (ID: ${docSet.id})');

        for (final docType in _supportedTypes) {
          final option = DocumentTypeOption(
            documentSet: docSet,
            documentType: docType,
          );
          options.add(option);
          AppLogger.d('   ✓ ${option.displayName}');
        }
      }

      // Ordenar: primeiro por tipo (FS, FT, FR), depois por nome da série
      options.sort((a, b) {
        final typeCompare = _supportedTypes.indexOf(a.documentType)
            .compareTo(_supportedTypes.indexOf(b.documentType));
        if (typeCompare != 0) return typeCompare;
        return a.documentSet.name.compareTo(b.documentSet.name);
      });

      // Selecionar Fatura Simplificada da série default por defeito
      final defaultOption = options.firstWhere(
        (o) => o.documentType == DocumentTypeId.simplifiedInvoice &&
               o.documentSet.id == defaultSet!.id,
        orElse: () => options.first,
      );

      AppLogger.i('📄 ${options.length} opções de documento criadas');
      AppLogger.i('📄 Opção pré-selecionada: ${defaultOption.displayName}');

      state = state.copyWith(
        documentSets: sets,
        documentTypeOptions: options,
        selectedOption: defaultOption,
        isLoading: false,
      );

    } catch (e) {
      AppLogger.e('❌ Erro ao carregar séries: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Seleciona uma opção de tipo de documento
  void selectOption(DocumentTypeOption option) {
    AppLogger.i('📄 Selecionado: ${option.displayName}');
    state = state.copyWith(selectedOption: option);
  }

  /// Obtém opções filtradas por tipo de documento
  List<DocumentTypeOption> getOptionsByType(DocumentTypeId type) {
    return state.documentTypeOptions
        .where((o) => o.documentType == type)
        .toList();
  }

  /// Obtém opções agrupadas por tipo de documento
  /// Retorna um Map onde a chave é o DocumentTypeId e o valor é a lista de opções
  Map<DocumentTypeId, List<DocumentTypeOption>> get groupedOptions {
    final grouped = <DocumentTypeId, List<DocumentTypeOption>>{};

    // Inicializar com listas vazias para todos os tipos suportados
    for (final type in _supportedTypes) {
      grouped[type] = <DocumentTypeOption>[];
    }

    // Preencher com as opções do state
    for (final option in state.documentTypeOptions) {
      if (grouped.containsKey(option.documentType)) {
        grouped[option.documentType]!.add(option);
      }
    }

    // Debug log
    AppLogger.d('📄 groupedOptions chamado:');
    for (final entry in grouped.entries) {
      AppLogger.d('   - ${entry.key.name}: ${entry.value.length} opções');
      for (final opt in entry.value) {
        AppLogger.d('      • ${opt.documentSet.name}');
      }
    }

    return grouped;
  }

  /// Limpa o estado
  void clear() {
    state = const DocumentSetState();
  }
}

/// Provider para a opção selecionada
final selectedDocumentOptionProvider = Provider<DocumentTypeOption?>((ref) {
  return ref.watch(documentSetProvider).selectedOption;
});

/// Provider para verificar se está a carregar
final isLoadingDocumentSetsProvider = Provider<bool>((ref) {
  return ref.watch(documentSetProvider).isLoading;
});
