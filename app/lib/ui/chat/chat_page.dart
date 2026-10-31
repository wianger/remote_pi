import 'package:app/ui/core/branding/app_brand.dart';
import 'package:app/data/preferences/preferences.dart';
import 'package:app/domain/session_state.dart';
import 'package:app/domain/value_objects/session_room.dart';
import 'package:app/pairing/storage.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/core/widgets/baya_glass_surface.dart';
import 'package:app/ui/workspaces/session_shell.dart';
import 'package:app/ui/workspaces/session_dialogs.dart';
import 'package:app/ui/workspaces/workspace_navigation.dart';
import 'package:app/ui/chat/widgets/thinking_block.dart';
import 'package:app/ui/chat/context/widgets/context_usage_button.dart';
import 'package:app/ui/chat/context/widgets/context_usage_sheet.dart';
import 'package:app/ui/chat/quick_actions/widgets/quick_actions_sheet.dart';
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
        child: Column(
          children: [
            _buildTopBar(context, state),
            // Pairing revocation is the only banner kept — it's a hard
            // failure (can't proceed without re-pairing), red, with an
            // explicit action. Plain offline / Pi-gone / presence-off
            // banners were removed: the AppBar status line already
            // surfaces those, and stacking duplicates noise the surface.
            if (state is ChatReady && state.pairingRevoked)
              _RevokedBanner(onRePair: () => context.go('/pair')),
            Expanded(child: _buildBody(context, state, vm)),
            _buildInput(context, state, vm),
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
    final title = displayName.replaceFirst('Codex · ', '');
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: BayaGlassSurface(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Row(
            children: [
              if (SessionShell.menuOf(context) != null)
                IconButton(
                  tooltip: 'Sessions',
                  onPressed: SessionShell.menuOf(context),
                  icon: Icon(
                    LucideIcons.panelLeft,
                    size: 21,
                    color: colors.text,
                  ),
                )
              else if (showBack)
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(LucideIcons.chevronLeft, size: 21),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                )
              else
                const SizedBox(width: 12),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typo.sansBody.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            device,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ContextUsageButton(
                key: ValueKey('${peer?.remoteEpk}:${peer?.roomId}'),
                enabled: online && peer != null,
                working: working,
                messageCount: state is ChatReady ? state.messages.length : 0,
              ),
              PopupMenuButton<String>(
                tooltip: 'Session actions',
                icon: Icon(
                  LucideIcons.ellipsis,
                  size: 21,
                  color: colors.muted2,
                ),
                onSelected: (value) async {
                  final currentPeer = vm.activePeer;
                  if (currentPeer == null) return;
                  if (value == 'rename') {
                    final name = await showSessionRenameDialog(
                      context,
                      currentName: displayName,
                    );
                    if (name != null) {
                      await prefs.setSessionName(
                        currentPeer.remoteEpk,
                        vm.activeRoom?.roomId ?? 'main',
                        name,
                      );
                    }
                  } else if (value == 'info') {
                    await showSessionInfoDialog(
                      context,
                      peer: currentPeer,
                      room: vm.activeRoom,
                      name: displayName,
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'info', child: Text('Info')),
                ],
              ),
            ],
          ),
        ),
      ),
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
      agentLabel:
          (vm.activeRoom?.name ?? initialTitle ?? '').startsWith('Codex · ')
          ? 'Codex'
          : 'Pi',
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
          ? () => showQuickActionsSheet(context)
          : null,
      onSlashCommand: (id, raw) {
        switch (id) {
          case 'new':
            openNewSession(
              context,
              workspaceKey: context.read<HomeViewModel>().selectedWorkspace,
            );
          case 'model':
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

class _ToolRun {
  const _ToolRun(this.tools);
  final List<ToolEvent> tools;
}

/// Returns the final assistant segment of each completed user turn. Tool
/// boundaries split one logical answer across several bubbles; only this last
/// segment owns the copy action.
Set<String> assistantCopyIdsForTurns(List<ChatMessage> messages) {
  final ids = <String>{};
  String? lastAssistant;
  for (final message in messages) {
    if (message is AssistantMsg) lastAssistant = message.id;
    if (message is UserMsg) {
      if (lastAssistant != null) ids.add(lastAssistant);
      lastAssistant = null;
    }
  }
  if (lastAssistant != null) ids.add(lastAssistant);
  return ids;
}

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final StreamingMessage? streaming;
  final void Function(String, ApproveDecision) onDecide;

  const _MessageList({
    required this.messages,
    required this.streaming,
    required this.onDecide,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Object>[];
    final toolRun = <ToolEvent>[];
    void flushTools() {
      if (toolRun.isEmpty) return;
      items.add(
        toolRun.length == 1
            ? toolRun.single
            : _ToolRun(List<ToolEvent>.unmodifiable(toolRun)),
      );
      toolRun.clear();
    }

    for (final message in messages) {
      final needsApproval =
          message is ToolEvent &&
          message.status == ToolEventStatus.pending &&
          message.args is Map &&
          message.args['approval_required'] == true;
      if (message is ToolEvent && !needsApproval) {
        toolRun.add(message);
      } else {
        flushTools();
        items.add(message);
      }
    }
    flushTools();

    final itemCount = items.length + (streaming != null ? 1 : 0);
    // One copy action per assistant turn: tool calls can split a single reply
    // into several text segments, but only the final segment gets the button.
    final copyIds = assistantCopyIdsForTurns(messages);

    // `reverse: true` anchors the viewport to the bottom (offset 0 = newest)
    // and keeps it there as content arrives — no manual scroll-to-bottom is
    // needed. The previous animateTo-on-every-rebuild fought this and caused
    // overlapping animations (flicker / runaway scroll) during streaming.
    return Align(
      alignment: Alignment.topCenter,
      child: ListView.separated(
        shrinkWrap: true,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        itemCount: itemCount,
        separatorBuilder: (context, idx) => const SizedBox(height: 24),
        itemBuilder: (_, i) {
          // Index 0 = bottom = newest. Stable keys are REQUIRED here: when the
          // streaming bubble appears/disappears at index 0 every other item's
          // index shifts by 1, and without keys Flutter re-matches elements by
          // position — briefly painting the wrong message at a slot (the
          // momentary C/B/A → B/C/A reorder). Keying by message id makes it
          // match by identity instead.
          if (streaming != null && i == 0) {
            return KeyedSubtree(
              key: const ValueKey('streaming'),
              child: StreamingBubble(streaming!),
            );
          }
          final itemIdx = items.length - 1 - (i - (streaming != null ? 1 : 0));
          final item = items[itemIdx];
          if (item is _ToolRun) {
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
              ToolEvent() => ToolRequestCard(tool: msg, onDecide: onDecide),
              CompactionMsg() => CompactionBubble(msg),
            },
          );
        },
      ),
    );
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
