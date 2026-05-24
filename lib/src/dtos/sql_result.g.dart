// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sql_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SQLResult _$SQLResultFromJson(Map<String, dynamic> json) => SQLResult(
      execTime: json['execTime'] as num? ?? 0,
      affectedRows: json['affectedRows'] as num? ?? 0,
      columns: json['columns'] as List<dynamic>? ?? const [],
      rows: json['rows'] as List<dynamic>? ?? const [],
    );

Map<String, dynamic> _$SQLResultToJson(SQLResult instance) => <String, dynamic>{
      'execTime': instance.execTime,
      'affectedRows': instance.affectedRows,
      'columns': instance.columns,
      'rows': instance.rows,
    };
