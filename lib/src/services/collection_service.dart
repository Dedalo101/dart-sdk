import "../client.dart";
import "../dtos/collection_model.dart";
import "../dtos/configurable_oauth2_provider.dart";
import "../dtos/record_model.dart";
import "base_crud_service.dart";

/// The service that handles the **Collection APIs**.
///
/// Usually shouldn't be initialized manually and instead
/// [PocketBase.collections] should be used.
class CollectionService extends BaseCrudService<CollectionModel> {
  CollectionService(super.client);

  @override
  String get baseCrudPath => "/api/collections";

  @override
  CollectionModel itemFactoryFunc(Map<String, dynamic> json) =>
      CollectionModel.fromJson(json);

  /// Imports the provided collections.
  ///
  /// If [deleteMissing] is `true`, all local collections and schema fields,
  /// that are not present in the imported configuration, WILL BE DELETED
  /// (including their related records data)!
  Future<void> import(
    List<CollectionModel> collections, {
    bool deleteMissing = false,
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) {
    final enrichedBody = Map<String, dynamic>.of(body);
    enrichedBody["collections"] = collections;
    enrichedBody["deleteMissing"] = deleteMissing;

    return client.send(
      "$baseCrudPath/import",
      method: "PUT",
      body: enrichedBody,
      query: query,
      headers: headers,
    );
  }

  /// Deletes all records associated with the specified collection.
  Future<void> truncate(
    String collectionIdOrName, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) {
    return client.send(
      "$baseCrudPath/${Uri.encodeComponent(collectionIdOrName)}/truncate",
      method: "DELETE",
      body: body,
      query: query,
      headers: headers,
    );
  }

  /// Returns type indexed map with scaffolded collection models
  /// populated with their default field values.
  Future<Map<String, CollectionModel>> getScaffolds({
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) {
    return client
        .send<Map<String, dynamic>>(
      "$baseCrudPath/meta/scaffolds",
      query: query,
      headers: headers,
    )
        .then((data) {
      final result = <String, CollectionModel>{};

      data.forEach((key, value) {
        result[key] =
            CollectionModel.fromJson(value as Map<String, dynamic>? ?? {});
      });

      return result;
    });
  }

  /// Returns a list with all configurable OAuth2 providers.
  Future<List<ConfigurableOAuth2Provider>> getAllOAuth2Providers({
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) {
    return client
        .send<List<dynamic>>(
          "$baseCrudPath/meta/oauth2-providers",
          query: query,
          headers: headers,
        )
        .then((data) => data
            .map((item) => ConfigurableOAuth2Provider.fromJson(
                item as Map<String, dynamic>? ?? {}))
            .toList());
  }

  /// Executes the specified view query and returns a sample of the
  /// resulting records.
  Future<List<RecordModel>> dryRunViewQuery(
    String viewQuery, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) {
    final enrichedBody = Map<String, dynamic>.of(body);
    enrichedBody["query"] = viewQuery;

    return client
        .send<List<dynamic>>(
          "$baseCrudPath/meta/dry-run-view",
          method: "POST",
          body: enrichedBody,
          query: query,
          headers: headers,
        )
        .then((data) => data
            .map((item) =>
                RecordModel.fromJson(item as Map<String, dynamic>? ?? {}))
            .toList());
  }
}
