import 'package:app/ui/core/branding/app_brand.dart';
import 'package:app/data/preferences/preferences.dart';
import 'package:app/domain/session_state.dart';
import 'package:app/domain/workspaces/workspace_repository.dart';
import 'package:app/domain/value_objects/session_room.dart';
import 'package:app/pairing/storage.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/routing/adaptive.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/core/widgets/baya_glass_surface.dart';
import 'package:app/ui/workspaces/session_shell.dart';
import 'package:app/ui/workspaces/session_dialogs.dart';
import 'package:app/ui/workspaces/workspace_navigation.dart';
import 'package:app/ui/chat/widgets/thinking_block.dart';
import 'package:app/ui/chat/context/widgets/context_usage_button.dart';
import 'package:app/ui/chat/context/widgets/context_usage_sheet.dart';
import 'package:app/ui/chat/quick_actions/widgets/quick_actions_sheet.dart';
import 'package:app/ui/chat/quick_actions/widgets/model_picker_sheet.dart';
import 'package:app/ui/chat/attachment/states/attachment_state.dart';
import 'package:app/ui/chat/attachment/viewmodels/attachment_viewmodel.dart';
import 'package:app/ui/chat/commands/viewmodels/agent_commands_viewmodel.dart';
import 'package:app/ui/chat/states/chat_state.dart';
import 'package:app/ui/chat/viewmodels/chat_viewmodel.dart';
import 'package:app/ui/chat/voice/viewmodels/voice_input_viewmodel.dart';
import 'package:app/ui/chat/widgets/attach_sheet.dart';
import 'package:app/ui/chat/widgets/input_bar.dart';
import 'package:app/ui/chat/widgets/message_bubble.dart';
import 'package:app/ui/chat/widgets/streaming_bubble.dart';
import 'package:app/ui/chat/widgets/tool_request_card.dart';
import 'package:app/ui/chat/widgets/tool_run_group.dart';
import 'package:app/ui/chat/widgets/extension_ui_sheet.dart';
import 'package:app/ui/home/viewmodels/home_viewmodel.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class ChatPage extends StatelessWidget {
  /// Plan/24-fix-title: optional title hint passed via `go_router`
  /// `extra` from the Home tile. Used as the peer-label fallback in
  /// the AppBar so the user sees the right name *immediately* on
  /// navigation, instead of "—" / "Remote Pi" until the PeerRecord
  /// is loaded by the ViewModel and the first `room_meta_updated`
  /// arrives.
  final String? initialTitle;

  /// Plan/32g — the paired-device (Mac) label Home already knows, passed via
  /// `extra` / [SessionSelection]. Drives the AppBar's line 2 immediately so
  /// it never flickers empty/room-title while the PeerRecord loads async.
  /// When the PeerRecord arrives it resolves to the same string, so there's no
  /// visible change.
  final String? initialDevice;

  /// Plan/32g — the live state of the tile Home tapped (its green dot). Seeds
  /// the AppBar status dot so it doesn't flash "reconnecting" before the VM
  /// reads the real runtime. Superseded by the live signal once it resolves
  /// ([ChatViewModel.connectionResolved]).
  final bool initialOnline;

  /// Plan/tablet — `false` when the chat is embedded as the tablet's
  /// detail pane (no navigation stack to pop back to). Hides the back
  /// arrow; defaults to `true` for the phone full-screen route.
  final bool showBack;

  const ChatPage({
    super.key,
    this.initialTitle,
    this.initialDevice,
    this.initialOnline = false,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatViewModel>();
    final state = vm.state;

    final scaffold = Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: _buildBody(context, state, vm)),
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: _buildTopBar(context, state),
            ),
            if (state is ChatReady && state.pairingRevoked)
              Positioned(
                top: 78,
                left: 12,
                right: 12,
                child: _RevokedBanner(onRePair: () => context.go('/pair')),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _buildInput(context, state, vm),
              ),
            ),
          ],
        ),
      ),
    );

    // Plan/57 — an interactive extension_ui_request (ask_user via pi-ask)
    // renders as a full-screen modal layered ABOVE the Scaffold. Purely
    // reactive: the overlay leaves the tree when the pending request clears
    // (completed dismiss) — no route lifecycle to manage. `error` carries a
    // submit-result rejection so the modal can offer a retry instead of a dead
    // end.
    final ready = state is ChatReady ? state : null;
    final uiRequest = ready?.pendingUiRequest;
    if (uiRequest == null) return scaffold;
    return Stack(
      children: [
        scaffold,
        Positioned.fill(
          // Keyed by request id: a new flow must get a fresh State — question
          // ids repeat across flows (e.g. "goal"), so reusing the State would
          // leak old selections/custom text into the new modal.
          child: ExtensionUiSheet(
            key: ValueKey(uiRequest.id),
            request: uiRequest,
            error: ready?.pendingUiError,
            onRespond: vm.respondExtensionUi,
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, ChatState state) {
    final colors = context.colors;
    final vm = context.watch<ChatViewModel>();
    final peer = vm.activePeer;
    final room = vm.activeRoom;
    final resolved = vm.connectionResolved;
    final online = resolved ? vm.isRoomLive : initialOnline;
    final reconnecting = resolved && state is ChatReady && state.isOffline;
    final working = vm.isWorking;
    final roomName = _roomDisplayName(room, state, initialTitle);
    final prefs = context.watch<Preferences>();
    final localName = peer != null && room != null
        ? prefs.sessionName(peer.remoteEpk, room.roomId)
        : null;
    final displayName = localName ?? roomName;
    final title = workspaceSessionTitle(displayName);
    final device = _peerDisplayName(peer, initialDevice);
    final statusColor = working
        ? colors.working
        : reconnecting
        ? colors.warning
        : online
        ? colors.success
        : colors.muted;
    final status = working
        ? 'Working'
        : reconnecting
        ? 'Reconnecting'
        : online
        ? 'Ready'
        : 'Offline';
    final menu = SessionShell.menuOf(context);
    final leadingAction =
        menu ??
        (showBack
            ? () => context.canPop() ? context.pop() : context.go('/home')
            : null);
    return SizedBox(
      key: const ValueKey('chat-floating-header'),
      height: 58,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BayaGlassSurface(
              radius: 24,
              padding: EdgeInsets.zero,
              child: SizedBox.square(
                dimension: 48,
                child: IconButton(
                  tooltip: menu != null ? 'Sessions' : 'Back',
                  onPressed: leadingAction,
                  icon: Icon(
                    menu != null ? LucideIcons.menu : LucideIcons.chevronLeft,
                    size: 21,
                    color: colors.text,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.typo.sansBody.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.25,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          device,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: colors.muted),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(fontSize: 10.5, color: statusColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: BayaGlassSurface(
              radius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ContextUsageButton(
                    key: ValueKey('${peer?.remoteEpk}:${peer?.roomId}'),
                    enabled: online && peer != null,
                    working: working,
                    messageCount: state is ChatReady
                        ? state.messages.length
                        : 0,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Session actions',
                    icon: Icon(
                      LucideIcons.ellipsis,
                      size: 21,
                      color: colors.muted2,
                    ),
                    onSelected: (value) =>
                        _handleSessionAction(context, vm, value, displayName),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename'),
                      ),
                      const PopupMenuItem(value: 'info', child: Text('Info')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.trash2,
                              size: 17,
                              color: colors.error,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Delete',
                              style: TextStyle(color: colors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSessionAction(
    BuildContext context,
    ChatViewModel vm,
    String value,
    String displayName,
  ) async {
    final currentPeer = vm.activePeer;
    if (currentPeer == null) return;
    final roomId = vm.activeRoom?.roomId ?? 'main';
    if (value == 'rename') {
      final name = await showSessionRenameDialog(
        context,
        currentName: displayName,
      );
      if (name == null || !context.mounted) return;
      await context.read<Preferences>().setSessionName(
        currentPeer.remoteEpk,
        roomId,
        name,
      );
      return;
    }
    if (value == 'info') {
      await showSessionInfoDialog(
        context,
        peer: currentPeer,
        room: vm.activeRoom,
        name: displayName,
      );
      return;
    }
    if (value != 'delete' || !context.mounted) return;
    final confirmed = await showSessionDeleteDialog(context, name: displayName);
    if (!confirmed || !context.mounted) return;
    final home = context.read<HomeViewModel>();
    for (final item in home.allItems) {
      if (item.peer.remoteEpk == currentPeer.remoteEpk &&
          item.room.roomId == roomId) {
        await home.deleteSession(item);
        if (!context.mounted) return;
        context.read<SessionSelection>().clear();
        context.go('/home');
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not find this session to delete.')),
    );
  }

  static String _roomDisplayName(
    RoomInfo? room,
    ChatState state,
    String? initialTitle,
  ) {
    if (room != null) {
      final announced = displayRoomName(room.name);
      if (announced.isNotEmpty) return announced;
      final cwd = room.cwd;
      if (cwd != null && cwd.isNotEmpty) {
        final segs = cwd.split('/').where((s) => s.isNotEmpty).toList();
        if (segs.isNotEmpty) return segs.last;
      }
    }
    if (state is ChatReady && state.messages.isNotEmpty) {
      return _inferSessionName(state.messages);
    }
    // Plan/24-fix-title: Home knows the peer label before /chat
    // mounts; use it instead of the generic kAppName placeholder
    // while we wait for the first room_meta_updated to populate
    // `room.name`.
    if (initialTitle != null && initialTitle.isNotEmpty) return initialTitle;
    return kAppName;
  }

  static String _peerDisplayName(PeerRecord? peer, String? fallback) {
    if (peer == null) {
      // Plan/32g: while the ViewModel hasn't loaded the PeerRecord yet, fall
      // back to the device label Home passed (initialDevice) — same value the
      // PeerRecord resolves to, so no flicker on load.
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return '—';
    }
    if (peer.nickname != null && peer.nickname!.isNotEmpty) {
      return peer.nickname!;
    }
    if (peer.sessionName.isNotEmpty) return peer.sessionName;
    return peer.remoteEpk.substring(0, 8);
  }

  Widget _buildBody(BuildContext context, ChatState state, ChatViewModel vm) {
    final hideToolCalls = context.watch<Preferences>().hideToolCalls;
    return switch (state) {
      // Edge case: opened /chat without a peer (e.g. peer revoked while
      // user was here). The chat is not the place to pair — render
      // a minimal empty state without an action. User navigates back
      // and uses Home / Settings → pairing.
      ChatNoPeer() => const _EmptyState(
        icon: LucideIcons.messageCircle,
        message: 'No active device',
      ),
      ChatConnecting() => const _EmptyState(
        icon: LucideIcons.refreshCw,
        message: 'Connecting…',
      ),
      ChatFatalError(:final message) => _EmptyState(
        icon: LucideIcons.circleAlert,
        message: message,
        actionLabel: 'Re-pair',
        onAction: () => context.go('/pair'),
      ),
      ChatReady(:final messages, :final streaming) => () {
        final visible = hideToolCalls
            ? messages
                  .where(
                    (m) =>
                        m is! ToolEvent ||
                        m.status == ToolEventStatus.pending &&
                            m.args is Map &&
                            m.args['approval_required'] == true,
                  )
                  .toList()
            : messages;
        // Empty body → the default placeholder (Pi brand icon + "Nothing
        // here"), shown whenever there's nothing to render — including while
        // reconnecting (the reconnect handshake never swaps the body).
        if (visible.isEmpty && streaming == null) {
          return const _EmptyState(
            icon: LucideIcons.terminal,
            message: 'Nothing here',
          );
        }
        return _MessageList(
          key: const ValueKey('chat-message-list'),
          messages: visible,
          streaming: streaming,
          onDecide: (id, decision) => vm.approveTool(id, decision),
        );
      }(),
    };
  }

  Widget _buildInput(BuildContext context, ChatState state, ChatViewModel vm) {
    final isReady = state is ChatReady;
    final isOffline = isReady && state.isOffline;
    final isRevoked = isReady && state.pairingRevoked;
    final isPeerOffline = isReady && state.peerOfflineReason != null;
    // Live relay-reported offline (no `bye`): Pi is just not reachable.
    final isPresenceOffline = isReady && state.peerPresence is PresenceOffline;
    // Plan/31 — the composer is locked + the send button becomes "stop" for
    // the WHOLE working turn (send/echo → agent_done), not just the narrow
    // token-streaming window. Driven by the broad working signal so it matches
    // the AppBar/Home "working" indicator.
    final isWorking = isReady && vm.isWorking;
    final cancelId = vm.cancelTargetId;
    // Quick actions need an open channel to dispatch — only offer the
    // entry point when the chat input itself is enabled. Hiding the
    // ⚙ button on offline avoids a tap that would just throw inside
    // the sheet.
    final actionsEnabled =
        isReady &&
        !isOffline &&
        !isRevoked &&
        !isPeerOffline &&
        !isPresenceOffline;
    final commandState = context.watch<AgentCommandsViewModel>().state;

    return InputBar(
      key: const ValueKey('chat-floating-composer'),
      agentLabel: workspaceAgentLabelForRoom(
        vm.activeRoom?.name ?? initialTitle,
      ),
      modelLabel: vm.activeRoom?.model ?? 'Model',
      disabled:
          !isReady ||
          isOffline ||
          isRevoked ||
          isPeerOffline ||
          isPresenceOffline,
      streaming: isWorking,
      onCancel: cancelId != null ? () => vm.cancel(cancelId) : null,
      onOpenQuickActions: actionsEnabled
          ? () => showStandaloneModelPicker(context)
          : null,
      onSlashCommand: (id, raw) {
        switch (id) {
          case 'new':
            openNewSession(
              context,
              workspaceKey: context.read<HomeViewModel>().selectedWorkspace,
            );
          case 'model':
            showStandaloneModelPicker(context);
          case 'thinking':
            showQuickActionsSheet(context);
          case 'compact':
            showQuickActionsSheet(context, compactOnOpen: true);
          case 'context':
            showContextUsage(context);
          case 'attach':
            _openAttach(context, context.read<AttachmentViewModel>());
          case 'settings':
            context.push('/settings');
          case 'pair':
            context.push('/pair');
          case 'about':
            context.push('/about');
          case 'agent':
            vm.sendMessage(raw);
          case 'workspace':
            showCreateWorkspace(context);
        }
      },
      onSlashOpen: context.read<AgentCommandsViewModel>().refresh,
      agentCommands: commandState.commands,
      agentCommandsLoading: commandState.loading,
      agentCommandsError: commandState.error,
      queuedMessages: isReady ? state.queuedMessages : const [],
      onSetQueued: vm.queueMessage,
      onClearQueued: vm.clearQueuedMessage,
      // Plan/29 — hold-to-talk voice input. The VM is route-scoped (bound in
      // app_router alongside ChatViewModel); InputBar listens to it directly,
      // so a read() is enough here.
      voice: context.read<VoiceInputViewModel>(),
      onVoiceHint: (hint) => _handleVoiceHint(context, hint),
      // Plan/30 — image attachments. takeImageForSend() reads + clears the
      // attached image so the inline image rides along with the (optionally
      // empty) caption. Attach-button gating by vision / already-attached is
      // internal to InputBar; the host only gates by channel availability.
      attachment: context.read<AttachmentViewModel>(),
      onOpenAttach: actionsEnabled
          ? () => _openAttach(context, context.read<AttachmentViewModel>())
          : null,
      onSend: (text) {
        final image = context.read<AttachmentViewModel>().takeImageForSend();
        vm.sendMessage(text, image: image);
      },
    );
  }

  /// Open the Camera/Gallery sheet and drive the picker. Captures the
  /// messenger up front so a permission-denied hint can deep-link to Settings
  /// after the async pick.
  static Future<void> _openAttach(
    BuildContext context,
    AttachmentViewModel vm,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final source = await showAttachSheet(context);
    if (source == null) return;
    AttachHint? hint;
    final sub = vm.hints.listen((h) => hint = h);
    switch (source) {
      case AttachSource.camera:
        await vm.pickFromCamera();
      case AttachSource.gallery:
        await vm.pickFromGallery();
    }
    await Future<void>.delayed(Duration.zero); // flush the hint microtask
    await sub.cancel();
    if (hint != null) _handleAttachHint(messenger, hint!);
  }

  static void _handleAttachHint(
    ScaffoldMessengerState messenger,
    AttachHint hint,
  ) {
    messenger.hideCurrentSnackBar();
    switch (hint) {
      case AttachHint.cameraPermissionDenied:
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Camera access is off — enable it in Settings to attach a photo.',
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: AppSettings.openAppSettings,
            ),
          ),
        );
      case AttachHint.pickFailed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't attach that image."),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// Surfaces the InputBar's voice hints (decision #10 permission path +
  /// the "hold to talk" nudge) as snackbars. Captures the messenger up front
  /// so the settings deep-link is safe across the async permission round-trip.
  static void _handleVoiceHint(BuildContext context, VoiceHint hint) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    switch (hint) {
      case VoiceHint.holdToTalk:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Hold the mic to talk'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case VoiceHint.permissionDenied:
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Microphone access is off — enable it in Settings to dictate.',
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: AppSettings.openAppSettings,
            ),
          ),
        );
    }
  }

  static String _inferSessionName(List<ChatMessage> msgs) {
    for (final m in msgs) {
      if (m is UserMsg) return m.text.substring(0, m.text.length.clamp(0, 32));
    }
    return kAppName;
  }
}

// ---------------------------------------------------------------------------

/// Groups chat messages for rendering: consecutive completed tool calls become
/// a single [ToolRunItem]; everything else stays in order.
List<Object> toolRunItemsForMessages(List<ChatMessage> messages) {
  final items = <Object>[];
  final run = <ToolEvent>[];
  void flushRun() {
    if (run.isEmpty) return;
    items.add(run.length == 1 ? run.single : ToolRunItem(List.of(run)));
    run.clear();
  }

  for (final message in messages) {
    final needsApproval =
        message is ToolEvent &&
        message.status == ToolEventStatus.pending &&
        message.args is Map &&
        message.args['approval_required'] == true;
    if (message is ToolEvent && !needsApproval) {
      run.add(message);
      continue;
    }
    flushRun();
    items.add(message);
  }
  flushRun();
  return items;
}

/// A run of consecutive tool calls rendered as one collapsible row.
class ToolRunItem {
  const ToolRunItem(this.tools);
  final List<ToolEvent> tools;
}

/// Returns the final assistant segment of each completed user turn. Tool
/// boundaries split one logical answer across several bubbles; only this last
/// segment owns the copy action, so a reply interleaved with tool calls shows
/// a single copy button under the final text instead of one per segment.
Set<String> assistantCopyIdsForTurns(List<ChatMessage> messages) {
  final ids = <String>{};
  String? lastAssistant;
  for (final message in messages) {
    if (message is AssistantMsg) {
      lastAssistant = message.id;
      continue;
    }
    // Any non-assistant content ends the current run of assistant segments, so
    // a later segment becomes the newest candidate for the turn.
    if (message is ToolEvent || message is ThinkingMsg) {
      continue;
    }
    if (message is UserMsg) {
      if (lastAssistant != null) ids.add(lastAssistant);
      lastAssistant = null;
    }
  }
  if (lastAssistant != null) ids.add(lastAssistant);
  return ids;
}

class _MessageList extends StatefulWidget {
  final List<ChatMessage> messages;
  final StreamingMessage? streaming;
  final void Function(String, ApproveDecision) onDecide;

  const _MessageList({
    super.key,
    required this.messages,
    required this.streaming,
    required this.onDecide,
  });

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  /// How far past the newest message the user must scroll before the
  /// "jump to latest" button appears. Small on purpose so it shows up as soon
  /// as the newest message leaves the viewport.
  static const _latestThreshold = 72.0;

  final _controller = ScrollController();
  bool _showLatest = false;
  bool _keyboardDismissTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final next = _isAwayFromLatest(_controller.position);
    if (next == _showLatest) return;
    setState(() => _showLatest = next);
  }

  /// `reverse: true` anchors the newest row at scroll offset 0, so
  /// `extentBefore` is exactly how far the user has travelled back into the
  /// history. That stays correct when a single message is taller than the
  /// viewport, where a plain offset threshold can be reached instantly.
  bool _isAwayFromLatest(ScrollMetrics metrics) {
    if (metrics.maxScrollExtent <= 0) return false;
    return metrics.extentBefore > _latestThreshold;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _keyboardDismissTriggered = false;
    }
    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      if (!_keyboardDismissTriggered) {
        _keyboardDismissTriggered = true;
        FocusManager.instance.primaryFocus?.unfocus();
      }
    }
    if (notification is ScrollEndNotification) {
      _keyboardDismissTriggered = false;
    }
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification ||
        notification is UserScrollNotification) {
      final next = _isAwayFromLatest(notification.metrics);
      if (next != _showLatest) setState(() => _showLatest = next);
    }
    return false;
  }

  Future<void> _jumpToLatest() async {
    if (!_controller.hasClients) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  List<Object> _items() => toolRunItemsForMessages(widget.messages);
  @override
  Widget build(BuildContext context) {
    final items = _items();
    final streaming = widget.streaming;
    final itemCount = items.length + (streaming != null ? 1 : 0);
    // One copy action per assistant turn: tool calls can split a single reply
    // into several text segments, but only the final segment gets the button.
    final copyIds = assistantCopyIdsForTurns(widget.messages);

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ListView.separated(
              key: const ValueKey('chat-message-scroll'),
              controller: _controller,
              shrinkWrap: true,
              reverse: true,
              padding: const EdgeInsets.fromLTRB(22, 94, 22, 128),
              itemCount: itemCount,
              separatorBuilder: (context, idx) => const SizedBox(height: 24),
              itemBuilder: (_, i) {
                // `reverse: true` makes index 0 the newest row. Stable keys
                // keep streaming insertion from rematching unrelated rows.
                if (streaming != null && i == 0) {
                  return KeyedSubtree(
                    key: const ValueKey('streaming'),
                    child: StreamingBubble(streaming),
                  );
                }
                final itemIdx =
                    items.length - 1 - (i - (streaming != null ? 1 : 0));
                final item = items[itemIdx];
                if (item is ToolRunItem) {
                  return KeyedSubtree(
                    key: ValueKey('tool-run-${item.tools.first.id}'),
                    child: ToolRunGroup(tools: item.tools),
                  );
                }
                final msg = item as ChatMessage;
                return KeyedSubtree(
                  key: ValueKey(msg.id),
                  child: switch (msg) {
                    UserMsg() => UserBubble(msg),
                    AssistantMsg() => AssistantBubble(
                      msg,
                      showCopy: copyIds.contains(msg.id),
                    ),
                    ThinkingMsg() => ThinkingBlock(
                      text: msg.text,
                      complete: msg.complete,
                    ),
                    ToolEvent() => ToolRequestCard(
                      tool: msg,
                      onDecide: widget.onDecide,
                    ),
                    CompactionMsg() => CompactionBubble(msg),
                  },
                );
              },
            ),
          ),
          Positioned(
            right: 22,
            bottom: 128,
            child: IgnorePointer(
              ignoring: !_showLatest,
              child: AnimatedOpacity(
                opacity: _showLatest ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: AnimatedScale(
                  scale: _showLatest ? 1 : .82,
                  duration: const Duration(milliseconds: 180),
                  child: BayaGlassSurface(
                    radius: 21,
                    child: SizedBox.square(
                      dimension: 42,
                      child: IconButton(
                        key: const Key('jump-to-latest'),
                        tooltip: 'Jump to latest',
                        onPressed: _jumpToLatest,
                        icon: Icon(
                          LucideIcons.arrowDown,
                          size: 19,
                          color: context.colors.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.muted, size: 48),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: colors.muted, fontSize: 14)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _RevokedBanner extends StatelessWidget {
  final VoidCallback onRePair;
  const _RevokedBanner({required this.onRePair});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade900.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(LucideIcons.unlink, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Pairing revoked by Mac — re-pair to continue',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRePair,
            child: const Text(
              'Re-pair',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
