import 'package:flutter/material.dart';

import '../models/remediation_protocol.dart';
import '../services/protocol_service.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/protocol_cards.dart';
import '../widgets/tile_card.dart';

// Guide tab: every disease the app knows, with how to recognise and treat it.
// Works offline, the data is bundled in assets/data.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  late final Future<List<RemediationProtocol>> _protocols =
      ProtocolService.getAll();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disease Guide')),
      body: FutureBuilder<List<RemediationProtocol>>(
        future: _protocols,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final protocols = snapshot.data ?? [];

          // One column, kept narrow on tablets so lines stay easy to read
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  Text(
                    'Tap a condition to see its symptoms, what to do now and '
                    'how to prevent it.',
                    style: TextStyle(
                      fontSize: 15,
                      color: context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (protocols.isEmpty)
                    const EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'No guide data available',
                      text: 'The disease guide could not be loaded.',
                    ),
                  for (final protocol in protocols)
                    _DiseaseTile(protocol: protocol),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// One condition in the list: photo, name with its color, type and severity
class _DiseaseTile extends StatelessWidget {
  final RemediationProtocol protocol;

  const _DiseaseTile({required this.protocol});

  @override
  Widget build(BuildContext context) {
    return TileCard(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _ProtocolDetailScreen(protocol: protocol),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: _DiseaseImage(
                  path: protocol.image,
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: protocolColor(context, protocol),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            protocol.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        KindChip(kind: protocol.kind),
                        if (protocol.severity.toLowerCase() != 'none')
                          SeverityChip(severity: protocol.severity),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: context.colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// The full guide for one condition: photo, header, then each section
class _ProtocolDetailScreen extends StatelessWidget {
  final RemediationProtocol protocol;

  const _ProtocolDetailScreen({required this.protocol});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(protocol.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              DiseaseHeader(protocol: protocol),
              const SizedBox(height: AppSpacing.md),
              PathogenCard(protocol: protocol),
              const SizedBox(height: AppSpacing.md),
              RemediationCard(protocol: protocol),
              const SizedBox(height: AppSpacing.page),
            ],
          ),
        ),
      ),
    );
  }
}

// The disease photo from assets/images/diseases. Shows a plain placeholder
// when the disease has no photo or the file is missing.
class _DiseaseImage extends StatelessWidget {
  final String? path;
  final double width;
  final double height;

  const _DiseaseImage({
    required this.path,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: context.colors.surface2,
      child: Icon(
        Icons.image_outlined,
        color: context.colors.textMuted,
        size: height > 100 ? 48 : 24,
      ),
    );
    if (path == null) return placeholder;

    return Image.asset(
      path!,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
