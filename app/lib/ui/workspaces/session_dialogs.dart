import 'package:app/pairing/storage.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';

/// Phone-local conversation rename. Empty input clears the override so the
/// computer's announced room name is shown again.
Future<String?> showSessionRenameDialog(
  BuildContext context, {
  required String currentName,
}) => showNameDialog(
  context,
  title: 'Rename conversation',
  currentValue: currentName,
  hintText: 'Leave empty to use the computer name',
);

Future<String?> showDeviceRenameDialog(
  BuildContext context, {
  required String currentName,
}) => showNameDialog(
  context,
  title: 'Rename device',
  currentValue: currentName,
  hintText: 'Name shown in this app',
);

Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  required String currentValue,
  required String hintText,
}) {
  final controller = TextEditingController(text: currentValue);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );
  return showDialog<String?>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: hintText),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Shared by the sidebar action sheet and the chat header menu, so both show
/// the same room, directory, model and device details.
Future<void> showSessionInfoDialog(
  BuildContext context, {
  required PeerRecord peer,
  required RoomInfo? room,
  required String name,
}) {
  final owner = (peer.nickname?.isNotEmpty ?? false)
      ? peer.nickname!
      : peer.sessionName.isNotEmpty
      ? peer.sessionName
      : peer.remoteEpk.substring(0, 8);
  final model = room?.model;
  final paired = peer.pairedAt.contains('T')
      ? peer.pairedAt.split('T').first
      : peer.pairedAt;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return AlertDialog(
        backgroundColor: colors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.border),
        ),
        title: Text('Session info', style: dialogContext.typo.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Name', value: name),
            _InfoRow(label: 'Path', value: room?.cwd ?? '—'),
            _InfoRow(label: 'Owner', value: owner),
            if (model != null && model.isNotEmpty)
              _InfoRow(label: 'Model', value: model),
            _InfoRow(label: 'Room', value: room?.roomId ?? '—'),
            _InfoRow(label: 'Paired', value: paired),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: context.typo.monoSmall.copyWith(color: colors.muted),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: context.typo.monoSmall.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}
