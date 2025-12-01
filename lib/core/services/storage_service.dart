import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper de storage que funciona em todas as plataformas
/// Em mobile usa FlutterSecureStorage, em desktop usa SharedPreferences
class StorageService {
  StorageService._();
  
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool? _useSecureStorage;
  
  /// Verifica se deve usar secure storage (mobile) ou shared_preferences (desktop)
  Future<bool> _shouldUseSecureStorage() async {
    if (_useSecureStorage != null) return _useSecureStorage!;
    
    // Em web, usa shared_preferences
    if (kIsWeb) {
      _useSecureStorage = false;
      debugPrint('📦 [Storage] Plataforma Web - usando SharedPreferences');
      return false;
    }
    
    // Em mobile (Android/iOS), usa secure storage
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      _useSecureStorage = true;
      debugPrint('📦 [Storage] Plataforma Mobile - usando FlutterSecureStorage');
      return true;
    }
    
    // Em desktop (macOS/Windows/Linux), testa se secure storage funciona
    try {
      await _secureStorage.write(key: '_storage_test', value: 'test');
      await _secureStorage.delete(key: '_storage_test');
      _useSecureStorage = true;
      debugPrint('📦 [Storage] Desktop com SecureStorage funcional');
      return true;
    } catch (e) {
      debugPrint('⚠️ [Storage] SecureStorage não disponível em desktop: $e');
      debugPrint('📦 [Storage] Usando SharedPreferences como fallback');
      _useSecureStorage = false;
      return false;
    }
  }

  Future<void> write({required String key, required String? value}) async {
    final useSecure = await _shouldUseSecureStorage();
    
    if (value == null) {
      await delete(key: key);
      return;
    }
    
    if (useSecure) {
      await _secureStorage.write(key: key, value: value);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
    
    // Log sem mostrar valores sensíveis
    final isSensitive = key.toLowerCase().contains('password') ||
        key.toLowerCase().contains('secret') ||
        key.toLowerCase().contains('token');
    debugPrint('💾 [Storage] WRITE: $key = ${isSensitive ? '***' : value}');
  }

  Future<String?> read({required String key}) async {
    final useSecure = await _shouldUseSecureStorage();
    
    String? value;
    if (useSecure) {
      value = await _secureStorage.read(key: key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getString(key);
    }
    
    // Log sem mostrar valores sensíveis
    final isSensitive = key.toLowerCase().contains('password') ||
        key.toLowerCase().contains('secret') ||
        key.toLowerCase().contains('token');
    debugPrint('📖 [Storage] READ: $key = ${value != null ? (isSensitive ? '***' : value) : 'null'}');
    
    return value;
  }

  Future<void> delete({required String key}) async {
    final useSecure = await _shouldUseSecureStorage();
    
    if (useSecure) {
      await _secureStorage.delete(key: key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
    debugPrint('🗑️ [Storage] DELETE: $key');
  }

  Future<void> deleteAll() async {
    final useSecure = await _shouldUseSecureStorage();
    
    if (useSecure) {
      await _secureStorage.deleteAll();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
    debugPrint('🗑️ [Storage] DELETE ALL');
  }

  Future<Map<String, String>> readAll() async {
    final useSecure = await _shouldUseSecureStorage();
    
    if (useSecure) {
      return await _secureStorage.readAll();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, String> result = {};
      for (final key in keys) {
        final value = prefs.getString(key);
        if (value != null) {
          result[key] = value;
        }
      }
      return result;
    }
  }

  Future<bool> containsKey({required String key}) async {
    final useSecure = await _shouldUseSecureStorage();
    
    if (useSecure) {
      return await _secureStorage.containsKey(key: key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(key);
    }
  }
}

/// Adapter que implementa a interface do FlutterSecureStorage
/// para ser usado como drop-in replacement nos providers existentes
class PlatformStorage implements FlutterSecureStorage {
  PlatformStorage._();
  
  static final PlatformStorage _instance = PlatformStorage._();
  static PlatformStorage get instance => _instance;
  
  final StorageService _storage = StorageService.instance;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await _storage.deleteAll();
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return await _storage.readAll();
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return await _storage.containsKey(key: key);
  }
  
  @override
  IOSOptions get iOptions => IOSOptions.defaultOptions;
  
  @override
  AndroidOptions get aOptions => AndroidOptions.defaultOptions;
  
  @override
  LinuxOptions get lOptions => LinuxOptions.defaultOptions;
  
  @override
  WebOptions get webOptions => WebOptions.defaultOptions;
  
  @override
  MacOsOptions get mOptions => MacOsOptions.defaultOptions;
  
  @override
  WindowsOptions get wOptions => WindowsOptions.defaultOptions;

  @override
  Future<bool> isCupertinoProtectedDataAvailable() async => true;

  @override
  Stream<bool> get onCupertinoProtectedDataAvailabilityChanged => 
      Stream.value(true);
  
  @override
  void registerListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {
    // Não implementado - não é necessário para o caso de uso atual
  }
  
  @override
  void unregisterListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {
    // Não implementado - não é necessário para o caso de uso atual
  }
  
  @override
  void unregisterAllListeners() {
    // Não implementado - não é necessário para o caso de uso atual
  }
  
  @override
  void unregisterAllListenersForKey({required String key}) {
    // Não implementado - não é necessário para o caso de uso atual
  }
}
