import 'package:flutter/material.dart';

import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/screens/login_screen.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// docs/DESIGN.md 화면 1: 온보딩.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _start(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final steps = [
      l10n.onboardingStep1,
      l10n.onboardingStep2,
      l10n.onboardingStep3
    ];
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 28, 26, 34),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    l10n.onboardingKicker,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: colors.gold700,
                      letterSpacing: 3.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('널널',
                      style: AppTextStyles.display(
                          fontSize: 64, color: colors.ink)),
                  const SizedBox(height: 18),
                  Container(width: 44, height: 1, color: colors.gold),
                  const SizedBox(height: 20),
                  Text(
                    l10n.onboardingIntro,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                        fontSize: 16.5, color: colors.ink800, height: 1.75),
                  ),
                ],
              ),
              Column(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        border: Border(
                          top: i == 0
                              ? BorderSide(color: colors.divider)
                              : BorderSide.none,
                          bottom: BorderSide(color: colors.divider),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (i + 1).toString().padLeft(2, '0'),
                            style: AppTextStyles.tabularNums(
                              AppTextStyles.body(
                                  fontSize: 13, color: colors.gold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              steps[i],
                              style: AppTextStyles.body(
                                fontSize: 12.5,
                                color: colors.ink800,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _start(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.gold),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        overlayColor: colors.goldTint08,
                      ),
                      child: Text(
                        l10n.onboardingCta,
                        style: AppTextStyles.body(
                            fontSize: 15,
                            color: colors.ink,
                            letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
