import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/auth/domain/entities/auth_tokens.dart';
import 'package:pos_moloni_app/features/auth/domain/entities/user.dart';
import 'package:pos_moloni_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:pos_moloni_app/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:pos_moloni_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:pos_moloni_app/features/auth/data/models/auth_tokens_model.dart';
import 'package:pos_moloni_app/features/auth/data/models/user_model.dart';

/// Implementação do repositório de autenticação
/// Coordena entre datasources local e remoto
class AuthRepositoryImpl implements AuthRepository {

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  @override
  Future<Either<Failure, AuthTokens>> login({
    required String username,
    required String password,
  }) async {
    try {
      AppLogger.i('🔐 Iniciando login...');

      // 1. Fazer login na API
      final tokens = await remoteDataSource.login(
        username: username,
        password: password,
      );

      // 2. Guardar tokens localmente
      await localDataSource.saveTokens(tokens);

      // 3. Guardar username
      await localDataSource.saveUsername(username);

      // 4. Criar user básico (Moloni não retorna user info no login)
      final user = UserModel(
        id: username, // Usar username como ID temporário
        username: username,
      );
      await localDataSource.saveUser(user);

      AppLogger.i('✅ Login bem-sucedido');
      return Right(tokens.toEntity());
    } on InvalidCredentialsException {
      AppLogger.w('❌ Credenciais inválidas');
      return const Left(InvalidCredentialsFailure());
    } on NetworkException {
      AppLogger.w('❌ Erro de rede');
      return const Left(NetworkFailure());
    } on TimeoutException {
      AppLogger.w('❌ Timeout');
      return const Left(TimeoutFailure());
    } on ConfigurationException catch (e) {
      AppLogger.e('❌ Configuração ausente', error: e);
      return Left(ConfigurationFailure(e.message));
    } on ServerException catch (e) {
      AppLogger.e('❌ Erro no servidor', error: e);
      return Left(ServerFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado no login', error: e);
      return const Left(UnexpectedFailure('Erro inesperado ao fazer login'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      AppLogger.i('🚪 Fazendo logout...');

      // Limpar todos os dados de autenticação
      await localDataSource.clearAll();

      AppLogger.i('✅ Logout bem-sucedido');
      return const Right(null);
    } on CacheException catch (e) {
      AppLogger.e('❌ Erro ao fazer logout', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado no logout', error: e);
      return const Left(UnexpectedFailure('Erro ao fazer logout'));
    }
  }

  @override
  Future<Either<Failure, AuthTokens>> refreshToken() async {
    try {
      AppLogger.i('🔄 Refreshing token...');

      // 1. Obter refresh token guardado
      final storedTokens = await localDataSource.getStoredTokens();
      
      if (storedTokens == null) {
        AppLogger.w('❌ Nenhum token guardado');
        return const Left(AuthenticationFailure('Nenhum token guardado'));
      }

      // 2. Fazer refresh na API
      final newTokens = await remoteDataSource.refreshToken(
        storedTokens.refreshToken,
      );

      // 3. Guardar novos tokens
      await localDataSource.saveTokens(newTokens);

      AppLogger.i('✅ Token atualizado');
      return Right(newTokens.toEntity());
    } on TokenExpiredException {
      AppLogger.w('❌ Refresh token expirado');
      
      // Limpar dados antigos
      await localDataSource.clearAll();
      
      return const Left(TokenExpiredFailure());
    } on NetworkException {
      AppLogger.w('❌ Erro de rede no refresh');
      return const Left(NetworkFailure());
    } on TimeoutException {
      AppLogger.w('❌ Timeout no refresh');
      return const Left(TimeoutFailure());
    } on ServerException catch (e) {
      AppLogger.e('❌ Erro no servidor (refresh)', error: e);
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      AppLogger.e('❌ Erro no cache (refresh)', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado no refresh', error: e);
      return const Left(UnexpectedFailure('Erro ao atualizar token'));
    }
  }

  @override
  Future<Either<Failure, bool>> hasValidToken() async {
    try {
      final tokens = await localDataSource.getStoredTokens();

      if (tokens == null) {
        AppLogger.d('❌ Nenhum token encontrado');
        return const Right(false);
      }

      // Verificar se o token ainda é válido
      if (tokens.isExpired) {
        AppLogger.d('❌ Token expirado');
        return const Right(false);
      }

      AppLogger.d('✅ Token válido encontrado');
      return const Right(true);
    } on CacheException catch (e) {
      AppLogger.e('❌ Erro ao verificar token', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado ao verificar token', error: e);
      return const Left(UnexpectedFailure('Erro ao verificar token'));
    }
  }

  @override
  Future<Either<Failure, AuthTokens?>> getStoredTokens() async {
    try {
      final tokens = await localDataSource.getStoredTokens();
      
      if (tokens == null) {
        return const Right(null);
      }

      return Right(tokens.toEntity());
    } on CacheException catch (e) {
      AppLogger.e('❌ Erro ao obter tokens', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado ao obter tokens', error: e);
      return const Left(UnexpectedFailure('Erro ao obter tokens'));
    }
  }

  @override
  Future<Either<Failure, void>> saveTokens(AuthTokens tokens) async {
    try {
      final model = AuthTokensModel.fromEntity(tokens);
      await localDataSource.saveTokens(model);
      
      return const Right(null);
    } on CacheException catch (e) {
      AppLogger.e('❌ Erro ao guardar tokens', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado ao guardar tokens', error: e);
      return const Left(UnexpectedFailure('Erro ao guardar tokens'));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final user = await localDataSource.getStoredUser();
      
      if (user == null) {
        return const Right(null);
      }

      return Right(user.toEntity());
    } on CacheException catch (e) {
      AppLogger.e('❌ Erro ao obter utilizador', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado ao obter utilizador', error: e);
      return const Left(UnexpectedFailure('Erro ao obter utilizador'));
    }
  }

  @override
  Future<Either<Failure, void>> clearAuthData() async {
    try {
      await localDataSource.clearAll();
      return const Right(null);
    } on CacheException catch (e) {
      AppLogger.e('❌ Erro ao limpar dados', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('❌ Erro inesperado ao limpar dados', error: e);
      return const Left(UnexpectedFailure('Erro ao limpar dados'));
    }
  }
}
