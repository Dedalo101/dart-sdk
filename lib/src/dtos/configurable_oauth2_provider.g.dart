// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'configurable_oauth2_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfigurableOAuth2Provider _$ConfigurableOAuth2ProviderFromJson(
        Map<String, dynamic> json) =>
    ConfigurableOAuth2Provider(
      name: json['name'] as String? ?? "",
      displayName: json['displayName'] as String? ?? "",
      logo: json['logo'] as String? ?? "",
    );

Map<String, dynamic> _$ConfigurableOAuth2ProviderToJson(
        ConfigurableOAuth2Provider instance) =>
    <String, dynamic>{
      'name': instance.name,
      'displayName': instance.displayName,
      'logo': instance.logo,
    };
