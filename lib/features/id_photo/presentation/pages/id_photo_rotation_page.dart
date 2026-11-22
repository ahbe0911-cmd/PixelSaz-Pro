import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/id_photo_providers.dart';

class IdPhotoRotationPage extends ConsumerStatefulWidget {
  const IdPhotoRotationPage({super.key, required this.sourcePath});

  final String sourcePath;

  @override
  ConsumerState<IdPhotoRotationPage> createState() => _IdPhotoRotationPageState();
}

class _IdPhotoRotationPageState extends ConsumerState<IdPhotoRotationPage> {
  double _angle = 0;
  int _quarterTurns = 0;
  bool _applying = false;

  Future<void> _applyRotation() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      final outputPath = await ref.read(idPhotoRotationServiceProvider).rotateFile(
            sourcePath: widget.sourcePath,
            angleDegrees: _angle + (_quarterTurns * 90),
          );
      if (!mounted) return;
      Navigator.of(context).pop<String>(outputPath);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('چرخش تصویر انجام نشد: $error')),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیم زاویه عکس')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: <Widget>[
              Text(
                'عکس عمودی باید عمودی بماند. در صورت نیاز از چرخش ۹۰ درجه یا تنظیم جزئی زاویه استفاده کنید.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: double.infinity,
                      color: theme.colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.all(12),
                      child: Transform.rotate(
                        angle: (_angle + _quarterTurns * 90) * math.pi / 180,
                        child: Image.file(
                          File(widget.sourcePath),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Text('پیش‌نمایش تصویر در دسترس نیست.'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _applying ? null : () => setState(() => _quarterTurns = (_quarterTurns + 3) % 4),
                    icon: const Icon(Icons.rotate_left_rounded),
                    label: const Text('چرخش ۹۰° چپ'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _applying ? null : () => setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
                    icon: const Icon(Icons.rotate_right_rounded),
                    label: const Text('چرخش ۹۰° راست'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  const Icon(Icons.rotate_left_rounded),
                  Expanded(
                    child: Slider(
                      value: _angle,
                      min: -10,
                      max: 10,
                      divisions: 200,
                      label: '${_angle.toStringAsFixed(1)}°',
                      onChanged: _applying ? null : (value) => setState(() => _angle = value),
                    ),
                  ),
                  const Icon(Icons.rotate_right_rounded),
                ],
              ),
              Row(
                children: <Widget>[
                  Text('زاویه: ${_angle.toStringAsFixed(1)}°',
                      style: theme.textTheme.labelLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _applying ? null : () => setState(() { _angle = 0; _quarterTurns = 0; }),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('بازنشانی'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _applying ? null : _applyRotation,
                  icon: _applying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.crop_rounded),
                  label: Text(_applying ? 'در حال اعمال چرخش...' : 'ادامه و تنظیم کادر ۳×۴'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
