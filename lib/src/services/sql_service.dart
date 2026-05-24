import "../client.dart";
import "../dtos/sql_result.dart";
import "base_service.dart";

/// The service that handles the **SQL APIs**.
///
/// Usually shouldn't be initialized manually and instead
/// [PocketBase.sql] should be used.
class SQLService extends BaseService {
  SQLService(super.client);

  /// Executes the specified raw SQL query.
  /// This operation is allowed only for superusers.
  Future<SQLResult> run(
    String sqlQuery, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) {
    final enrichedBody = Map<String, dynamic>.of(body);
    enrichedBody["query"] = sqlQuery;

    return client
        .send<Map<String, dynamic>>(
          "/api/sql",
          method: "POST",
          body: enrichedBody,
          query: query,
          headers: headers,
        )
        .then(SQLResult.fromJson);
  }
}
