// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MergeConfig _$MergeConfigFromJson(Map<String, dynamic> json) => _MergeConfig(
  squash: json['squash'] as bool? ?? true,
  rebase: json['rebase'] as bool? ?? true,
  remove: json['remove'] as bool? ?? true,
  verify: json['verify'] as bool? ?? true,
  push: json['push'] as bool? ?? false,
);

Map<String, dynamic> _$MergeConfigToJson(_MergeConfig instance) =>
    <String, dynamic>{
      'squash': instance.squash,
      'rebase': instance.rebase,
      'remove': instance.remove,
      'verify': instance.verify,
      'push': instance.push,
    };

_ListConfig _$ListConfigFromJson(Map<String, dynamic> json) =>
    _ListConfig(url: json['url'] as String? ?? '');

Map<String, dynamic> _$ListConfigToJson(_ListConfig instance) =>
    <String, dynamic>{'url': instance.url};

_CopyIgnoredConfig _$CopyIgnoredConfigFromJson(Map<String, dynamic> json) =>
    _CopyIgnoredConfig(
      exclude:
          (json['exclude'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$CopyIgnoredConfigToJson(_CopyIgnoredConfig instance) =>
    <String, dynamic>{'exclude': instance.exclude};

_Config _$ConfigFromJson(Map<String, dynamic> json) => _Config(
  createBookmark: json['create-bookmark'] as bool? ?? true,
  workspacePath: json['workspace-path'] as String? ?? '',
  merge: json['merge'] == null
      ? const MergeConfig()
      : MergeConfig.fromJson(json['merge'] as Map<String, dynamic>),
  list: json['list'] == null
      ? const ListConfig()
      : ListConfig.fromJson(json['list'] as Map<String, dynamic>),
  copyIgnored: json['copy-ignored'] == null
      ? const CopyIgnoredConfig()
      : CopyIgnoredConfig.fromJson(
          json['copy-ignored'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$ConfigToJson(_Config instance) => <String, dynamic>{
  'create-bookmark': instance.createBookmark,
  'workspace-path': instance.workspacePath,
  'merge': instance.merge,
  'list': instance.list,
  'copy-ignored': instance.copyIgnored,
};
