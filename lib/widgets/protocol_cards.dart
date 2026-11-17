import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/remediation_protocol.dart';
import '../theme/app_colors.dart';
import 'disease_badge.dart';

// Shared by the diagnostic report and the Guide tab, so a disease looks the
// same wherever it is shown. The sections use the same titles as the
// remediation guide on the website: Symptoms, Immediate action, Prevention.

// Body text of the guide: a bit larger than normal and in the full text color,
// so it is easy to read outside in the sun.
const double guideTextSize = 16;
const double guideLineHeight = 1.5;

Color severityColor(BuildContext context, String severity) {
  switch (severity.toLowerCase()) {
    case 'none':
      return context.colors.success;
    case 'low':
    case 'medium':
      return context.colors.warning;
    case 'high':
    case 'critical':
      return context.colors.danger;
    default:
      return context.colors.textMuted;
  }
}

// The fixed disease color for a protocol, grey when there is none
Color protocolColor(BuildContext context, RemediationProtocol protocol) {
  return diseaseColors[protocol.label] ?? context.colors.textMuted;
}

// Small tinted pill, the same shape as the disease badge
class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// "High severity", colored by how serious it is
class SeverityChip extends StatelessWidget {
  final String severity;

  const SeverityChip({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      text: '$severity severity',
      color: severityColor(context, severity),
    );
  }
}

// "Disease", "Disorder" or "Healthy"
class KindChip extends StatelessWidget {
  final String kind;

  const KindChip({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    return _Pill(text: kind, color: context.colors.textMuted);
  }
}

// Name of the disease with its color, the scientific name and the two chips.
// Sits at the top of a guide page.
class DiseaseHeader extends StatelessWidget {
  final RemediationProtocol protocol;

  const DiseaseHeader({super.key, required this.protocol});

  @override
  Widget build(BuildContext context) {
    final color = protocolColor(context, protocol);
    final hasScientificName =
        protocol.scientificName.isNotEmpty && protocol.scientificName != 'N/A';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color strip on the left, like the dot next to a disease name
            Container(width: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main reference photo plus four more, above the name
                    ReferencePhotoRow(
                      paths: protocol.images,
                      caption: protocol.name,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      protocol.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (hasScientificName) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        protocol.scientificName,
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        KindChip(kind: protocol.kind),
                        if (protocol.severity.toLowerCase() != 'none')
                          SeverityChip(severity: protocol.severity),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Cause: ${protocol.pathogenType}',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The photos in the guide header: the main photo (200x130) and four smaller
// ones (96x130) to its right. The row scrolls sideways so it never overflows
// on a small phone. Tapping a photo opens the full-screen viewer at that photo,
// where you can swipe between the photos that loaded.
class ReferencePhotoRow extends StatefulWidget {
  final List<String> paths;
  final String caption;
  final int slots;

  const ReferencePhotoRow({
    super.key,
    required this.paths,
    required this.caption,
    this.slots = 5,
  });

  @override
  State<ReferencePhotoRow> createState() => _ReferencePhotoRowState();
}

class _ReferencePhotoRowState extends State<ReferencePhotoRow> {
  // Paths whose file could not be loaded
  final Set<String> _failed = {};

  @override
  void didUpdateWidget(ReferencePhotoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paths != widget.paths) _failed.clear();
  }

  List<String> get _loaded => widget.paths
      .take(widget.slots)
      .where((p) => !_failed.contains(p))
      .toList();

  void _open(String path) {
    final loaded = _loaded;
    final index = loaded.indexOf(path);
    if (index == -1) return;
    showPhotoViewer(
      context,
      paths: loaded,
      initialIndex: index,
      caption: widget.caption,
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < widget.slots; i++) {
      final path = i < widget.paths.length ? widget.paths[i] : null;
      if (i > 0) children.add(const SizedBox(width: AppSpacing.sm));
      children.add(
        ReferencePhoto(
          key: ValueKey('photo-slot-$i'),
          path: path,
          caption: widget.caption,
          width: i == 0 ? 200 : 96,
          compact: i > 0,
          onTap: path == null ? null : () => _open(path),
          onFailed: path == null
              ? null
              : () {
                  if (mounted && !_failed.contains(path)) {
                    setState(() => _failed.add(path));
                  }
                },
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }
}

// One photo slot. Tapping a photo opens it full screen with pinch zoom; when
// there is no photo (or the file is missing) it shows a "Photo coming soon"
// box that does nothing when tapped. The compact placeholder shows only the
// icon.
class ReferencePhoto extends StatefulWidget {
  final String? path;
  final String caption;
  final double width;
  final double height;
  final bool compact;
  // Called on tap instead of opening a single-photo viewer
  final VoidCallback? onTap;
  // Called once when the file cannot be loaded
  final VoidCallback? onFailed;

  const ReferencePhoto({
    super.key,
    required this.path,
    required this.caption,
    this.width = 200,
    this.height = 130,
    this.compact = false,
    this.onTap,
    this.onFailed,
  });

  @override
  State<ReferencePhoto> createState() => _ReferencePhotoState();
}

class _ReferencePhotoState extends State<ReferencePhoto> {
  bool _failed = false;

  @override
  void didUpdateWidget(ReferencePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _failed = false;
  }

  Widget _placeholder(BuildContext context) {
    final icon = Icon(
      Icons.image_outlined,
      color: context.colors.textMuted,
      size: 24,
    );
    if (widget.compact) {
      return Semantics(
        label: 'Photo coming soon',
        child: Container(
          color: context.colors.surface2,
          alignment: Alignment.center,
          child: icon,
        ),
      );
    }
    return Container(
      color: context.colors.surface2,
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(height: 2),
          Text(
            'Photo coming soon',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context) {
    final onTap = widget.onTap;
    if (onTap != null) {
      onTap();
    } else {
      showPhotoViewer(
        context,
        paths: [widget.path!],
        initialIndex: 0,
        caption: widget.caption,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final hasPhoto = path != null && !_failed;
    final content = !hasPhoto
        ? _placeholder(context)
        : Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // the file is missing: switch to the placeholder after this frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_failed) {
                  setState(() => _failed = true);
                  widget.onFailed?.call();
                }
              });
              return _placeholder(context);
            },
          );

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: context.colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: !hasPhoto
          ? content
          : Semantics(
              button: true,
              label: 'View larger photo',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleTap(context),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      content,
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// Full-screen photo viewer: opens at [initialIndex], swipe between [paths],
// pinch to zoom each one.
Future<void> showPhotoViewer(
  BuildContext context, {
  required List<String> paths,
  required int initialIndex,
  required String caption,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (context) =>
        PhotoViewer(paths: paths, initialIndex: initialIndex, caption: caption),
  );
}

class PhotoViewer extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  final String caption;

  const PhotoViewer({
    super.key,
    required this.paths,
    required this.initialIndex,
    required this.caption,
  });

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.paths.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.paths.length;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: total,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => InteractiveViewer(
                      maxScale: 5,
                      child: Center(
                        child: Image.asset(
                          widget.paths[i],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    '${widget.caption} · ${_index + 1} / $total',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A titled card with an icon in a soft amber square, like the scan hint on Home
class GuideSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  // The "what to do" card: tinted amber so it stands out from the reading parts
  final bool highlight;

  const GuideSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: highlight
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.10),
                context.colors.surface,
              )
            : context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: highlight
              ? accent.withValues(alpha: 0.35)
              : context.colors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: highlight
                      ? context.colors.surface
                      : context.colors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(icon, size: 20, color: context.colors.accentText),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

// A plain paragraph of guide text
class GuideParagraph extends StatelessWidget {
  final String text;

  const GuideParagraph({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: guideTextSize, height: guideLineHeight),
    );
  }
}

// One item in a short list, like the look-alikes or who to call
class GuideBullet extends StatelessWidget {
  final String text;

  const GuideBullet({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '•',
              style: TextStyle(
                color: context.colors.accentText,
                fontSize: guideTextSize,
                fontWeight: FontWeight.w700,
                height: guideLineHeight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: guideTextSize,
                height: guideLineHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// One numbered step. Only the steps are numbered, because their order matters;
// symptoms and prevention read as short paragraphs.
class GuideStep extends StatelessWidget {
  final String text;
  final int number;

  const GuideStep({super.key, required this.text, required this.number});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$number.',
              style: TextStyle(
                color: context.colors.accentText,
                fontSize: guideTextSize,
                fontWeight: FontWeight.w700,
                height: guideLineHeight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: guideTextSize,
                height: guideLineHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Small grey label above a group of guide cards, like "Identify"
class GuideGroupLabel extends StatelessWidget {
  final String text;

  const GuideGroupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// Cards with a gap between them, skipping the ones that have no content
Widget _stack(String label, List<Widget> cards) {
  if (cards.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GuideGroupLabel(label),
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.md),
        cards[i],
      ],
    ],
  );
}

Widget _bullets(List<String> items) =>
    Column(children: [for (final item in items) GuideBullet(text: item)]);

// The healthy guide has hand checks instead of treatment
bool _isHealthy(RemediationProtocol p) => p.checks.isNotEmpty;

Widget _checksCard(RemediationProtocol p) => GuideSection(
  icon: Icons.fact_check_outlined,
  title: 'Check the plant yourself',
  highlight: true,
  children: [_bullets(p.checks)],
);

Widget _lookAlikesCard(RemediationProtocol p) => GuideSection(
  icon: Icons.compare_arrows,
  title: 'Could also be',
  children: [_bullets(p.lookAlikes)],
);

// "Identify": what it is, the symptoms and the look-alikes.
// The healthy guide shows About, then Check the plant yourself.
class PathogenCard extends StatelessWidget {
  final RemediationProtocol protocol;

  const PathogenCard({super.key, required this.protocol});

  @override
  Widget build(BuildContext context) {
    final p = protocol;
    final healthy = _isHealthy(p);
    return _stack(healthy ? 'Result' : 'Identify', [
      GuideSection(
        icon: Icons.info_outline,
        title: 'About',
        children: [GuideParagraph(text: p.description)],
      ),
      if (p.symptoms.isNotEmpty)
        GuideSection(
          icon: Icons.search,
          title: 'Symptoms',
          children: [_bullets(p.symptoms)],
        ),
      if (healthy) _checksCard(p),
      if (!healthy && p.lookAlikes.isNotEmpty) _lookAlikesCard(p),
    ]);
  }
}

// "What to do": the numbered steps in an amber card, then prevention.
// Then "Help and sources". The healthy guide shows Could also be and the
// scanning tips instead.
class RemediationCard extends StatelessWidget {
  final RemediationProtocol protocol;

  const RemediationCard({super.key, required this.protocol});

  @override
  Widget build(BuildContext context) {
    final p = protocol;
    final healthy = _isHealthy(p);
    final act = _stack(healthy ? 'Keep watching' : 'What to do', [
      if (healthy && p.lookAlikes.isNotEmpty) _lookAlikesCard(p),
      if (p.scanTips.isNotEmpty)
        GuideSection(
          icon: Icons.photo_camera_outlined,
          title: 'Scanning tips',
          children: [_bullets(p.scanTips)],
        ),
      if (p.remediationSteps.isNotEmpty)
        GuideSection(
          icon: Icons.healing_outlined,
          title: 'Immediate action',
          highlight: true,
          children: [
            for (var i = 0; i < p.remediationSteps.length; i++)
              GuideStep(text: p.remediationSteps[i], number: i + 1),
          ],
        ),
      if (p.preventiveMeasures.isNotEmpty)
        GuideSection(
          icon: Icons.eco_outlined,
          title: 'Prevention',
          children: [_bullets(p.preventiveMeasures)],
        ),
    ]);
    final help = _stack('Help and sources', [
      if (p.getHelp.isNotEmpty)
        GuideSection(
          icon: Icons.support_agent_outlined,
          title: 'Get help',
          children: [_bullets(p.getHelp)],
        ),
      if (p.sources.isNotEmpty)
        SourcesCard(protocol: p)
      else if (p.photoCredits.isNotEmpty)
        GuideSection(
          icon: Icons.photo_camera_outlined,
          title: 'Photo credits',
          children: [PhotoCreditList(credits: p.photoCredits)],
        ),
    ]);
    final hasHelp =
        p.getHelp.isNotEmpty ||
        p.sources.isNotEmpty ||
        p.photoCredits.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        act,
        if (hasHelp) ...[const SizedBox(height: AppSpacing.lg), help],
      ],
    );
  }
}

// Opens a source in the phone's browser. Shows a short message when there is
// no browser or no internet to hand it to.
Future<void> openSource(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var opened = false;
  if (uri != null) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Some phones have no app set for links; let the system pick instead
      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      // e.g. MissingPluginException when the app was hot-restarted instead
      // of rebuilt after url_launcher was added
      debugPrint('openSource failed for $url: $e');
    }
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
  }
}

// Where the guide's advice comes from, Philippine sources first. Tapping a
// source opens it in the browser (it needs internet). Long lists start folded
// to the first few.
class SourcesCard extends StatefulWidget {
  final RemediationProtocol protocol;

  const SourcesCard({super.key, required this.protocol});

  @override
  State<SourcesCard> createState() => _SourcesCardState();
}

class _SourcesCardState extends State<SourcesCard> {
  static const _shownAtFirst = 4;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.textMuted;
    final all = widget.protocol.sortedSources;
    final shown = _showAll ? all : all.take(_shownAtFirst).toList();
    final reviewed = widget.protocol.reviewed;

    return GuideSection(
      icon: Icons.menu_book_outlined,
      title: 'Sources (${all.length})',
      children: [
        for (final source in shown) _SourceTile(source: source),
        if (all.length > _shownAtFirst)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: context.colors.accentText,
            ),
            onPressed: () => setState(() => _showAll = !_showAll),
            icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _showAll ? 'Show fewer' : 'Show all ${all.length} sources',
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Always check that a product is registered with the Fertilizer and '
          'Pesticide Authority (FPA) and follow its label.'
          '${reviewed != null ? ' Last reviewed $reviewed.' : ''}',
          style: TextStyle(color: muted, fontSize: 13, height: 1.4),
        ),
        if (widget.protocol.photoCredits.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Photo credits',
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          PhotoCreditList(credits: widget.protocol.photoCredits),
        ],
      ],
    );
  }
}

// Small muted lines, one per guide photo: "author · license". Tapping a line
// opens the photo's source page.
class PhotoCreditList extends StatelessWidget {
  final List<PhotoCredit> credits;

  const PhotoCreditList({super.key, required this.credits});

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.textMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final credit in credits)
          InkWell(
            onTap: credit.url.isEmpty
                ? null
                : () => openSource(context, credit.url),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${credit.author} · ${credit.license}',
                style: TextStyle(color: muted, fontSize: 12, height: 1.35),
              ),
            ),
          ),
      ],
    );
  }
}

// One source: title in the accent color, publisher and region under it
class _SourceTile extends StatelessWidget {
  final GuideSource source;

  const _SourceTile({required this.source});

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: source.url.isEmpty
            ? null
            : () => openSource(context, source.url),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.title,
                      style: TextStyle(
                        color: context.colors.accentText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${source.publisher} · ${source.tier}',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (source.url.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Icon(Icons.open_in_new, size: 18, color: muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
