import "dart:convert";

import "package:json_annotation/json_annotation.dart";

import "jsonable.dart";

part "configurable_oauth2_provider.g.dart";

/// Response DTO of a single configurable OAuth2 provider item.
@JsonSerializable(explicitToJson: true)
class ConfigurableOAuth2Provider implements Jsonable {
  String name;
  String displayName;
  String logo;

  ConfigurableOAuth2Provider({
    this.name = "",
    this.displayName = "",
    this.logo = "",
  });

  static ConfigurableOAuth2Provider fromJson(Map<String, dynamic> json) =>
      _$ConfigurableOAuth2ProviderFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$ConfigurableOAuth2ProviderToJson(this);

  @override
  String toString() => jsonEncode(toJson());
}
