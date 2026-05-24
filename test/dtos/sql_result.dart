import "package:pocketbase/pocketbase.dart";
import "package:test/test.dart";

void main() {
  group("SQLResult", () {
    test("fromJson() and toJson()", () {
      final json = {
        "execTime": 1,
        "affectedRows": 2,
        "columns": [
          {"col1": 1},
          {"col2": 2}
        ],
        "rows": [
          [1, 2],
          [3, 4],
        ],
      };

      final model = SQLResult.fromJson(json);

      expect(model.toJson(), json);
    });
  });
}
