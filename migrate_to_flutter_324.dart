#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Script para converter código Flutter 3.27+ para Flutter 3.24 stable
/// 
/// Uso:
///   dart run migrate_to_flutter_324.dart
/// 
/// Ou com dry-run (apenas mostra o que seria alterado):
///   dart run migrate_to_flutter_324.dart --dry-run

import 'dart:io';

void main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║  Migração para Flutter 3.24 Stable                          ║');
  print('║  Converte APIs novas para versões compatíveis               ║');
  print('╚══════════════════════════════════════════════════════════════╝');
  print('');
  
  if (dryRun) {
    print('🔍 Modo DRY-RUN: apenas mostra alterações, não modifica ficheiros\n');
  }

  final libDir = Directory('lib');
  if (!await libDir.exists()) {
    print('❌ Erro: pasta "lib" não encontrada. Execute na raiz do projeto.');
    exit(1);
  }

  var totalFiles = 0;
  var totalChanges = 0;
  final changedFiles = <String>[];

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final result = await processFile(entity, dryRun);
      if (result > 0) {
        totalFiles++;
        totalChanges += result;
        changedFiles.add(entity.path);
      }
    }
  }

  print('');
  print('═══════════════════════════════════════════════════════════════');
  print('📊 Resumo:');
  print('   Ficheiros alterados: $totalFiles');
  print('   Total de substituições: $totalChanges');
  
  if (changedFiles.isNotEmpty) {
    print('');
    print('📁 Ficheiros modificados:');
    for (final file in changedFiles) {
      print('   • $file');
    }
  }
  
  if (dryRun && totalChanges > 0) {
    print('');
    print('💡 Execute sem --dry-run para aplicar as alterações.');
  }
  
  print('═══════════════════════════════════════════════════════════════');
}

Future<int> processFile(File file, bool dryRun) async {
  final content = await file.readAsString();
  var newContent = content;
  var changes = 0;

  // ============================================
  // 1. withValues(alpha: X) → withOpacity(X)
  // ============================================
  // Padrão: .withValues(alpha: 0.5) ou .withValues(alpha: 0.5,)
  final withValuesRegex = RegExp(
    r'\.withValues\s*\(\s*alpha\s*:\s*([0-9.]+)\s*,?\s*\)',
    multiLine: true,
  );
  
  newContent = newContent.replaceAllMapped(withValuesRegex, (match) {
    changes++;
    final alphaValue = match.group(1);
    return '.withOpacity($alphaValue)';
  });

  // ============================================
  // 2. CardThemeData → CardTheme (Flutter 3.27+ usa CardThemeData)
  // NOTA: Em Flutter 3.24, CardTheme é o correto
  // ============================================
  // NÃO FAZER - CardTheme está correto em 3.24

  // ============================================
  // 3. DialogThemeData → DialogTheme (Flutter 3.27+ usa DialogThemeData)
  // NOTA: Em Flutter 3.24, DialogTheme é o correto
  // ============================================
  // NÃO FAZER - DialogTheme está correto em 3.24

  // ============================================
  // 4. AppBarThemeData → AppBarTheme (se existir)
  // ============================================
  // NÃO FAZER - AppBarTheme está correto em 3.24

  // ============================================
  // 5. IconThemeData (este já existe, não mudar)
  // ============================================
  // IconThemeData é válido em ambas as versões

  // ============================================
  // 6-8. ButtonTheme - NÃO SUBSTITUIR
  // Em Flutter 3.24, usa-se:
  //   - ElevatedButtonThemeData
  //   - TextButtonThemeData  
  //   - OutlinedButtonThemeData
  // ============================================
  
  // CORRIGIR: Se o script anterior removeu "Data", restaurar
  if (newContent.contains('elevatedButtonTheme: ElevatedButtonTheme(')) {
    newContent = newContent.replaceAll(
      'elevatedButtonTheme: ElevatedButtonTheme(',
      'elevatedButtonTheme: ElevatedButtonThemeData(',
    );
    changes++;
  }
  
  if (newContent.contains('outlinedButtonTheme: OutlinedButtonTheme(')) {
    newContent = newContent.replaceAll(
      'outlinedButtonTheme: OutlinedButtonTheme(',
      'outlinedButtonTheme: OutlinedButtonThemeData(',
    );
    changes++;
  }
  
  if (newContent.contains('textButtonTheme: TextButtonTheme(')) {
    newContent = newContent.replaceAll(
      'textButtonTheme: TextButtonTheme(',
      'textButtonTheme: TextButtonThemeData(',
    );
    changes++;
  }

  // ============================================
  // 10. Outros padrões withValues com múltiplos parâmetros
  // ============================================
  // Padrão: .withValues(alpha: X, red: Y, ...) - mais complexo
  // Converter para .withOpacity(X) se só tem alpha
  final withValuesComplexRegex = RegExp(
    r'\.withValues\s*\(\s*alpha\s*:\s*([0-9.]+)\s*\)',
    multiLine: true,
  );
  
  newContent = newContent.replaceAllMapped(withValuesComplexRegex, (match) {
    // Já foi tratado acima, mas por segurança
    return '.withOpacity(${match.group(1)})';
  });

  // Guardar se houve alterações
  if (changes > 0 && newContent != content) {
    if (!dryRun) {
      await file.writeAsString(newContent);
      print('✅ ${file.path} ($changes alterações)');
    } else {
      print('📝 ${file.path} ($changes alterações pendentes)');
      
      // Mostrar preview das alterações
      _showDiff(content, newContent, file.path);
    }
    return changes;
  }

  return 0;
}

void _showDiff(String oldContent, String newContent, String filePath) {
  final oldLines = oldContent.split('\n');
  final newLines = newContent.split('\n');
  
  var diffCount = 0;
  const maxDiffs = 5; // Mostrar no máximo 5 diferenças por ficheiro
  
  for (var i = 0; i < oldLines.length && i < newLines.length; i++) {
    if (oldLines[i] != newLines[i] && diffCount < maxDiffs) {
      print('   Linha ${i + 1}:');
      print('   - ${oldLines[i].trim()}');
      print('   + ${newLines[i].trim()}');
      print('');
      diffCount++;
    }
  }
  
  if (diffCount >= maxDiffs) {
    print('   ... (mais alterações não mostradas)');
    print('');
  }
}
