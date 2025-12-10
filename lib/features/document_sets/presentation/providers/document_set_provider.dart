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
  }) {
    return DocumentSetState(
      documentSets: documentSets ?? this.documentSets,
      documentTypeOptions: documentTypeOptions ?? this.documentTypeOptions,
      selectedOption: selectedOption ?? this.selectedOption,
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
    DocumentTypeId.simplifiedInvoice,
    DocumentTypeId.invoice,
    DocumentTypeId.invoiceReceipt,
  ];

  /// Carrega as séries de documentos
  Future<void> loadDocumentSets() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      AppLogger.i('📄 A carregar séries de documentos...');

      final sets = await _dataSource.getAll();

      AppLogger.i('✅ Carregadas ${sets.length} séries');

      // Criar opções combinando séries com tipos de documento
      // IMPORTANTE: Criar opções para TODOS os tipos suportados em cada série
      // Isto permite usar qualquer tipo de documento disponível no POS
      final options = <DocumentTypeOption>[];
      
      // Encontrar a série default ou a primeira série disponível
      DocumentSet? defaultSet;
      for (final docSet in sets) {
        if (docSet.isDefault) {
          defaultSet = docSet;
          break;
        }
      }
      defaultSet ??= sets.isNotEmpty ? sets.first : null;
      
      if (defaultSet == null) {
        AppLogger.w('⚠️ Nenhuma série de documentos encontrada');
        state = state.copyWith(
          documentSets: sets,
          documentTypeOptions: [],
          isLoading: false,
        );
        return;
      }
      
      AppLogger.d('📄 Série default: "${defaultSet.name}" (ID: ${defaultSet.id})');
      
      // Criar opções para TODOS os tipos suportados usando a série default
      // Isto garante que o utilizador pode escolher FS, FT ou FR
      for (final docType in _supportedTypes) {
        options.add(DocumentTypeOption(
          documentSet: defaultSet,
          documentType: docType,
        ));
        AppLogger.d('   ✓ Adicionado: ${docType.name} - ${defaultSet.name}');
      }
      
      // Se há outras séries, adicionar também as suas opções
      for (final docSet in sets) {
        if (docSet.id == defaultSet.id) continue; // Já adicionámos
        
        AppLogger.d('📄 Série adicional: "${docSet.name}" (ID: ${docSet.id})');
        
        // Adicionar todos os tipos suportados para esta série também
        for (final docType in _supportedTypes) {
          options.add(DocumentTypeOption(
            documentSet: docSet,
            documentType: docType,
          ));
          AppLogger.d('   ✓ Adicionado: ${docType.name} - ${docSet.name}');
        }
      }

      // Ordenar: primeiro por tipo, depois por nome da série
      options.sort((a, b) {
        final typeCompare = _supportedTypes.indexOf(a.documentType)
            .compareTo(_supportedTypes.indexOf(b.documentType));
        if (typeCompare != 0) return typeCompare;
        return a.documentSet.name.compareTo(b.documentSet.name);
      });

      // Selecionar opção default (Fatura Simplificada da série default)
      DocumentTypeOption? defaultOption;
      if (options.isNotEmpty) {
        // Tentar encontrar Fatura Simplificada da série default
        defaultOption = options.firstWhere(
          (o) => o.documentType == DocumentTypeId.simplifiedInvoice && 
                 o.documentSet.id == defaultSet!.id,
          orElse: () => options.first,
        );
      }

      state = state.copyWith(
        documentSets: sets,
        documentTypeOptions: options,
        selectedOption: defaultOption,
        isLoading: false,
      );

      AppLogger.i('📄 ${options.length} opções de documento disponíveis');
      for (final opt in options) {
        AppLogger.d('   - ${opt.displayName} (set: ${opt.documentSet.id}, type: ${opt.documentType.id})');
      }
      if (defaultOption != null) {
        AppLogger.i('📄 Opção selecionada: ${defaultOption.displayName}');
      }
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
  Map<DocumentTypeId, List<DocumentTypeOption>> get groupedOptions {
    final grouped = <DocumentTypeId, List<DocumentTypeOption>>{};
    for (final type in _supportedTypes) {
      grouped[type] = getOptionsByType(type);
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
