import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/screens/settings_screen.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/app_icon.dart';

/// docs/DESIGN.md 화면 4: 지난 대화(히스토리).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final entries =
        historyEntriesFor(Localizations.localeOf(context).languageCode);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: l10n.historyTitle,
              leading: IconButton(
                icon: AppIcon(AppIconShape.chevronLeft,
                    size: 18, color: colors.ink),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: l10n.commonBack,
              ),
              trailing: IconButton(
                icon:
                    AppIcon(AppIconShape.settings, size: 18, color: colors.ink),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen()),
                  );
                },
                tooltip: l10n.commonSettings,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: index == 0
                            ? BorderSide(color: colors.divider)
                            : BorderSide.none,
                        bottom: BorderSide(color: colors.divider),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                entry.title,
                                style: AppTextStyles.heading(
                                  fontSize: 16.5,
                                  color: colors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              entry.date,
                              style: AppTextStyles.tabularNums(
                                AppTextStyles.body(
                                    fontSize: 11.5, color: colors.ink600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(
                              fontSize: 13, color: colors.ink700, height: 1.6),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
