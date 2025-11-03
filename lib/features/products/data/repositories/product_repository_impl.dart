import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/exceptions.dart';
import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/core/utils/logger.dart';
import 'package:pos_moloni_app/features/products/data/datasources/product_local_datasource.dart';
import 'package:pos_moloni_app/features/products/data/datasources/product_remote_datasource.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/domain/repositories/product_repository.dart';

/// Implementação do repositório de produtos
/// Coordena entre datasources local e remoto
class ProductRepositoryImpl implements ProductRepository {

  ProductRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });
  final ProductRemoteDataSource remoteDataSource;
  final ProductLocalDataSource localDataSource;

  @override
  Future<Either<Failure, List<Product>>> searchProducts({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      AppLogger.i('🔍 Pesquisando produtos: "$query"');

      // 1. Tentar buscar na API
      final remoteProducts = await remoteDataSource.searchProducts(
        query: query,
        limit: limit,
        offset: offset,
      );

      // 2. Se sucesso, guardar em cache
      await localDataSource.cacheProducts(remoteProducts);

      final entities = remoteProducts.map((model) => model.toEntity()).toList();

      AppLogger.i('✅ ${entities.length} produtos encontrados');
      return Right(entities);
    } on TokenExpiredException {
      AppLogger.w('⚠️ Token expirado');

      // Tentar em cache local como fallback
      try {
        final cachedProducts = await localDataSource.searchInCache(query);
        if (cachedProducts.isNotEmpty) {
          final entities =
              cachedProducts.map((model) => model.toEntity()).toList();
          return Right(entities);
        }
      } catch (e) {
        AppLogger.e('Erro ao acessar cache local', error: e);
      }

      return const Left(TokenExpiredFailure());
    } on NetworkException {
      AppLogger.w('⚠️ Erro de rede');

      // Fallback: procurar em cache local
      try {
        final cachedProducts = await localDataSource.searchInCache(query);
        if (cachedProducts.isNotEmpty) {
          final entities =
              cachedProducts.map((model) => model.toEntity()).toList();
          AppLogger.i('Resultados do cache local');
          return Right(entities);
        }
      } catch (e) {
        AppLogger.e('Erro ao acessar cache local', error: e);
      }

      return const Left(NetworkFailure());
    } on TimeoutException {
      AppLogger.w('⚠️ Timeout na pesquisa');
      return const Left(TimeoutFailure());
    } on ServerException catch (e) {
      AppLogger.e('⚠️ Erro no servidor', error: e);
      return Left(ServerFailure(e.message));
    } catch (e) {
      AppLogger.e('⚠️ Erro inesperado ao pesquisar', error: e);
      return const Left(UnexpectedFailure('Erro ao pesquisar produtos'));
    }
  }

  @override
  Future<Either<Failure, Product?>> getProductByBarcode(String barcode) async {
    try {
      AppLogger.i('🔍 Procurando produto por código de barras: $barcode');

      // 1. Procurar em cache primeiro (mais rápido)
      final cachedProduct =
          await localDataSource.getCachedProductByEan(barcode);
      if (cachedProduct != null) {
        AppLogger.i('✅ Produto encontrado no cache');
        return Right(cachedProduct.toEntity());
      }

      // 2. Se não encontrou, buscar na API
      final remoteProduct =
          await remoteDataSource.getProductByBarcode(barcode);

      if (remoteProduct != null) {
        // Guardar em cache para próximas vezes
        await localDataSource.cacheProducts([remoteProduct]);
        AppLogger.i('✅ Produto encontrado na API');
        return Right(remoteProduct.toEntity());
      }

      AppLogger.d('⚠️ Produto não encontrado');
      return const Right(null);
    } on TokenExpiredException {
      AppLogger.w('⚠️ Token expirado');
      return const Left(TokenExpiredFailure());
    } on NetworkException {
      AppLogger.w('⚠️ Erro de rede');
      return const Left(NetworkFailure());
    } on TimeoutException {
      AppLogger.w('⚠️ Timeout');
      return const Left(TimeoutFailure());
    } on ServerException catch (e) {
      AppLogger.e('⚠️ Erro no servidor', error: e);
      return Left(ServerFailure(e.message));
    } catch (e) {
      AppLogger.e('⚠️ Erro inesperado', error: e);
      return const Left(UnexpectedFailure('Erro ao procurar produto'));
    }
  }

  @override
  Future<Either<Failure, Product?>> getProductByReference(
    String reference,
  ) async {
    try {
      AppLogger.i('🔍 Procurando produto por referência: $reference');

      // 1. Procurar em cache primeiro
      final cachedProduct =
          await localDataSource.getCachedProductByReference(reference);
      if (cachedProduct != null) {
        AppLogger.i('✅ Produto encontrado no cache');
        return Right(cachedProduct.toEntity());
      }

      // 2. Se não encontrou, buscar na API
      final remoteProduct =
          await remoteDataSource.getProductByReference(reference);

      if (remoteProduct != null) {
        // Guardar em cache
        await localDataSource.cacheProducts([remoteProduct]);
        AppLogger.i('✅ Produto encontrado na API');
        return Right(remoteProduct.toEntity());
      }

      AppLogger.d('⚠️ Produto não encontrado');
      return const Right(null);
    } on TokenExpiredException {
      AppLogger.w('⚠️ Token expirado');
      return const Left(TokenExpiredFailure());
    } on NetworkException {
      AppLogger.w('⚠️ Erro de rede');
      return const Left(NetworkFailure());
    } on TimeoutException {
      AppLogger.w('⚠️ Timeout');
      return const Left(TimeoutFailure());
    } on ServerException catch (e) {
      AppLogger.e('⚠️ Erro no servidor', error: e);
      return Left(ServerFailure(e.message));
    } catch (e) {
      AppLogger.e('⚠️ Erro inesperado', error: e);
      return const Left(UnexpectedFailure('Erro ao procurar produto'));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getCachedProducts() async {
    try {
      AppLogger.i('💾 Obtendo produtos do cache');

      final cachedProducts = await localDataSource.getCachedProducts();
      final entities = cachedProducts.map((model) => model.toEntity()).toList();

      AppLogger.i('✅ ${entities.length} produtos no cache');
      return Right(entities);
    } on CacheException catch (e) {
      AppLogger.e('⚠️ Erro no cache', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('⚠️ Erro inesperado', error: e);
      return const Left(UnexpectedFailure('Erro ao obter cache'));
    }
  }

  @override
  Future<Either<Failure, void>> clearCache() async {
    try {
      AppLogger.i('🗑️ Limpando cache de produtos');

      await localDataSource.clearCache();

      AppLogger.i('✅ Cache limpo');
      return const Right(null);
    } on CacheException catch (e) {
      AppLogger.e('⚠️ Erro ao limpar cache', error: e);
      return Left(CacheFailure(e.message));
    } catch (e) {
      AppLogger.e('⚠️ Erro inesperado', error: e);
      return const Left(UnexpectedFailure('Erro ao limpar cache'));
    }
  }
}
