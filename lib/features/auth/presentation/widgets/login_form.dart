import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/utils/validators.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';

/// Formulário de login
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Password sempre oculta (sem botão para mostrar)
  final bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // ═══════════════════════════════════════════════════════════════════
    // VALORES PRÉ-PREENCHIDOS
    // ═══════════════════════════════════════════════════════════════════
    _usernameController.text = 'madalena.ac@gmail.com';
    _passwordController.text = 'lojam2019';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Validar formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Esconder teclado
    FocusScope.of(context).unfocus();

    // Executar login (sempre guarda credenciais para auto-login)
    await ref.read(authProvider.notifier).login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      saveCredentials: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Campo Username
          TextFormField(
            controller: _usernameController,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: 'Utilizador',
              hintText: 'Digite seu utilizador',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) => AppValidators.required(value, 'Utilizador'),
            onFieldSubmitted: (_) {
              // Ao pressionar Enter, focar no próximo campo
              FocusScope.of(context).nextFocus();
            },
          ),
          const SizedBox(height: 16),

          // Campo Password - SEM botão para mostrar password
          TextFormField(
            controller: _passwordController,
            enabled: !isLoading,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Digite sua password',
              prefixIcon: const Icon(Icons.lock_outline),
              // SEM suffixIcon (botão de mostrar password removido)
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.done,
            validator: (value) => AppValidators.required(value, 'Password'),
            onFieldSubmitted: (_) {
              // Ao pressionar Enter, fazer login
              _handleLogin();
            },
          ),
          const SizedBox(height: 24),

          // Botão Login
          ElevatedButton(
            onPressed: isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Entrar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),

          // Mensagem de erro (se houver)
          if (authState.error != null && !isLoading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      authState.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
