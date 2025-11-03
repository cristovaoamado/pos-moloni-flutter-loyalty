import 'package:dartz/dartz.dart';

import 'package:pos_moloni_app/core/errors/failures.dart';
import 'package:pos_moloni_app/features/products/domain/entities/product.dart';

/// Interface do repositório de produtos
abstract class ProductRepository {
  /// Pesquisa produtos por termo de busca
  Future<Either<Failure, List<Product>>> searchProducts({
    required String query,
    int limit = 50,
    int offset = 0,
  });

  /// Busca produto por código de barras (EAN)
  Future<Either<Failure, Product?>> getProductByBarcode(String barcode);

  /// Busca produto por referência
  Future<Either<Failure, Product?>> getProductByReference(String reference);

  /// Obtém produtos do cache local
  Future<Either<Failure, List<Product>>> getCachedProducts();

  /// Limpa cache de produtos
  Future<Either<Failure, void>> clearCache();
}
