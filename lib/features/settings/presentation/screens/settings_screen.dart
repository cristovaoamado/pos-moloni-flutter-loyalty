import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_moloni_app/core/constants/api_constants.dart';

import 'package:pos_moloni_app/core/constants/app_constants.dart';
import 'package:pos_moloni_app/core/utils/validators.dart';
import 'package:pos_moloni_app/features/settings/domain/entities/app_settings.dart';
import 'package:pos_moloni_app/features/settings/presentation/providers/settings_provider.dart';

/// Tela de Configurações
class SettingsScreen extends ConsumerStatefulWidget {

  const SettingsScreen({super.key, this.onSaved});
  final VoidCallback? onSaved;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _apiUrlController;
  late final TextEditingController _clientIdController;
  late final TextEditingController _clientSecretController;

  bool _obscureSecret = true;

  @override
  void initState() {
    super.initState();

    // Inicializar controllers com valores default ou salvos
    final settings = ref.read(settingsProvider).settings;
    final defaultSettings = ref.read(settingsProvider.notifier).getDefaultSettings();

    _apiUrlController = TextEditingController(
      text: settings?.apiUrl ?? defaultSettings.apiUrl,
    );
    _clientIdController = TextEditingController(
      text: settings?.clientId ?? defaultSettings.clientId,
    );
    _clientSecretController = TextEditingController(
      text: settings?.clientSecret ?? defaultSettings.clientSecret,
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    // Validar formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Criar objeto de configurações
    final settings = AppSettings(
      apiUrl: _apiUrlController.text.trim(),
      clientId: _clientIdController.text.trim(),
      clientSecret: _clientSecretController.text.trim(),
    );

    // Guardar
    final success = await ref.read(settingsProvider.notifier).saveSettings(settings);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Configurações guardadas!'),
          backgroundColor: Colors.green,
        ),
      );

      // Callback se fornecido
      widget.onSaved?.call();

      // Voltar para tela anterior
      Navigator.of(context).pop();
    } else {
      final error = ref.read(settingsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Erro ao guardar configurações'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final isSaving = settingsState.isSaving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          // Botão de guardar no AppBar
          TextButton.icon(
            onPressed: isSaving ? null : _handleSave,
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check, color: Colors.white),
            label: const Text(
              'Guardar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding * 2),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ícone e título
                Icon(
                  Icons.settings,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Configuração da API Moloni',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure as credenciais para aceder à API',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Campo API URL
                TextFormField(
                  controller: _apiUrlController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'URL da API',
                    hintText: ApiConstants.defaultMoloniApiUrl,
                    prefixIcon: const Icon(Icons.link),
                    helperText: 'URL base da API Moloni',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) => AppValidators.url(value, fieldName: 'URL da API'),
                ),
                const SizedBox(height: 20),

                // Campo Client ID
                TextFormField(
                  controller: _clientIdController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Client ID *',
                    hintText: 'Digite o Client ID',
                    prefixIcon: const Icon(Icons.vpn_key),
                    helperText: 'Fornecido pela Moloni',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => AppValidators.required(value, 'Client ID'),
                ),
                const SizedBox(height: 20),

                // Campo Client Secret
                TextFormField(
                  controller: _clientSecretController,
                  enabled: !isSaving,
                  obscureText: _obscureSecret,
                  decoration: InputDecoration(
                    labelText: 'Client Secret *',
                    hintText: 'Digite o Client Secret',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSecret ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureSecret = !_obscureSecret;
                        });
                      },
                    ),
                    helperText: 'Fornecido pela Moloni (mantenha em segredo)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => AppValidators.required(value, 'Client Secret'),
                ),
                const SizedBox(height: 32),

                // Aviso de segurança
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'As credenciais são guardadas de forma segura no dispositivo.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Botão Guardar
                ElevatedButton.icon(
                  onPressed: isSaving ? null : _handleSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(isSaving ? 'A guardar...' : 'Guardar Configurações'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Link para obter credenciais
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    // TO DO: Abrir link para documentação Moloni
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Aceda a https://www.moloni.pt para obter credenciais'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Como obter credenciais?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
