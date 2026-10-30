import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../states/context_usage_state.dart';
import '../viewmodels/context_usage_viewmodel.dart';

Future<void> showContextUsage(BuildContext context) {
  final vm = context.read<ContextUsageViewModel>();
  vm.refresh();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: vm,
      child: const ContextUsageSheet(),
    ),
  );
}

class ContextUsageSheet extends StatelessWidget {
  const ContextUsageSheet({super.key});
  String _tokens(int? value) => value == null
      ? 'Not reported'
      : value.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ContextUsageViewModel>();
    final state = vm.state;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Context usage',
                      style: context.typo.sansBody.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh context usage',
                    onPressed: state is ContextUsageLoading ? null : vm.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (state is ContextUsageLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (state is ContextUsageError) Text(state.message),
              if (state is ContextUsageReady) ...[
                _row(context, 'Used tokens', _tokens(state.usage.tokens)),
                _row(context, 'Context window', _tokens(state.usage.window)),
                _row(
                  context,
                  'Usage',
                  state.usage.percent == null
                      ? 'Not reported'
                      : '${state.usage.percent!.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 16),
                if (state.usage.percent != null)
                  LinearProgressIndicator(
                    value: (state.usage.percent! / 100).clamp(0.0, 1.0),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Reported by ${state.usage.source == 'codex' ? 'Codex' : 'Pi'}. Token usage is an estimate and may be unavailable before the first response or just after compaction.',
                  style: context.typo.sansBody.copyWith(
                    color: context.colors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: context.typo.monoSmall),
      ],
    ),
  );
}
