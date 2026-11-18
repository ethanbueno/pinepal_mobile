import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/scan_record.dart';
import '../services/app_settings.dart';
import '../services/classifier_service.dart';
import '../services/database_helper.dart';
import '../services/location_service.dart';
import '../services/sync_controller.dart';
import '../theme/app_colors.dart';
import '../utils/municipalities.dart';
import 'result_detail_screen.dart';

// Photo on top, a rounded sheet at the bottom. Tapping "Analyze Photo" runs
// the model and the sheet shows the result (disease, confidence, top 3).
// A photo that doesn't look like a pineapple gets a retake message instead,
// and is not saved.
class PhotoPreviewScreen extends StatefulWidget {
  // Sent back to the scanner when a gallery photo wasn't a pineapple, so the
  // scanner opens the gallery again
  static const String pickAnother = 'pick_another';

  final String imagePath;
  final String imageSource; // 'Camera' or 'Gallery'

  const PhotoPreviewScreen({
    super.key,
    required this.imagePath,
    required this.imageSource,
  });

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  final ClassifierService _classifier = ClassifierService();

  bool _analyzing = false;
  ClassificationResult? _result;
  ScanRecord? _savedScan; // set once the scan is in the database
  bool _saving = false;
  String? _error;

  // Every scan is saved under Echague; there is no municipality picker.
  static const String _municipality = scanMunicipality;

  @override
  void dispose() {
    _classifier.close();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      await _classifier.initialize(); // loads the model the first time only
      final result = await _classifier.classifyImage(widget.imagePath);
      if (!mounted) return;
      setState(() => _result = result);
      // Not a pineapple: show the retake message and keep it out of History
      if (!result.isPineapple) return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not analyze the photo: $e');
      return;
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }

    await _saveScan(_result!);
  }

  // Camera and gallery files live in a cache folder the OS may clear, so the
  // photo is copied to the app documents folder before it goes in history.
  Future<String> _persistImage() async {
    final documents = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${documents.path}/scans');
    if (!await scansDir.exists()) {
      await scansDir.create(recursive: true);
    }
    final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final saved = await File(
      widget.imagePath,
    ).copy('${scansDir.path}/$fileName');
    return saved.path;
  }

  // Saves the finished scan to the local database so it shows in History.
  Future<void> _saveScan(ClassificationResult result) async {
    if (_saving) return;
    _saving = true;
    try {
      final imagePath = await _persistImage();
      final position = await LocationService.getCurrentLocation();
      final settings = AppSettings.instance;

      final record = ScanRecord(
        scanUuid: const Uuid().v4(),
        predictedLabel: result.best.label,
        confidence: result.best.confidence,
        secondLabel: result.second?.label,
        secondConfidence: result.second?.confidence,
        imageSource: widget.imageSource,
        imagePath: imagePath,
        latitude: position.latitude,
        longitude: position.longitude,
        scannedAt: DateTime.now(),
        municipality: _municipality,
        farmName: settings.farmName.isEmpty ? null : settings.farmName,
      );
      await DatabaseHelper.instance.insertScan(record);
      SyncController.instance.onLocalChange();
      if (mounted) setState(() => _savedScan = record);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save the scan: $e');
    } finally {
      _saving = false;
    }
  }

  // "Crown_Rot_Disease" -> "Crown Rot Disease"
  String _pretty(String label) => label.replaceAll('_', ' ');

  String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    // Light status bar icons, they sit on top of the photo
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: CameraColors.background,
      body: Column(
        children: [
          // Photo fills the space above the sheet
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(widget.imagePath), fit: BoxFit.cover),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircleAvatar(
                        backgroundColor: CameraColors.scrim,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildSheet(),
        ],
      ),
    );
  }

  Widget _buildSheet() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.colors.line),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_result != null && !_result!.isPineapple)
              ..._buildNotPineapple()
            else if (_result != null)
              ..._buildResult(_result!)
            else
              ..._buildBeforeAnalysis(),
          ],
        ),
      ),
    );
  }

  // Shown until the model has run
  List<Widget> _buildBeforeAnalysis() {
    return [
      const Text(
        'Photo Ready',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(
        'Source: ${widget.imageSource}',
        style: TextStyle(color: context.colors.textMuted),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: TextStyle(color: context.colors.danger)),
      ],
      const SizedBox(height: 20),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: _analyzing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.search),
        label: Text(_analyzing ? 'Analyzing...' : 'Analyze Photo'),
        onPressed: _analyzing ? null : _analyze,
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () => Navigator.pop(context),
        child: const Text('Retake'),
      ),
    ];
  }

  // Shown when the model says the photo is not a pineapple. Nothing is saved,
  // and the farmer goes back to take or pick a better photo.
  List<Widget> _buildNotPineapple() {
    final fromGallery = widget.imageSource == 'Gallery';
    return [
      Row(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: context.colors.danger,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "This doesn't look like a pineapple",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        fromGallery
            ? 'Pick a photo that clearly shows the pineapple fruit, crown or '
                  'leaves. This photo was not checked for disease or saved.'
            : 'Take a closer photo of the pineapple fruit, crown or leaves, in '
                  'good light. This photo was not checked for disease or saved.',
        style: TextStyle(color: context.colors.textMuted),
      ),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: Icon(
          fromGallery
              ? Icons.photo_library_outlined
              : Icons.camera_alt_outlined,
        ),
        label: Text(fromGallery ? 'Choose Another Photo' : 'Retake Photo'),
        // Camera: back to the live camera. Gallery: the scanner reopens the gallery.
        onPressed: () => Navigator.pop(
          context,
          fromGallery ? PhotoPreviewScreen.pickAnother : null,
        ),
      ),
    ];
  }

  // Shown after the model has run
  List<Widget> _buildResult(ClassificationResult result) {
    return [
      Text(
        _pretty(result.best.label),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(
        'Confidence: ${_percent(result.best.confidence)}',
        style: TextStyle(color: context.colors.textMuted),
      ),

      // Warning when the model is not sure
      if (result.isLowConfidence) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surface2,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: context.colors.danger),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: context.colors.danger),
              SizedBox(width: 8),
              Expanded(child: Text('Not sure, please retake the photo.')),
            ],
          ),
        ),
      ],

      const SizedBox(height: 16),
      Text('Top 3 guesses', style: TextStyle(color: context.colors.textMuted)),
      const SizedBox(height: 8),
      for (final p in result.topPredictions)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(_pretty(p.label))),
              Text(_percent(p.confidence)),
            ],
          ),
        ),

      const SizedBox(height: 12),
      if (_savedScan != null)
        Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: context.colors.success),
            SizedBox(width: 6),
            Text(
              'Saved to history',
              style: TextStyle(color: context.colors.success, fontSize: 13),
            ),
          ],
        )
      else if (_error != null)
        Text(_error!, style: TextStyle(color: context.colors.danger)),
      const SizedBox(height: 16),
      if (_savedScan != null) ...[
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.description_outlined),
          label: const Text('View Full Report'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultDetailScreen(scan: _savedScan!),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () => Navigator.pop(context),
        child: const Text('Scan Another'),
      ),
    ];
  }
}
