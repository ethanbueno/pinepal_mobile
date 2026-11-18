import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/pinepal_loader.dart';
import '../widgets/scanner_controls.dart';
import 'photo_preview_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

// WidgetsBindingObserver lets us know when the app goes to the background,
// so we can release the camera and start it again when the user returns.
class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;

  int _cameraIndex = 0;
  bool _cameraReady = false;
  bool _busy = false; // true while taking a photo
  bool _torchOn = false; // the user wants the light on
  bool _shutterFlash = false; // white flash right after the shutter
  bool _permissionDenied = false;
  String? _error;

  final ImagePicker _picker = ImagePicker();

  // Only the back cameras have a light
  bool get _isBackCamera =>
      _cameras.isNotEmpty &&
      _cameras[_cameraIndex].lensDirection == CameraLensDirection.back;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null && _cameras.isNotEmpty) {
        _openCamera(_cameras[_cameraIndex]);
      }
    }
  }

  // Ask for permission, then find the cameras on the phone
  Future<void> _startCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _error = 'Camera permission is needed to scan.';
          _permissionDenied = true;
        });
        _showPermissionDialog();
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found on this device.');
        return;
      }
      // Start on the back camera; the order of the list is not guaranteed
      final back = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _cameraIndex = back == -1 ? 0 : back;
      await _openCamera(_cameras[_cameraIndex]);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start the camera: $e');
    }
  }

  Future<void> _openCamera(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      if (mounted) setState(() => _error = 'Camera error: ${e.description}');
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _cameraReady = true;
      _error = null;
      _permissionDenied = false;
    });
    // A new controller starts with the light off
    if (_torchOn) await _applyTorch(true);
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _controller = null;
      _cameraReady = false;
    });
    await controller.dispose();
  }

  // Switch between the back and front camera
  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _busy || !_cameraReady) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    if (_cameras[_cameraIndex].lensDirection != CameraLensDirection.back) {
      _torchOn = false;
    }
    await _stopCamera();
    await _openCamera(_cameras[_cameraIndex]);
  }

  // The light stays on while scanning, which helps in the shade or at dusk
  Future<void> _toggleTorch() async {
    setState(() => _torchOn = !_torchOn);
    await _applyTorch(_torchOn);
  }

  Future<void> _applyTorch(bool on) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!_isBackCamera) return;

    try {
      await controller.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    } on CameraException {
      if (on && mounted) {
        setState(() => _torchOn = false);
        _showMessage('This camera has no light.');
      }
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _shutterFlash = true;
    });
    // The flash is only a blink, then it fades out
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) setState(() => _shutterFlash = false);
    });

    try {
      final photo = await controller.takePicture();
      await _showPreview(photo.path, 'Camera');
    } on CameraException catch (e) {
      _showMessage('Could not take the photo: ${e.description}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    try {
      // Phone photos can be 12-50 megapixels, which are slow to decode and
      // heavy to keep. The model only looks at 224 x 224, so Android shrinks
      // the photo to at most 1024 px while picking it (fast, native code).
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 92,
      );
      if (picked != null) {
        final result = await _showPreview(picked.path, 'Gallery');
        // The photo wasn't a pineapple: open the gallery again right away
        if (result == PhotoPreviewScreen.pickAnother && mounted) {
          await _pickFromGallery();
        }
      }
    } catch (e) {
      _showMessage('Could not open the gallery: $e');
    }
  }

  Future<Object?> _showPreview(String path, String source) {
    return _openPage(PhotoPreviewScreen(imagePath: path, imageSource: source));
  }

  // Opens another screen on top of the camera. The light is switched off while
  // it is open, so it does not stay on behind a photo or the history list.
  // Returns what the page sent back when it closed, if anything.
  Future<Object?> _openPage(Widget page) async {
    if (!mounted) return null;
    if (_torchOn) await _applyTorch(false);
    if (!mounted) return null;
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (mounted && _torchOn) await _applyTorch(true);
    return result;
  }

  // Pop-up explaining why the camera is needed, with a shortcut to Settings
  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'PinePal needs camera access to inspect pineapple fruits for '
          'diseases. Please grant permission in App Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    // The camera screen is always dark, whatever theme the app uses
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyleFor(
        Brightness.dark,
        background: CameraColors.background,
      ),
      child: Theme(
        data: buildTheme(Brightness.dark),
        child: Scaffold(
          backgroundColor: CameraColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildPreview()),
                _buildControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Back, title, light and flip camera
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          GlassButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Scan Pineapple',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GlassButton(
            icon: _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
            tooltip: _torchOn ? 'Turn Light Off' : 'Turn Light On',
            active: _torchOn,
            onPressed: _cameraReady && _isBackCamera ? _toggleTorch : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildError(),
        ),
      );
    }

    final controller = _controller;
    if (!_cameraReady || controller == null) return _buildStarting();

    return Stack(
      fit: StackFit.expand,
      children: [
        // The picture fills the whole area, everything else lies on top of it
        CoverCameraPreview(controller: controller),
        ViewfinderFrame(tight: _busy),
        const Positioned(
          top: 14,
          left: 12,
          right: 12,
          child: Center(
            child: ScannerHint(text: 'Fit the whole fruit in the frame'),
          ),
        ),
        // Blink when the shutter is pressed
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _shutterFlash ? 0.6 : 0,
            duration: Duration(milliseconds: _shutterFlash ? 30 : 250),
            child: const ColoredBox(color: CameraColors.foreground),
          ),
        ),
      ],
    );
  }

  Widget _buildStarting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PinePalLoader(
            label: 'Starting camera...',
            trackColor: AppPalette.dark.line,
            labelColor: AppPalette.dark.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final p = AppPalette.dark;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: p.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: p.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.no_photography_outlined,
                size: 32,
                color: p.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            if (_permissionDenied)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: openAppSettings,
                  child: const Text('Open Settings'),
                ),
              ),
            TextButton(
              onPressed: () {
                setState(() => _error = null);
                _startCamera();
              },
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 4),
            Text(
              'You can still upload a photo from the gallery.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // Gallery and flip camera on the sides, the shutter exactly in the middle
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: GlassAction(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onPressed: _pickFromGallery,
              ),
            ),
          ),
          ShutterButton(
            onPressed: _cameraReady ? _takePhoto : null,
            busy: _busy,
          ),
          Expanded(
            child: Center(
              // empty with a single camera, so the shutter stays centred
              child: _cameras.length > 1
                  ? GlassAction(
                      icon: Icons.cameraswitch_outlined,
                      label: 'Flip',
                      onPressed: _cameraReady && !_busy ? _flipCamera : null,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
