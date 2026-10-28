import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/workspaces/new_session_page.dart';
import 'package:app/ui/workspaces/viewmodels/new_session_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'new_session_viewmodel_test.dart' show FakeWorkspaces;

void main() {
  testWidgets('folder chooser works on phone and remains usable with the keyboard', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previews = Platform.environment['REMOTE_PI_PREVIEW_DIR'];
    if (previews != null && Platform.isWindows) {
      final font = File(r'C:\Windows\Fonts\segoeui.ttf');
      if (font.existsSync()) {
        final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
        await tester.runAsync(loader.load);
      }
    }
    final vm = NewSessionViewModel(FakeWorkspaces());
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: vm, child: MaterialApp(
      theme: buildDarkTheme(), home: RepaintBoundary(key: boundaryKey, child: const NewSessionPage()),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Open Pi here'), findsOneWidget);
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    expect(find.text('Open Codex here'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (previews != null) {
      await tester.runAsync(() async {
        final image = await (boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(previews).create(recursive: true);
        await File('$previews/folder-phone.png').writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    tester.view.physicalSize = const Size(390, 430);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Open Codex here'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
  });
}
