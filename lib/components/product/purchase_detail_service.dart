import 'package:supabase_flutter/supabase_flutter.dart';
import 'purchase_detail_model.dart';

class PurchaseDetailService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String tableName = 'products_details';

  // Fetch purchase details with pagination
  Future<Map<String, dynamic>> fetchPurchaseDetails({
    int page = 1,
    int pageSize = 50,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterField =
        'expire_date', // Can be 'expire_date' or 'created_at'
    String sortColumn = 'created_at',
    bool sortAscending = false,
  }) async {
    try {
      // Calculate offset
      final int offset = (page - 1) * pageSize;

      // Get total count first
      var countQuery = _supabase.from(tableName).select('id');

      // Add search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        countQuery = countQuery.or(
          'identity_id.ilike.%$searchQuery%,supplier.ilike.%$searchQuery%',
        );
      }

      // Add date range filter
      if (startDate != null) {
        final startDateStr =
            dateFilterField == 'expire_date'
                ? startDate.toIso8601String().split('T')[0]
                : startDate.toIso8601String();
        countQuery = countQuery.gte(dateFilterField, startDateStr);
      }
      if (endDate != null) {
        final endDateStr =
            dateFilterField == 'expire_date'
                ? endDate.toIso8601String().split('T')[0]
                : DateTime(
                  endDate.year,
                  endDate.month,
                  endDate.day,
                  23,
                  59,
                  59,
                ).toIso8601String();
        countQuery = countQuery.lte(dateFilterField, endDateStr);
      }

      final countResponse = await countQuery;
      final totalCount = countResponse.length;

      // Build data query
      var dataQuery = _supabase.from(tableName).select();

      // Add search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        dataQuery = dataQuery.or(
          'identity_id.ilike.%$searchQuery%,supplier.ilike.%$searchQuery%',
        );
      }

      // Add date range filter
      if (startDate != null) {
        final startDateStr =
            dateFilterField == 'expire_date'
                ? startDate.toIso8601String().split('T')[0]
                : startDate.toIso8601String();
        dataQuery = dataQuery.gte(dateFilterField, startDateStr);
      }
      if (endDate != null) {
        final endDateStr =
            dateFilterField == 'expire_date'
                ? endDate.toIso8601String().split('T')[0]
                : DateTime(
                  endDate.year,
                  endDate.month,
                  endDate.day,
                  23,
                  59,
                  59,
                ).toIso8601String();
        dataQuery = dataQuery.lte(dateFilterField, endDateStr);
      }

      // Add ordering and pagination
      final response = await dataQuery
          .order(sortColumn, ascending: sortAscending)
          .range(offset, offset + pageSize - 1);

      // Convert to model
      final List<PurchaseDetail> purchaseDetails =
          (response as List<dynamic>)
              .map(
                (json) => PurchaseDetail.fromJson(json as Map<String, dynamic>),
              )
              .toList();

      return {
        'data': purchaseDetails,
        'totalCount': totalCount,
        'currentPage': page,
        'pageSize': pageSize,
        'totalPages': (totalCount / pageSize).ceil(),
      };
    } catch (e) {
      throw Exception('Failed to fetch purchase details: $e');
    }
  }

  // Add new purchase detail
  Future<PurchaseDetail> addPurchaseDetail(PurchaseDetail detail) async {
    try {
      final response =
          await _supabase
              .from(tableName)
              .insert(detail.toJson())
              .select()
              .single();

      return PurchaseDetail.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add purchase detail: $e');
    }
  }

  // Update purchase detail
  Future<PurchaseDetail> updatePurchaseDetail(PurchaseDetail detail) async {
    try {
      if (detail.id == null) {
        throw Exception('Purchase detail ID is required for update');
      }

      final response =
          await _supabase
              .from(tableName)
              .update(detail.toJson())
              .eq('id', detail.id!)
              .select()
              .single();

      return PurchaseDetail.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update purchase detail: $e');
    }
  }

  // Delete purchase detail
  Future<void> deletePurchaseDetail(int id) async {
    try {
      await _supabase.from(tableName).delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete purchase detail: $e');
    }
  }

  // Get single purchase detail by ID
  Future<PurchaseDetail?> getPurchaseDetailById(int id) async {
    try {
      final response =
          await _supabase.from(tableName).select().eq('id', id).maybeSingle();

      if (response == null) return null;

      return PurchaseDetail.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch purchase detail: $e');
    }
  }
}
