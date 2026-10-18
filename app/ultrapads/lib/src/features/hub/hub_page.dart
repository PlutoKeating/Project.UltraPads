import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../routing/routes.dart';
import '../../state/engine_state.dart';

/// 多设备协同（F10）：
/// - 本机（桌面优先）：开启 Hub，显示 6 位配对码；
/// - 附近的设备（手机优先）：mDNS 发现 → 输入配对码 → 同步曲库 → 控制器模式
///   （之后演奏页的 pad 事件转发到电脑引擎）。
class HubPage extends ConsumerStatefulWidget {
  const HubPage({super.key});

  @override
  ConsumerState<HubPage> createState() => _HubPageState();
}

class _HubPageState extends ConsumerState<HubPage> {
  final List<HubPeer> _peers = [];
  StreamSubscription<HubPeer>? _discovery;
  bool _discovering = false;
  bool _unsupported = false;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  EngineClient get _engine => ref.read(engineProvider);

  @override
  void initState() {
    super.initState();
    _discover();
  }

  @override
  void dispose() {
    _discovery?.cancel();
    super.dispose();
  }

  void _discover() {
    _discovery?.cancel();
    setState(() {
      _peers.clear();
      _discovering = true;
    });
    _discovery = _engine.hubDiscover().listen(
      (p) => setState(() {
        _peers.removeWhere((e) => e.id == p.id);
        _peers.add(p);
      }),
      onError: (Object e) => setState(() {
        _discovering = false;
        _unsupported = e is EngineNotImplemented;
      }),
      onDone: () => setState(() => _discovering = false),
    );
  }

  Future<void> _toggleServer(bool on) async {
    final l10n = context.l10n;
    final ok = await tryEngineDo(() async {
      if (on) {
        await _engine.hubStartServer(Platform.localHostname);
      } else {
        await _engine.hubStopServer();
      }
    });
    if (!ok && mounted) showUpToast(context, l10n.errorEngineUnsupported);
  }

  Future<void> _pair(HubPeer peer) async {
    final l10n = context.l10n;
    final code = await showUpDialog<String>(
      context,
      builder: (ctx) => UpDialog(
        title: l10n.pairingConfirm(peer.name),
        message: l10n.pairingEnterCode,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: UpSpacing.md,
          children: [
            PairingCodeInput(
              onCompleted: (v) => Navigator.pop(ctx, v),
              semanticLabel: l10n.pairingCodeTitle,
            ),
            UpText(
              l10n.pairingOwnDevicesOnly,
              role: UpTextRole.caption,
              color: UpTheme.of(ctx).colors.textSecondary,
            ),
          ],
        ),
        actions: [
          UpButton(
            label: l10n.commonCancel,
            variant: UpButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
    if (code == null || !mounted) return;
    try {
      final d = await _engine.hubPair(peer, code);
      if (mounted) showUpToast(context, l10n.pairingSuccess(d.peer.name));
    } on EngineNotImplemented {
      if (mounted) showUpToast(context, l10n.errorEngineUnsupported);
    } on EngineException {
      if (mounted) showUpToast(context, l10n.pairingFailed);
    }
  }

  Future<void> _sync(HubPeer peer) async {
    final l10n = context.l10n;
    final report = await tryEngine(() => _engine.hubSync(peer));
    if (!mounted) return;
    if (report == null) {
      showUpToast(context, l10n.errorEngineUnsupported);
    } else {
      showUpToast(
        context,
        report.conflicts > 0
            ? l10n.hubSyncConflicts(report.conflicts)
            : l10n.hubSyncDone,
      );
    }
  }

  Future<void> _controller(HubPeer peer) async {
    final ok = await tryEngineDo(() => _engine.hubControllerConnect(peer));
    if (!mounted) return;
    if (!ok) {
      showUpToast(context, context.l10n.errorEngineUnsupported);
      return;
    }
    context.go(Routes.perform);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final hub = ref.watch(hubViewProvider);
    final paired = {for (final d in hub.paired) d.peer.id};

    final local = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: UpSpacing.md,
      children: [
        UpText(
          l10n.hubThisDevice,
          role: UpTextRole.titleSm,
          color: c.textSecondary,
        ),
        UpSwitchRow(
          title: l10n.hubEnable,
          subtitle: hub.server.running
              ? l10n.hubRunning('${Platform.localHostname}:${hub.server.port}')
              : l10n.hubStopped,
          value: hub.server.running,
          onChanged: _toggleServer,
        ),
        if (hub.server.running && hub.server.pairingCode.isNotEmpty) ...[
          UpText(
            l10n.pairingCodeTitle,
            role: UpTextRole.label,
            color: c.textPrimary,
            align: TextAlign.center,
          ),
          Center(
            child: PairingCodeDisplay(
              code: hub.server.pairingCode,
              semanticLabel: l10n.pairingCodeTitle,
            ),
          ),
          UpText(
            l10n.pairingCodeBody(hub.server.pairingCode),
            role: UpTextRole.caption,
            color: c.textSecondary,
            align: TextAlign.center,
            maxLines: 2,
          ),
        ],
        UpText(
          l10n.hubDeviceCount(hub.paired.length),
          role: UpTextRole.caption,
          color: c.textMuted,
        ),
      ],
    );

    final nearby = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: UpSpacing.md,
      children: [
        Row(
          children: [
            Expanded(
              child: UpText(
                l10n.hubNearbyDevices,
                role: UpTextRole.titleSm,
                color: c.textSecondary,
              ),
            ),
            UpIconButton(
              icon: Icons.refresh_rounded,
              semanticLabel: l10n.commonRetry,
              onPressed: _discover,
            ),
          ],
        ),
        UpText(
          l10n.pairingSameNetwork,
          role: UpTextRole.caption,
          color: c.textMuted,
          maxLines: 2,
        ),
        if (_unsupported)
          UpText(
            l10n.errorEngineUnsupported,
            role: UpTextRole.body,
            color: c.statusWarning,
          )
        else if (_peers.isEmpty)
          UpText(
            _discovering ? l10n.hubDiscovering : l10n.hubNoDevices,
            role: UpTextRole.body,
            color: c.textSecondary,
          ),
        for (final p in _peers)
          _PeerCard(
            peer: p,
            paired: paired.contains(p.id) || p.paired,
            progress: hub.syncProgress[p.id],
            controlling: hub.controllerPeer?.id == p.id,
            onPair: () => _pair(p),
            onSync: () => _sync(p),
            onController: () => _controller(p),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: c.surfacePage,
      body: SafeArea(
        child: Column(
          children: [
            UpTopBar(
              leading: UpIconButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: l10n.commonBack,
                onPressed: () => context.pop(),
              ),
              title: l10n.hubTitle,
              centerTitle: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(UpPageTokens.paddingX),
                children: [
                  UpText(
                    l10n.hubDescription,
                    role: UpTextRole.body,
                    color: c.textSecondary,
                    maxLines: 4,
                  ),
                  const SizedBox(height: UpSpacing.xxl),
                  if (_isDesktop) ...[
                    local,
                    const SizedBox(height: UpSpacing.xxxl),
                    nearby,
                  ] else ...[
                    nearby,
                    const SizedBox(height: UpSpacing.xxxl),
                    local,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerCard extends StatelessWidget {
  const _PeerCard({
    required this.peer,
    required this.paired,
    required this.progress,
    required this.controlling,
    required this.onPair,
    required this.onSync,
    required this.onController,
  });

  final HubPeer peer;
  final bool paired;
  final double? progress;
  final bool controlling;
  final VoidCallback onPair;
  final VoidCallback onSync;
  final VoidCallback onController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final syncing = progress != null && progress! < 1;
    return Container(
      padding: const EdgeInsets.all(UpSpacing.lg),
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(UpKitCardTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: UpSpacing.md,
        children: [
          Row(
            spacing: UpSpacing.md,
            children: [
              Icon(
                peer.kind == HubPeerKind.desktop
                    ? Icons.computer_rounded
                    : Icons.smartphone_rounded,
                color: paired ? c.hubOnline : c.hubPairing,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UpText(
                      peer.name,
                      role: UpTextRole.titleSm,
                      color: c.textPrimary,
                    ),
                    UpText(
                      peer.address,
                      role: UpTextRole.caption,
                      color: c.textMuted,
                    ),
                  ],
                ),
              ),
              UpBadge(
                label: paired ? l10n.hubDeviceOnline : l10n.pairingNewDevice,
                kind: paired ? UpBadgeKind.isNew : UpBadgeKind.neutral,
              ),
            ],
          ),
          if (syncing) ...[
            UpText(
              l10n.hubSyncProgress((progress! * 100).round(), 100),
              role: UpTextRole.caption,
              color: c.textSecondary,
            ),
            UpSlider(value: progress!, onChanged: null),
          ],
          Wrap(
            spacing: UpSpacing.md,
            runSpacing: UpSpacing.md,
            children: paired
                ? [
                    UpButton(
                      label: l10n.hubSyncLibrary,
                      icon: Icons.sync_rounded,
                      variant: UpButtonVariant.secondary,
                      size: UpButtonSize.sm,
                      onPressed: syncing ? null : onSync,
                    ),
                    UpButton(
                      label: controlling
                          ? l10n.hubControlling(peer.name)
                          : l10n.hubUseAsController,
                      icon: Icons.gamepad_rounded,
                      size: UpButtonSize.sm,
                      onPressed: controlling ? null : onController,
                    ),
                  ]
                : [
                    UpButton(
                      label: l10n.pairingNewDevice,
                      icon: Icons.link_rounded,
                      size: UpButtonSize.sm,
                      onPressed: onPair,
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
