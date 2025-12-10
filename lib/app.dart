import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/app_constants.dart';
import 'package:pos_moloni_app/core/theme/app_theme.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/auth/presentation/screens/login_screen.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_data_provider.dart';
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
    // Usar addPostFrameCallback para garantir que o widget esta montado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuth();
    });
  }

  Future<void> _initializeAuth() async {
    AppLogger.i('Iniciando verificacao de autenticacao...');
    
    // Inicializar autenticação (verifica token/credenciais guardadas)
    await ref.read(authProvider.notifier).initialize();
    
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.d('Building MyApp (initialized: $_initialized)');

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
                      color: Colors.black.withOpacity(0.2),
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
class _AuthenticatedFlow extends ConsumerStatefulWidget {
  const _AuthenticatedFlow();

  @override
  ConsumerState<_AuthenticatedFlow> createState() => _AuthenticatedFlowState();
}

class _AuthenticatedFlowState extends ConsumerState<_AuthenticatedFlow> {
  bool _initialized = false;
  bool _hasCompany = false;

  @override
  void initState() {
    super.initState();
    // Usar addPostFrameCallback para garantir que o widget esta montado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    AppLogger.d('A verificar empresa na storage...');
    
    // 1. Carregar empresa da storage
    await ref.read(companyProvider.notifier).loadSelectedCompany();
    
    // 2. Verificar se tem empresa
    final company = ref.read(companyProvider).selectedCompany;
    
    if (company != null) {
      AppLogger.i('Empresa encontrada: ${company.name}');
      
      // 3. Carregar dados da empresa
      await ref.read(companyDataProvider.notifier).loadCompanyData(company);
      
      if (mounted) {
        setState(() {
          _hasCompany = true;
          _initialized = true;
        });
      }
    } else {
      AppLogger.i('Nenhuma empresa seleccionada');
      if (mounted) {
        setState(() {
          _hasCompany = false;
          _initialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Aguardar inicializacao
    if (!_initialized) {
      return const _LoadingCompanyDataScreen();
    }

    // Se tem empresa, ir para POS
    if (_hasCompany) {
      return const PosScreen();
    }

    // Se nao tem empresa, mostrar seleccao
    return const CompanySelectionScreen();
  }
}

/// Tela de loading enquanto carrega dados da empresa
class _LoadingCompanyDataScreen extends StatelessWidget {
  const _LoadingCompanyDataScreen();

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
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.business,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
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
                'A carregar dados da empresa...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
