import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:pos_moloni_app/app.dart';
import 'package:pos_moloni_app/core/constants/app_constants.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/favorites/data/models/favorite_product_model.dart';
import 'package:pos_moloni_app/features/suspended_sales/data/suspended_sales_storage.dart';

void main() async {
  // Garantir inicialização do Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar logger
  AppLogger.i('🚀 Iniciando ${AppConstants.appName}...');

  try {
    // Configurar orientação da tela (forçar horizontal)
    if (AppConstants.forceHorizontal) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      AppLogger.d('Orientação: Horizontal (forçado)');
    }

    // Inicializar Hive (database local)
    await Hive.initFlutter();
    AppLogger.d('Hive inicializado');

    // ══════════════════════════════════════════════════════════════════════════
    // REGISTAR ADAPTADORES HIVE (ANTES de abrir qualquer box)
    // ══════════════════════════════════════════════════════════════════════════
    
    // Registar adapter de favoritos (typeId: 10)
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(FavoriteProductModelAdapter());
      AppLogger.d('⭐ Adapter FavoriteProductModel registado');
    }

    // Inicializar storage de vendas suspensas (regista os seus adaptadores)
    await SuspendedSalesStorage.initialize();
    AppLogger.d('Storage de vendas suspensas inicializado');

    // Configurar UI do sistema (status bar)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    AppLogger.i('✅ Inicialização completa');

    // Executar app com Riverpod
    runApp(
      const ProviderScope(
        child: MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    AppLogger.e('❌ Erro na inicialização', error: e, stackTrace: stackTrace);
    
    // Em caso de erro crítico, mostrar tela de erro
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Erro ao inicializar aplicação',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    e.toString(),
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Tentar reiniciar
                      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                    },
                    child: const Text('Fechar aplicação'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
