// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jj.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WorkspaceInfo _$WorkspaceInfoFromJson(Map<String, dynamic> json) =>
    _WorkspaceInfo(
      name: json['name'] as String,
      changeId: json['changeId'] as String,
      bookmarks: (json['bookmarks'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      description: json['description'] as String,
      conflict: json['conflict'] as bool,
      divergent: json['divergent'] as bool,
      empty: json['empty'] as bool,
      current: json['current'] as bool,
      modifiedFiles: (json['modifiedFiles'] as num).toInt(),
      age: json['age'] as String? ?? '',
      path: json['path'] as String? ?? '',
      insertions: (json['insertions'] as num?)?.toInt() ?? 0,
      deletions: (json['deletions'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$WorkspaceInfoToJson(_WorkspaceInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'changeId': instance.changeId,
      'bookmarks': instance.bookmarks,
      'description': instance.description,
      'conflict': instance.conflict,
      'divergent': instance.divergent,
      'empty': instance.empty,
      'current': instance.current,
      'modifiedFiles': instance.modifiedFiles,
      'age': instance.age,
      'path': instance.path,
      'insertions': instance.insertions,
      'deletions': instance.deletions,
    };
