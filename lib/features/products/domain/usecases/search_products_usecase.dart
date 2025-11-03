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
