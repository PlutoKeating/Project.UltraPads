import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../routing/routes.dart';
import '../../state/engine_state.dart';

/// 多设备协同（F10，`docs/API.md` §3.1）：
/// - 本机（桌面优先显示）：开启 Hub → 6 位配对码、本机 IP:端口、受信设备与撤销、
///   正在控制本机的手机；
/// - 附近的设备（手机优先显示）：mDNS 发现 + 手动输入 IP → 配对 → 同步（进度）→
///   控制器模式（演奏页的 pad 事件转发到电脑引擎，可选本机同时发声）。
class HubPage extends ConsumerStatefulWidget {
  const HubPage({super.key});

  @override
  ConsumerState<HubPage> createState() => _HubPageState();
}

class _HubPageState extends ConsumerState<HubPage> {
  final Map<String, HubPeer> _peers = {};
  final _address = TextEditingController();
  StreamSubscription<HubPeerEvent>? _discovery;
  Timer? _latencyPoll;
  bool _discovering = false;
  bool _probing = false;
  bool _unsupported = false;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  late final EngineClient _engine = ref.read(engineProvider);

  @override
  void initState() {
    super.initState();
    _loadKnown();
    _discover();
    // 控制器模式下定时刷新往返延迟（同步读取，开销很小）。
    _latencyPoll = Timer.periodic(UpDurations.slower, (_) {
      if (ref.read(hubViewProvider).controller.connected) {
        ref.read(hubViewProvider.notifier).refreshController();
      }
    });
  }

  @override
  void dispose() {
    _discovery?.cancel();
    _latencyPoll?.cancel();
    // 停止 mDNS 浏览（释放 Android 组播锁）；只取消订阅要等下一个事件才生效。
    unawaited(tryEngineDo(_engine.hubDiscoverStop));
    _address.dispose();
    super.dispose();
  }

  Future<void> _loadKnown() async {
    final known = await tryEngine(_engine.hubKnownPeers);
    if (!mounted || known == null) return;
    setState(() {
      for (final p in known) {
        _peers[p.id] = p;
      }
    });
  }

  void _discover() {
    _discovery?.cancel();
    setState(() => _discovering = true);
    _discovery = _engine.hubDiscover().listen(
      (e) {
        if (!mounted) return;
        setState(() {
          switch (e) {
            case HubPeerFound(:final peer):
              _peers[peer.id] = peer;
            case HubPeerLost(:final id):
              // 已配对的 Hub 保留在列表里（还可以手动连接）。
              if (_peers[id]?.paired != true) _peers.remove(id);
          }
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _discovering = false;
          _unsupported = e is EngineNotImplemented;
        });
      },
      onDone: () {
        if (mounted) setState(() => _discovering = false);
      },
    );
  }

  Future<void> _toggleServer(bool on) async {
    final l10n = context.l10n;
    final hub = ref.read(hubViewProvider.notifier);
    final ok = await tryEngineDo(() async {
      if (on) {
        await _engine.hubStartServer(Platform.localHostname);
      } else {
        await _engine.hubStopServer();
      }
    });
    if (!mounted) return;
    if (!ok) {
      showUpToast(context, l10n.errorEngineUnsupported);
      return;
    }
    await hub.refresh();
    if (on) await hub.newPairingCode();
  }

  Future<void> _probe() async {
    final l10n = context.l10n;
    final address = _address.text.trim();
    if (address.isEmpty) return;
    setState(() => _probing = true);
    try {
      final peer = await _engine.hubProbe(address);
      if (!mounted) return;
      setState(() => _peers[peer.id] = peer);
    } on EngineException {
      if (mounted) showUpToast(context, l10n.hubProbeFailed(address));
    } finally {
      if (mounted) setState(() => _probing = false);
    }
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
      if (!mounted) return;
      setState(() => _peers[peer.id] = peer.copyWith(paired: true));
      showUpToast(context, l10n.pairingSuccess(d.name));
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
      showUpToast(context, l10n.errorGeneric);
    } else if (report.conflicts > 0) {
      showUpToast(context, l10n.hubSyncConflicts(report.conflicts));
    } else {
      showUpToast(
        context,
        report.downloadedBlobs + report.uploadedBlobs == 0
            ? l10n.hubSyncDone
            : l10n.hubSyncFinished(
                report.downloadedBlobs,
                report.uploadedBlobs,
              ),
      );
    }
  }

  Future<void> _controller(HubPeer peer) async {
    final ok = await tryEngineDo(() => _engine.hubControllerConnect(peer));
    if (!mounted) return;
    if (!ok) {
      showUpToast(context, context.l10n.errorGeneric);
      return;
    }
    context.go(Routes.perform);
  }

  Future<void> _forget(HubPeer peer) async {
    final l10n = context.l10n;
    final yes = await _confirm(
      l10n.pairingUnpair,
      l10n.pairingUnpairConfirm(peer.name),
    );
    if (!yes || !mounted) return;
    await tryEngine(() => _engine.hubForget(peer.id));
    if (!mounted) return;
    setState(() => _peers[peer.id] = peer.copyWith(paired: false));
    await ref.read(hubViewProvider.notifier).refresh();
  }

  Future<void> _revoke(PairedDevice d) async {
    final l10n = context.l10n;
    final yes = await _confirm(l10n.hubRevoke, l10n.hubRevokeConfirm(d.name));
    if (yes) await ref.read(hubViewProvider.notifier).revoke(d.id);
  }

  Future<bool> _confirm(String title, String message) async {
    final l10n = context.l10n;
    final v = await showUpDialog<bool>(
      context,
      builder: (ctx) => UpDialog(
        title: title,
        message: message,
        actions: [
          UpButton(
            label: l10n.commonCancel,
            variant: UpButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          UpButton(
            label: title,
            variant: UpButtonVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return v ?? false;
  }

  // ------------------------------------------------------------------ UI

  Widget _section(String title, List<Widget> children, {Widget? action}) {
    final c = UpTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: UpSpacing.md,
      children: [
        Row(
          children: [
            Expanded(
              child: UpText(
                title,
                role: UpTextRole.titleSm,
                color: c.textSecondary,
              ),
            ),
            ?action,
          ],
        ),
        ...children,
      ],
    );
  }

  Widget _localSection(HubView hub) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final server = hub.server;
    final code = hub.pairingCode;
    final time = code == null
        ? ''
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(code.expiresAt));
    return _section(l10n.hubThisDevice, [
      UpSwitchRow(
        title: l10n.hubEnable,
        subtitle: server.running
            ? l10n.hubRunning('${server.name}:${server.port}')
            : l10n.hubStopped,
        value: server.running,
        onChanged: _toggleServer,
      ),
      if (server.running) ...[
        UpText(
          l10n.pairingCodeTitle,
          role: UpTextRole.label,
          color: c.textPrimary,
          align: TextAlign.center,
        ),
        if (code != null) ...[
          Center(
            child: PairingCodeDisplay(
              code: code.code,
              semanticLabel: l10n.pairingCodeTitle,
            ),
          ),
          UpText(
            l10n.pairingValidUntil(time),
            role: UpTextRole.caption,
            color: c.textSecondary,
            align: TextAlign.center,
          ),
        ],
        Center(
          child: UpButton(
            label: l10n.pairingNewCode,
            icon: Icons.refresh_rounded,
            variant: UpButtonVariant.secondary,
            size: UpButtonSize.sm,
            onPressed: () =>
                ref.read(hubViewProvider.notifier).newPairingCode(),
          ),
        ),
        for (final MapEntry(value: name) in hub.remoteControllers.entries)
          _Banner(
            icon: Icons.cast_connected_rounded,
            text: l10n.hubRemoteControlling(name),
          ),
      ],
      UpText(
        l10n.hubTrustedDevices,
        role: UpTextRole.label,
        color: c.textPrimary,
      ),
      UpText(
        l10n.hubDeviceCount(hub.trusted.length),
        role: UpTextRole.caption,
        color: c.textMuted,
      ),
      for (final d in hub.trusted)
        UpListItem(
          title: d.name,
          subtitle: d.pairedAt == null
              ? null
              : MaterialLocalizations.of(context).formatShortDate(d.pairedAt!),
          icon: Icons.verified_user_rounded,
          trailing: UpButton(
            label: l10n.hubRevoke,
            variant: UpButtonVariant.ghost,
            size: UpButtonSize.sm,
            onPressed: () => _revoke(d),
          ),
        ),
      if (server.running) ...[
        UpText(
          l10n.hubLocalAddresses,
          role: UpTextRole.label,
          color: c.textPrimary,
        ),
        UpText(
          l10n.hubAddressHint,
          role: UpTextRole.caption,
          color: c.textMuted,
          maxLines: 2,
        ),
        for (final a in server.addresses)
          UpListItem(
            title: a,
            icon: Icons.lan_rounded,
            trailing: Icon(Icons.copy_rounded, color: c.textMuted),
            onTap: () => Clipboard.setData(ClipboardData(text: a)),
          ),
        if (server.id.isNotEmpty)
          UpText(
            l10n.hubDeviceId(server.id),
            role: UpTextRole.caption,
            color: c.textMuted,
            maxLines: 2,
          ),
      ],
    ]);
  }

  Widget _nearbySection(HubView hub) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final controlling = hub.controller.connected;
    return _section(
      l10n.hubNearbyDevices,
      action: UpIconButton(
        icon: Icons.refresh_rounded,
        semanticLabel: l10n.commonRetry,
        onPressed: _discover,
      ),
      [
        UpText(
          l10n.pairingSameNetwork,
          role: UpTextRole.caption,
          color: c.textMuted,
          maxLines: 2,
        ),
        if (controlling)
          _ControllerCard(
            status: hub.controller,
            peerName: hub.controllerPeer?.name ?? hub.controller.peerName ?? '',
            onLocalEcho: ref.read(hubViewProvider.notifier).setLocalEcho,
            onStop: () => tryEngineDo(_engine.hubControllerDisconnect),
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
        for (final p in _peers.values)
          _PeerCard(
            peer: p,
            sync: hub.sync[p.id],
            controlling: controlling && hub.controller.peerId == p.id,
            onPair: () => _pair(p),
            onSync: () => _sync(p),
            onController: () => _controller(p),
            onForget: () => _forget(p),
          ),
        UpText(
          l10n.hubManualAddress,
          role: UpTextRole.label,
          color: c.textPrimary,
        ),
        Row(
          spacing: UpSpacing.md,
          children: [
            Expanded(
              child: UpSearchField(
                hint: l10n.hubManualAddressHint,
                controller: _address,
                icon: Icons.lan_rounded,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _probe(),
              ),
            ),
            UpButton(
              label: l10n.hubConnect,
              size: UpButtonSize.sm,
              onPressed: _probing ? null : _probe,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final hub = ref.watch(hubViewProvider);
    final local = _localSection(hub);
    final nearby = _nearbySection(hub);

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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: UpPadGridTokens.maxWidth,
                  ),
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
                      if (_isDesktop) local else nearby,
                      const SizedBox(height: UpSpacing.xxxl),
                      if (_isDesktop) nearby else local,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = UpTheme.of(context).colors;
    return Container(
      padding: const EdgeInsets.all(UpSpacing.md),
      decoration: BoxDecoration(
        color: c.hubOnline,
        borderRadius: BorderRadius.circular(UpKitCardTokens.radius),
      ),
      child: Row(
        spacing: UpSpacing.sm,
        children: [
          Icon(icon, size: UpSizes.iconSm, color: c.textOnAccent),
          Expanded(
            child: UpText(text, role: UpTextRole.label, color: c.textOnAccent),
          ),
        ],
      ),
    );
  }
}

/// 本机正作为控制器：状态 + 往返延迟 + 本机同时发声 + 退出。
class _ControllerCard extends StatelessWidget {
  const _ControllerCard({
    required this.status,
    required this.peerName,
    required this.onLocalEcho,
    required this.onStop,
  });

  final HubControllerStatus status;
  final String peerName;
  final ValueChanged<bool> onLocalEcho;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final rtt = status.rttMs;
    return Container(
      padding: const EdgeInsets.all(UpSpacing.lg),
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(UpKitCardTokens.radius),
        border: Border.all(color: c.hubOnline, width: UpBorderWidths.thick),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: UpSpacing.sm,
        children: [
          _Banner(
            icon: Icons.gamepad_rounded,
            text: l10n.hubControlling(peerName),
          ),
          if (rtt != null)
            UpText(
              l10n.hubRoundTrip(rtt.round()),
              role: UpTextRole.caption,
              color: c.textSecondary,
            ),
          UpSwitchRow(
            title: l10n.hubLocalEcho,
            subtitle: l10n.hubLocalEchoHint,
            value: status.localEcho,
            onChanged: onLocalEcho,
          ),
          UpButton(
            label: l10n.hubStopControlling,
            icon: Icons.close_rounded,
            variant: UpButtonVariant.secondary,
            size: UpButtonSize.sm,
            onPressed: onStop,
          ),
        ],
      ),
    );
  }
}

class _PeerCard extends StatelessWidget {
  const _PeerCard({
    required this.peer,
    required this.sync,
    required this.controlling,
    required this.onPair,
    required this.onSync,
    required this.onController,
    required this.onForget,
  });

  final HubPeer peer;
  final HubSyncProgress? sync;
  final bool controlling;
  final VoidCallback onPair;
  final VoidCallback onSync;
  final VoidCallback onController;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final syncing = sync != null;
    final paired = peer.paired;
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
                      peer.endpoint,
                      role: UpTextRole.caption,
                      color: c.textMuted,
                    ),
                  ],
                ),
              ),
              if (paired)
                UpBadge(label: l10n.hubDeviceOnline, kind: UpBadgeKind.isNew),
            ],
          ),
          if (syncing) ...[
            UpText(
              sync!.total == 0
                  ? l10n.hubSyncStarting
                  : l10n.hubSyncProgress(sync!.done, sync!.total),
              role: UpTextRole.caption,
              color: c.textSecondary,
            ),
            UpSlider(value: sync!.fraction, onChanged: null),
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
                    UpButton(
                      label: l10n.pairingUnpair,
                      variant: UpButtonVariant.ghost,
                      size: UpButtonSize.sm,
                      onPressed: onForget,
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
