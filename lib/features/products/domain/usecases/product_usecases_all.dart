// ==================== USE CASE 1: SEARCH PRODUCTS ====================
import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/domain/repositories/product_repository.dart';

/// Use Case para pesquisar produtos
class SearchProductsUseCase {

  SearchProductsUseCase(this.repository);
  final ProductRepository repository;

  Future<Either<Failure, List<Product>>> call({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    // Validação: mínimo 3 caracteres
    if (query.trim().length < 3) {
      return const Left(
        ValidationFailure('Digite pelo menos 3 caracteres para pesquisar'),
      );
    }

    return await repository.searchProducts(
      query: query.trim(),
      limit: limit,
      offset: offset,
    );
  }
}

// ==================== USE CASE 2: GET BY BARCODE ====================

/// Use Case para obter produto por código de barras
class GetProductByBarcodeUseCase {
  GetProductByBarcodeUseCase(this.repository);
  final ProductRepository repository;

  Future<Either<Failure, Product?>> call(String barcode) async {
    // Validação: barcode não vazio
    if (barcode.trim().isEmpty) {
      return const Left(
        ValidationFailure('Código de barras não pode estar vazio'),
      );
    }

    return await repository.getProductByBarcode(barcode.trim());
  }
}

// ==================== USE CASE 3: GET BY REFERENCE ====================

/// Use Case para obter produto por referência
class GetProductByReferenceUseCase {
  GetProductByReferenceUseCase(this.repository);
  final ProductRepository repository;

  Future<Either<Failure, Product?>> call(String reference) async {
    // Validação: referência não vazia
    if (reference.trim().isEmpty) {
      return const Left(
        ValidationFailure('Referência não pode estar vazia'),
      );
    }

    return await repository.getProductByReference(reference.trim());
  }
}

// ==================== USE CASE 4: GET CACHED ====================

/// Use Case para obter produtos cacheados
class GetCachedProductsUseCase {
  GetCachedProductsUseCase(this.repository);
  final ProductRepository repository;

  Future<Either<Failure, List<Product>>> call() async {
    return await repository.getCachedProducts();
  }
}

// ==================== USE CASE 5: CLEAR CACHE ====================

/// Use Case para limpar cache
class ClearProductsCacheUseCase {
  ClearProductsCacheUseCase(this.repository);
  final ProductRepository repository;

  Future<Either<Failure, void>> call() async {
    return await repository.clearCache();
  }
}
