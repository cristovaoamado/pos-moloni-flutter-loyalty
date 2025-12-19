import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/app_constants.dart';
import 'package:pos_moloni_app/core/theme/app_theme.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/auth/presentation/screens/login_screen.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';
import 'package:pos_moloni_app/features/company/presentation/screens/company_selection_screen.dart';
import 'package:pos_moloni_app/features/pos/presentation/screens/pos_screen.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  /// Flag que indica se a inicialização completa terminou
  bool _appReady = false;

  @override
  void initState() {
    super.initState();
    // Inicializar aplicação após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    AppLogger.i('🚀 Iniciando aplicação...');
    
    // 1. Tentar auto-login
    await ref.read(authProvider.notifier).initialize();
    
    // 2. Se autenticado, carregar empresa guardada
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      AppLogger.i('🏢 Carregando empresa guardada...');
      await ref.read(companyProvider.notifier).loadSelectedCompany();
    }
    
    // 3. Marcar app como pronta
    if (mounted) {
      setState(() {
        _appReady = true;
      });
      AppLogger.i('✅ Aplicação pronta');
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.i('🎨 Building MyApp (ready: $_appReady)');

    // Observar estados
    final authState = ref.watch(authProvider);
    final companyState = ref.watch(companyProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,

      // Navegação baseada em estado
      home: _buildHome(authState, companyState),

      // Builder para capturar contexto global (útil para SnackBars, Dialogs)
      builder: (context, child) {
        // Prevenir que o texto escale além do normal (acessibilidade)
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }

  Widget _buildHome(AuthState authState, CompanyState companyState) {
    // ═══════════════════════════════════════════════════════════════════
    // SPLASH: Mostrar enquanto inicializa (auto-login + carregar empresa)
    // ═══════════════════════════════════════════════════════════════════
    if (!_appReady) {
      return const _SplashScreen();
    }

    // ═══════════════════════════════════════════════════════════════════
    // LOGIN: Se não autenticado
    // ═══════════════════════════════════════════════════════════════════
    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    // ═══════════════════════════════════════════════════════════════════
    // POS: Se autenticado E tem empresa selecionada
    // ═══════════════════════════════════════════════════════════════════
    if (companyState.selectedCompany != null) {
      return const PosScreen();
    }

    // ═══════════════════════════════════════════════════════════════════
    // SELEÇÃO DE EMPRESA: Se autenticado mas sem empresa
    // ═══════════════════════════════════════════════════════════════════
    return const CompanySelectionScreen();
  }
}

/// Tela de splash (loading inicial) - COM LOGO
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ═══════════════════════════════════════════════════════════════
            // LOGO DA EMPRESA (em vez do ícone)
            // ═══════════════════════════════════════════════════════════════
            Image.asset(
              'assets/img/logo.png',
              height: 150,  // Tamanho grande para o splash
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback para ícone se o logo não carregar
                return Icon(
                  Icons.point_of_sale_rounded,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'POS Moloni',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'A carregar...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
