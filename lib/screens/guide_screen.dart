import 'package:flutter/material.dart';

import '../models/remediation_protocol.dart';
import '../services/protocol_service.dart';
import '../theme/app_colors.dart';
import '../widgets/tile_card.dart';
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: protocols.length,
            itemBuilder: (context, index) {
              final protocol = protocols[index];
              return TileCard(
                child: ListTile(
                  title: Text(
                    protocol.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    protocol.pathogenType,
                    style: TextStyle(color: context.colors.textMuted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        protocol.severity,
                        style: TextStyle(
                          color: severityColor(context, protocol.severity),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          _ProtocolDetailScreen(protocol: protocol),
                    ),
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
