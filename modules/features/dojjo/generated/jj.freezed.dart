// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jj.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WorkspaceInfo {

 String get name; String get changeId; List<String> get bookmarks; String get description; bool get conflict; bool get divergent; bool get empty; bool get current; int get modifiedFiles; String get age; String get path; int get insertions; int get deletions;
/// Create a copy of WorkspaceInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceInfoCopyWith<WorkspaceInfo> get copyWith => _$WorkspaceInfoCopyWithImpl<WorkspaceInfo>(this as WorkspaceInfo, _$identity);

  /// Serializes this WorkspaceInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.changeId, changeId) || other.changeId == changeId)&&const DeepCollectionEquality().equals(other.bookmarks, bookmarks)&&(identical(other.description, description) || other.description == description)&&(identical(other.conflict, conflict) || other.conflict == conflict)&&(identical(other.divergent, divergent) || other.divergent == divergent)&&(identical(other.empty, empty) || other.empty == empty)&&(identical(other.current, current) || other.current == current)&&(identical(other.modifiedFiles, modifiedFiles) || other.modifiedFiles == modifiedFiles)&&(identical(other.age, age) || other.age == age)&&(identical(other.path, path) || other.path == path)&&(identical(other.insertions, insertions) || other.insertions == insertions)&&(identical(other.deletions, deletions) || other.deletions == deletions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,changeId,const DeepCollectionEquality().hash(bookmarks),description,conflict,divergent,empty,current,modifiedFiles,age,path,insertions,deletions);

@override
String toString() {
  return 'WorkspaceInfo(name: $name, changeId: $changeId, bookmarks: $bookmarks, description: $description, conflict: $conflict, divergent: $divergent, empty: $empty, current: $current, modifiedFiles: $modifiedFiles, age: $age, path: $path, insertions: $insertions, deletions: $deletions)';
}


}

/// @nodoc
abstract mixin class $WorkspaceInfoCopyWith<$Res>  {
  factory $WorkspaceInfoCopyWith(WorkspaceInfo value, $Res Function(WorkspaceInfo) _then) = _$WorkspaceInfoCopyWithImpl;
@useResult
$Res call({
 String name, String changeId, List<String> bookmarks, String description, bool conflict, bool divergent, bool empty, bool current, int modifiedFiles, String age, String path, int insertions, int deletions
});




}
/// @nodoc
class _$WorkspaceInfoCopyWithImpl<$Res>
    implements $WorkspaceInfoCopyWith<$Res> {
  _$WorkspaceInfoCopyWithImpl(this._self, this._then);

  final WorkspaceInfo _self;
  final $Res Function(WorkspaceInfo) _then;

/// Create a copy of WorkspaceInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? changeId = null,Object? bookmarks = null,Object? description = null,Object? conflict = null,Object? divergent = null,Object? empty = null,Object? current = null,Object? modifiedFiles = null,Object? age = null,Object? path = null,Object? insertions = null,Object? deletions = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,changeId: null == changeId ? _self.changeId : changeId // ignore: cast_nullable_to_non_nullable
as String,bookmarks: null == bookmarks ? _self.bookmarks : bookmarks // ignore: cast_nullable_to_non_nullable
as List<String>,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,conflict: null == conflict ? _self.conflict : conflict // ignore: cast_nullable_to_non_nullable
as bool,divergent: null == divergent ? _self.divergent : divergent // ignore: cast_nullable_to_non_nullable
as bool,empty: null == empty ? _self.empty : empty // ignore: cast_nullable_to_non_nullable
as bool,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,modifiedFiles: null == modifiedFiles ? _self.modifiedFiles : modifiedFiles // ignore: cast_nullable_to_non_nullable
as int,age: null == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,insertions: null == insertions ? _self.insertions : insertions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceInfo].
extension WorkspaceInfoPatterns on WorkspaceInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceInfo value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceInfo():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceInfo value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String changeId,  List<String> bookmarks,  String description,  bool conflict,  bool divergent,  bool empty,  bool current,  int modifiedFiles,  String age,  String path,  int insertions,  int deletions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceInfo() when $default != null:
return $default(_that.name,_that.changeId,_that.bookmarks,_that.description,_that.conflict,_that.divergent,_that.empty,_that.current,_that.modifiedFiles,_that.age,_that.path,_that.insertions,_that.deletions);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String changeId,  List<String> bookmarks,  String description,  bool conflict,  bool divergent,  bool empty,  bool current,  int modifiedFiles,  String age,  String path,  int insertions,  int deletions)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceInfo():
return $default(_that.name,_that.changeId,_that.bookmarks,_that.description,_that.conflict,_that.divergent,_that.empty,_that.current,_that.modifiedFiles,_that.age,_that.path,_that.insertions,_that.deletions);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String changeId,  List<String> bookmarks,  String description,  bool conflict,  bool divergent,  bool empty,  bool current,  int modifiedFiles,  String age,  String path,  int insertions,  int deletions)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceInfo() when $default != null:
return $default(_that.name,_that.changeId,_that.bookmarks,_that.description,_that.conflict,_that.divergent,_that.empty,_that.current,_that.modifiedFiles,_that.age,_that.path,_that.insertions,_that.deletions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkspaceInfo implements WorkspaceInfo {
  const _WorkspaceInfo({required this.name, required this.changeId, required final  List<String> bookmarks, required this.description, required this.conflict, required this.divergent, required this.empty, required this.current, required this.modifiedFiles, this.age = '', this.path = '', this.insertions = 0, this.deletions = 0}): _bookmarks = bookmarks;
  factory _WorkspaceInfo.fromJson(Map<String, dynamic> json) => _$WorkspaceInfoFromJson(json);

@override final  String name;
@override final  String changeId;
 final  List<String> _bookmarks;
@override List<String> get bookmarks {
  if (_bookmarks is EqualUnmodifiableListView) return _bookmarks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bookmarks);
}

@override final  String description;
@override final  bool conflict;
@override final  bool divergent;
@override final  bool empty;
@override final  bool current;
@override final  int modifiedFiles;
@override@JsonKey() final  String age;
@override@JsonKey() final  String path;
@override@JsonKey() final  int insertions;
@override@JsonKey() final  int deletions;

/// Create a copy of WorkspaceInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceInfoCopyWith<_WorkspaceInfo> get copyWith => __$WorkspaceInfoCopyWithImpl<_WorkspaceInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkspaceInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.changeId, changeId) || other.changeId == changeId)&&const DeepCollectionEquality().equals(other._bookmarks, _bookmarks)&&(identical(other.description, description) || other.description == description)&&(identical(other.conflict, conflict) || other.conflict == conflict)&&(identical(other.divergent, divergent) || other.divergent == divergent)&&(identical(other.empty, empty) || other.empty == empty)&&(identical(other.current, current) || other.current == current)&&(identical(other.modifiedFiles, modifiedFiles) || other.modifiedFiles == modifiedFiles)&&(identical(other.age, age) || other.age == age)&&(identical(other.path, path) || other.path == path)&&(identical(other.insertions, insertions) || other.insertions == insertions)&&(identical(other.deletions, deletions) || other.deletions == deletions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,changeId,const DeepCollectionEquality().hash(_bookmarks),description,conflict,divergent,empty,current,modifiedFiles,age,path,insertions,deletions);

@override
String toString() {
  return 'WorkspaceInfo(name: $name, changeId: $changeId, bookmarks: $bookmarks, description: $description, conflict: $conflict, divergent: $divergent, empty: $empty, current: $current, modifiedFiles: $modifiedFiles, age: $age, path: $path, insertions: $insertions, deletions: $deletions)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceInfoCopyWith<$Res> implements $WorkspaceInfoCopyWith<$Res> {
  factory _$WorkspaceInfoCopyWith(_WorkspaceInfo value, $Res Function(_WorkspaceInfo) _then) = __$WorkspaceInfoCopyWithImpl;
@override @useResult
$Res call({
 String name, String changeId, List<String> bookmarks, String description, bool conflict, bool divergent, bool empty, bool current, int modifiedFiles, String age, String path, int insertions, int deletions
});




}
/// @nodoc
class __$WorkspaceInfoCopyWithImpl<$Res>
    implements _$WorkspaceInfoCopyWith<$Res> {
  __$WorkspaceInfoCopyWithImpl(this._self, this._then);

  final _WorkspaceInfo _self;
  final $Res Function(_WorkspaceInfo) _then;

/// Create a copy of WorkspaceInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? changeId = null,Object? bookmarks = null,Object? description = null,Object? conflict = null,Object? divergent = null,Object? empty = null,Object? current = null,Object? modifiedFiles = null,Object? age = null,Object? path = null,Object? insertions = null,Object? deletions = null,}) {
  return _then(_WorkspaceInfo(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,changeId: null == changeId ? _self.changeId : changeId // ignore: cast_nullable_to_non_nullable
as String,bookmarks: null == bookmarks ? _self._bookmarks : bookmarks // ignore: cast_nullable_to_non_nullable
as List<String>,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,conflict: null == conflict ? _self.conflict : conflict // ignore: cast_nullable_to_non_nullable
as bool,divergent: null == divergent ? _self.divergent : divergent // ignore: cast_nullable_to_non_nullable
as bool,empty: null == empty ? _self.empty : empty // ignore: cast_nullable_to_non_nullable
as bool,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,modifiedFiles: null == modifiedFiles ? _self.modifiedFiles : modifiedFiles // ignore: cast_nullable_to_non_nullable
as int,age: null == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,insertions: null == insertions ? _self.insertions : insertions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
