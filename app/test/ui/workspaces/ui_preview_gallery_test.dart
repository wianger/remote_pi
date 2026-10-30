// Manual preview renderer. Only runs when REMOTE_PI_PREVIEW_DIR is set.
// Uses production widgets with fixture ViewModels; no pairing or network.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app/data/preferences/preferences.dart';
import 'package:app/domain/session_state.dart';
import 'package:app/domain/workspaces/workspace_repository.dart';
import 'package:app/pairing/storage.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/routing/adaptive.dart';
import 'package:app/ui/chat/attachment/states/attachment_state.dart';
import 'package:app/ui/chat/attachment/viewmodels/attachment_viewmodel.dart';
import 'package:app/ui/chat/chat_page.dart';
import 'package:app/ui/chat/states/chat_state.dart';
import 'package:app/ui/chat/viewmodels/chat_viewmodel.dart';
import 'package:app/ui/chat/widgets/message_bubble.dart';
import 'package:app/ui/chat/voice/states/voice_input_state.dart';
import 'package:app/ui/chat/voice/viewmodels/voice_input_viewmodel.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/core/viewmodel/viewmodel.dart';
import 'package:app/ui/home/states/home_state.dart';
import 'package:app/ui/home/viewmodels/home_viewmodel.dart';
import 'package:app/ui/workspaces/new_session_page.dart';
import 'package:app/ui/workspaces/session_shell.dart';
import 'package:app/ui/workspaces/viewmodels/new_session_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _computer = PeerRecord(
  remoteEpk: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  sessionName: 'Windows PC',
  relayUrl: 'https://example.invalid',
  pairedAt: '2026-10-30',
);
const _linux = PeerRecord(
  remoteEpk: 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=',
  sessionName: 'Ubuntu WSL',
  relayUrl: 'https://example.invalid',
  pairedAt: '2026-10-30',
);
const _room = RoomInfo(
  roomId: 'codex-project',
  startedAt: 0,
  name: 'Codex · remote_pi',
  cwd: r'C:\Projects\remote_pi',
  model: 'Codex',
);

class _Home extends ViewModel<HomeState> implements HomeViewModel {
  _Home()
    : super(
        const HomeList(
          peers: [_computer, _linux],
          roomsByPeer: {
            'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=': [
              _room,
              RoomInfo(
                roomId: 'notes',
                startedAt: 0,
                name: 'notes',
                cwd: r'C:\Projects\notes',
              ),
              RoomInfo(
                roomId: 'website',
                startedAt: 0,
                name: 'Codex · website',
                cwd: r'C:\Projects\website',
              ),
            ],
            'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=': [
              RoomInfo(
                roomId: 'backend',
                startedAt: 0,
                name: 'backend',
                cwd: '/home/developer/backend',
              ),
            ],
          },
        ),
      );
  @override
  bool get isRelayConnected => true;
  @override
  bool isRoomLive(String epk, String roomId) => roomId != 'website';
  @override
  bool isRoomWorking(String epk, String roomId) => roomId == 'backend';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Chat extends ViewModel<ChatState> implements ChatViewModel {
  _Chat()
    : super(
        const ChatReady(
          messages: [
            UserMsg(id: 'u1', text: 'Review the Android session flow.'),
            ThinkingMsg(
              id: 'thinking-preview',
              text:
                  'Check the selected project and available agents before opening a session.',
            ),
            AssistantMsg(
              id: 'a1',
              text:
                  'The workspace is *ready*. You can:\n\n- Switch between Pi and Codex\n- Browse folders on your computer\n- Continue a session from your phone',
            ),
            ToolEvent(
              id: 'tool',
              toolCallId: 'tool',
              tool: 'bash',
              args: {'command': 'pnpm typecheck'},
              result: 'TypeScript checks passed. No errors found.',
              status: ToolEventStatus.completed,
            ),
            AssistantMsg(
              id: 'a2',
              text:
                  'Open **New session** to choose a folder and an agent.\n\n中文回复也可阅读，代码使用 `pnpm test`。',
            ),
          ],
        ),
      );
  @override
  PeerRecord get activePeer => _computer;
  @override
  RoomInfo get activeRoom => _room;
  @override
  bool get connectionResolved => true;
  @override
  bool get isRoomLive => true;
  @override
  bool get isWorking => false;
  @override
  String? get cancelTargetId => null;
  @override
  void queueMessage(String text) {}
  @override
  void clearQueuedMessage([String? id]) {}
  @override
  Future<void> sendMessage(String text, {MessageImage? image}) async {}
  @override
  Future<void> respondExtensionUi(ExtensionUiResponse response) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Voice extends ViewModel<VoiceInputState> implements VoiceInputViewModel {
  _Voice() : super(const VoiceIdle());
  @override
  Stream<String> get transcripts => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Attachment extends ViewModel<AttachmentState>
    implements AttachmentViewModel {
  _Attachment() : super(const AttachmentEmpty(visionSupported: true));
  @override
  bool get hasImage => false;
  @override
  MessageImage? takeImageForSend() => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Workspaces extends IWorkspaceRepository {
  @override
  WorkspaceSelection get currentSelection => const WorkspaceSelection(
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    'codex-project',
  );
  @override
  Future<List<WorkspaceHost>> listHosts() async => const [
    WorkspaceHost(
      id: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      label: 'Windows PC',
      online: true,
    ),
    WorkspaceHost(
      id: 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=',
      label: 'Ubuntu WSL',
      online: true,
    ),
  ];
  @override
  Future<WorkspaceDirectory> browse(
    String hostId, {
    String? path,
    bool showHidden = false,
  }) async => WorkspaceDirectory(
    path: path ?? r'C:\Projects\remote_pi',
    home: r'C:\Users\developer',
    parent: r'C:\Projects',
    roots: const ['C:\\'],
    folders: ['app', 'docs', 'pi-extension', 'scripts', 'test', 'tools']
        .map(
          (name) => WorkspaceFolder(
            name: name,
            path: 'C:\\Projects\\remote_pi\\$name',
          ),
        )
        .toList(),
    agents: const [WorkspaceAgent.pi, WorkspaceAgent.codex],
  );
  @override
  Future<OpenedWorkspace> open(
    String hostId,
    String path,
    WorkspaceAgent agent,
  ) async => OpenedWorkspace(
    hostId: hostId,
    hostLabel: 'Windows PC',
    path: path,
    roomId: _room.roomId,
    name: _room.name!,
    agent: agent,
  );
  @override
  Future<void> restore(WorkspaceSelection? selection) async {}
}

Future<void> _fonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    // Use exactly the packaged font manifest: no host Georgia/Courier or
    // network fonts that could make previews differ from the Android APK.
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest) {
      final loader = FontLoader(entry['family'] as String);
      for (final face in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(face['asset'] as String));
      }
      await loader.load();
    }
    // The test engine has no Android system fonts. Supply the open Noto CJK
    // face used for this preview's device fallback; it is not an APK asset.
    final cjk = Platform.environment['REMOTE_PI_PREVIEW_CJK_FONT'];
    if (cjk == null) throw StateError('Set REMOTE_PI_PREVIEW_CJK_FONT');
    final loader = FontLoader(kFontFallback.first)
      ..addFont(File(cjk).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });
}

Future<void> _save(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  final output = Platform.environment['REMOTE_PI_PREVIEW_DIR'];
  testWidgets(
    'render Android chat, session drawer and folder chooser previews',
    (tester) async {
      tester.view.physicalSize = const Size(1332, 1048);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _fonts(tester);
      final home = _Home();
      final chat = _Chat();
      final voice = _Voice();
      final attachment = _Attachment();
      final prefs = Preferences();
      final selection = SessionSelection()
        ..select(
          _computer.remoteEpk,
          _room.roomId,
          _room.name!,
          'Windows PC',
          true,
        );
      final newSession = NewSessionViewModel(_Workspaces());
      final galleryKey = GlobalKey();
      final chatKey = GlobalKey();
      final drawerKey = GlobalKey();
      final foldersKey = GlobalKey();
      final light = Platform.environment['REMOTE_PI_PREVIEW_THEME'] == 'light';
      final theme = light ? buildLightTheme() : buildDarkTheme();
      final previewTheme = theme.copyWith(platform: TargetPlatform.android);
      Widget phone(String title, GlobalKey key, Widget child) => SizedBox(
        width: 412,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, letterSpacing: 1.6),
                ),
              ),
            ),
            RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 412,
                height: 892,
                child: MediaQuery(
                  data: const MediaQueryData(size: Size(412, 892)),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HomeViewModel>.value(value: home),
            ChangeNotifierProvider<ChatViewModel>.value(value: chat),
            ChangeNotifierProvider<VoiceInputViewModel>.value(value: voice),
            ChangeNotifierProvider<AttachmentViewModel>.value(
              value: attachment,
            ),
            ChangeNotifierProvider<Preferences>.value(value: prefs),
            ChangeNotifierProvider<SessionSelection>.value(value: selection),
            ChangeNotifierProvider<NewSessionViewModel>.value(
              value: newSession,
            ),
          ],
          child: RepaintBoundary(
            key: galleryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: previewTheme,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REMOTE PI  /  ANDROID PREVIEW',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Current Flutter widgets · demonstration data · 412 × 892 logical pixels',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          phone(
                            '01 / CHAT',
                            chatKey,
                            const SessionShell(
                              child: ChatPage(showBack: false),
                            ),
                          ),
                          const SizedBox(width: 24),
                          phone(
                            '02 / SESSIONS',
                            drawerKey,
                            const SessionShell(
                              child: ChatPage(showBack: false),
                            ),
                          ),
                          const SizedBox(width: 24),
                          phone(
                            '03 / NEW SESSION',
                            foldersKey,
                            const NewSessionPage(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      newSession.setAgent(WorkspaceAgent.codex);
      await tester.tap(
        find.descendant(
          of: find.byKey(drawerKey),
          matching: find.byTooltip('Sessions'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final firstMessage = find.descendant(
        of: find.byKey(chatKey),
        matching: find.text('Review the Android session flow.'),
      );
      expect(
        tester.getTopLeft(firstMessage).dy -
            tester.getTopLeft(find.byKey(chatKey)).dy,
        lessThan(140),
        reason: 'Short conversations start near the header.',
      );
      await _save(tester, galleryKey, '$output/overview.png');
      await _save(tester, chatKey, '$output/chat.png');
      await _save(tester, drawerKey, '$output/sessions.png');
      await _save(tester, foldersKey, '$output/new-session.png');
      chat.emit(
        const ChatReady(
          messages: [
            UserMsg(id: 'activity-user', text: 'Check this project.'),
            ThinkingMsg(
              id: 'thinking-preview',
              text:
                  'Check the selected project and available agents before opening a session.',
            ),
            ToolEvent(
              id: 'tool',
              toolCallId: 'tool',
              tool: 'bash',
              args: {'command': 'pnpm typecheck'},
              result: 'TypeScript checks passed. No errors found.',
              status: ToolEventStatus.completed,
            ),
            AssistantMsg(
              id: 'activity-answer',
              text: 'The project is ready. Choose a folder to continue.',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(chatKey),
          matching: find.byKey(const ValueKey('thinking-disclosure')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(chatKey),
          matching: find.byKey(const ValueKey('tool-details-tool')),
        ),
      );
      await tester.pumpAndSettle();
      await _save(tester, chatKey, '$output/activity-details.png');
      await tester.tap(
        find.descendant(
          of: find.byKey(drawerKey),
          matching: find.text('Working 1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(drawerKey),
          matching: find.text('backend'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.descendant(
            of: find.byKey(drawerKey),
            matching: find.byType(SessionSidebar),
          ),
          matching: find.text('remote_pi'),
        ),
        findsNothing,
      );
      tester.view.physicalSize = const Size(412, 892);
      final homeKey = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HomeViewModel>.value(value: home),
            ChangeNotifierProvider<SessionSelection>.value(value: selection),
          ],
          child: RepaintBoundary(
            key: homeKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: previewTheme,
              home: const SessionShell(child: SessionWelcome()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your workspaces'), findsOneWidget);
      await _save(tester, homeKey, '$output/home.png');
      final agentPickerKey = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider<NewSessionViewModel>.value(
          value: newSession,
          child: RepaintBoundary(
            key: agentPickerKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: previewTheme,
              home: const NewSessionPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workspace-agent-picker')));
      await tester.pumpAndSettle();
      expect(find.text('Choose Agent'), findsOneWidget);
      await _save(tester, agentPickerKey, '$output/agent-picker.png');
      await tester.tap(find.byTooltip('Close agent picker'));
      await tester.pumpAndSettle();
      chat.emit(
        ChatReady(
          messages: List.generate(
            4000,
            (index) => AssistantMsg(
              id: 'long-$index',
              text: 'Message $index in a long conversation.',
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ChatViewModel>.value(value: chat),
            ChangeNotifierProvider<VoiceInputViewModel>.value(value: voice),
            ChangeNotifierProvider<AttachmentViewModel>.value(
              value: attachment,
            ),
            ChangeNotifierProvider<Preferences>.value(value: prefs),
          ],
          child: MaterialApp(
            theme: previewTheme,
            home: const ChatPage(showBack: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(AssistantBubble).evaluate().length,
        lessThan(80),
        reason: 'Long history must remain virtualized.',
      );
      expect(find.text('Message 3999 in a long conversation.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      for (final notifier in <ChangeNotifier>[
        home,
        chat,
        voice,
        attachment,
        prefs,
        selection,
        newSession,
      ]) {
        notifier.dispose();
      }
    },
    skip: output == null,
  );
}
