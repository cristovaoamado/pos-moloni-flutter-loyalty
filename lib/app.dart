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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuth();
    });
  }

  Future<void> _initializeAuth() async {
    AppLogger.i('🚀 Iniciando verificação de autenticação...');

    // Inicializar autenticação (verifica token/credenciais guardadas)
    await ref.read(authProvider.notifier).initialize();

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.d('🎨 Building MyApp (initialized: $_initialized)');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      home: _buildHome(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }

  Widget _buildHome() {
    // Se ainda não inicializou, mostrar splash
    if (!_initialized) {
      return const _SplashScreen();
    }

    // Observar estado de autenticação
    final authState = ref.watch(authProvider);

    // Se está a carregar (após inicialização), mostrar splash
    if (authState.isLoading) {
      return const _SplashScreen();
    }

    // Se autenticado, verificar empresa
    if (authState.isAuthenticated) {
      return const _AuthenticatedFlow();
    }

    // Se não autenticado, mostrar login
    return const LoginScreen();
  }
}

/// Tela de splash (loading inicial)
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.point_of_sale_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'A verificar sessão...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fluxo quando autenticado (verifica empresa)
class _AuthenticatedFlow extends ConsumerWidget {
  const _AuthenticatedFlow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyState = ref.watch(companyProvider);
    final hasSelectedCompany = companyState.selectedCompany != null;

    // Se já tem empresa selecionada, ir para POS
    if (hasSelectedCompany) {
      return const PosScreen();
    }

    // Se não tem empresa, mostrar seleção
    return const CompanySelectionScreen();
  }
}
