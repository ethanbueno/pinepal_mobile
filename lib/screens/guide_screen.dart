import 'package:flutter/material.dart';

import '../models/remediation_protocol.dart';
import '../services/protocol_service.dart';
import '../theme/app_colors.dart';
import '../widgets/protocol_cards.dart';

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
          if (protocols.isEmpty) {
            return const Center(child: Text('No guide data available.'));
          }

          // One column on phones, two on large phones in landscape and small
          // tablets, three from tablet width up. Cards in a row share a
          // height so their buttons line up, and the grid stops growing past
          // 1100 so cards don't stretch on wide screens.
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width < 560 ? 1 : (width < 900 ? 2 : 3);
              final gap = width < 560 ? 12.0 : 20.0;
              final rows = <Widget>[];
              for (var i = 0; i < protocols.length; i += columns) {
                final cards = <Widget>[];
                for (var j = i; j < i + columns; j++) {
                  if (cards.isNotEmpty) cards.add(SizedBox(width: gap));
                  cards.add(Expanded(
                    child: j < protocols.length
                        ? _DiseaseCard(protocol: protocols[j])
                        : const SizedBox.shrink(),
                  ));
                }
                if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
                rows.add(IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: cards,
                  ),
                ));
              }

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: width < 560 ? 16 : 24,
                  vertical: width < 560 ? 16 : 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(children: rows),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// A disease laid out like a plan card: name, severity as the headline figure,
// pathogen type under it, the main symptoms as divided rows, and a button at
// the bottom. It lifts with a darker border and a shadow on hover or press.
class _DiseaseCard extends StatefulWidget {
  final RemediationProtocol protocol;

  const _DiseaseCard({required this.protocol});

  @override
  State<_DiseaseCard> createState() => _DiseaseCardState();
}

class _DiseaseCardState extends State<_DiseaseCard> {
  bool _hovered = false;
  bool _pressed = false;

  void _open() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ProtocolDetailScreen(protocol: widget.protocol),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final protocol = widget.protocol;
    final lifted = _hovered || _pressed;
    final symptoms = protocol.symptoms.take(3).toList();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, lifted ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: lifted ? colors.text : colors.line,
            width: lifted ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: lifted ? 0.12 : 0.04),
              blurRadius: lifted ? 24 : 10,
              offset: Offset(0, lifted ? 10 : 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: _open,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    child: _DiseaseImage(
                      path: protocol.image,
                      width: double.infinity,
                      height: 140,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    protocol.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    protocol.severity,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: severityColor(context, protocol.severity),
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    protocol.pathogenType.toLowerCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  for (final symptom in symptoms)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: colors.line)),
                      ),
                      child: Text(
                        symptom,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Pushes the button to the bottom when a row is taller
                  const Spacer(),
                  Center(
                    child: SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        onPressed: _open,
                        child: const Text('View Guide'),
                      ),
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
}

class _ProtocolDetailScreen extends StatelessWidget {
  final RemediationProtocol protocol;

  const _ProtocolDetailScreen({required this.protocol});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(protocol.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: _DiseaseImage(
                path: protocol.image,
                width: double.infinity,
                height: 220,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              protocol.scientificName,
              style: TextStyle(
                color: context.colors.textMuted,
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            SeverityChip(severity: protocol.severity),
            const SizedBox(height: 16),
            PathogenCard(protocol: protocol),
            const SizedBox(height: 16),
            RemediationCard(protocol: protocol),
            const SizedBox(height: 20),
          ],
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
