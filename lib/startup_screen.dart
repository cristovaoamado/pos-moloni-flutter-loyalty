import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/app_constants.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';

/// Ecrã de arranque que verifica autenticação
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({
    super.key,
    required this.onAuthenticated,
    required this.onUnauthenticated,
  });

  /// Callback quando autenticado com sucesso
  final VoidCallback onAuthenticated;

  /// Callback quando não autenticado (ir para login)
  final VoidCallback onUnauthenticated;

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  String _statusMessage = 'A iniciar...';
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _statusMessage = 'A verificar sessão...';
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Inicializar o auth provider (faz auto-login)
      await ref.read(authProvider.notifier).initialize();

      // Aguardar um momento para garantir que o estado foi atualizado
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      final authState = ref.read(authProvider);

      if (authState.isAuthenticated) {
        setState(() => _statusMessage = 'Sessão válida!');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) widget.onAuthenticated();
      } else {
        setState(() => _statusMessage = 'Sessão expirada');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) widget.onUnauthenticated();
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _statusMessage = 'Erro ao iniciar';
      });
    }
  }

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
              // Logo ou ícone
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
                  Icons.point_of_sale,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

              const SizedBox(height: 32),

              // Nome da app
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 48),

              // Indicador de progresso ou erro
              if (_hasError) ...[
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.shade100,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _errorMessage ?? 'Erro desconhecido',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _initialize,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onUnauthenticated,
                  child: const Text(
                    'Ir para Login',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ] else ...[
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Provider para controlar o estado de navegação inicial
enum AppStartupState {
  loading,
  authenticated,
  unauthenticated,
}

final appStartupStateProvider = StateProvider<AppStartupState>((ref) {
  return AppStartupState.loading;
});
