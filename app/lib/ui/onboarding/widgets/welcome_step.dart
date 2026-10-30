import 'package:app/ui/core/branding/app_brand.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';

/// Onboarding step 1 — welcome. Static, no animations (per plan 14 D2 —
/// "Welcome conservador (sem animações)").
class WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;
  const WelcomeStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AppMark(size: 88, tile: true)),
          const SizedBox(height: 32),
          Text(
            kAppName,
            textAlign: TextAlign.center,
            style: brandTextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colors.text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your agents. Across devices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kMonoFamily,
              fontSize: 13,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Pair your computer, choose a workspace, and continue '
            'your Pi or Codex conversations wherever you are.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kMonoFamily,
              fontSize: 12,
              color: colors.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
            child: const Text(
              'Get started',
              style: TextStyle(
                fontFamily: kMonoFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
