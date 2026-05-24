import "dart:convert";

import "package:json_annotation/json_annotation.dart";

import "jsonable.dart";

part "sql_result.g.dart";

/// Response DTO of a SQL run request result.
@JsonSerializable(explicitToJson: true)
class SQLResult implements Jsonable {
  num execTime;
  num affectedRows;
  List<dynamic> columns;
  List<dynamic> rows;

  SQLResult({
    this.execTime = 0,
    this.affectedRows = 0,
    this.columns = const [],
    this.rows = const [],
  });

  static SQLResult fromJson(Map<String, dynamic> json) =>
      _$SQLResultFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$SQLResultToJson(this);

  @override
  String toString() => jsonEncode(toJson());
}
