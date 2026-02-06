import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/loyalty_provider.dart';

/// Widget de configurações da fidelização para o settings_screen
class LoyaltySettingsWidget extends ConsumerStatefulWidget {
  const LoyaltySettingsWidget({super.key});

  @override
  ConsumerState<LoyaltySettingsWidget> createState() => _LoyaltySettingsWidgetState();
}

class _LoyaltySettingsWidgetState extends ConsumerState<LoyaltySettingsWidget> {
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _cardPrefixController = TextEditingController();
  bool _isTesting = false;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final state = ref.read(loyaltyProvider);
    _apiUrlController.text = state.apiUrl;
    _apiKeyController.text = state.apiKey;
    _cardPrefixController.text = state.cardPrefix;
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _cardPrefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loyaltyState = ref.watch(loyaltyProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.loyalty, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Sistema de Fidelização',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildConnectionStatus(loyaltyState),
              ],
            ),
            
            const Divider(height: 24),

            // Switch activar/desactivar
            SwitchListTile(
              title: const Text('Activar fidelização'),
              subtitle: const Text('Permite identificar clientes e acumular pontos'),
              value: loyaltyState.isEnabled,
              onChanged: (value) {
                ref.read(loyaltyProvider.notifier).setEnabled(value);
              },
            ),

            if (loyaltyState.isEnabled) ...[
              const SizedBox(height: 16),

              // URL da API
              TextField(
                controller: _apiUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL da API Loyalty',
                  hintText: 'http://localhost:5000/api',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                  helperText: 'Endereço do servidor de fidelização',
                ),
                onChanged: (value) {
                  ref.read(loyaltyProvider.notifier).setApiUrl(value);
                },
              ),

              const SizedBox(height: 16),

              // API Key
              TextField(
                controller: _apiKeyController,
                obscureText: !_showApiKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'pk_xxxxxxxxxxxxxxxx',
                  prefixIcon: const Icon(Icons.key),
                  border: const OutlineInputBorder(),
                  helperText: 'Chave de autenticação do POS',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() => _showApiKey = !_showApiKey);
                        },
                        tooltip: _showApiKey ? 'Esconder' : 'Mostrar',
                      ),
                      if (_apiKeyController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            // Copiar para clipboard
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('API Key copiada'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          tooltip: 'Copiar',
                        ),
                    ],
                  ),
                ),
                onChanged: (value) {
                  ref.read(loyaltyProvider.notifier).setApiKey(value);
                },
              ),

              const SizedBox(height: 16),

              // Prefixo dos cartões
              TextField(
                controller: _cardPrefixController,
                decoration: const InputDecoration(
                  labelText: 'Prefixo dos cartões',
                  hintText: '269',
                  prefixIcon: Icon(Icons.credit_card),
                  border: OutlineInputBorder(),
                  helperText: 'Prefixo para identificar cartões de fidelização',
                ),
                onChanged: (value) {
                  ref.read(loyaltyProvider.notifier).setCardPrefix(value);
                },
              ),

              const SizedBox(height: 16),

              // Botão testar
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(_isTesting ? 'A testar...' : 'Testar ligação'),
                  onPressed: _isTesting ? null : _testConnection,
                ),
              ),

              // Erro
              if (loyaltyState.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loyaltyState.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Como funciona',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Passe o cartão de fidelização no leitor\n'
                      '• O cliente será identificado automaticamente\n'
                      '• No checkout, pode usar pontos como desconto\n'
                      '• Os pontos são acumulados após finalizar a venda',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.vpn_key, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'API Key',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• A API Key é gerada no dashboard de fidelização\n'
                      '• Menu: Configurações → API Keys → Criar nova\n'
                      '• Copie a chave e cole no campo acima',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(LoyaltyState state) {
    if (!state.isEnabled) {
      return const Chip(
        label: Text('Desactivado'),
        backgroundColor: Colors.grey,
        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
      );
    }

    if (state.isLoading) {
      return const Chip(
        avatar: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text('A verificar...'),
      );
    }

    if (state.isConnected) {
      return const Chip(
        avatar: Icon(Icons.check_circle, color: Colors.white, size: 18),
        label: Text('Ligado'),
        backgroundColor: Colors.green,
        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
      );
    }

    // Verificar se tem API Key configurada
    if (state.apiKey.isEmpty) {
      return const Chip(
        avatar: Icon(Icons.key_off, color: Colors.white, size: 18),
        label: Text('Sem API Key'),
        backgroundColor: Colors.orange,
        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
      );
    }

    return const Chip(
      avatar: Icon(Icons.warning, color: Colors.white, size: 18),
      label: Text('Sem ligação'),
      backgroundColor: Colors.orange,
      labelStyle: TextStyle(color: Colors.white, fontSize: 12),
    );
  }

  Future<void> _testConnection() async {
    // Validar que tem URL e API Key
    if (_apiUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure o URL da API'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure a API Key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);
    
    await ref.read(loyaltyProvider.notifier).testConnection();
    
    if (mounted) {
      setState(() => _isTesting = false);
      
      final state = ref.read(loyaltyProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.isConnected
                ? '✓ Ligação estabelecida com sucesso!'
                : '✗ ${state.error ?? "Não foi possível ligar à API"}',
          ),
          backgroundColor: state.isConnected ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
