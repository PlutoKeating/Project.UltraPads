// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'types.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Command {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Command()';
}


}

/// @nodoc
class $CommandCopyWith<$Res>  {
$CommandCopyWith(Command _, $Res Function(Command) __);
}


/// Adds pattern-matching-related methods to [Command].
extension CommandPatterns on Command {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Command_PadDown value)?  padDown,TResult Function( Command_PadUp value)?  padUp,TResult Function( Command_StopAll value)?  stopAll,TResult Function( Command_SetTempo value)?  setTempo,TResult Function( Command_SetSpeed value)?  setSpeed,TResult Function( Command_SetQuantize value)?  setQuantize,TResult Function( Command_SetPadParams value)?  setPadParams,TResult Function( Command_SetMasterGain value)?  setMasterGain,TResult Function( Command_StartRecording value)?  startRecording,TResult Function( Command_StopRecording value)?  stopRecording,TResult Function( Command_Transport value)?  transport,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Command_PadDown() when padDown != null:
return padDown(_that);case Command_PadUp() when padUp != null:
return padUp(_that);case Command_StopAll() when stopAll != null:
return stopAll(_that);case Command_SetTempo() when setTempo != null:
return setTempo(_that);case Command_SetSpeed() when setSpeed != null:
return setSpeed(_that);case Command_SetQuantize() when setQuantize != null:
return setQuantize(_that);case Command_SetPadParams() when setPadParams != null:
return setPadParams(_that);case Command_SetMasterGain() when setMasterGain != null:
return setMasterGain(_that);case Command_StartRecording() when startRecording != null:
return startRecording(_that);case Command_StopRecording() when stopRecording != null:
return stopRecording(_that);case Command_Transport() when transport != null:
return transport(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Command_PadDown value)  padDown,required TResult Function( Command_PadUp value)  padUp,required TResult Function( Command_StopAll value)  stopAll,required TResult Function( Command_SetTempo value)  setTempo,required TResult Function( Command_SetSpeed value)  setSpeed,required TResult Function( Command_SetQuantize value)  setQuantize,required TResult Function( Command_SetPadParams value)  setPadParams,required TResult Function( Command_SetMasterGain value)  setMasterGain,required TResult Function( Command_StartRecording value)  startRecording,required TResult Function( Command_StopRecording value)  stopRecording,required TResult Function( Command_Transport value)  transport,}){
final _that = this;
switch (_that) {
case Command_PadDown():
return padDown(_that);case Command_PadUp():
return padUp(_that);case Command_StopAll():
return stopAll(_that);case Command_SetTempo():
return setTempo(_that);case Command_SetSpeed():
return setSpeed(_that);case Command_SetQuantize():
return setQuantize(_that);case Command_SetPadParams():
return setPadParams(_that);case Command_SetMasterGain():
return setMasterGain(_that);case Command_StartRecording():
return startRecording(_that);case Command_StopRecording():
return stopRecording(_that);case Command_Transport():
return transport(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Command_PadDown value)?  padDown,TResult? Function( Command_PadUp value)?  padUp,TResult? Function( Command_StopAll value)?  stopAll,TResult? Function( Command_SetTempo value)?  setTempo,TResult? Function( Command_SetSpeed value)?  setSpeed,TResult? Function( Command_SetQuantize value)?  setQuantize,TResult? Function( Command_SetPadParams value)?  setPadParams,TResult? Function( Command_SetMasterGain value)?  setMasterGain,TResult? Function( Command_StartRecording value)?  startRecording,TResult? Function( Command_StopRecording value)?  stopRecording,TResult? Function( Command_Transport value)?  transport,}){
final _that = this;
switch (_that) {
case Command_PadDown() when padDown != null:
return padDown(_that);case Command_PadUp() when padUp != null:
return padUp(_that);case Command_StopAll() when stopAll != null:
return stopAll(_that);case Command_SetTempo() when setTempo != null:
return setTempo(_that);case Command_SetSpeed() when setSpeed != null:
return setSpeed(_that);case Command_SetQuantize() when setQuantize != null:
return setQuantize(_that);case Command_SetPadParams() when setPadParams != null:
return setPadParams(_that);case Command_SetMasterGain() when setMasterGain != null:
return setMasterGain(_that);case Command_StartRecording() when startRecording != null:
return startRecording(_that);case Command_StopRecording() when stopRecording != null:
return stopRecording(_that);case Command_Transport() when transport != null:
return transport(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( PadId pad,  double velocity)?  padDown,TResult Function( PadId pad)?  padUp,TResult Function()?  stopAll,TResult Function( double bpm)?  setTempo,TResult Function( double ratio)?  setSpeed,TResult Function( Quantize q)?  setQuantize,TResult Function( PadId pad,  PadParams params)?  setPadParams,TResult Function( double gain)?  setMasterGain,TResult Function()?  startRecording,TResult Function()?  stopRecording,TResult Function( TransportCmd field0)?  transport,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Command_PadDown() when padDown != null:
return padDown(_that.pad,_that.velocity);case Command_PadUp() when padUp != null:
return padUp(_that.pad);case Command_StopAll() when stopAll != null:
return stopAll();case Command_SetTempo() when setTempo != null:
return setTempo(_that.bpm);case Command_SetSpeed() when setSpeed != null:
return setSpeed(_that.ratio);case Command_SetQuantize() when setQuantize != null:
return setQuantize(_that.q);case Command_SetPadParams() when setPadParams != null:
return setPadParams(_that.pad,_that.params);case Command_SetMasterGain() when setMasterGain != null:
return setMasterGain(_that.gain);case Command_StartRecording() when startRecording != null:
return startRecording();case Command_StopRecording() when stopRecording != null:
return stopRecording();case Command_Transport() when transport != null:
return transport(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( PadId pad,  double velocity)  padDown,required TResult Function( PadId pad)  padUp,required TResult Function()  stopAll,required TResult Function( double bpm)  setTempo,required TResult Function( double ratio)  setSpeed,required TResult Function( Quantize q)  setQuantize,required TResult Function( PadId pad,  PadParams params)  setPadParams,required TResult Function( double gain)  setMasterGain,required TResult Function()  startRecording,required TResult Function()  stopRecording,required TResult Function( TransportCmd field0)  transport,}) {final _that = this;
switch (_that) {
case Command_PadDown():
return padDown(_that.pad,_that.velocity);case Command_PadUp():
return padUp(_that.pad);case Command_StopAll():
return stopAll();case Command_SetTempo():
return setTempo(_that.bpm);case Command_SetSpeed():
return setSpeed(_that.ratio);case Command_SetQuantize():
return setQuantize(_that.q);case Command_SetPadParams():
return setPadParams(_that.pad,_that.params);case Command_SetMasterGain():
return setMasterGain(_that.gain);case Command_StartRecording():
return startRecording();case Command_StopRecording():
return stopRecording();case Command_Transport():
return transport(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( PadId pad,  double velocity)?  padDown,TResult? Function( PadId pad)?  padUp,TResult? Function()?  stopAll,TResult? Function( double bpm)?  setTempo,TResult? Function( double ratio)?  setSpeed,TResult? Function( Quantize q)?  setQuantize,TResult? Function( PadId pad,  PadParams params)?  setPadParams,TResult? Function( double gain)?  setMasterGain,TResult? Function()?  startRecording,TResult? Function()?  stopRecording,TResult? Function( TransportCmd field0)?  transport,}) {final _that = this;
switch (_that) {
case Command_PadDown() when padDown != null:
return padDown(_that.pad,_that.velocity);case Command_PadUp() when padUp != null:
return padUp(_that.pad);case Command_StopAll() when stopAll != null:
return stopAll();case Command_SetTempo() when setTempo != null:
return setTempo(_that.bpm);case Command_SetSpeed() when setSpeed != null:
return setSpeed(_that.ratio);case Command_SetQuantize() when setQuantize != null:
return setQuantize(_that.q);case Command_SetPadParams() when setPadParams != null:
return setPadParams(_that.pad,_that.params);case Command_SetMasterGain() when setMasterGain != null:
return setMasterGain(_that.gain);case Command_StartRecording() when startRecording != null:
return startRecording();case Command_StopRecording() when stopRecording != null:
return stopRecording();case Command_Transport() when transport != null:
return transport(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class Command_PadDown extends Command {
  const Command_PadDown({required this.pad, required this.velocity}): super._();
  

 final  PadId pad;
 final  double velocity;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Command_PadDownCopyWith<Command_PadDown> get copyWith => _$Command_PadDownCopyWithImpl<Command_PadDown>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command_PadDown&&(identical(other.pad, pad) || other.pad == pad)&&(identical(other.velocity, velocity) || other.velocity == velocity));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pad,velocity);
}

@override
String toString() {
    return 'Command.padDown(pad: $pad, velocity: $velocity)';
}


}

/// @nodoc
abstract mixin class $Command_PadDownCopyWith<$Res> implements $CommandCopyWith<$Res> {
  factory $Command_PadDownCopyWith(Command_PadDown value, $Res Function(Command_PadDown) _then) = _$Command_PadDownCopyWithImpl;
@useResult
$Res call({
 PadId pad, double velocity
});




}
/// @nodoc
class _$Command_PadDownCopyWithImpl<$Res>
    implements $Command_PadDownCopyWith<$Res> {
  _$Command_PadDownCopyWithImpl(this._self, this._then);

  final Command_PadDown _self;
  final $Res Function(Command_PadDown) _then;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pad = null,Object? velocity = null,}) {
  return _then(Command_PadDown(
pad: null == pad ? _self.pad : pad // ignore: cast_nullable_to_non_nullable
as PadId,velocity: null == velocity ? _self.velocity : velocity // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class Command_PadUp extends Command {
  const Command_PadUp({required this.pad}): super._();
  

 final  PadId pad;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Command_PadUpCopyWith<Command_PadUp> get copyWith => _$Command_PadUpCopyWithImpl<Command_PadUp>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command_PadUp&&(identical(other.pad, pad) || other.pad == pad));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pad);
}

@override
String toString() {
    return 'Command.padUp(pad: $pad)';
}


}

/// @nodoc
abstract mixin class $Command_PadUpCopyWith<$Res> implements $CommandCopyWith<$Res> {
  factory $Command_PadUpCopyWith(Command_PadUp value, $Res Function(Command_PadUp) _then) = _$Command_PadUpCopyWithImpl;
@useResult
$Res call({
 PadId pad
});




}
/// @nodoc
class _$Command_PadUpCopyWithImpl<$Res>
    implements $Command_PadUpCopyWith<$Res> {
  _$Command_PadUpCopyWithImpl(this._self, this._then);

  final Command_PadUp _self;
  final $Res Function(Command_PadUp) _then;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pad = null,}) {
  return _then(Command_PadUp(
pad: null == pad ? _self.pad : pad // ignore: cast_nullable_to_non_nullable
as PadId,
  ));
}


}

/// @nodoc


class Command_StopAll extends Command {
  const Command_StopAll(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command_StopAll);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Command.stopAll()';
}


}




/// @nodoc


class Command_SetTempo extends Command {
  const Command_SetTempo({required this.bpm}): super._();
  

 final  double bpm;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Command_SetTempoCopyWith<Command_SetTempo> get copyWith => _$Command_SetTempoCopyWithImpl<Command_SetTempo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command_SetTempo&&(identical(other.bpm, bpm) || other.bpm == bpm));
}


@override
int get hashCode {
    return Object.hash(runtimeType,bpm);
}

@override
String toString() {
    return 'Command.setTempo(bpm: $bpm)';
}


}

/// @nodoc
abstract mixin class $Command_SetTempoCopyWith<$Res> implements $CommandCopyWith<$Res> {
  factory $Command_SetTempoCopyWith(Command_SetTempo value, $Res Function(Command_SetTempo) _then) = _$Command_SetTempoCopyWithImpl;
@useResult
$Res call({
 double bpm
});




}
/// @nodoc
class _$Command_SetTempoCopyWithImpl<$Res>
    implements $Command_SetTempoCopyWith<$Res> {
  _$Command_SetTempoCopyWithImpl(this._self, this._then);

  final Command_SetTempo _self;
  final $Res Function(Command_SetTempo) _then;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bpm = null,}) {
  return _then(Command_SetTempo(
bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class Command_SetSpeed extends Command {
  const Command_SetSpeed({required this.ratio}): super._();
  

 final  double ratio;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Command_SetSpeedCopyWith<Command_SetSpeed> get copyWith => _$Command_SetSpeedCopyWithImpl<Command_SetSpeed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command_SetSpeed&&(identical(other.ratio, ratio) || other.ratio == ratio));
}


@override
int get hashCode {
    return Object.hash(runtimeType,ratio);
}

@override
String toString() {
    return 'Command.setSpeed(ratio: $ratio)';
}


}

/// @nodoc
abstract mixin class $Command_SetSpeedCopyWith<$Res> implements $CommandCopyWith<$Res> {
  factory $Command_SetSpeedCopyWith(Command_SetSpeed value, $Res Function(Command_SetSpeed) _then) = _$Command_SetSpeedCopyWithImpl;
@useResult
$Res call({
 double ratio
});




}
/// @nodoc
class _$Command_SetSpeedCopyWithImpl<$Res>
    implements $Command_SetSpeedCopyWith<$Res> {
  _$Command_SetSpeedCopyWithImpl(this._self, this._then);

  final Command_SetSpeed _self;
  final $Res Function(Command_SetSpeed) _then;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ratio = null,}) {
  return _then(Command_SetSpeed(
ratio: null == ratio ? _self.ratio : ratio // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class Command_SetQuantize extends Command {
  const Command_SetQuantize({required this.q}): super._();
  

 final  Quantize q;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Command_SetQuantizeCopyWith<Command_SetQuantize> get copyWith => _$Command_SetQuantizeCopyWithImpl<Command_SetQuantize>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command_SetQuantize&&(identical(other.q, q) || other.q == q));
}


@override
int get hashCode {
    return Object.hash(runtimeType,q);
}

@override
String toString() {
    return 'Command.setQuantize(q: $q)';
}


}

/// @nodoc
abstract mixin class $Command_SetQuantizeCopyWith<$Res> implements $CommandCopyWith<$Res> {
  factory $Command_SetQuantizeCopyWith(Command_SetQuantize value, $Res Function(Command_SetQuantize) _then) = _$Command_SetQuantizeCopyWithImpl;
@useResult
$Res call({
 Quantize q
});




}
/// @nodoc
class _$Command_SetQuantizeCopyWithImpl<$Res>
    implements $Command_SetQuantizeCopyWith<$Res> {
  _$Command_SetQuantizeCopyWithImpl(this._self, this._then);

  final Command_SetQuantize _self;
  final $Res Function(Command_SetQuantize) _then;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? q = null,}) {
  return _then(Command_SetQuantize(
q: null == q ? _self.q : q // ignore: cast_nullable_to_non_nullable
as Quantize,
  ));
}


}

/// @nodoc


class Command_SetPadParams extends Command {
  const Command_SetPadParams({required this.pad, required this.params}): super._();
  

 final  PadId pad;
 final  PadParams params;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Command_SetPadParamsCopyWith<Command_SetPadParams> get copyWith => _$Command_SetPadParamsCopyWithImpl<Command_SetPadParams>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command_SetPadParams&&(identical(other.pad, pad) || other.pad == pad)&&(identical(other.params, params) || other.params == params));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pad,params);
}

@override
String toString() {
    return 'Command.setPadParams(pad: $pad, params: $params)';
}


}

/// @nodoc
abstract mixin class $Command_SetPadParamsCopyWith<$Res> implements $CommandCopyWith<$Res> {
  factory $Command_SetPadParamsCopyWith(Command_SetPadParams value, $Res Function(Command_SetPadParams) _then) = _$Command_SetPadParamsCopyWithImpl;
@useResult
$Res call({
 PadId pad, PadParams params
});




}
/// @nodoc
class _$Command_SetPadParamsCopyWithImpl<$Res>
    implements $Command_SetPadParamsCopyWith<$Res> {
  _$Command_SetPadParamsCopyWithImpl(this._self, this._then);

  final Command_SetPadParams _self;
  final $Res Function(Command_SetPadParams) _then;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pad = null,Object? params = null,}) {
  return _then(Command_SetPadParams(
pad: null == pad ? _self.pad : pad // ignore: cast_nullable_to_non_nullable
as PadId,params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as PadParams,
  ));
}


}

/// @nodoc


class Command_SetMasterGain extends Command {
  const Command_SetMasterGain({required this.gain}): super._();
  

 final  double gain;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Command_SetMasterGainCopyWith<Command_SetMasterGain> get copyWith => _$Command_SetMasterGainCopyWithImpl<Command_SetMasterGain>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command_SetMasterGain&&(identical(other.gain, gain) || other.gain == gain));
}


@override
int get hashCode {
    return Object.hash(runtimeType,gain);
}

@override
String toString() {
    return 'Command.setMasterGain(gain: $gain)';
}


}

/// @nodoc
abstract mixin class $Command_SetMasterGainCopyWith<$Res> implements $CommandCopyWith<$Res> {
  factory $Command_SetMasterGainCopyWith(Command_SetMasterGain value, $Res Function(Command_SetMasterGain) _then) = _$Command_SetMasterGainCopyWithImpl;
@useResult
$Res call({
 double gain
});




}
/// @nodoc
class _$Command_SetMasterGainCopyWithImpl<$Res>
    implements $Command_SetMasterGainCopyWith<$Res> {
  _$Command_SetMasterGainCopyWithImpl(this._self, this._then);

  final Command_SetMasterGain _self;
  final $Res Function(Command_SetMasterGain) _then;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? gain = null,}) {
  return _then(Command_SetMasterGain(
gain: null == gain ? _self.gain : gain // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class Command_StartRecording extends Command {
  const Command_StartRecording(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command_StartRecording);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Command.startRecording()';
}


}




/// @nodoc


class Command_StopRecording extends Command {
  const Command_StopRecording(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command_StopRecording);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Command.stopRecording()';
}


}




/// @nodoc


class Command_Transport extends Command {
  const Command_Transport(this.field0): super._();
  

 final  TransportCmd field0;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Command_TransportCopyWith<Command_Transport> get copyWith => _$Command_TransportCopyWithImpl<Command_Transport>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Command_Transport&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'Command.transport(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Command_TransportCopyWith<$Res> implements $CommandCopyWith<$Res> {
  factory $Command_TransportCopyWith(Command_Transport value, $Res Function(Command_Transport) _then) = _$Command_TransportCopyWithImpl;
@useResult
$Res call({
 TransportCmd field0
});


$TransportCmdCopyWith<$Res> get field0;

}
/// @nodoc
class _$Command_TransportCopyWithImpl<$Res>
    implements $Command_TransportCopyWith<$Res> {
  _$Command_TransportCopyWithImpl(this._self, this._then);

  final Command_Transport _self;
  final $Res Function(Command_Transport) _then;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Command_Transport(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as TransportCmd,
  ));
}

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TransportCmdCopyWith<$Res> get field0 {
  
  return $TransportCmdCopyWith<$Res>(_self.field0, (value) {
    return _then(_self.copyWith(field0: value));
  });
}
}

/// @nodoc
mixin _$EngineEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'EngineEvent()';
}


}

/// @nodoc
class $EngineEventCopyWith<$Res>  {
$EngineEventCopyWith(EngineEvent _, $Res Function(EngineEvent) __);
}


/// Adds pattern-matching-related methods to [EngineEvent].
extension EngineEventPatterns on EngineEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( EngineEvent_PadState value)?  padState,TResult Function( EngineEvent_Transport value)?  transport,TResult Function( EngineEvent_Meters value)?  meters,TResult Function( EngineEvent_Recorder value)?  recorder,TResult Function( EngineEvent_KitLoaded value)?  kitLoaded,TResult Function( EngineEvent_TrackSaved value)?  trackSaved,TResult Function( EngineEvent_TrackPlayback value)?  trackPlayback,TResult Function( EngineEvent_LibraryChanged value)?  libraryChanged,TResult Function( EngineEvent_Hub value)?  hub,TResult Function( EngineEvent_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case EngineEvent_PadState() when padState != null:
return padState(_that);case EngineEvent_Transport() when transport != null:
return transport(_that);case EngineEvent_Meters() when meters != null:
return meters(_that);case EngineEvent_Recorder() when recorder != null:
return recorder(_that);case EngineEvent_KitLoaded() when kitLoaded != null:
return kitLoaded(_that);case EngineEvent_TrackSaved() when trackSaved != null:
return trackSaved(_that);case EngineEvent_TrackPlayback() when trackPlayback != null:
return trackPlayback(_that);case EngineEvent_LibraryChanged() when libraryChanged != null:
return libraryChanged(_that);case EngineEvent_Hub() when hub != null:
return hub(_that);case EngineEvent_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( EngineEvent_PadState value)  padState,required TResult Function( EngineEvent_Transport value)  transport,required TResult Function( EngineEvent_Meters value)  meters,required TResult Function( EngineEvent_Recorder value)  recorder,required TResult Function( EngineEvent_KitLoaded value)  kitLoaded,required TResult Function( EngineEvent_TrackSaved value)  trackSaved,required TResult Function( EngineEvent_TrackPlayback value)  trackPlayback,required TResult Function( EngineEvent_LibraryChanged value)  libraryChanged,required TResult Function( EngineEvent_Hub value)  hub,required TResult Function( EngineEvent_Error value)  error,}){
final _that = this;
switch (_that) {
case EngineEvent_PadState():
return padState(_that);case EngineEvent_Transport():
return transport(_that);case EngineEvent_Meters():
return meters(_that);case EngineEvent_Recorder():
return recorder(_that);case EngineEvent_KitLoaded():
return kitLoaded(_that);case EngineEvent_TrackSaved():
return trackSaved(_that);case EngineEvent_TrackPlayback():
return trackPlayback(_that);case EngineEvent_LibraryChanged():
return libraryChanged(_that);case EngineEvent_Hub():
return hub(_that);case EngineEvent_Error():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( EngineEvent_PadState value)?  padState,TResult? Function( EngineEvent_Transport value)?  transport,TResult? Function( EngineEvent_Meters value)?  meters,TResult? Function( EngineEvent_Recorder value)?  recorder,TResult? Function( EngineEvent_KitLoaded value)?  kitLoaded,TResult? Function( EngineEvent_TrackSaved value)?  trackSaved,TResult? Function( EngineEvent_TrackPlayback value)?  trackPlayback,TResult? Function( EngineEvent_LibraryChanged value)?  libraryChanged,TResult? Function( EngineEvent_Hub value)?  hub,TResult? Function( EngineEvent_Error value)?  error,}){
final _that = this;
switch (_that) {
case EngineEvent_PadState() when padState != null:
return padState(_that);case EngineEvent_Transport() when transport != null:
return transport(_that);case EngineEvent_Meters() when meters != null:
return meters(_that);case EngineEvent_Recorder() when recorder != null:
return recorder(_that);case EngineEvent_KitLoaded() when kitLoaded != null:
return kitLoaded(_that);case EngineEvent_TrackSaved() when trackSaved != null:
return trackSaved(_that);case EngineEvent_TrackPlayback() when trackPlayback != null:
return trackPlayback(_that);case EngineEvent_LibraryChanged() when libraryChanged != null:
return libraryChanged(_that);case EngineEvent_Hub() when hub != null:
return hub(_that);case EngineEvent_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( PadId pad,  PadPlayState state)?  padState,TResult Function( bool playing,  double beat,  double bpm,  double barLenBeats,  double songSecs)?  transport,TResult Function( Float32List masterPeak,  Float32List masterRms,  Float32List padLevels)?  meters,TResult Function( RecorderState state,  double elapsedSecs)?  recorder,TResult Function( KitSummary kit)?  kitLoaded,TResult Function( TrackInfo track)?  trackSaved,TResult Function( String? track)?  trackPlayback,TResult Function()?  libraryChanged,TResult Function( HubEvent field0)?  hub,TResult Function( UpError field0)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case EngineEvent_PadState() when padState != null:
return padState(_that.pad,_that.state);case EngineEvent_Transport() when transport != null:
return transport(_that.playing,_that.beat,_that.bpm,_that.barLenBeats,_that.songSecs);case EngineEvent_Meters() when meters != null:
return meters(_that.masterPeak,_that.masterRms,_that.padLevels);case EngineEvent_Recorder() when recorder != null:
return recorder(_that.state,_that.elapsedSecs);case EngineEvent_KitLoaded() when kitLoaded != null:
return kitLoaded(_that.kit);case EngineEvent_TrackSaved() when trackSaved != null:
return trackSaved(_that.track);case EngineEvent_TrackPlayback() when trackPlayback != null:
return trackPlayback(_that.track);case EngineEvent_LibraryChanged() when libraryChanged != null:
return libraryChanged();case EngineEvent_Hub() when hub != null:
return hub(_that.field0);case EngineEvent_Error() when error != null:
return error(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( PadId pad,  PadPlayState state)  padState,required TResult Function( bool playing,  double beat,  double bpm,  double barLenBeats,  double songSecs)  transport,required TResult Function( Float32List masterPeak,  Float32List masterRms,  Float32List padLevels)  meters,required TResult Function( RecorderState state,  double elapsedSecs)  recorder,required TResult Function( KitSummary kit)  kitLoaded,required TResult Function( TrackInfo track)  trackSaved,required TResult Function( String? track)  trackPlayback,required TResult Function()  libraryChanged,required TResult Function( HubEvent field0)  hub,required TResult Function( UpError field0)  error,}) {final _that = this;
switch (_that) {
case EngineEvent_PadState():
return padState(_that.pad,_that.state);case EngineEvent_Transport():
return transport(_that.playing,_that.beat,_that.bpm,_that.barLenBeats,_that.songSecs);case EngineEvent_Meters():
return meters(_that.masterPeak,_that.masterRms,_that.padLevels);case EngineEvent_Recorder():
return recorder(_that.state,_that.elapsedSecs);case EngineEvent_KitLoaded():
return kitLoaded(_that.kit);case EngineEvent_TrackSaved():
return trackSaved(_that.track);case EngineEvent_TrackPlayback():
return trackPlayback(_that.track);case EngineEvent_LibraryChanged():
return libraryChanged();case EngineEvent_Hub():
return hub(_that.field0);case EngineEvent_Error():
return error(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( PadId pad,  PadPlayState state)?  padState,TResult? Function( bool playing,  double beat,  double bpm,  double barLenBeats,  double songSecs)?  transport,TResult? Function( Float32List masterPeak,  Float32List masterRms,  Float32List padLevels)?  meters,TResult? Function( RecorderState state,  double elapsedSecs)?  recorder,TResult? Function( KitSummary kit)?  kitLoaded,TResult? Function( TrackInfo track)?  trackSaved,TResult? Function( String? track)?  trackPlayback,TResult? Function()?  libraryChanged,TResult? Function( HubEvent field0)?  hub,TResult? Function( UpError field0)?  error,}) {final _that = this;
switch (_that) {
case EngineEvent_PadState() when padState != null:
return padState(_that.pad,_that.state);case EngineEvent_Transport() when transport != null:
return transport(_that.playing,_that.beat,_that.bpm,_that.barLenBeats,_that.songSecs);case EngineEvent_Meters() when meters != null:
return meters(_that.masterPeak,_that.masterRms,_that.padLevels);case EngineEvent_Recorder() when recorder != null:
return recorder(_that.state,_that.elapsedSecs);case EngineEvent_KitLoaded() when kitLoaded != null:
return kitLoaded(_that.kit);case EngineEvent_TrackSaved() when trackSaved != null:
return trackSaved(_that.track);case EngineEvent_TrackPlayback() when trackPlayback != null:
return trackPlayback(_that.track);case EngineEvent_LibraryChanged() when libraryChanged != null:
return libraryChanged();case EngineEvent_Hub() when hub != null:
return hub(_that.field0);case EngineEvent_Error() when error != null:
return error(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class EngineEvent_PadState extends EngineEvent {
  const EngineEvent_PadState({required this.pad, required this.state}): super._();
  

 final  PadId pad;
 final  PadPlayState state;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EngineEvent_PadStateCopyWith<EngineEvent_PadState> get copyWith => _$EngineEvent_PadStateCopyWithImpl<EngineEvent_PadState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineEvent_PadState&&(identical(other.pad, pad) || other.pad == pad)&&(identical(other.state, state) || other.state == state));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pad,state);
}

@override
String toString() {
    return 'EngineEvent.padState(pad: $pad, state: $state)';
}


}

/// @nodoc
abstract mixin class $EngineEvent_PadStateCopyWith<$Res> implements $EngineEventCopyWith<$Res> {
  factory $EngineEvent_PadStateCopyWith(EngineEvent_PadState value, $Res Function(EngineEvent_PadState) _then) = _$EngineEvent_PadStateCopyWithImpl;
@useResult
$Res call({
 PadId pad, PadPlayState state
});




}
/// @nodoc
class _$EngineEvent_PadStateCopyWithImpl<$Res>
    implements $EngineEvent_PadStateCopyWith<$Res> {
  _$EngineEvent_PadStateCopyWithImpl(this._self, this._then);

  final EngineEvent_PadState _self;
  final $Res Function(EngineEvent_PadState) _then;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pad = null,Object? state = null,}) {
  return _then(EngineEvent_PadState(
pad: null == pad ? _self.pad : pad // ignore: cast_nullable_to_non_nullable
as PadId,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PadPlayState,
  ));
}


}

/// @nodoc


class EngineEvent_Transport extends EngineEvent {
  const EngineEvent_Transport({required this.playing, required this.beat, required this.bpm, required this.barLenBeats, required this.songSecs}): super._();
  

 final  bool playing;
 final  double beat;
 final  double bpm;
 final  double barLenBeats;
 final  double songSecs;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EngineEvent_TransportCopyWith<EngineEvent_Transport> get copyWith => _$EngineEvent_TransportCopyWithImpl<EngineEvent_Transport>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineEvent_Transport&&(identical(other.playing, playing) || other.playing == playing)&&(identical(other.beat, beat) || other.beat == beat)&&(identical(other.bpm, bpm) || other.bpm == bpm)&&(identical(other.barLenBeats, barLenBeats) || other.barLenBeats == barLenBeats)&&(identical(other.songSecs, songSecs) || other.songSecs == songSecs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,playing,beat,bpm,barLenBeats,songSecs);
}

@override
String toString() {
    return 'EngineEvent.transport(playing: $playing, beat: $beat, bpm: $bpm, barLenBeats: $barLenBeats, songSecs: $songSecs)';
}


}

/// @nodoc
abstract mixin class $EngineEvent_TransportCopyWith<$Res> implements $EngineEventCopyWith<$Res> {
  factory $EngineEvent_TransportCopyWith(EngineEvent_Transport value, $Res Function(EngineEvent_Transport) _then) = _$EngineEvent_TransportCopyWithImpl;
@useResult
$Res call({
 bool playing, double beat, double bpm, double barLenBeats, double songSecs
});




}
/// @nodoc
class _$EngineEvent_TransportCopyWithImpl<$Res>
    implements $EngineEvent_TransportCopyWith<$Res> {
  _$EngineEvent_TransportCopyWithImpl(this._self, this._then);

  final EngineEvent_Transport _self;
  final $Res Function(EngineEvent_Transport) _then;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? playing = null,Object? beat = null,Object? bpm = null,Object? barLenBeats = null,Object? songSecs = null,}) {
  return _then(EngineEvent_Transport(
playing: null == playing ? _self.playing : playing // ignore: cast_nullable_to_non_nullable
as bool,beat: null == beat ? _self.beat : beat // ignore: cast_nullable_to_non_nullable
as double,bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double,barLenBeats: null == barLenBeats ? _self.barLenBeats : barLenBeats // ignore: cast_nullable_to_non_nullable
as double,songSecs: null == songSecs ? _self.songSecs : songSecs // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class EngineEvent_Meters extends EngineEvent {
  const EngineEvent_Meters({required this.masterPeak, required this.masterRms, required this.padLevels}): super._();
  

 final  Float32List masterPeak;
 final  Float32List masterRms;
 final  Float32List padLevels;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EngineEvent_MetersCopyWith<EngineEvent_Meters> get copyWith => _$EngineEvent_MetersCopyWithImpl<EngineEvent_Meters>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineEvent_Meters&&const DeepCollectionEquality().equals(other.masterPeak, masterPeak)&&const DeepCollectionEquality().equals(other.masterRms, masterRms)&&const DeepCollectionEquality().equals(other.padLevels, padLevels));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(masterPeak),const DeepCollectionEquality().hash(masterRms),const DeepCollectionEquality().hash(padLevels));
}

@override
String toString() {
    return 'EngineEvent.meters(masterPeak: $masterPeak, masterRms: $masterRms, padLevels: $padLevels)';
}


}

/// @nodoc
abstract mixin class $EngineEvent_MetersCopyWith<$Res> implements $EngineEventCopyWith<$Res> {
  factory $EngineEvent_MetersCopyWith(EngineEvent_Meters value, $Res Function(EngineEvent_Meters) _then) = _$EngineEvent_MetersCopyWithImpl;
@useResult
$Res call({
 Float32List masterPeak, Float32List masterRms, Float32List padLevels
});




}
/// @nodoc
class _$EngineEvent_MetersCopyWithImpl<$Res>
    implements $EngineEvent_MetersCopyWith<$Res> {
  _$EngineEvent_MetersCopyWithImpl(this._self, this._then);

  final EngineEvent_Meters _self;
  final $Res Function(EngineEvent_Meters) _then;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? masterPeak = null,Object? masterRms = null,Object? padLevels = null,}) {
  return _then(EngineEvent_Meters(
masterPeak: null == masterPeak ? _self.masterPeak : masterPeak // ignore: cast_nullable_to_non_nullable
as Float32List,masterRms: null == masterRms ? _self.masterRms : masterRms // ignore: cast_nullable_to_non_nullable
as Float32List,padLevels: null == padLevels ? _self.padLevels : padLevels // ignore: cast_nullable_to_non_nullable
as Float32List,
  ));
}


}

/// @nodoc


class EngineEvent_Recorder extends EngineEvent {
  const EngineEvent_Recorder({required this.state, required this.elapsedSecs}): super._();
  

 final  RecorderState state;
 final  double elapsedSecs;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EngineEvent_RecorderCopyWith<EngineEvent_Recorder> get copyWith => _$EngineEvent_RecorderCopyWithImpl<EngineEvent_Recorder>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineEvent_Recorder&&(identical(other.state, state) || other.state == state)&&(identical(other.elapsedSecs, elapsedSecs) || other.elapsedSecs == elapsedSecs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,state,elapsedSecs);
}

@override
String toString() {
    return 'EngineEvent.recorder(state: $state, elapsedSecs: $elapsedSecs)';
}


}

/// @nodoc
abstract mixin class $EngineEvent_RecorderCopyWith<$Res> implements $EngineEventCopyWith<$Res> {
  factory $EngineEvent_RecorderCopyWith(EngineEvent_Recorder value, $Res Function(EngineEvent_Recorder) _then) = _$EngineEvent_RecorderCopyWithImpl;
@useResult
$Res call({
 RecorderState state, double elapsedSecs
});




}
/// @nodoc
class _$EngineEvent_RecorderCopyWithImpl<$Res>
    implements $EngineEvent_RecorderCopyWith<$Res> {
  _$EngineEvent_RecorderCopyWithImpl(this._self, this._then);

  final EngineEvent_Recorder _self;
  final $Res Function(EngineEvent_Recorder) _then;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? state = null,Object? elapsedSecs = null,}) {
  return _then(EngineEvent_Recorder(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as RecorderState,elapsedSecs: null == elapsedSecs ? _self.elapsedSecs : elapsedSecs // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class EngineEvent_KitLoaded extends EngineEvent {
  const EngineEvent_KitLoaded({required this.kit}): super._();
  

 final  KitSummary kit;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EngineEvent_KitLoadedCopyWith<EngineEvent_KitLoaded> get copyWith => _$EngineEvent_KitLoadedCopyWithImpl<EngineEvent_KitLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineEvent_KitLoaded&&(identical(other.kit, kit) || other.kit == kit));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kit);
}

@override
String toString() {
    return 'EngineEvent.kitLoaded(kit: $kit)';
}


}

/// @nodoc
abstract mixin class $EngineEvent_KitLoadedCopyWith<$Res> implements $EngineEventCopyWith<$Res> {
  factory $EngineEvent_KitLoadedCopyWith(EngineEvent_KitLoaded value, $Res Function(EngineEvent_KitLoaded) _then) = _$EngineEvent_KitLoadedCopyWithImpl;
@useResult
$Res call({
 KitSummary kit
});




}
/// @nodoc
class _$EngineEvent_KitLoadedCopyWithImpl<$Res>
    implements $EngineEvent_KitLoadedCopyWith<$Res> {
  _$EngineEvent_KitLoadedCopyWithImpl(this._self, this._then);

  final EngineEvent_KitLoaded _self;
  final $Res Function(EngineEvent_KitLoaded) _then;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kit = null,}) {
  return _then(EngineEvent_KitLoaded(
kit: null == kit ? _self.kit : kit // ignore: cast_nullable_to_non_nullable
as KitSummary,
  ));
}


}

/// @nodoc


class EngineEvent_TrackSaved extends EngineEvent {
  const EngineEvent_TrackSaved({required this.track}): super._();
  

 final  TrackInfo track;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EngineEvent_TrackSavedCopyWith<EngineEvent_TrackSaved> get copyWith => _$EngineEvent_TrackSavedCopyWithImpl<EngineEvent_TrackSaved>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineEvent_TrackSaved&&(identical(other.track, track) || other.track == track));
}


@override
int get hashCode {
    return Object.hash(runtimeType,track);
}

@override
String toString() {
    return 'EngineEvent.trackSaved(track: $track)';
}


}

/// @nodoc
abstract mixin class $EngineEvent_TrackSavedCopyWith<$Res> implements $EngineEventCopyWith<$Res> {
  factory $EngineEvent_TrackSavedCopyWith(EngineEvent_TrackSaved value, $Res Function(EngineEvent_TrackSaved) _then) = _$EngineEvent_TrackSavedCopyWithImpl;
@useResult
$Res call({
 TrackInfo track
});




}
/// @nodoc
class _$EngineEvent_TrackSavedCopyWithImpl<$Res>
    implements $EngineEvent_TrackSavedCopyWith<$Res> {
  _$EngineEvent_TrackSavedCopyWithImpl(this._self, this._then);

  final EngineEvent_TrackSaved _self;
  final $Res Function(EngineEvent_TrackSaved) _then;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? track = null,}) {
  return _then(EngineEvent_TrackSaved(
track: null == track ? _self.track : track // ignore: cast_nullable_to_non_nullable
as TrackInfo,
  ));
}


}

/// @nodoc


class EngineEvent_TrackPlayback extends EngineEvent {
  const EngineEvent_TrackPlayback({this.track}): super._();
  

 final  String? track;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EngineEvent_TrackPlaybackCopyWith<EngineEvent_TrackPlayback> get copyWith => _$EngineEvent_TrackPlaybackCopyWithImpl<EngineEvent_TrackPlayback>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineEvent_TrackPlayback&&(identical(other.track, track) || other.track == track));
}


@override
int get hashCode {
    return Object.hash(runtimeType,track);
}

@override
String toString() {
    return 'EngineEvent.trackPlayback(track: $track)';
}


}

/// @nodoc
abstract mixin class $EngineEvent_TrackPlaybackCopyWith<$Res> implements $EngineEventCopyWith<$Res> {
  factory $EngineEvent_TrackPlaybackCopyWith(EngineEvent_TrackPlayback value, $Res Function(EngineEvent_TrackPlayback) _then) = _$EngineEvent_TrackPlaybackCopyWithImpl;
@useResult
$Res call({
 String? track
});




}
/// @nodoc
class _$EngineEvent_TrackPlaybackCopyWithImpl<$Res>
    implements $EngineEvent_TrackPlaybackCopyWith<$Res> {
  _$EngineEvent_TrackPlaybackCopyWithImpl(this._self, this._then);

  final EngineEvent_TrackPlayback _self;
  final $Res Function(EngineEvent_TrackPlayback) _then;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? track = freezed,}) {
  return _then(EngineEvent_TrackPlayback(
track: freezed == track ? _self.track : track // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class EngineEvent_LibraryChanged extends EngineEvent {
  const EngineEvent_LibraryChanged(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineEvent_LibraryChanged);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'EngineEvent.libraryChanged()';
}


}




/// @nodoc


class EngineEvent_Hub extends EngineEvent {
  const EngineEvent_Hub(this.field0): super._();
  

 final  HubEvent field0;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EngineEvent_HubCopyWith<EngineEvent_Hub> get copyWith => _$EngineEvent_HubCopyWithImpl<EngineEvent_Hub>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineEvent_Hub&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'EngineEvent.hub(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $EngineEvent_HubCopyWith<$Res> implements $EngineEventCopyWith<$Res> {
  factory $EngineEvent_HubCopyWith(EngineEvent_Hub value, $Res Function(EngineEvent_Hub) _then) = _$EngineEvent_HubCopyWithImpl;
@useResult
$Res call({
 HubEvent field0
});


$HubEventCopyWith<$Res> get field0;

}
/// @nodoc
class _$EngineEvent_HubCopyWithImpl<$Res>
    implements $EngineEvent_HubCopyWith<$Res> {
  _$EngineEvent_HubCopyWithImpl(this._self, this._then);

  final EngineEvent_Hub _self;
  final $Res Function(EngineEvent_Hub) _then;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(EngineEvent_Hub(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as HubEvent,
  ));
}

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HubEventCopyWith<$Res> get field0 {
  
  return $HubEventCopyWith<$Res>(_self.field0, (value) {
    return _then(_self.copyWith(field0: value));
  });
}
}

/// @nodoc


class EngineEvent_Error extends EngineEvent {
  const EngineEvent_Error(this.field0): super._();
  

 final  UpError field0;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EngineEvent_ErrorCopyWith<EngineEvent_Error> get copyWith => _$EngineEvent_ErrorCopyWithImpl<EngineEvent_Error>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineEvent_Error&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'EngineEvent.error(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $EngineEvent_ErrorCopyWith<$Res> implements $EngineEventCopyWith<$Res> {
  factory $EngineEvent_ErrorCopyWith(EngineEvent_Error value, $Res Function(EngineEvent_Error) _then) = _$EngineEvent_ErrorCopyWithImpl;
@useResult
$Res call({
 UpError field0
});




}
/// @nodoc
class _$EngineEvent_ErrorCopyWithImpl<$Res>
    implements $EngineEvent_ErrorCopyWith<$Res> {
  _$EngineEvent_ErrorCopyWithImpl(this._self, this._then);

  final EngineEvent_Error _self;
  final $Res Function(EngineEvent_Error) _then;

/// Create a copy of EngineEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(EngineEvent_Error(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as UpError,
  ));
}


}

/// @nodoc
mixin _$HubEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is HubEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'HubEvent()';
}


}

/// @nodoc
class $HubEventCopyWith<$Res>  {
$HubEventCopyWith(HubEvent _, $Res Function(HubEvent) __);
}


/// Adds pattern-matching-related methods to [HubEvent].
extension HubEventPatterns on HubEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( HubEvent_ServerStarted value)?  serverStarted,TResult Function( HubEvent_ServerStopped value)?  serverStopped,TResult Function( HubEvent_PeerDiscovered value)?  peerDiscovered,TResult Function( HubEvent_PeerLost value)?  peerLost,TResult Function( HubEvent_Paired value)?  paired,TResult Function( HubEvent_SyncProgress value)?  syncProgress,TResult Function( HubEvent_ControllerConnected value)?  controllerConnected,TResult Function( HubEvent_ControllerDisconnected value)?  controllerDisconnected,required TResult orElse(),}){
final _that = this;
switch (_that) {
case HubEvent_ServerStarted() when serverStarted != null:
return serverStarted(_that);case HubEvent_ServerStopped() when serverStopped != null:
return serverStopped(_that);case HubEvent_PeerDiscovered() when peerDiscovered != null:
return peerDiscovered(_that);case HubEvent_PeerLost() when peerLost != null:
return peerLost(_that);case HubEvent_Paired() when paired != null:
return paired(_that);case HubEvent_SyncProgress() when syncProgress != null:
return syncProgress(_that);case HubEvent_ControllerConnected() when controllerConnected != null:
return controllerConnected(_that);case HubEvent_ControllerDisconnected() when controllerDisconnected != null:
return controllerDisconnected(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( HubEvent_ServerStarted value)  serverStarted,required TResult Function( HubEvent_ServerStopped value)  serverStopped,required TResult Function( HubEvent_PeerDiscovered value)  peerDiscovered,required TResult Function( HubEvent_PeerLost value)  peerLost,required TResult Function( HubEvent_Paired value)  paired,required TResult Function( HubEvent_SyncProgress value)  syncProgress,required TResult Function( HubEvent_ControllerConnected value)  controllerConnected,required TResult Function( HubEvent_ControllerDisconnected value)  controllerDisconnected,}){
final _that = this;
switch (_that) {
case HubEvent_ServerStarted():
return serverStarted(_that);case HubEvent_ServerStopped():
return serverStopped(_that);case HubEvent_PeerDiscovered():
return peerDiscovered(_that);case HubEvent_PeerLost():
return peerLost(_that);case HubEvent_Paired():
return paired(_that);case HubEvent_SyncProgress():
return syncProgress(_that);case HubEvent_ControllerConnected():
return controllerConnected(_that);case HubEvent_ControllerDisconnected():
return controllerDisconnected(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( HubEvent_ServerStarted value)?  serverStarted,TResult? Function( HubEvent_ServerStopped value)?  serverStopped,TResult? Function( HubEvent_PeerDiscovered value)?  peerDiscovered,TResult? Function( HubEvent_PeerLost value)?  peerLost,TResult? Function( HubEvent_Paired value)?  paired,TResult? Function( HubEvent_SyncProgress value)?  syncProgress,TResult? Function( HubEvent_ControllerConnected value)?  controllerConnected,TResult? Function( HubEvent_ControllerDisconnected value)?  controllerDisconnected,}){
final _that = this;
switch (_that) {
case HubEvent_ServerStarted() when serverStarted != null:
return serverStarted(_that);case HubEvent_ServerStopped() when serverStopped != null:
return serverStopped(_that);case HubEvent_PeerDiscovered() when peerDiscovered != null:
return peerDiscovered(_that);case HubEvent_PeerLost() when peerLost != null:
return peerLost(_that);case HubEvent_Paired() when paired != null:
return paired(_that);case HubEvent_SyncProgress() when syncProgress != null:
return syncProgress(_that);case HubEvent_ControllerConnected() when controllerConnected != null:
return controllerConnected(_that);case HubEvent_ControllerDisconnected() when controllerDisconnected != null:
return controllerDisconnected(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int port)?  serverStarted,TResult Function()?  serverStopped,TResult Function( String id,  String name)?  peerDiscovered,TResult Function( String id)?  peerLost,TResult Function( String id,  String name)?  paired,TResult Function( String peer,  BigInt done,  BigInt total)?  syncProgress,TResult Function( String peer)?  controllerConnected,TResult Function()?  controllerDisconnected,required TResult orElse(),}) {final _that = this;
switch (_that) {
case HubEvent_ServerStarted() when serverStarted != null:
return serverStarted(_that.port);case HubEvent_ServerStopped() when serverStopped != null:
return serverStopped();case HubEvent_PeerDiscovered() when peerDiscovered != null:
return peerDiscovered(_that.id,_that.name);case HubEvent_PeerLost() when peerLost != null:
return peerLost(_that.id);case HubEvent_Paired() when paired != null:
return paired(_that.id,_that.name);case HubEvent_SyncProgress() when syncProgress != null:
return syncProgress(_that.peer,_that.done,_that.total);case HubEvent_ControllerConnected() when controllerConnected != null:
return controllerConnected(_that.peer);case HubEvent_ControllerDisconnected() when controllerDisconnected != null:
return controllerDisconnected();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int port)  serverStarted,required TResult Function()  serverStopped,required TResult Function( String id,  String name)  peerDiscovered,required TResult Function( String id)  peerLost,required TResult Function( String id,  String name)  paired,required TResult Function( String peer,  BigInt done,  BigInt total)  syncProgress,required TResult Function( String peer)  controllerConnected,required TResult Function()  controllerDisconnected,}) {final _that = this;
switch (_that) {
case HubEvent_ServerStarted():
return serverStarted(_that.port);case HubEvent_ServerStopped():
return serverStopped();case HubEvent_PeerDiscovered():
return peerDiscovered(_that.id,_that.name);case HubEvent_PeerLost():
return peerLost(_that.id);case HubEvent_Paired():
return paired(_that.id,_that.name);case HubEvent_SyncProgress():
return syncProgress(_that.peer,_that.done,_that.total);case HubEvent_ControllerConnected():
return controllerConnected(_that.peer);case HubEvent_ControllerDisconnected():
return controllerDisconnected();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int port)?  serverStarted,TResult? Function()?  serverStopped,TResult? Function( String id,  String name)?  peerDiscovered,TResult? Function( String id)?  peerLost,TResult? Function( String id,  String name)?  paired,TResult? Function( String peer,  BigInt done,  BigInt total)?  syncProgress,TResult? Function( String peer)?  controllerConnected,TResult? Function()?  controllerDisconnected,}) {final _that = this;
switch (_that) {
case HubEvent_ServerStarted() when serverStarted != null:
return serverStarted(_that.port);case HubEvent_ServerStopped() when serverStopped != null:
return serverStopped();case HubEvent_PeerDiscovered() when peerDiscovered != null:
return peerDiscovered(_that.id,_that.name);case HubEvent_PeerLost() when peerLost != null:
return peerLost(_that.id);case HubEvent_Paired() when paired != null:
return paired(_that.id,_that.name);case HubEvent_SyncProgress() when syncProgress != null:
return syncProgress(_that.peer,_that.done,_that.total);case HubEvent_ControllerConnected() when controllerConnected != null:
return controllerConnected(_that.peer);case HubEvent_ControllerDisconnected() when controllerDisconnected != null:
return controllerDisconnected();case _:
  return null;

}
}

}

/// @nodoc


class HubEvent_ServerStarted extends HubEvent {
  const HubEvent_ServerStarted({required this.port}): super._();
  

 final  int port;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HubEvent_ServerStartedCopyWith<HubEvent_ServerStarted> get copyWith => _$HubEvent_ServerStartedCopyWithImpl<HubEvent_ServerStarted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is HubEvent_ServerStarted&&(identical(other.port, port) || other.port == port));
}


@override
int get hashCode {
    return Object.hash(runtimeType,port);
}

@override
String toString() {
    return 'HubEvent.serverStarted(port: $port)';
}


}

/// @nodoc
abstract mixin class $HubEvent_ServerStartedCopyWith<$Res> implements $HubEventCopyWith<$Res> {
  factory $HubEvent_ServerStartedCopyWith(HubEvent_ServerStarted value, $Res Function(HubEvent_ServerStarted) _then) = _$HubEvent_ServerStartedCopyWithImpl;
@useResult
$Res call({
 int port
});




}
/// @nodoc
class _$HubEvent_ServerStartedCopyWithImpl<$Res>
    implements $HubEvent_ServerStartedCopyWith<$Res> {
  _$HubEvent_ServerStartedCopyWithImpl(this._self, this._then);

  final HubEvent_ServerStarted _self;
  final $Res Function(HubEvent_ServerStarted) _then;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? port = null,}) {
  return _then(HubEvent_ServerStarted(
port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class HubEvent_ServerStopped extends HubEvent {
  const HubEvent_ServerStopped(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is HubEvent_ServerStopped);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'HubEvent.serverStopped()';
}


}




/// @nodoc


class HubEvent_PeerDiscovered extends HubEvent {
  const HubEvent_PeerDiscovered({required this.id, required this.name}): super._();
  

 final  String id;
 final  String name;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HubEvent_PeerDiscoveredCopyWith<HubEvent_PeerDiscovered> get copyWith => _$HubEvent_PeerDiscoveredCopyWithImpl<HubEvent_PeerDiscovered>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is HubEvent_PeerDiscovered&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name);
}

@override
String toString() {
    return 'HubEvent.peerDiscovered(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $HubEvent_PeerDiscoveredCopyWith<$Res> implements $HubEventCopyWith<$Res> {
  factory $HubEvent_PeerDiscoveredCopyWith(HubEvent_PeerDiscovered value, $Res Function(HubEvent_PeerDiscovered) _then) = _$HubEvent_PeerDiscoveredCopyWithImpl;
@useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class _$HubEvent_PeerDiscoveredCopyWithImpl<$Res>
    implements $HubEvent_PeerDiscoveredCopyWith<$Res> {
  _$HubEvent_PeerDiscoveredCopyWithImpl(this._self, this._then);

  final HubEvent_PeerDiscovered _self;
  final $Res Function(HubEvent_PeerDiscovered) _then;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(HubEvent_PeerDiscovered(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class HubEvent_PeerLost extends HubEvent {
  const HubEvent_PeerLost({required this.id}): super._();
  

 final  String id;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HubEvent_PeerLostCopyWith<HubEvent_PeerLost> get copyWith => _$HubEvent_PeerLostCopyWithImpl<HubEvent_PeerLost>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is HubEvent_PeerLost&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id);
}

@override
String toString() {
    return 'HubEvent.peerLost(id: $id)';
}


}

/// @nodoc
abstract mixin class $HubEvent_PeerLostCopyWith<$Res> implements $HubEventCopyWith<$Res> {
  factory $HubEvent_PeerLostCopyWith(HubEvent_PeerLost value, $Res Function(HubEvent_PeerLost) _then) = _$HubEvent_PeerLostCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$HubEvent_PeerLostCopyWithImpl<$Res>
    implements $HubEvent_PeerLostCopyWith<$Res> {
  _$HubEvent_PeerLostCopyWithImpl(this._self, this._then);

  final HubEvent_PeerLost _self;
  final $Res Function(HubEvent_PeerLost) _then;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(HubEvent_PeerLost(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class HubEvent_Paired extends HubEvent {
  const HubEvent_Paired({required this.id, required this.name}): super._();
  

 final  String id;
 final  String name;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HubEvent_PairedCopyWith<HubEvent_Paired> get copyWith => _$HubEvent_PairedCopyWithImpl<HubEvent_Paired>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is HubEvent_Paired&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name);
}

@override
String toString() {
    return 'HubEvent.paired(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $HubEvent_PairedCopyWith<$Res> implements $HubEventCopyWith<$Res> {
  factory $HubEvent_PairedCopyWith(HubEvent_Paired value, $Res Function(HubEvent_Paired) _then) = _$HubEvent_PairedCopyWithImpl;
@useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class _$HubEvent_PairedCopyWithImpl<$Res>
    implements $HubEvent_PairedCopyWith<$Res> {
  _$HubEvent_PairedCopyWithImpl(this._self, this._then);

  final HubEvent_Paired _self;
  final $Res Function(HubEvent_Paired) _then;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(HubEvent_Paired(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class HubEvent_SyncProgress extends HubEvent {
  const HubEvent_SyncProgress({required this.peer, required this.done, required this.total}): super._();
  

 final  String peer;
 final  BigInt done;
 final  BigInt total;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HubEvent_SyncProgressCopyWith<HubEvent_SyncProgress> get copyWith => _$HubEvent_SyncProgressCopyWithImpl<HubEvent_SyncProgress>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is HubEvent_SyncProgress&&(identical(other.peer, peer) || other.peer == peer)&&(identical(other.done, done) || other.done == done)&&(identical(other.total, total) || other.total == total));
}


@override
int get hashCode {
    return Object.hash(runtimeType,peer,done,total);
}

@override
String toString() {
    return 'HubEvent.syncProgress(peer: $peer, done: $done, total: $total)';
}


}

/// @nodoc
abstract mixin class $HubEvent_SyncProgressCopyWith<$Res> implements $HubEventCopyWith<$Res> {
  factory $HubEvent_SyncProgressCopyWith(HubEvent_SyncProgress value, $Res Function(HubEvent_SyncProgress) _then) = _$HubEvent_SyncProgressCopyWithImpl;
@useResult
$Res call({
 String peer, BigInt done, BigInt total
});




}
/// @nodoc
class _$HubEvent_SyncProgressCopyWithImpl<$Res>
    implements $HubEvent_SyncProgressCopyWith<$Res> {
  _$HubEvent_SyncProgressCopyWithImpl(this._self, this._then);

  final HubEvent_SyncProgress _self;
  final $Res Function(HubEvent_SyncProgress) _then;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peer = null,Object? done = null,Object? total = null,}) {
  return _then(HubEvent_SyncProgress(
peer: null == peer ? _self.peer : peer // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as BigInt,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class HubEvent_ControllerConnected extends HubEvent {
  const HubEvent_ControllerConnected({required this.peer}): super._();
  

 final  String peer;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HubEvent_ControllerConnectedCopyWith<HubEvent_ControllerConnected> get copyWith => _$HubEvent_ControllerConnectedCopyWithImpl<HubEvent_ControllerConnected>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is HubEvent_ControllerConnected&&(identical(other.peer, peer) || other.peer == peer));
}


@override
int get hashCode {
    return Object.hash(runtimeType,peer);
}

@override
String toString() {
    return 'HubEvent.controllerConnected(peer: $peer)';
}


}

/// @nodoc
abstract mixin class $HubEvent_ControllerConnectedCopyWith<$Res> implements $HubEventCopyWith<$Res> {
  factory $HubEvent_ControllerConnectedCopyWith(HubEvent_ControllerConnected value, $Res Function(HubEvent_ControllerConnected) _then) = _$HubEvent_ControllerConnectedCopyWithImpl;
@useResult
$Res call({
 String peer
});




}
/// @nodoc
class _$HubEvent_ControllerConnectedCopyWithImpl<$Res>
    implements $HubEvent_ControllerConnectedCopyWith<$Res> {
  _$HubEvent_ControllerConnectedCopyWithImpl(this._self, this._then);

  final HubEvent_ControllerConnected _self;
  final $Res Function(HubEvent_ControllerConnected) _then;

/// Create a copy of HubEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peer = null,}) {
  return _then(HubEvent_ControllerConnected(
peer: null == peer ? _self.peer : peer // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class HubEvent_ControllerDisconnected extends HubEvent {
  const HubEvent_ControllerDisconnected(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is HubEvent_ControllerDisconnected);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'HubEvent.controllerDisconnected()';
}


}




/// @nodoc
mixin _$TransportCmd {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportCmd);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TransportCmd()';
}


}

/// @nodoc
class $TransportCmdCopyWith<$Res>  {
$TransportCmdCopyWith(TransportCmd _, $Res Function(TransportCmd) __);
}


/// Adds pattern-matching-related methods to [TransportCmd].
extension TransportCmdPatterns on TransportCmd {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TransportCmd_Play value)?  play,TResult Function( TransportCmd_Stop value)?  stop,TResult Function( TransportCmd_Seek value)?  seek,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TransportCmd_Play() when play != null:
return play(_that);case TransportCmd_Stop() when stop != null:
return stop(_that);case TransportCmd_Seek() when seek != null:
return seek(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TransportCmd_Play value)  play,required TResult Function( TransportCmd_Stop value)  stop,required TResult Function( TransportCmd_Seek value)  seek,}){
final _that = this;
switch (_that) {
case TransportCmd_Play():
return play(_that);case TransportCmd_Stop():
return stop(_that);case TransportCmd_Seek():
return seek(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TransportCmd_Play value)?  play,TResult? Function( TransportCmd_Stop value)?  stop,TResult? Function( TransportCmd_Seek value)?  seek,}){
final _that = this;
switch (_that) {
case TransportCmd_Play() when play != null:
return play(_that);case TransportCmd_Stop() when stop != null:
return stop(_that);case TransportCmd_Seek() when seek != null:
return seek(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  play,TResult Function()?  stop,TResult Function( double field0)?  seek,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TransportCmd_Play() when play != null:
return play();case TransportCmd_Stop() when stop != null:
return stop();case TransportCmd_Seek() when seek != null:
return seek(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  play,required TResult Function()  stop,required TResult Function( double field0)  seek,}) {final _that = this;
switch (_that) {
case TransportCmd_Play():
return play();case TransportCmd_Stop():
return stop();case TransportCmd_Seek():
return seek(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  play,TResult? Function()?  stop,TResult? Function( double field0)?  seek,}) {final _that = this;
switch (_that) {
case TransportCmd_Play() when play != null:
return play();case TransportCmd_Stop() when stop != null:
return stop();case TransportCmd_Seek() when seek != null:
return seek(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class TransportCmd_Play extends TransportCmd {
  const TransportCmd_Play(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportCmd_Play);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TransportCmd.play()';
}


}




/// @nodoc


class TransportCmd_Stop extends TransportCmd {
  const TransportCmd_Stop(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportCmd_Stop);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TransportCmd.stop()';
}


}




/// @nodoc


class TransportCmd_Seek extends TransportCmd {
  const TransportCmd_Seek(this.field0): super._();
  

 final  double field0;

/// Create a copy of TransportCmd
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransportCmd_SeekCopyWith<TransportCmd_Seek> get copyWith => _$TransportCmd_SeekCopyWithImpl<TransportCmd_Seek>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportCmd_Seek&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'TransportCmd.seek(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TransportCmd_SeekCopyWith<$Res> implements $TransportCmdCopyWith<$Res> {
  factory $TransportCmd_SeekCopyWith(TransportCmd_Seek value, $Res Function(TransportCmd_Seek) _then) = _$TransportCmd_SeekCopyWithImpl;
@useResult
$Res call({
 double field0
});




}
/// @nodoc
class _$TransportCmd_SeekCopyWithImpl<$Res>
    implements $TransportCmd_SeekCopyWith<$Res> {
  _$TransportCmd_SeekCopyWithImpl(this._self, this._then);

  final TransportCmd_Seek _self;
  final $Res Function(TransportCmd_Seek) _then;

/// Create a copy of TransportCmd
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(TransportCmd_Seek(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
