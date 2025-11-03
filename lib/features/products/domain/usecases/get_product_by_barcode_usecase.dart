import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';
import 'package:pos_moloni_app/features/products/domain/repositories/product_repository.dart';

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

/// Use Case para obter produtos cacheados
class GetCachedProductsUseCase {
  GetCachedProductsUseCase(this.repository);
  final ProductRepository repository;

  Future<Either<Failure, List<Product>>> call() async {
    return await repository.getCachedProducts();
  }
}

/// Use Case para limpar cache
class ClearProductsCacheUseCase {
  ClearProductsCacheUseCase(this.repository);
  final ProductRepository repository;

  Future<Either<Failure, void>> call() async {
    return await repository.clearCache();
  }
}
