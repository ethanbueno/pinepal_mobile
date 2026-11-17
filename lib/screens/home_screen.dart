import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_record.dart';
import '../services/database_helper.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../utils/format.dart';
import '../utils/image_size.dart';
import '../widgets/tile_card.dart';
import '../widgets/disease_badge.dart';
import '../widgets/farm_dashboard.dart';
import 'guide_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'result_detail_screen.dart';
import 'scanner_screen.dart';

// The main screen after the app starts: bottom navigation bar with
// Home, History, Guide, Profile and a big Scan button in the middle.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // Changes after the scanner closes, so the current tab loads fresh data
  int _reload = 0;

  Widget _currentPage() {
    switch (_index) {
      case 0:
        return const _HomeTab();
      case 1:
        return const HistoryScreen();
      case 2:
        return const GuideScreen();
      default:
        return const ProfileScreen();
    }
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    if (mounted) setState(() => _reload++);
  }

  // The bar is a pill. The active tab is a pill inside it, with the same gap
  // on every side (AppNav.inset), so both shapes follow each other. Sizes are
  // in AppNav (lib/theme/app_colors.dart).
  //
  // Active tab gets a soft accent background, like the web navigation.
  // Outlined icon normally, filled icon on the active tab.
  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final selected = _index == index;
    final color = selected
        ? context.colors.accentText
        : context.colors.textMuted;

    return Expanded(
      child: Padding(
        // 2 between tabs; the first and last keep the full gap to the bar edge
        padding: EdgeInsets.fromLTRB(
          index == 0 ? AppNav.inset : 2,
          AppNav.inset,
          index == 3 ? AppNav.inset : 2,
          AppNav.inset,
        ),
        // The pill fades in and out; the press effect is tinted with the accent
        // instead of Material's default grey
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? context.colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppNav.tabRadius),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(AppNav.tabRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _index = index),
              splashColor: context.colors.accent.withValues(alpha: 0.18),
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? activeIcon : icon,
                    color: color,
                    size: AppNav.iconSize,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppNav.labelSize,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyedSubtree(
        key: ValueKey('$_index-$_reload'),
        child: _currentPage(),
      ),
      // Floating rounded bar, inset from the screen edges. SafeArea adds the
      // gesture bar space under it on phones without buttons.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppNav.sideMargin,
            0,
            AppNav.sideMargin,
            AppNav.sideMargin,
          ),
          child: Container(
            height: AppNav.barHeight,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppNav.barRadius),
              border: Border.all(color: context.colors.line),
            ),
            child: Row(
              children: [
                _navItem(0, Icons.home_outlined, Icons.home, 'Home'),
                _navItem(1, Icons.history, Icons.history, 'History'),
                // Scan button: a circle inside the bar
                Expanded(
                  child: Center(
                    child: Material(
                      color: context.colors.accent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _openScanner,
                        splashColor: context.colors.onAccent.withValues(
                          alpha: 0.15,
                        ),
                        highlightColor: Colors.transparent,
                        child: Tooltip(
                          message: 'Scan a pineapple',
                          child: SizedBox(
                            width: AppNav.scanButton,
                            height: AppNav.scanButton,
                            child: Icon(
                              Icons.camera_alt,
                              size: AppNav.scanIcon,
                              color: context.colors.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _navItem(2, Icons.menu_book_outlined, Icons.menu_book, 'Guide'),
                _navItem(3, Icons.person_outline, Icons.person, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Content of the Home tab: greeting, a prompt to scan, and the latest scans.
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late Future<List<ScanRecord>> _recent;

  // Goes up to make the dashboard load its numbers again
  int _dashboardVersion = 0;

  // Reloads the dashboard and the recent scans, after a pull or an edit
  void _reloadAll() {
    setState(() {
      _recent = _loadRecent();
      _dashboardVersion++;
    });
  }

  @override
  void initState() {
    super.initState();
    _recent = _loadRecent();
  }

  Future<List<ScanRecord>> _loadRecent() async {
    final all = await DatabaseHelper.instance.getAllScans();
    return all.take(3).toList();
  }

  void _openScan(ScanRecord scan) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ResultDetailScreen(scan: scan)),
    ).then((_) {
      // the scan may have been verified or deleted
      if (mounted) _reloadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => _reloadAll(),
        child: ListView(
          // so pull to refresh also works when the page is short
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            // Logo with the app name and a short line under it
            Row(
              children: [
                Image.asset('assets/icons/logo.png', width: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PinePal',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pineapple disease scanner',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const _ThemeToggle(),
              ],
            ),
            const SizedBox(height: AppSpacing.section),

            const _ScanHint(),
            const SizedBox(height: AppSpacing.section),

            // The farmer's dashboard, right on Home
            Row(
              children: [
                Icon(Icons.insights_outlined, color: context.colors.accentText),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  'My farm',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FarmDashboard(key: ValueKey(_dashboardVersion)),
            const SizedBox(height: AppSpacing.section),

            const Text(
              'Recent scans',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<ScanRecord>>(
              future: _recent,
              builder: (context, snapshot) {
                // Recent scans come from the phone and load almost instantly,
                // so only the farm dashboard above shows a loader (one per screen).
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                final scans = snapshot.data ?? [];
                if (scans.isEmpty) {
                  return const _NoScansYet();
                }
                return Column(
                  children: scans.map((scan) {
                    return TileCard(
                      child: ListTile(
                        onTap: () => _openScan(scan),
                        minVerticalPadding: AppSpacing.md,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                          child: Image.file(
                            File(scan.imagePath),
                            width: 56,
                            height: 56,
                            // decode a small copy, not the full-size photo
                            cacheWidth: thumbnailPixels(context, 56),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              width: 56,
                              height: 56,
                              color: context.colors.surface2,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: context.colors.textMuted,
                              ),
                            ),
                          ),
                        ),
                        title: Align(
                          alignment: Alignment.centerLeft,
                          child: DiseaseBadge(label: scan.predictedLabel),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            '${(scan.confidence * 100).toStringAsFixed(0)}% confidence'
                            '  ·  ${formatDateTime(scan.scannedAt)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.textMuted,
                            ),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: context.colors.textMuted,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Tells the user where the scan button is. It is not a button itself, so the
// icon sits in a soft square instead of the solid circle used by the real one.
class _ScanHint extends StatelessWidget {
  const _ScanHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              color: context.colors.accentText,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Check a pineapple',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap the camera button below to scan for diseases.',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Shown in place of the list before the first scan
class _NoScansYet extends StatelessWidget {
  const _NoScansYet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.section,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.line),
      ),
      child: Column(
        children: [
          Icon(Icons.eco_outlined, size: 32, color: context.colors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'No scans yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your last three scans will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}

// Light/dark switch, same outline icon button as the web
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () =>
          ThemeController.instance.toggle(Theme.of(context).brightness),
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      style: IconButton.styleFrom(
        side: BorderSide(color: context.colors.line),
        backgroundColor: dark ? context.colors.surface2 : context.colors.canvas,
      ),
    );
  }
}
