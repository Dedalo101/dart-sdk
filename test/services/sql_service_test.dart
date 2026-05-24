import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:pocketbase/pocketbase.dart";
import "package:test/test.dart";

void main() {
  group("SQLService", () {
    test("run()", () async {
      final expectedBody = SQLResult(
        execTime: 1,
        affectedRows: 2,
        columns: [
          {"a": 1},
          {"b": 2}
        ],
        rows: [
          [1, 2],
          [3, 4]
        ],
      );

      final mock = MockClient((request) async {
        expect(request.method, "POST");
        expect(
          request.body,
          jsonEncode({"test_body": 123, "query": "test_query"}),
        );
        expect(
          request.url.toString(),
          "/base/api/sql?a=1&a=2&b=%40demo",
        );
        expect(request.headers["test"], "789");

        return http.Response(expectedBody.toString(), 200);
      });

      final client = PocketBase("/base", httpClientFactory: () => mock);

      final result = await client.sql.run(
        "test_query",
        query: {
          "a": ["1", null, 2],
          "b": "@demo",
        },
        body: {
          "test_body": 123,
        },
        headers: {
          "test": "789",
        },
      );

      expect(result.toJson(), equals(expectedBody.toJson()));
    });
  });
}
