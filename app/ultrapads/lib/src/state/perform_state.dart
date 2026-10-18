import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_engine/up_engine.dart';

import '../features/tutorial/tutorial_timing.dart';
import 'engine_state.dart';

/// 演奏页当前显示的页（0 = A，1 = B）——纯 UI 状态。
class BankController extends Notifier<int> {
  @override
  int build() {
    // 加载新 Kit 时翻回 A（APK：KitLoaded → A）
    ref.listen(
      engineViewProvider.select((v) => v.kit?.id),
      (_, _) => state = 0,
    );
    return 0;
  }

  void toggle() => state = state == 0 ? 1 : 0;
  void set(int bank) => state = bank;
}

final bankProvider = NotifierProvider<BankController, int>(BankController.new);

/// 教程判定（4.7.0：PERFECT / TOO FAST / TOO SLOW，外加 MISS）。
enum TutorialJudgement { perfect, tooFast, tooSlow, miss }

/// 最近一次判定（用于反馈动画）。
class TutorialFeedback {
  const TutorialFeedback(this.judgement, this.flat, this.serial);
  final TutorialJudgement judgement;
  final int? flat;

  /// 递增序号，让相同判定也能触发新动画。
  final int serial;
}

/// 教程会话（UI 逻辑：消费引擎给的 TutorialChart，不改变业务状态）。
///
/// 时间轴模式（4.7.0）：[position] 由 UI 时钟推进（× [speed]），pad 在目标时间前
/// [TutorialTiming.fill] 开始填满；无时间的旧版谱面退化为按顺序逐步高亮。
class TutorialSession {
  const TutorialSession({
    required this.chart,
    this.position = 0,
    this.playing = true,
    this.speed = 1.0,
    this.resolved = const {},
    this.pressed = const {},
    this.feedback,
    this.completed = false,
    this.perfectCount = 0,
  });

  final TutorialChart chart;
  final double position;
  final bool playing;
  final double speed;

  /// 已结束的步骤下标。
  final Set<int> resolved;

  /// 步骤下标 → 已按中的 pad（多 pad 同时按的步骤）。
  final Map<int, Set<int>> pressed;
  final TutorialFeedback? feedback;
  final bool completed;
  final int perfectCount;

  bool get timed => chart.timed;
  int get total => chart.steps.length;
  double get length => chart.length;

  /// 第一个未结束的步骤。
  int get step {
    for (var i = 0; i < total; i++) {
      if (!resolved.contains(i)) return i;
    }
    return total;
  }

  double get progress => timed
      ? (length <= 0 ? 0 : (position / length).clamp(0.0, 1.0))
      : (total <= 1 ? 1.0 : step / (total - 1)).clamp(0.0, 1.0);

  /// 正在等待（已开始填充、尚未结束）的步骤。
  Iterable<int> activeSteps(double fillSecs) sync* {
    for (var i = 0; i < total; i++) {
      if (resolved.contains(i)) continue;
      final s = chart.steps[i];
      if (!timed) {
        yield i;
        return;
      }
      final t = s.timeSecs ?? 0;
      if (position >= t - fillSecs) yield i;
    }
  }

  /// 当前要求的页（第一个未结束的翻页步骤且已到时）。
  int? requiredBank(double fillSecs) {
    for (final i in activeSteps(fillSecs)) {
      final s = chart.steps[i];
      if (s.page != null) return s.page;
      if (s.pads.isNotEmpty) return s.pads.first.bank;
    }
    return null;
  }

  /// 目标 pad → 填充进度（0..1）。
  Map<int, double> fills(double fillSecs) {
    final out = <int, double>{};
    for (final i in activeSteps(fillSecs)) {
      final s = chart.steps[i];
      final done = pressed[i] ?? const {};
      for (final p in s.pads) {
        if (done.contains(p.flat)) continue;
        final f = timed && fillSecs > 0
            ? ((position - ((s.timeSecs ?? 0) - fillSecs)) / fillSecs).clamp(
                0.0,
                1.0,
              )
            : 1.0;
        out[p.flat] = out[p.flat] == null
            ? f
            : (out[p.flat]! > f ? out[p.flat]! : f);
      }
    }
    return out;
  }

  TutorialSession copyWith({
    double? position,
    bool? playing,
    double? speed,
    Set<int>? resolved,
    Map<int, Set<int>>? pressed,
    TutorialFeedback? feedback,
    bool? completed,
    int? perfectCount,
  }) => TutorialSession(
    chart: chart,
    position: position ?? this.position,
    playing: playing ?? this.playing,
    speed: speed ?? this.speed,
    resolved: resolved ?? this.resolved,
    pressed: pressed ?? this.pressed,
    feedback: feedback ?? this.feedback,
    completed: completed ?? this.completed,
    perfectCount: perfectCount ?? this.perfectCount,
  );
}

class TutorialController extends Notifier<TutorialSession?> {
  @override
  TutorialSession? build() => null;

  int _serial = 0;
  double get _fill => TutorialTiming.fill.inMicroseconds / 1e6;

  /// 判定窗口：优先用引擎谱面给的毫秒值，否则用 TutorialTiming 默认值。
  double get _perfect =>
      (state?.chart.perfectMs ??
          TutorialTiming.perfectWindow.inMicroseconds / 1e3) /
      1e3;
  double get _miss =>
      (state?.chart.missMs ?? TutorialTiming.missWindow.inMicroseconds / 1e3) /
      1e3;

  void start(TutorialChart chart) {
    if (chart.steps.isEmpty) return;
    // 时间轴从「第一步前一个填充时长」开始，让第一个 pad 有完整的填充过程。
    final first = chart.steps
        .map((s) => s.timeSecs ?? 0)
        .fold<double>(double.infinity, (a, b) => a < b ? a : b);
    state = TutorialSession(
      chart: chart,
      position: chart.timed ? first - _fill : 0,
    );
  }

  /// 退出教程：速度恢复 1.0（4.7.0 的速度控件只属于教程模式）。
  void stop() {
    if ((state?.speed ?? 1) != 1) _applySpeed(1);
    state = null;
  }

  void togglePlay() {
    final s = state;
    if (s != null) state = s.copyWith(playing: !s.playing);
  }

  /// 速度 1.0 / 0.7 / 0.5：引擎 `SetSpeed` 实时变速播放（varispeed），
  /// 教程时间轴按同一比例推进（引擎 `transport_clock.song_secs` 同样按 speed 推进）。
  void setSpeed(double v) {
    final s = state;
    if (s == null) return;
    _applySpeed(v);
    state = s.copyWith(speed: v);
  }

  void _applySpeed(double v) => ref.read(engineProvider).send(SetSpeedCmd(v));

  /// 拖动进度条（0..1）：重置之后的步骤。
  void seekFraction(double f) {
    final s = state;
    if (s == null) return;
    if (!s.timed) {
      final target = (f * (s.total - 1)).round();
      state = s.copyWith(
        resolved: {for (var i = 0; i < target; i++) i},
        pressed: const {},
      );
      return;
    }
    final pos = f * s.length;
    state = s.copyWith(
      position: pos,
      resolved: {
        for (var i = 0; i < s.total; i++)
          if ((s.chart.steps[i].timeSecs ?? 0) < pos) i,
      },
      pressed: const {},
      completed: false,
    );
  }

  /// UI 时钟推进（秒，未乘速度）。
  void tick(double dt, int bank) {
    final s = state;
    if (s == null || !s.playing || s.completed || !s.timed) return;
    final pos = s.position + dt * s.speed;
    var resolved = s.resolved;
    TutorialFeedback? fb;
    for (var i = 0; i < s.total; i++) {
      if (resolved.contains(i)) continue;
      final step = s.chart.steps[i];
      final t = step.timeSecs ?? 0;
      if (step.page != null) {
        if (pos >= t - _fill && bank == step.page) resolved = {...resolved, i};
        continue;
      }
      if (pos > t + _miss) {
        resolved = {...resolved, i};
        fb = TutorialFeedback(
          TutorialJudgement.miss,
          step.pads.firstOrNull?.flat,
          ++_serial,
        );
      }
    }
    final done = resolved.length >= s.total && pos >= s.length;
    state = s.copyWith(
      position: pos,
      resolved: resolved,
      feedback: fb,
      completed: done,
    );
  }

  /// 用户按下 pad：判定离它最近的活动步骤。
  TutorialJudgement? onPad(int flat, int bank) {
    final s = state;
    if (s == null || s.completed) return null;
    int? best;
    double bestDist = double.infinity;
    for (final i in s.activeSteps(_fill)) {
      final step = s.chart.steps[i];
      if (!step.pads.any((p) => p.flat == flat)) continue;
      if (s.pressed[i]?.contains(flat) ?? false) continue;
      final d = ((step.timeSecs ?? s.position) - s.position).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    if (best == null) return null;
    final step = s.chart.steps[best];
    final delta = s.position - (step.timeSecs ?? s.position);
    final j = !s.timed || delta.abs() <= _perfect
        ? TutorialJudgement.perfect
        : delta < 0
        ? TutorialJudgement.tooFast
        : TutorialJudgement.tooSlow;
    final hit = {...?s.pressed[best], flat};
    final stepDone = step.pads.every((p) => hit.contains(p.flat));
    final resolved = stepDone ? {...s.resolved, best} : s.resolved;
    state = s.copyWith(
      pressed: {...s.pressed, best: hit},
      resolved: resolved,
      feedback: TutorialFeedback(j, flat, ++_serial),
      perfectCount: s.perfectCount + (j == TutorialJudgement.perfect ? 1 : 0),
      completed: !s.timed && resolved.length >= s.total,
    );
    return j;
  }

  /// 用户切页（无时间谱面：翻页步骤立即完成）。
  void onBank(int bank) {
    final s = state;
    if (s == null || s.timed) return;
    var resolved = s.resolved;
    for (final i in s.activeSteps(_fill)) {
      if (s.chart.steps[i].page == bank) resolved = {...resolved, i};
      break;
    }
    state = s.copyWith(
      resolved: resolved,
      completed: resolved.length >= s.total,
    );
  }

  /// 无时间谱面：当前页已满足的翻页步骤自动完成。
  void settle(int bank) {
    final s = state;
    if (s == null || s.timed) return;
    var resolved = s.resolved;
    for (var i = 0; i < s.total; i++) {
      if (resolved.contains(i)) continue;
      if (s.chart.steps[i].page == bank && s.chart.steps[i].pads.isEmpty) {
        resolved = {...resolved, i};
      } else {
        break;
      }
    }
    state = s.copyWith(resolved: resolved);
  }
}

final tutorialProvider = NotifierProvider<TutorialController, TutorialSession?>(
  TutorialController.new,
);
