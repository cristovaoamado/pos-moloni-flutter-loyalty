import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_moloni_app/core/constants/api_constants.dart';
import 'package:pos_moloni_app/core/services/storage_service.dart';
import 'package:pos_moloni_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:pos_moloni_app/features/company/domain/entities/company.dart';
import 'package:pos_moloni_app/features/company/presentation/providers/company_provider.dart';

/// Ecrã de Configurações
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = PlatformStorage.instance;

  // Controllers
  final _apiUrlController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();

  // Estado
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showClientSecret = false;
  String? _savedUsername;
  String? _savedPassword;
  Company? _selectedCompany;
  List<Company> _availableCompanies = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // Carregar configurações da API
      final apiUrl = await _storage.read(key: ApiConstants.keyApiUrl);
      final clientId = await _storage.read(key: ApiConstants.keyClientId);
      final clientSecret = await _storage.read(key: ApiConstants.keyClientSecret);

      // Carregar credenciais de login guardadas
      final username = await _storage.read(key: 'moloni_username');
      final password = await _storage.read(key: 'moloni_password');

      // Carregar empresa selecionada
      final companyId = await _storage.read(key: ApiConstants.keyCompanyId);
      final companyName = await _storage.read(key: 'company_name');
      final companyVat = await _storage.read(key: 'company_vat');
      final companyEmail = await _storage.read(key: 'company_email');
      final companyAddress = await _storage.read(key: 'company_address');
      final companyCity = await _storage.read(key: 'company_city');
      final companyZipCode = await _storage.read(key: 'company_zip_code');

      if (mounted) {
        setState(() {
          _apiUrlController.text = apiUrl ?? ApiConstants.defaultMoloniApiUrl;
          _clientIdController.text = clientId ?? '';
          _clientSecretController.text = clientSecret ?? '';
          _savedUsername = username;
          _savedPassword = password;

          if (companyId != null && companyName != null) {
            _selectedCompany = Company(
              id: int.tryParse(companyId) ?? 0,
              name: companyName,
              vat: companyVat ?? '',
              email: companyEmail ?? '',
              address: companyAddress ?? '',
              city: companyCity ?? '',
              zipCode: companyZipCode ?? '',
            );
          }

          _isLoading = false;
        });
      }

      // Carregar lista de empresas disponíveis
      _loadCompanies();
    } catch (e) {
      debugPrint('Erro ao carregar configurações: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCompanies() async {
    final companyState = ref.read(companyProvider);
    if (companyState.companies.isNotEmpty) {
      setState(() {
        _availableCompanies = companyState.companies;
        // Atualizar empresa selecionada com dados completos
        if (_selectedCompany != null) {
          final found = _availableCompanies.firstWhere(
            (c) => c.id == _selectedCompany!.id,
            orElse: () => _selectedCompany!,
          );
          _selectedCompany = found;
        }
      });
    } else {
      // Tentar carregar empresas
      await ref.read(companyProvider.notifier).loadCompanies();
      final newState = ref.read(companyProvider);
      if (mounted && newState.companies.isNotEmpty) {
        setState(() {
          _availableCompanies = newState.companies;
        });
      }
    }
  }

  Future<void> _saveApiSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _storage.write(
        key: ApiConstants.keyApiUrl,
        value: _apiUrlController.text.trim(),
      );
      await _storage.write(
        key: ApiConstants.keyClientId,
        value: _clientIdController.text.trim(),
      );
      await _storage.write(
        key: ApiConstants.keyClientSecret,
        value: _clientSecretController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações da API guardadas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changeCompany() async {
    if (_availableCompanies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma empresa disponível')),
      );
      return;
    }

    final selected = await showDialog<Company>(
      context: context,
      builder: (context) => _CompanySelectionDialog(
        companies: _availableCompanies,
        currentCompany: _selectedCompany,
      ),
    );

    if (selected != null && selected.id != _selectedCompany?.id) {
      // Guardar nova empresa
      await _storage.write(
        key: ApiConstants.keyCompanyId,
        value: selected.id.toString(),
      );
      await _storage.write(key: 'company_name', value: selected.name);

      // Atualizar provider
      ref.read(companyProvider.notifier).selectCompany(selected);

      setState(() => _selectedCompany = selected);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Empresa alterada para: ${selected.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _clearLoginData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar dados de login?'),
        content: const Text(
          'As credenciais guardadas serão apagadas. '
          'Terá de fazer login novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storage.delete(key: 'moloni_username');
      await _storage.delete(key: 'moloni_password');

      setState(() {
        _savedUsername = null;
        _savedPassword = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados de login limpos')),
        );
      }
    }
  }

  Future<void> _resetAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repor tudo?'),
        content: const Text(
          'ATENÇÃO: Todas as configurações, dados de login e empresa '
          'serão apagados. A aplicação voltará ao estado inicial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Apagar Tudo'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storage.deleteAll();
      ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==================== SESSÃO ATUAL ====================
                    _buildSectionHeader('Sessão Atual', Icons.person),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              'Utilizador',
                              authState.user?.displayName ?? 'Não autenticado',
                              icon: Icons.account_circle,
                            ),
                            const Divider(),
                            _buildInfoRow(
                              'Estado',
                              authState.isAuthenticated ? 'Autenticado' : 'Não autenticado',
                              icon: authState.isAuthenticated
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              valueColor: authState.isAuthenticated
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================== EMPRESA ====================
                    _buildSectionHeader('Empresa', Icons.business),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              'Empresa selecionada',
                              _selectedCompany?.name ?? 'Nenhuma',
                              icon: Icons.store,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _changeCompany,
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('Alterar Empresa'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================== CREDENCIAIS GUARDADAS ====================
                    _buildSectionHeader('Credenciais Guardadas', Icons.key),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              'Username',
                              _savedUsername ?? 'Não guardado',
                              icon: Icons.person_outline,
                            ),
                            const Divider(),
                            _buildInfoRow(
                              'Password',
                              _savedPassword != null ? '••••••••' : 'Não guardada',
                              icon: Icons.lock_outline,
                            ),
                            if (_savedUsername != null || _savedPassword != null) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _clearLoginData,
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Limpar credenciais'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'As credenciais são usadas para login automático',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================== API MOLONI ====================
                    _buildSectionHeader('API Moloni', Icons.api),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _apiUrlController,
                              decoration: const InputDecoration(
                                labelText: 'URL da API',
                                hintText: 'https://api.moloni.pt/v1',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.link),
                              ),
                              validator: (v) =>
                                  v?.trim().isEmpty == true ? 'Obrigatório' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _clientIdController,
                              decoration: const InputDecoration(
                                labelText: 'Client ID',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.badge),
                              ),
                              validator: (v) =>
                                  v?.trim().isEmpty == true ? 'Obrigatório' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _clientSecretController,
                              obscureText: !_showClientSecret,
                              decoration: InputDecoration(
                                labelText: 'Client Secret',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.vpn_key),
                                suffixIcon: IconButton(
                                  icon: Icon(_showClientSecret
                                      ? Icons.visibility_off
                                      : Icons.visibility,),
                                  onPressed: () => setState(
                                      () => _showClientSecret = !_showClientSecret,),
                                ),
                              ),
                              validator: (v) =>
                                  v?.trim().isEmpty == true ? 'Obrigatório' : null,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveApiSettings,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(
                                    _isSaving ? 'A guardar...' : 'Guardar API',),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================== INFO ====================
                    _buildSectionHeader('Informações', Icons.info_outline),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              'Plataforma',
                              _getPlatformName(),
                              icon: Icons.devices,
                            ),
                            const Divider(),
                            _buildInfoRow(
                              'Versão',
                              '1.0.0',
                              icon: Icons.info,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================== AÇÕES ====================
                    ElevatedButton.icon(
                      onPressed: _resetAll,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Repor Configuração'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: valueColor ?? Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
        ),
      ],
    );
  }

  String _getPlatformName() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      default:
        return 'Desconhecido';
    }
  }
}

/// Diálogo de seleção de empresa
class _CompanySelectionDialog extends StatelessWidget {
  const _CompanySelectionDialog({
    required this.companies,
    this.currentCompany,
  });

  final List<Company> companies;
  final Company? currentCompany;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.business),
          SizedBox(width: 12),
          Text('Selecionar Empresa'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: companies.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final company = companies[index];
            final isSelected = company.id == currentCompany?.id;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.business,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              title: Text(
                company.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              selected: isSelected,
              onTap: () => Navigator.pop(context, company),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
