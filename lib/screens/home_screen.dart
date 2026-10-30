import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_record.dart';
import '../services/database_helper.dart';
import '../theme/app_colors.dart';
import '../widgets/tile_card.dart';
import '../theme/theme_controller.dart';
import '../widgets/disease_badge.dart';
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

  // The bar is a pill (radius 32). The active tab is a pill inside it, with the
  // same gap on every side (6), so both shapes follow each other. 25 is half
  // of the tab height: 64 - 2 (border) - 2 * 6 = 50.
  static const _navInset = 6.0;
  static const _tabRadius = 25.0;

  // Active tab gets a soft accent background, like the web navigation
  Widget _navItem(int index, IconData icon, String label) {
    final selected = _index == index;
    final color = selected
        ? context.colors.accentText
        : context.colors.textMuted;

    return Expanded(
      child: Padding(
        // 2 between tabs; the first and last keep the full gap to the bar edge
        padding: EdgeInsets.fromLTRB(
          index == 0 ? _navInset : 2,
          _navInset,
          index == 3 ? _navInset : 2,
          _navInset,
        ),
        // The pill fades in and out; the press effect is tinted with the accent
        // instead of Material's default grey
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? context.colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(_tabRadius),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(_tabRadius),
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
                  Icon(icon, color: color),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
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
      // Floating rounded bar, inset from the screen edges
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: context.colors.line),
            ),
            child: Row(
              children: [
                _navItem(0, Icons.home, 'Home'),
                _navItem(1, Icons.history, 'History'),
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
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(
                            Icons.camera_alt,
                            size: 28,
                            color: context.colors.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _navItem(2, Icons.menu_book, 'Guide'),
                _navItem(3, Icons.person, 'Profile'),
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

  @override
  void initState() {
    super.initState();
    _recent = _loadRecent();
  }

  Future<List<ScanRecord>> _loadRecent() async {
    final all = await DatabaseHelper.instance.getAllScans();
    return all.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Image.asset('assets/icons/logo.png', width: 56),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'PINEPAL',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const _ThemeToggle(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pineapple disease scanner',
            style: TextStyle(color: context.colors.textMuted),
          ),
          const SizedBox(height: 24),

          // Prompt to scan
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.colors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  // Same look as the scan button in the bottom bar
                  decoration: BoxDecoration(
                    color: context.colors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 28,
                    color: context.colors.onAccent,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Tap the camera button below to scan a pineapple '
                    'for diseases.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Recent scans',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<ScanRecord>>(
            future: _recent,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final scans = snapshot.data ?? [];
              if (scans.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No scans yet',
                    style: TextStyle(color: context.colors.textMuted),
                  ),
                );
              }
              return Column(
                children: scans.map((scan) {
                  return TileCard(
                    child: ListTile(
                      onTap: () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ResultDetailScreen(scan: scan),
                            ),
                          ).then((_) {
                            if (mounted) {
                              setState(() => _recent = _loadRecent());
                            }
                          }),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        child: Image.file(
                          File(scan.imagePath),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Icon(
                            Icons.image_not_supported,
                            size: 40,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ),
                      title: Align(
                        alignment: Alignment.centerLeft,
                        child: DiseaseBadge(label: scan.predictedLabel),
                      ),
                      subtitle: Text(
                        '${(scan.confidence * 100).toStringAsFixed(0)}% confidence',
                        style: TextStyle(color: context.colors.textMuted),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
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
      onPressed: ThemeController.instance.toggle,
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      style: IconButton.styleFrom(
        side: BorderSide(color: context.colors.line),
        backgroundColor: dark ? context.colors.surface2 : context.colors.canvas,
      ),
    );
  }
}
