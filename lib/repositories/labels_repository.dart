import 'base_repository.dart';

/// Repository for label print history
class LabelsRepository extends BaseRepository {
  @override
  String get tableName => 'label_print_history';

  /// Get all print history
  Future<List<Map<String, dynamic>>> getAll() async {
    return await fetchList(cacheKey: 'all');
  }

  /// Create print history record
  Future<Map<String, dynamic>> createPrintHistory({
    String? productId,
    required String productName,
    String? lot,
    String? weight,
    String? preparedBy,
    String? manufacturedAt,
    String? dlc,
    String? dluo,
    required String zpl,
    required String status,
    String? errorMessage,
  }) async {
    return await super.create({
      'product_id': productId,
      'product_name': productName,
      'lot': lot,
      'weight': weight,
      'prepared_by': preparedBy,
      'manufactured_at': manufacturedAt,
      'dlc': dlc,
      'dluo': dluo,
      'zpl': zpl,
      'printed_at': DateTime.now().toIso8601String(),
      'status': status,
      'error_message': errorMessage,
    });
  }
}
