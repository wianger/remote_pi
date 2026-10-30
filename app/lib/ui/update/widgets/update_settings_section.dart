import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/update/states/update_banner_state.dart';
import 'package:app/ui/update/viewmodels/update_banner_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UpdateSettingsSection extends StatelessWidget {
  const UpdateSettingsSection({super.key});

  Future<void> _download(BuildContext context) async {
    final opened = await context.read<UpdateBannerViewModel>().download();
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open the download. Open GitHub Releases instead.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UpdateBannerViewModel>();
    final state = vm.state;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App updates',
            style: context.typo.sansBody.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Remote Pi Dev ${vm.currentVersion} (${vm.currentBuildNumber})',
            style: context.typo.monoSmall.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('check-github-updates'),
            onPressed: state is UpdateCheckInProgress ? null : vm.checkManually,
            icon: state is UpdateCheckInProgress
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update, size: 18),
            label: Text(
              state is UpdateCheckInProgress
                  ? 'Checking GitHub…'
                  : 'Check for updates',
            ),
          ),
          if (state is UpdateCheckCurrent)
            const Text('You are using the latest development release.'),
          if (state is UpdateCheckFailed) Text(state.message),
          if (state is UpdateBannerVisible) ...[
            const SizedBox(height: 12),
            Text(
              'Version ${state.info.version} (${state.info.buildNumber}) is available.',
            ),
            if (state.info.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                state.info.notes,
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('download-github-apk'),
              onPressed: () => _download(context),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download APK'),
            ),
            const SizedBox(height: 8),
            Text(
              'Open the download to update this app. Your pairings and settings are kept.',
              style: context.typo.sansBody.copyWith(
                color: context.colors.muted,
              ),
            ),
          ],
          TextButton(
            onPressed: vm.openReleases,
            child: const Text('GitHub Releases'),
          ),
        ],
      ),
    );
  }
}
