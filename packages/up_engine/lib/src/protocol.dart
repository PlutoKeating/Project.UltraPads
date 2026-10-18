/// 引擎协议：`Command`（UI → 引擎）与 `EngineEvent`（引擎 → UI）。
/// 对照 `docs/API.md` §2 / `engine/up-protocol`。
library;

import 'models.dart';

sealed class Command {
  const Command();
}

final class PadDownCmd extends Command {
  const PadDownCmd(this.pad, {this.velocity = 1.0});
  final PadId pad;
  final double velocity;
}

final class PadUpCmd extends Command {
  const PadUpCmd(this.pad);
  final PadId pad;
}

final class StopAllCmd extends Command {
  const StopAllCmd();
}

final class SetTempoCmd extends Command {
  const SetTempoCmd(this.bpm);
  final double bpm;
}

/// 0.5..=2.0，界面上的 1.0x。
final class SetSpeedCmd extends Command {
  const SetSpeedCmd(this.ratio);
  final double ratio;
}

final class SetQuantizeCmd extends Command {
  const SetQuantizeCmd(this.q);
  final Quantize q;
}

final class SetPadParamsCmd extends Command {
  const SetPadParamsCmd(this.pad, this.params);
  final PadId pad;
  final PadParams params;
}

final class SetMasterGainCmd extends Command {
  const SetMasterGainCmd(this.gain);
  final double gain;
}

final class StartRecordingCmd extends Command {
  const StartRecordingCmd();
}

final class StopRecordingCmd extends Command {
  const StopRecordingCmd();
}

enum TransportAction { play, stop, seek }

final class TransportCmd extends Command {
  const TransportCmd(this.action, {this.beat = 0});
  final TransportAction action;
  final double beat;
}

sealed class EngineEvent {
  const EngineEvent();
}

final class PadStateEvent extends EngineEvent {
  const PadStateEvent(this.pad, this.state);
  final PadId pad;
  final PadPlayState state;
}

final class TransportEvent extends EngineEvent {
  const TransportEvent(this.transport);
  final TransportState transport;
}

final class MetersEvent extends EngineEvent {
  const MetersEvent(this.meters);
  final Meters meters;
}

final class RecorderEvent extends EngineEvent {
  const RecorderEvent(this.state, this.elapsedSecs, {this.track});
  final RecorderState state;
  final double elapsedSecs;

  /// 录音结束时生成的作品。
  final TrackInfo? track;
}

final class KitLoadedEvent extends EngineEvent {
  const KitLoadedEvent(this.kit, this.pads);
  final KitSummary kit;
  final List<PadParams> pads;
}

final class LibraryChangedEvent extends EngineEvent {
  const LibraryChangedEvent();
}

/// 作品播放进度（TRACK 卡）。
final class TrackPlaybackEvent extends EngineEvent {
  const TrackPlaybackEvent(
    this.trackId,
    this.positionSecs, {
    this.playing = true,
  });
  final String? trackId;
  final double positionSecs;
  final bool playing;
}

final class HubEventWrapper extends EngineEvent {
  const HubEventWrapper(this.event);
  final HubEvent event;
}

final class ErrorEvent extends EngineEvent {
  const ErrorEvent(this.error);
  final EngineException error;
}

sealed class HubEvent {
  const HubEvent();
}

final class HubServerChanged extends HubEvent {
  const HubServerChanged(this.status);
  final HubServerStatus status;
}

final class HubPeerPaired extends HubEvent {
  const HubPeerPaired(this.device);
  final PairedDevice device;
}

final class HubSyncProgress extends HubEvent {
  const HubSyncProgress(this.peerId, this.progress, {this.report});
  final String peerId;

  /// 0..1；完成时为 1 并携带 [report]。
  final double progress;
  final SyncReport? report;
}

final class HubControllerChanged extends HubEvent {
  const HubControllerChanged({required this.connected, this.peer});
  final bool connected;
  final HubPeer? peer;
}
