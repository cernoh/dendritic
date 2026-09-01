// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MergeConfig {

 bool get squash; bool get rebase; bool get remove; bool get verify; bool get push;
/// Create a copy of MergeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MergeConfigCopyWith<MergeConfig> get copyWith => _$MergeConfigCopyWithImpl<MergeConfig>(this as MergeConfig, _$identity);

  /// Serializes this MergeConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MergeConfig&&(identical(other.squash, squash) || other.squash == squash)&&(identical(other.rebase, rebase) || other.rebase == rebase)&&(identical(other.remove, remove) || other.remove == remove)&&(identical(other.verify, verify) || other.verify == verify)&&(identical(other.push, push) || other.push == push));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,squash,rebase,remove,verify,push);

@override
String toString() {
  return 'MergeConfig(squash: $squash, rebase: $rebase, remove: $remove, verify: $verify, push: $push)';
}


}

/// @nodoc
abstract mixin class $MergeConfigCopyWith<$Res>  {
  factory $MergeConfigCopyWith(MergeConfig value, $Res Function(MergeConfig) _then) = _$MergeConfigCopyWithImpl;
@useResult
$Res call({
 bool squash, bool rebase, bool remove, bool verify, bool push
});




}
/// @nodoc
class _$MergeConfigCopyWithImpl<$Res>
    implements $MergeConfigCopyWith<$Res> {
  _$MergeConfigCopyWithImpl(this._self, this._then);

  final MergeConfig _self;
  final $Res Function(MergeConfig) _then;

/// Create a copy of MergeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? squash = null,Object? rebase = null,Object? remove = null,Object? verify = null,Object? push = null,}) {
  return _then(_self.copyWith(
squash: null == squash ? _self.squash : squash // ignore: cast_nullable_to_non_nullable
as bool,rebase: null == rebase ? _self.rebase : rebase // ignore: cast_nullable_to_non_nullable
as bool,remove: null == remove ? _self.remove : remove // ignore: cast_nullable_to_non_nullable
as bool,verify: null == verify ? _self.verify : verify // ignore: cast_nullable_to_non_nullable
as bool,push: null == push ? _self.push : push // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MergeConfig].
extension MergeConfigPatterns on MergeConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MergeConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MergeConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MergeConfig value)  $default,){
final _that = this;
switch (_that) {
case _MergeConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MergeConfig value)?  $default,){
final _that = this;
switch (_that) {
case _MergeConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool squash,  bool rebase,  bool remove,  bool verify,  bool push)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MergeConfig() when $default != null:
return $default(_that.squash,_that.rebase,_that.remove,_that.verify,_that.push);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool squash,  bool rebase,  bool remove,  bool verify,  bool push)  $default,) {final _that = this;
switch (_that) {
case _MergeConfig():
return $default(_that.squash,_that.rebase,_that.remove,_that.verify,_that.push);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool squash,  bool rebase,  bool remove,  bool verify,  bool push)?  $default,) {final _that = this;
switch (_that) {
case _MergeConfig() when $default != null:
return $default(_that.squash,_that.rebase,_that.remove,_that.verify,_that.push);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MergeConfig implements MergeConfig {
  const _MergeConfig({this.squash = true, this.rebase = true, this.remove = true, this.verify = true, this.push = false});
  factory _MergeConfig.fromJson(Map<String, dynamic> json) => _$MergeConfigFromJson(json);

@override@JsonKey() final  bool squash;
@override@JsonKey() final  bool rebase;
@override@JsonKey() final  bool remove;
@override@JsonKey() final  bool verify;
@override@JsonKey() final  bool push;

/// Create a copy of MergeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MergeConfigCopyWith<_MergeConfig> get copyWith => __$MergeConfigCopyWithImpl<_MergeConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MergeConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MergeConfig&&(identical(other.squash, squash) || other.squash == squash)&&(identical(other.rebase, rebase) || other.rebase == rebase)&&(identical(other.remove, remove) || other.remove == remove)&&(identical(other.verify, verify) || other.verify == verify)&&(identical(other.push, push) || other.push == push));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,squash,rebase,remove,verify,push);

@override
String toString() {
  return 'MergeConfig(squash: $squash, rebase: $rebase, remove: $remove, verify: $verify, push: $push)';
}


}

/// @nodoc
abstract mixin class _$MergeConfigCopyWith<$Res> implements $MergeConfigCopyWith<$Res> {
  factory _$MergeConfigCopyWith(_MergeConfig value, $Res Function(_MergeConfig) _then) = __$MergeConfigCopyWithImpl;
@override @useResult
$Res call({
 bool squash, bool rebase, bool remove, bool verify, bool push
});




}
/// @nodoc
class __$MergeConfigCopyWithImpl<$Res>
    implements _$MergeConfigCopyWith<$Res> {
  __$MergeConfigCopyWithImpl(this._self, this._then);

  final _MergeConfig _self;
  final $Res Function(_MergeConfig) _then;

/// Create a copy of MergeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? squash = null,Object? rebase = null,Object? remove = null,Object? verify = null,Object? push = null,}) {
  return _then(_MergeConfig(
squash: null == squash ? _self.squash : squash // ignore: cast_nullable_to_non_nullable
as bool,rebase: null == rebase ? _self.rebase : rebase // ignore: cast_nullable_to_non_nullable
as bool,remove: null == remove ? _self.remove : remove // ignore: cast_nullable_to_non_nullable
as bool,verify: null == verify ? _self.verify : verify // ignore: cast_nullable_to_non_nullable
as bool,push: null == push ? _self.push : push // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ListConfig {

 String get url;
/// Create a copy of ListConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ListConfigCopyWith<ListConfig> get copyWith => _$ListConfigCopyWithImpl<ListConfig>(this as ListConfig, _$identity);

  /// Serializes this ListConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ListConfig&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,url);

@override
String toString() {
  return 'ListConfig(url: $url)';
}


}

/// @nodoc
abstract mixin class $ListConfigCopyWith<$Res>  {
  factory $ListConfigCopyWith(ListConfig value, $Res Function(ListConfig) _then) = _$ListConfigCopyWithImpl;
@useResult
$Res call({
 String url
});




}
/// @nodoc
class _$ListConfigCopyWithImpl<$Res>
    implements $ListConfigCopyWith<$Res> {
  _$ListConfigCopyWithImpl(this._self, this._then);

  final ListConfig _self;
  final $Res Function(ListConfig) _then;

/// Create a copy of ListConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,}) {
  return _then(_self.copyWith(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ListConfig].
extension ListConfigPatterns on ListConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ListConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ListConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ListConfig value)  $default,){
final _that = this;
switch (_that) {
case _ListConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ListConfig value)?  $default,){
final _that = this;
switch (_that) {
case _ListConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ListConfig() when $default != null:
return $default(_that.url);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url)  $default,) {final _that = this;
switch (_that) {
case _ListConfig():
return $default(_that.url);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url)?  $default,) {final _that = this;
switch (_that) {
case _ListConfig() when $default != null:
return $default(_that.url);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ListConfig implements ListConfig {
  const _ListConfig({this.url = ''});
  factory _ListConfig.fromJson(Map<String, dynamic> json) => _$ListConfigFromJson(json);

@override@JsonKey() final  String url;

/// Create a copy of ListConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ListConfigCopyWith<_ListConfig> get copyWith => __$ListConfigCopyWithImpl<_ListConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ListConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ListConfig&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,url);

@override
String toString() {
  return 'ListConfig(url: $url)';
}


}

/// @nodoc
abstract mixin class _$ListConfigCopyWith<$Res> implements $ListConfigCopyWith<$Res> {
  factory _$ListConfigCopyWith(_ListConfig value, $Res Function(_ListConfig) _then) = __$ListConfigCopyWithImpl;
@override @useResult
$Res call({
 String url
});




}
/// @nodoc
class __$ListConfigCopyWithImpl<$Res>
    implements _$ListConfigCopyWith<$Res> {
  __$ListConfigCopyWithImpl(this._self, this._then);

  final _ListConfig _self;
  final $Res Function(_ListConfig) _then;

/// Create a copy of ListConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,}) {
  return _then(_ListConfig(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$HookEntry {

 String get name; String get command;
/// Create a copy of HookEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HookEntryCopyWith<HookEntry> get copyWith => _$HookEntryCopyWithImpl<HookEntry>(this as HookEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HookEntry&&(identical(other.name, name) || other.name == name)&&(identical(other.command, command) || other.command == command));
}


@override
int get hashCode => Object.hash(runtimeType,name,command);

@override
String toString() {
  return 'HookEntry(name: $name, command: $command)';
}


}

/// @nodoc
abstract mixin class $HookEntryCopyWith<$Res>  {
  factory $HookEntryCopyWith(HookEntry value, $Res Function(HookEntry) _then) = _$HookEntryCopyWithImpl;
@useResult
$Res call({
 String name, String command
});




}
/// @nodoc
class _$HookEntryCopyWithImpl<$Res>
    implements $HookEntryCopyWith<$Res> {
  _$HookEntryCopyWithImpl(this._self, this._then);

  final HookEntry _self;
  final $Res Function(HookEntry) _then;

/// Create a copy of HookEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? command = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [HookEntry].
extension HookEntryPatterns on HookEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HookEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HookEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HookEntry value)  $default,){
final _that = this;
switch (_that) {
case _HookEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HookEntry value)?  $default,){
final _that = this;
switch (_that) {
case _HookEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String command)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HookEntry() when $default != null:
return $default(_that.name,_that.command);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String command)  $default,) {final _that = this;
switch (_that) {
case _HookEntry():
return $default(_that.name,_that.command);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String command)?  $default,) {final _that = this;
switch (_that) {
case _HookEntry() when $default != null:
return $default(_that.name,_that.command);case _:
  return null;

}
}

}

/// @nodoc


class _HookEntry implements HookEntry {
  const _HookEntry({required this.name, required this.command});
  

@override final  String name;
@override final  String command;

/// Create a copy of HookEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HookEntryCopyWith<_HookEntry> get copyWith => __$HookEntryCopyWithImpl<_HookEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HookEntry&&(identical(other.name, name) || other.name == name)&&(identical(other.command, command) || other.command == command));
}


@override
int get hashCode => Object.hash(runtimeType,name,command);

@override
String toString() {
  return 'HookEntry(name: $name, command: $command)';
}


}

/// @nodoc
abstract mixin class _$HookEntryCopyWith<$Res> implements $HookEntryCopyWith<$Res> {
  factory _$HookEntryCopyWith(_HookEntry value, $Res Function(_HookEntry) _then) = __$HookEntryCopyWithImpl;
@override @useResult
$Res call({
 String name, String command
});




}
/// @nodoc
class __$HookEntryCopyWithImpl<$Res>
    implements _$HookEntryCopyWith<$Res> {
  __$HookEntryCopyWithImpl(this._self, this._then);

  final _HookEntry _self;
  final $Res Function(_HookEntry) _then;

/// Create a copy of HookEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? command = null,}) {
  return _then(_HookEntry(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CopyIgnoredConfig {

 List<String> get exclude;
/// Create a copy of CopyIgnoredConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CopyIgnoredConfigCopyWith<CopyIgnoredConfig> get copyWith => _$CopyIgnoredConfigCopyWithImpl<CopyIgnoredConfig>(this as CopyIgnoredConfig, _$identity);

  /// Serializes this CopyIgnoredConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CopyIgnoredConfig&&const DeepCollectionEquality().equals(other.exclude, exclude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(exclude));

@override
String toString() {
  return 'CopyIgnoredConfig(exclude: $exclude)';
}


}

/// @nodoc
abstract mixin class $CopyIgnoredConfigCopyWith<$Res>  {
  factory $CopyIgnoredConfigCopyWith(CopyIgnoredConfig value, $Res Function(CopyIgnoredConfig) _then) = _$CopyIgnoredConfigCopyWithImpl;
@useResult
$Res call({
 List<String> exclude
});




}
/// @nodoc
class _$CopyIgnoredConfigCopyWithImpl<$Res>
    implements $CopyIgnoredConfigCopyWith<$Res> {
  _$CopyIgnoredConfigCopyWithImpl(this._self, this._then);

  final CopyIgnoredConfig _self;
  final $Res Function(CopyIgnoredConfig) _then;

/// Create a copy of CopyIgnoredConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? exclude = null,}) {
  return _then(_self.copyWith(
exclude: null == exclude ? _self.exclude : exclude // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [CopyIgnoredConfig].
extension CopyIgnoredConfigPatterns on CopyIgnoredConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CopyIgnoredConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CopyIgnoredConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CopyIgnoredConfig value)  $default,){
final _that = this;
switch (_that) {
case _CopyIgnoredConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CopyIgnoredConfig value)?  $default,){
final _that = this;
switch (_that) {
case _CopyIgnoredConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> exclude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CopyIgnoredConfig() when $default != null:
return $default(_that.exclude);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> exclude)  $default,) {final _that = this;
switch (_that) {
case _CopyIgnoredConfig():
return $default(_that.exclude);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> exclude)?  $default,) {final _that = this;
switch (_that) {
case _CopyIgnoredConfig() when $default != null:
return $default(_that.exclude);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CopyIgnoredConfig implements CopyIgnoredConfig {
  const _CopyIgnoredConfig({final  List<String> exclude = const <String>[]}): _exclude = exclude;
  factory _CopyIgnoredConfig.fromJson(Map<String, dynamic> json) => _$CopyIgnoredConfigFromJson(json);

 final  List<String> _exclude;
@override@JsonKey() List<String> get exclude {
  if (_exclude is EqualUnmodifiableListView) return _exclude;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_exclude);
}


/// Create a copy of CopyIgnoredConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CopyIgnoredConfigCopyWith<_CopyIgnoredConfig> get copyWith => __$CopyIgnoredConfigCopyWithImpl<_CopyIgnoredConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CopyIgnoredConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CopyIgnoredConfig&&const DeepCollectionEquality().equals(other._exclude, _exclude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_exclude));

@override
String toString() {
  return 'CopyIgnoredConfig(exclude: $exclude)';
}


}

/// @nodoc
abstract mixin class _$CopyIgnoredConfigCopyWith<$Res> implements $CopyIgnoredConfigCopyWith<$Res> {
  factory _$CopyIgnoredConfigCopyWith(_CopyIgnoredConfig value, $Res Function(_CopyIgnoredConfig) _then) = __$CopyIgnoredConfigCopyWithImpl;
@override @useResult
$Res call({
 List<String> exclude
});




}
/// @nodoc
class __$CopyIgnoredConfigCopyWithImpl<$Res>
    implements _$CopyIgnoredConfigCopyWith<$Res> {
  __$CopyIgnoredConfigCopyWithImpl(this._self, this._then);

  final _CopyIgnoredConfig _self;
  final $Res Function(_CopyIgnoredConfig) _then;

/// Create a copy of CopyIgnoredConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? exclude = null,}) {
  return _then(_CopyIgnoredConfig(
exclude: null == exclude ? _self._exclude : exclude // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$IgnoreWorktrunkHooks {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IgnoreWorktrunkHooks);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'IgnoreWorktrunkHooks()';
}


}

/// @nodoc
class $IgnoreWorktrunkHooksCopyWith<$Res>  {
$IgnoreWorktrunkHooksCopyWith(IgnoreWorktrunkHooks _, $Res Function(IgnoreWorktrunkHooks) __);
}


/// Adds pattern-matching-related methods to [IgnoreWorktrunkHooks].
extension IgnoreWorktrunkHooksPatterns on IgnoreWorktrunkHooks {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( IgnoreWorktrunkHooksNone value)?  none,TResult Function( IgnoreWorktrunkHooksAll value)?  all,TResult Function( IgnoreWorktrunkHooksTypes value)?  types,required TResult orElse(),}){
final _that = this;
switch (_that) {
case IgnoreWorktrunkHooksNone() when none != null:
return none(_that);case IgnoreWorktrunkHooksAll() when all != null:
return all(_that);case IgnoreWorktrunkHooksTypes() when types != null:
return types(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( IgnoreWorktrunkHooksNone value)  none,required TResult Function( IgnoreWorktrunkHooksAll value)  all,required TResult Function( IgnoreWorktrunkHooksTypes value)  types,}){
final _that = this;
switch (_that) {
case IgnoreWorktrunkHooksNone():
return none(_that);case IgnoreWorktrunkHooksAll():
return all(_that);case IgnoreWorktrunkHooksTypes():
return types(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( IgnoreWorktrunkHooksNone value)?  none,TResult? Function( IgnoreWorktrunkHooksAll value)?  all,TResult? Function( IgnoreWorktrunkHooksTypes value)?  types,}){
final _that = this;
switch (_that) {
case IgnoreWorktrunkHooksNone() when none != null:
return none(_that);case IgnoreWorktrunkHooksAll() when all != null:
return all(_that);case IgnoreWorktrunkHooksTypes() when types != null:
return types(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  none,TResult Function()?  all,TResult Function( List<String> types)?  types,required TResult orElse(),}) {final _that = this;
switch (_that) {
case IgnoreWorktrunkHooksNone() when none != null:
return none();case IgnoreWorktrunkHooksAll() when all != null:
return all();case IgnoreWorktrunkHooksTypes() when types != null:
return types(_that.types);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  none,required TResult Function()  all,required TResult Function( List<String> types)  types,}) {final _that = this;
switch (_that) {
case IgnoreWorktrunkHooksNone():
return none();case IgnoreWorktrunkHooksAll():
return all();case IgnoreWorktrunkHooksTypes():
return types(_that.types);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  none,TResult? Function()?  all,TResult? Function( List<String> types)?  types,}) {final _that = this;
switch (_that) {
case IgnoreWorktrunkHooksNone() when none != null:
return none();case IgnoreWorktrunkHooksAll() when all != null:
return all();case IgnoreWorktrunkHooksTypes() when types != null:
return types(_that.types);case _:
  return null;

}
}

}

/// @nodoc


class IgnoreWorktrunkHooksNone implements IgnoreWorktrunkHooks {
  const IgnoreWorktrunkHooksNone();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IgnoreWorktrunkHooksNone);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'IgnoreWorktrunkHooks.none()';
}


}




/// @nodoc


class IgnoreWorktrunkHooksAll implements IgnoreWorktrunkHooks {
  const IgnoreWorktrunkHooksAll();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IgnoreWorktrunkHooksAll);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'IgnoreWorktrunkHooks.all()';
}


}




/// @nodoc


class IgnoreWorktrunkHooksTypes implements IgnoreWorktrunkHooks {
  const IgnoreWorktrunkHooksTypes(final  List<String> types): _types = types;
  

 final  List<String> _types;
 List<String> get types {
  if (_types is EqualUnmodifiableListView) return _types;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_types);
}


/// Create a copy of IgnoreWorktrunkHooks
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IgnoreWorktrunkHooksTypesCopyWith<IgnoreWorktrunkHooksTypes> get copyWith => _$IgnoreWorktrunkHooksTypesCopyWithImpl<IgnoreWorktrunkHooksTypes>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IgnoreWorktrunkHooksTypes&&const DeepCollectionEquality().equals(other._types, _types));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_types));

@override
String toString() {
  return 'IgnoreWorktrunkHooks.types(types: $types)';
}


}

/// @nodoc
abstract mixin class $IgnoreWorktrunkHooksTypesCopyWith<$Res> implements $IgnoreWorktrunkHooksCopyWith<$Res> {
  factory $IgnoreWorktrunkHooksTypesCopyWith(IgnoreWorktrunkHooksTypes value, $Res Function(IgnoreWorktrunkHooksTypes) _then) = _$IgnoreWorktrunkHooksTypesCopyWithImpl;
@useResult
$Res call({
 List<String> types
});




}
/// @nodoc
class _$IgnoreWorktrunkHooksTypesCopyWithImpl<$Res>
    implements $IgnoreWorktrunkHooksTypesCopyWith<$Res> {
  _$IgnoreWorktrunkHooksTypesCopyWithImpl(this._self, this._then);

  final IgnoreWorktrunkHooksTypes _self;
  final $Res Function(IgnoreWorktrunkHooksTypes) _then;

/// Create a copy of IgnoreWorktrunkHooks
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? types = null,}) {
  return _then(IgnoreWorktrunkHooksTypes(
null == types ? _self._types : types // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$Config {

 bool get createBookmark; String get workspacePath; MergeConfig get merge; ListConfig get list; CopyIgnoredConfig get copyIgnored;@JsonKey(includeFromJson: false, includeToJson: false) HookMap get aliases;@JsonKey(includeFromJson: false, includeToJson: false) HookMap get hooks;@JsonKey(includeFromJson: false, includeToJson: false) IgnoreWorktrunkHooks get ignoreWorktrunkHooks;
/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfigCopyWith<Config> get copyWith => _$ConfigCopyWithImpl<Config>(this as Config, _$identity);

  /// Serializes this Config to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Config&&(identical(other.createBookmark, createBookmark) || other.createBookmark == createBookmark)&&(identical(other.workspacePath, workspacePath) || other.workspacePath == workspacePath)&&(identical(other.merge, merge) || other.merge == merge)&&(identical(other.list, list) || other.list == list)&&(identical(other.copyIgnored, copyIgnored) || other.copyIgnored == copyIgnored)&&const DeepCollectionEquality().equals(other.aliases, aliases)&&const DeepCollectionEquality().equals(other.hooks, hooks)&&(identical(other.ignoreWorktrunkHooks, ignoreWorktrunkHooks) || other.ignoreWorktrunkHooks == ignoreWorktrunkHooks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,createBookmark,workspacePath,merge,list,copyIgnored,const DeepCollectionEquality().hash(aliases),const DeepCollectionEquality().hash(hooks),ignoreWorktrunkHooks);

@override
String toString() {
  return 'Config(createBookmark: $createBookmark, workspacePath: $workspacePath, merge: $merge, list: $list, copyIgnored: $copyIgnored, aliases: $aliases, hooks: $hooks, ignoreWorktrunkHooks: $ignoreWorktrunkHooks)';
}


}

/// @nodoc
abstract mixin class $ConfigCopyWith<$Res>  {
  factory $ConfigCopyWith(Config value, $Res Function(Config) _then) = _$ConfigCopyWithImpl;
@useResult
$Res call({
 bool createBookmark, String workspacePath, MergeConfig merge, ListConfig list, CopyIgnoredConfig copyIgnored,@JsonKey(includeFromJson: false, includeToJson: false) HookMap aliases,@JsonKey(includeFromJson: false, includeToJson: false) HookMap hooks,@JsonKey(includeFromJson: false, includeToJson: false) IgnoreWorktrunkHooks ignoreWorktrunkHooks
});


$MergeConfigCopyWith<$Res> get merge;$ListConfigCopyWith<$Res> get list;$CopyIgnoredConfigCopyWith<$Res> get copyIgnored;$IgnoreWorktrunkHooksCopyWith<$Res> get ignoreWorktrunkHooks;

}
/// @nodoc
class _$ConfigCopyWithImpl<$Res>
    implements $ConfigCopyWith<$Res> {
  _$ConfigCopyWithImpl(this._self, this._then);

  final Config _self;
  final $Res Function(Config) _then;

/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? createBookmark = null,Object? workspacePath = null,Object? merge = null,Object? list = null,Object? copyIgnored = null,Object? aliases = null,Object? hooks = null,Object? ignoreWorktrunkHooks = null,}) {
  return _then(_self.copyWith(
createBookmark: null == createBookmark ? _self.createBookmark : createBookmark // ignore: cast_nullable_to_non_nullable
as bool,workspacePath: null == workspacePath ? _self.workspacePath : workspacePath // ignore: cast_nullable_to_non_nullable
as String,merge: null == merge ? _self.merge : merge // ignore: cast_nullable_to_non_nullable
as MergeConfig,list: null == list ? _self.list : list // ignore: cast_nullable_to_non_nullable
as ListConfig,copyIgnored: null == copyIgnored ? _self.copyIgnored : copyIgnored // ignore: cast_nullable_to_non_nullable
as CopyIgnoredConfig,aliases: null == aliases ? _self.aliases : aliases // ignore: cast_nullable_to_non_nullable
as HookMap,hooks: null == hooks ? _self.hooks : hooks // ignore: cast_nullable_to_non_nullable
as HookMap,ignoreWorktrunkHooks: null == ignoreWorktrunkHooks ? _self.ignoreWorktrunkHooks : ignoreWorktrunkHooks // ignore: cast_nullable_to_non_nullable
as IgnoreWorktrunkHooks,
  ));
}
/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MergeConfigCopyWith<$Res> get merge {
  
  return $MergeConfigCopyWith<$Res>(_self.merge, (value) {
    return _then(_self.copyWith(merge: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ListConfigCopyWith<$Res> get list {
  
  return $ListConfigCopyWith<$Res>(_self.list, (value) {
    return _then(_self.copyWith(list: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CopyIgnoredConfigCopyWith<$Res> get copyIgnored {
  
  return $CopyIgnoredConfigCopyWith<$Res>(_self.copyIgnored, (value) {
    return _then(_self.copyWith(copyIgnored: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IgnoreWorktrunkHooksCopyWith<$Res> get ignoreWorktrunkHooks {
  
  return $IgnoreWorktrunkHooksCopyWith<$Res>(_self.ignoreWorktrunkHooks, (value) {
    return _then(_self.copyWith(ignoreWorktrunkHooks: value));
  });
}
}


/// Adds pattern-matching-related methods to [Config].
extension ConfigPatterns on Config {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Config value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Config() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Config value)  $default,){
final _that = this;
switch (_that) {
case _Config():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Config value)?  $default,){
final _that = this;
switch (_that) {
case _Config() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool createBookmark,  String workspacePath,  MergeConfig merge,  ListConfig list,  CopyIgnoredConfig copyIgnored, @JsonKey(includeFromJson: false, includeToJson: false)  HookMap aliases, @JsonKey(includeFromJson: false, includeToJson: false)  HookMap hooks, @JsonKey(includeFromJson: false, includeToJson: false)  IgnoreWorktrunkHooks ignoreWorktrunkHooks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Config() when $default != null:
return $default(_that.createBookmark,_that.workspacePath,_that.merge,_that.list,_that.copyIgnored,_that.aliases,_that.hooks,_that.ignoreWorktrunkHooks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool createBookmark,  String workspacePath,  MergeConfig merge,  ListConfig list,  CopyIgnoredConfig copyIgnored, @JsonKey(includeFromJson: false, includeToJson: false)  HookMap aliases, @JsonKey(includeFromJson: false, includeToJson: false)  HookMap hooks, @JsonKey(includeFromJson: false, includeToJson: false)  IgnoreWorktrunkHooks ignoreWorktrunkHooks)  $default,) {final _that = this;
switch (_that) {
case _Config():
return $default(_that.createBookmark,_that.workspacePath,_that.merge,_that.list,_that.copyIgnored,_that.aliases,_that.hooks,_that.ignoreWorktrunkHooks);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool createBookmark,  String workspacePath,  MergeConfig merge,  ListConfig list,  CopyIgnoredConfig copyIgnored, @JsonKey(includeFromJson: false, includeToJson: false)  HookMap aliases, @JsonKey(includeFromJson: false, includeToJson: false)  HookMap hooks, @JsonKey(includeFromJson: false, includeToJson: false)  IgnoreWorktrunkHooks ignoreWorktrunkHooks)?  $default,) {final _that = this;
switch (_that) {
case _Config() when $default != null:
return $default(_that.createBookmark,_that.workspacePath,_that.merge,_that.list,_that.copyIgnored,_that.aliases,_that.hooks,_that.ignoreWorktrunkHooks);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.kebab)
class _Config implements Config {
  const _Config({this.createBookmark = true, this.workspacePath = '', this.merge = const MergeConfig(), this.list = const ListConfig(), this.copyIgnored = const CopyIgnoredConfig(), @JsonKey(includeFromJson: false, includeToJson: false) final  HookMap aliases = const <String, HookPipeline>{}, @JsonKey(includeFromJson: false, includeToJson: false) final  HookMap hooks = const <String, HookPipeline>{}, @JsonKey(includeFromJson: false, includeToJson: false) this.ignoreWorktrunkHooks = const IgnoreWorktrunkHooks.none()}): _aliases = aliases,_hooks = hooks;
  factory _Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);

@override@JsonKey() final  bool createBookmark;
@override@JsonKey() final  String workspacePath;
@override@JsonKey() final  MergeConfig merge;
@override@JsonKey() final  ListConfig list;
@override@JsonKey() final  CopyIgnoredConfig copyIgnored;
 final  HookMap _aliases;
@override@JsonKey(includeFromJson: false, includeToJson: false) HookMap get aliases {
  if (_aliases is EqualUnmodifiableMapView) return _aliases;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_aliases);
}

 final  HookMap _hooks;
@override@JsonKey(includeFromJson: false, includeToJson: false) HookMap get hooks {
  if (_hooks is EqualUnmodifiableMapView) return _hooks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_hooks);
}

@override@JsonKey(includeFromJson: false, includeToJson: false) final  IgnoreWorktrunkHooks ignoreWorktrunkHooks;

/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConfigCopyWith<_Config> get copyWith => __$ConfigCopyWithImpl<_Config>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Config&&(identical(other.createBookmark, createBookmark) || other.createBookmark == createBookmark)&&(identical(other.workspacePath, workspacePath) || other.workspacePath == workspacePath)&&(identical(other.merge, merge) || other.merge == merge)&&(identical(other.list, list) || other.list == list)&&(identical(other.copyIgnored, copyIgnored) || other.copyIgnored == copyIgnored)&&const DeepCollectionEquality().equals(other._aliases, _aliases)&&const DeepCollectionEquality().equals(other._hooks, _hooks)&&(identical(other.ignoreWorktrunkHooks, ignoreWorktrunkHooks) || other.ignoreWorktrunkHooks == ignoreWorktrunkHooks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,createBookmark,workspacePath,merge,list,copyIgnored,const DeepCollectionEquality().hash(_aliases),const DeepCollectionEquality().hash(_hooks),ignoreWorktrunkHooks);

@override
String toString() {
  return 'Config(createBookmark: $createBookmark, workspacePath: $workspacePath, merge: $merge, list: $list, copyIgnored: $copyIgnored, aliases: $aliases, hooks: $hooks, ignoreWorktrunkHooks: $ignoreWorktrunkHooks)';
}


}

/// @nodoc
abstract mixin class _$ConfigCopyWith<$Res> implements $ConfigCopyWith<$Res> {
  factory _$ConfigCopyWith(_Config value, $Res Function(_Config) _then) = __$ConfigCopyWithImpl;
@override @useResult
$Res call({
 bool createBookmark, String workspacePath, MergeConfig merge, ListConfig list, CopyIgnoredConfig copyIgnored,@JsonKey(includeFromJson: false, includeToJson: false) HookMap aliases,@JsonKey(includeFromJson: false, includeToJson: false) HookMap hooks,@JsonKey(includeFromJson: false, includeToJson: false) IgnoreWorktrunkHooks ignoreWorktrunkHooks
});


@override $MergeConfigCopyWith<$Res> get merge;@override $ListConfigCopyWith<$Res> get list;@override $CopyIgnoredConfigCopyWith<$Res> get copyIgnored;@override $IgnoreWorktrunkHooksCopyWith<$Res> get ignoreWorktrunkHooks;

}
/// @nodoc
class __$ConfigCopyWithImpl<$Res>
    implements _$ConfigCopyWith<$Res> {
  __$ConfigCopyWithImpl(this._self, this._then);

  final _Config _self;
  final $Res Function(_Config) _then;

/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? createBookmark = null,Object? workspacePath = null,Object? merge = null,Object? list = null,Object? copyIgnored = null,Object? aliases = null,Object? hooks = null,Object? ignoreWorktrunkHooks = null,}) {
  return _then(_Config(
createBookmark: null == createBookmark ? _self.createBookmark : createBookmark // ignore: cast_nullable_to_non_nullable
as bool,workspacePath: null == workspacePath ? _self.workspacePath : workspacePath // ignore: cast_nullable_to_non_nullable
as String,merge: null == merge ? _self.merge : merge // ignore: cast_nullable_to_non_nullable
as MergeConfig,list: null == list ? _self.list : list // ignore: cast_nullable_to_non_nullable
as ListConfig,copyIgnored: null == copyIgnored ? _self.copyIgnored : copyIgnored // ignore: cast_nullable_to_non_nullable
as CopyIgnoredConfig,aliases: null == aliases ? _self._aliases : aliases // ignore: cast_nullable_to_non_nullable
as HookMap,hooks: null == hooks ? _self._hooks : hooks // ignore: cast_nullable_to_non_nullable
as HookMap,ignoreWorktrunkHooks: null == ignoreWorktrunkHooks ? _self.ignoreWorktrunkHooks : ignoreWorktrunkHooks // ignore: cast_nullable_to_non_nullable
as IgnoreWorktrunkHooks,
  ));
}

/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MergeConfigCopyWith<$Res> get merge {
  
  return $MergeConfigCopyWith<$Res>(_self.merge, (value) {
    return _then(_self.copyWith(merge: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ListConfigCopyWith<$Res> get list {
  
  return $ListConfigCopyWith<$Res>(_self.list, (value) {
    return _then(_self.copyWith(list: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CopyIgnoredConfigCopyWith<$Res> get copyIgnored {
  
  return $CopyIgnoredConfigCopyWith<$Res>(_self.copyIgnored, (value) {
    return _then(_self.copyWith(copyIgnored: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IgnoreWorktrunkHooksCopyWith<$Res> get ignoreWorktrunkHooks {
  
  return $IgnoreWorktrunkHooksCopyWith<$Res>(_self.ignoreWorktrunkHooks, (value) {
    return _then(_self.copyWith(ignoreWorktrunkHooks: value));
  });
}
}

/// @nodoc
mixin _$ConfigWithSource {

 Config get config; List<String> get sources;
/// Create a copy of ConfigWithSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfigWithSourceCopyWith<ConfigWithSource> get copyWith => _$ConfigWithSourceCopyWithImpl<ConfigWithSource>(this as ConfigWithSource, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfigWithSource&&(identical(other.config, config) || other.config == config)&&const DeepCollectionEquality().equals(other.sources, sources));
}


@override
int get hashCode => Object.hash(runtimeType,config,const DeepCollectionEquality().hash(sources));

@override
String toString() {
  return 'ConfigWithSource(config: $config, sources: $sources)';
}


}

/// @nodoc
abstract mixin class $ConfigWithSourceCopyWith<$Res>  {
  factory $ConfigWithSourceCopyWith(ConfigWithSource value, $Res Function(ConfigWithSource) _then) = _$ConfigWithSourceCopyWithImpl;
@useResult
$Res call({
 Config config, List<String> sources
});


$ConfigCopyWith<$Res> get config;

}
/// @nodoc
class _$ConfigWithSourceCopyWithImpl<$Res>
    implements $ConfigWithSourceCopyWith<$Res> {
  _$ConfigWithSourceCopyWithImpl(this._self, this._then);

  final ConfigWithSource _self;
  final $Res Function(ConfigWithSource) _then;

/// Create a copy of ConfigWithSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? config = null,Object? sources = null,}) {
  return _then(_self.copyWith(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as Config,sources: null == sources ? _self.sources : sources // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of ConfigWithSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConfigCopyWith<$Res> get config {
  
  return $ConfigCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConfigWithSource].
extension ConfigWithSourcePatterns on ConfigWithSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConfigWithSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConfigWithSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConfigWithSource value)  $default,){
final _that = this;
switch (_that) {
case _ConfigWithSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConfigWithSource value)?  $default,){
final _that = this;
switch (_that) {
case _ConfigWithSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Config config,  List<String> sources)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConfigWithSource() when $default != null:
return $default(_that.config,_that.sources);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Config config,  List<String> sources)  $default,) {final _that = this;
switch (_that) {
case _ConfigWithSource():
return $default(_that.config,_that.sources);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Config config,  List<String> sources)?  $default,) {final _that = this;
switch (_that) {
case _ConfigWithSource() when $default != null:
return $default(_that.config,_that.sources);case _:
  return null;

}
}

}

/// @nodoc


class _ConfigWithSource implements ConfigWithSource {
  const _ConfigWithSource({required this.config, final  List<String> sources = const <String>[]}): _sources = sources;
  

@override final  Config config;
 final  List<String> _sources;
@override@JsonKey() List<String> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}


/// Create a copy of ConfigWithSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConfigWithSourceCopyWith<_ConfigWithSource> get copyWith => __$ConfigWithSourceCopyWithImpl<_ConfigWithSource>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConfigWithSource&&(identical(other.config, config) || other.config == config)&&const DeepCollectionEquality().equals(other._sources, _sources));
}


@override
int get hashCode => Object.hash(runtimeType,config,const DeepCollectionEquality().hash(_sources));

@override
String toString() {
  return 'ConfigWithSource(config: $config, sources: $sources)';
}


}

/// @nodoc
abstract mixin class _$ConfigWithSourceCopyWith<$Res> implements $ConfigWithSourceCopyWith<$Res> {
  factory _$ConfigWithSourceCopyWith(_ConfigWithSource value, $Res Function(_ConfigWithSource) _then) = __$ConfigWithSourceCopyWithImpl;
@override @useResult
$Res call({
 Config config, List<String> sources
});


@override $ConfigCopyWith<$Res> get config;

}
/// @nodoc
class __$ConfigWithSourceCopyWithImpl<$Res>
    implements _$ConfigWithSourceCopyWith<$Res> {
  __$ConfigWithSourceCopyWithImpl(this._self, this._then);

  final _ConfigWithSource _self;
  final $Res Function(_ConfigWithSource) _then;

/// Create a copy of ConfigWithSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? config = null,Object? sources = null,}) {
  return _then(_ConfigWithSource(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as Config,sources: null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of ConfigWithSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConfigCopyWith<$Res> get config {
  
  return $ConfigCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}

// dart format on
