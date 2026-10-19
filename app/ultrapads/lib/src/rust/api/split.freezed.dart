// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'split.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SplitProgress {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SplitProgress);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SplitProgress()';
}


}

/// @nodoc
class $SplitProgressCopyWith<$Res>  {
$SplitProgressCopyWith(SplitProgress _, $Res Function(SplitProgress) __);
}


/// Adds pattern-matching-related methods to [SplitProgress].
extension SplitProgressPatterns on SplitProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SplitProgress_Progress value)?  progress,TResult Function( SplitProgress_Done value)?  done,TResult Function( SplitProgress_Failed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SplitProgress_Progress() when progress != null:
return progress(_that);case SplitProgress_Done() when done != null:
return done(_that);case SplitProgress_Failed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SplitProgress_Progress value)  progress,required TResult Function( SplitProgress_Done value)  done,required TResult Function( SplitProgress_Failed value)  failed,}){
final _that = this;
switch (_that) {
case SplitProgress_Progress():
return progress(_that);case SplitProgress_Done():
return done(_that);case SplitProgress_Failed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SplitProgress_Progress value)?  progress,TResult? Function( SplitProgress_Done value)?  done,TResult? Function( SplitProgress_Failed value)?  failed,}){
final _that = this;
switch (_that) {
case SplitProgress_Progress() when progress != null:
return progress(_that);case SplitProgress_Done() when done != null:
return done(_that);case SplitProgress_Failed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( SplitStage stage,  double fraction)?  progress,TResult Function( KitSummary kit,  double bpm,  int sections,  bool reliable,  bool separated)?  done,TResult Function( UpError error)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SplitProgress_Progress() when progress != null:
return progress(_that.stage,_that.fraction);case SplitProgress_Done() when done != null:
return done(_that.kit,_that.bpm,_that.sections,_that.reliable,_that.separated);case SplitProgress_Failed() when failed != null:
return failed(_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( SplitStage stage,  double fraction)  progress,required TResult Function( KitSummary kit,  double bpm,  int sections,  bool reliable,  bool separated)  done,required TResult Function( UpError error)  failed,}) {final _that = this;
switch (_that) {
case SplitProgress_Progress():
return progress(_that.stage,_that.fraction);case SplitProgress_Done():
return done(_that.kit,_that.bpm,_that.sections,_that.reliable,_that.separated);case SplitProgress_Failed():
return failed(_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( SplitStage stage,  double fraction)?  progress,TResult? Function( KitSummary kit,  double bpm,  int sections,  bool reliable,  bool separated)?  done,TResult? Function( UpError error)?  failed,}) {final _that = this;
switch (_that) {
case SplitProgress_Progress() when progress != null:
return progress(_that.stage,_that.fraction);case SplitProgress_Done() when done != null:
return done(_that.kit,_that.bpm,_that.sections,_that.reliable,_that.separated);case SplitProgress_Failed() when failed != null:
return failed(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class SplitProgress_Progress extends SplitProgress {
  const SplitProgress_Progress({required this.stage, required this.fraction}): super._();
  

 final  SplitStage stage;
/// 0..=1，该阶段内的完成比例。
 final  double fraction;

/// Create a copy of SplitProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SplitProgress_ProgressCopyWith<SplitProgress_Progress> get copyWith => _$SplitProgress_ProgressCopyWithImpl<SplitProgress_Progress>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SplitProgress_Progress&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.fraction, fraction) || other.fraction == fraction));
}


@override
int get hashCode {
    return Object.hash(runtimeType,stage,fraction);
}

@override
String toString() {
    return 'SplitProgress.progress(stage: $stage, fraction: $fraction)';
}


}

/// @nodoc
abstract mixin class $SplitProgress_ProgressCopyWith<$Res> implements $SplitProgressCopyWith<$Res> {
  factory $SplitProgress_ProgressCopyWith(SplitProgress_Progress value, $Res Function(SplitProgress_Progress) _then) = _$SplitProgress_ProgressCopyWithImpl;
@useResult
$Res call({
 SplitStage stage, double fraction
});




}
/// @nodoc
class _$SplitProgress_ProgressCopyWithImpl<$Res>
    implements $SplitProgress_ProgressCopyWith<$Res> {
  _$SplitProgress_ProgressCopyWithImpl(this._self, this._then);

  final SplitProgress_Progress _self;
  final $Res Function(SplitProgress_Progress) _then;

/// Create a copy of SplitProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? stage = null,Object? fraction = null,}) {
  return _then(SplitProgress_Progress(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as SplitStage,fraction: null == fraction ? _self.fraction : fraction // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class SplitProgress_Done extends SplitProgress {
  const SplitProgress_Done({required this.kit, required this.bpm, required this.sections, required this.reliable, required this.separated}): super._();
  

 final  KitSummary kit;
 final  double bpm;
 final  int sections;
/// 速度 / 小节估计是否可靠（不可靠时界面应提示可能偏拍）。
 final  bool reliable;
 final  bool separated;

/// Create a copy of SplitProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SplitProgress_DoneCopyWith<SplitProgress_Done> get copyWith => _$SplitProgress_DoneCopyWithImpl<SplitProgress_Done>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SplitProgress_Done&&(identical(other.kit, kit) || other.kit == kit)&&(identical(other.bpm, bpm) || other.bpm == bpm)&&(identical(other.sections, sections) || other.sections == sections)&&(identical(other.reliable, reliable) || other.reliable == reliable)&&(identical(other.separated, separated) || other.separated == separated));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kit,bpm,sections,reliable,separated);
}

@override
String toString() {
    return 'SplitProgress.done(kit: $kit, bpm: $bpm, sections: $sections, reliable: $reliable, separated: $separated)';
}


}

/// @nodoc
abstract mixin class $SplitProgress_DoneCopyWith<$Res> implements $SplitProgressCopyWith<$Res> {
  factory $SplitProgress_DoneCopyWith(SplitProgress_Done value, $Res Function(SplitProgress_Done) _then) = _$SplitProgress_DoneCopyWithImpl;
@useResult
$Res call({
 KitSummary kit, double bpm, int sections, bool reliable, bool separated
});




}
/// @nodoc
class _$SplitProgress_DoneCopyWithImpl<$Res>
    implements $SplitProgress_DoneCopyWith<$Res> {
  _$SplitProgress_DoneCopyWithImpl(this._self, this._then);

  final SplitProgress_Done _self;
  final $Res Function(SplitProgress_Done) _then;

/// Create a copy of SplitProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kit = null,Object? bpm = null,Object? sections = null,Object? reliable = null,Object? separated = null,}) {
  return _then(SplitProgress_Done(
kit: null == kit ? _self.kit : kit // ignore: cast_nullable_to_non_nullable
as KitSummary,bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double,sections: null == sections ? _self.sections : sections // ignore: cast_nullable_to_non_nullable
as int,reliable: null == reliable ? _self.reliable : reliable // ignore: cast_nullable_to_non_nullable
as bool,separated: null == separated ? _self.separated : separated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class SplitProgress_Failed extends SplitProgress {
  const SplitProgress_Failed({required this.error}): super._();
  

 final  UpError error;

/// Create a copy of SplitProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SplitProgress_FailedCopyWith<SplitProgress_Failed> get copyWith => _$SplitProgress_FailedCopyWithImpl<SplitProgress_Failed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SplitProgress_Failed&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,error);
}

@override
String toString() {
    return 'SplitProgress.failed(error: $error)';
}


}

/// @nodoc
abstract mixin class $SplitProgress_FailedCopyWith<$Res> implements $SplitProgressCopyWith<$Res> {
  factory $SplitProgress_FailedCopyWith(SplitProgress_Failed value, $Res Function(SplitProgress_Failed) _then) = _$SplitProgress_FailedCopyWithImpl;
@useResult
$Res call({
 UpError error
});




}
/// @nodoc
class _$SplitProgress_FailedCopyWithImpl<$Res>
    implements $SplitProgress_FailedCopyWith<$Res> {
  _$SplitProgress_FailedCopyWithImpl(this._self, this._then);

  final SplitProgress_Failed _self;
  final $Res Function(SplitProgress_Failed) _then;

/// Create a copy of SplitProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(SplitProgress_Failed(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as UpError,
  ));
}


}

// dart format on
