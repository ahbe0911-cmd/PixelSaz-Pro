import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

class IdPhotoCameraPage extends StatefulWidget {
  const IdPhotoCameraPage({super.key});

  @override
  State<IdPhotoCameraPage> createState() => _IdPhotoCameraPageState();
}

class _IdPhotoCameraPageState extends State<IdPhotoCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = <CameraDescription>[];
  CameraLensDirection _lensDirection = CameraLensDirection.back;
  bool _initializing = true;
  bool _capturing = false;
  bool _flashEnabled = false;
  String? _errorMessage;
  double _zoom = 1;
  double _minimumZoom = 1;
  double _maximumZoom = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller = null;
      if (controller != null) unawaited(controller.dispose());
    } else if (state == AppLifecycleState.resumed && _cameras.isNotEmpty) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    if (_initializing && _controller != null) return;
    if (mounted) {
      setState(() {
        _initializing = true;
        _errorMessage = null;
      });
    }

    CameraController? nextController;
    try {
      final cameras = await availableCameras();
      _cameras = cameras;
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'هیچ دوربینی روی دستگاه پیدا نشد.');
      }

      final matchingCameras = cameras
          .where((camera) => camera.lensDirection == _lensDirection)
          .toList(growable: false);
      final selected = matchingCameras.isNotEmpty ? matchingCameras.first : cameras.first;
      _lensDirection = selected.lensDirection;

      nextController = CameraController(
        selected,
        ResolutionPreset.max,
        enableAudio: false,
      );
      await nextController.initialize();
      await nextController.lockCaptureOrientation(DeviceOrientation.portraitUp);
      final minZoom = await nextController.getMinZoomLevel();
      final maxZoom = await nextController.getMaxZoomLevel();
      await nextController.setFlashMode(FlashMode.off);

      if (!mounted) {
        await nextController.dispose();
        return;
      }

      final previous = _controller;
      _controller = nextController;
      nextController = null;
      _minimumZoom = minZoom;
      _maximumZoom = maxZoom;
      _zoom = minZoom;
      _flashEnabled = false;
      setState(() => _initializing = false);
      if (previous != null) await previous.dispose();
    } catch (error) {
      if (nextController != null) await nextController.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = _cameraError(error);
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_capturing || _initializing) return;
    final nextDirection = _lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    if (!_cameras.any((camera) => camera.lensDirection == nextDirection)) {
      _showMessage('دوربین دیگری روی دستگاه موجود نیست.');
      return;
    }
    final previous = _controller;
    _controller = null;
    if (mounted) setState(() => _initializing = true);
    if (previous != null) await previous.dispose();
    _lensDirection = nextDirection;
    await _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final nextEnabled = !_flashEnabled;
    try {
      await controller.setFlashMode(nextEnabled ? FlashMode.always : FlashMode.off);
      if (mounted) setState(() => _flashEnabled = nextEnabled);
    } catch (_) {
      _showMessage('فلاش در این دوربین پشتیبانی نمی‌شود.');
    }
  }

  Future<void> _setZoom(double value) async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _zoom = value);
    try {
      await controller.setZoomLevel(value);
    } catch (_) {
      // Some devices expose a zoom range that changes after camera startup.
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop<String>(file.path);
    } catch (error) {
      if (mounted) _showMessage('ثبت عکس انجام نشد: ${_cameraError(error)}');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  String _cameraError(Object error) {
    if (error is CameraException) {
      if (error.code == 'CameraAccessDenied' ||
          error.code == 'CameraAccessDeniedWithoutPrompt' ||
          error.code == 'cameraPermission') {
        return 'دسترسی دوربین داده نشده است. از تنظیمات دستگاه مجوز دوربین را فعال کنید.';
      }
      if (error.code == 'CameraAccessRestricted') {
        return 'دسترسی دوربین در این دستگاه محدود شده است.';
      }
      return error.description ?? error.code;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message, textDirection: TextDirection.rtl)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;
    final cameraReady = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: const Color(0xFF090D18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D18),
        foregroundColor: Colors.white,
        title: const Text('دوربین عکس پرسنلی'),
        actions: <Widget>[
          IconButton(
            tooltip: 'فلاش',
            onPressed: cameraReady ? _toggleFlash : null,
            icon: Icon(_flashEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded),
          ),
          IconButton(
            tooltip: 'تعویض دوربین',
            onPressed: cameraReady ? _switchCamera : null,
            icon: const Icon(Icons.flip_camera_android_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          if (cameraReady)
                            CameraPreview(controller!)
                          else
                            Container(
                              color: const Color(0xFF151D2D),
                              alignment: Alignment.center,
                              child: _initializing
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        _errorMessage ?? 'دوربین آماده نیست.',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                                      ),
                                    ),
                            ),
                          if (cameraReady)
                            const IgnorePointer(
                              child: CustomPaint(painter: _FaceShoulderOverlayPainter()),
                            ),
                          if (_capturing)
                            Container(
                              color: Colors.black45,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
              child: Column(
                children: <Widget>[
                  const Text(
                    'صورت را داخل بیضی و شانه‌ها را روی خطوط راهنما قرار دهید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (cameraReady && _maximumZoom > _minimumZoom + 0.05) ...<Widget>[
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 18),
                        Expanded(
                          child: Slider(
                            value: _zoom.clamp(_minimumZoom, _maximumZoom),
                            min: _minimumZoom,
                            max: _maximumZoom,
                            onChanged: _setZoom,
                          ),
                        ),
                        const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 18),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            minimumSize: const Size.fromHeight(54),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('بازگشت'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: cameraReady && !_capturing ? _capture : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.oceanBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(54),
                          ),
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('ثبت عکس'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceShoulderOverlayPainter extends CustomPainter {
  const _FaceShoulderOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = Colors.white.withAlpha(220)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final faceRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.32),
      width: size.width * 0.38,
      height: size.height * 0.36,
    );
    canvas.drawOval(faceRect, guidePaint);

    final shoulders = Path()
      ..moveTo(size.width * 0.50, size.height * 0.53)
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.58,
        size.width * 0.36,
        size.height * 0.60,
        size.width * 0.27,
        size.height * 0.62,
      )
      ..cubicTo(
        size.width * 0.15,
        size.height * 0.66,
        size.width * 0.12,
        size.height * 0.77,
        size.width * 0.10,
        size.height * 0.91,
      )
      ..moveTo(size.width * 0.50, size.height * 0.53)
      ..cubicTo(
        size.width * 0.58,
        size.height * 0.58,
        size.width * 0.64,
        size.height * 0.60,
        size.width * 0.73,
        size.height * 0.62,
      )
      ..cubicTo(
        size.width * 0.85,
        size.height * 0.66,
        size.width * 0.88,
        size.height * 0.77,
        size.width * 0.90,
        size.height * 0.91,
      );
    canvas.drawPath(shoulders, guidePaint);

    final centerPaint = Paint()
      ..color = Colors.white.withAlpha(150)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.49),
      Offset(size.width * 0.88, size.height * 0.49),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceShoulderOverlayPainter oldDelegate) => false;
}
