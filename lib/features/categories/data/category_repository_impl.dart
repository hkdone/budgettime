import '../../../core/services/database_service.dart';
import '../../transactions/domain/categories.dart' as system_categories;
import '../domain/category.dart';
import '../domain/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final DatabaseService _dbService;

  CategoryRepositoryImpl(this._dbService);

  @override
  Future<List<Category>> getCategories() async {
    final user = _dbService.pb.authStore.record;
    // 1. Get System Categories (mapped to new Model)
    final systemCats = system_categories.kTransactionCategories
        .map(
          (c) => Category(
            id: c.id,
            name: c.name,
            icon: c.icon,
            color: c.color,
            isSystem: true,
          ),
        )
        .toList();

    if (user == null) {
      return systemCats;
    }

    // 2. Get User Categories from DB
    // Ensure collection exists first (handled by hook usually, but here we assume it exists)
    try {
      final records = await _dbService.pb
          .collection('categories')
          .getFullList(filter: 'user = "${user.id}"');

      final userCats = records
          .map((r) => Category.fromJson(r.toJson()))
          .toList();
      return [...systemCats, ...userCats];
    } catch (e) {
      // If collection doesn't exist or error, return system cats
      return systemCats;
    }
  }

  @override
  Future<Category> createCategory(Category category) async {
    final user = _dbService.pb.authStore.record;
    if (user == null) throw Exception('User not logged in');

    final body = category.toJson();
    body['user'] = user.id;

    final record = await _dbService.pb
        .collection('categories')
        .create(body: body);
    return Category.fromJson(record.toJson());
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _dbService.pb.collection('categories').delete(id);
  }
}
