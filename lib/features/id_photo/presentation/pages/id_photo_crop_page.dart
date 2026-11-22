import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/theme/app_colors.dart';

class IdPhotoCropPage extends StatefulWidget {
  const IdPhotoCropPage({super.key, required this.sourcePath});

  final String sourcePath;

  @override
  State<IdPhotoCropPage> createState() => _IdPhotoCropPageState();
}

class _IdPhotoCropPageState extends State<IdPhotoCropPage> {
  bool _openingCropper = false;

  Future<void> _openNativeCropper() async {
    if (_openingCropper) return;
    setState(() => _openingCropper = true);
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: widget.sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 4),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 100,
        uiSettings: <PlatformUiSettings>[
          AndroidUiSettings(
            toolbarTitle: 'برش استاندارد عکس ۳×۴',
            toolbarColor: AppColors.oceanBlue,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.oceanBlue,
            cropFrameColor: AppColors.oceanBlue,
            cropGridColor: Colors.white70,
            showCropGrid: true,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'برش استاندارد عکس ۳×۴',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
            rotateButtonsHidden: true,
          ),
        ],
      );
      if (!mounted) return;
      if (cropped == null) {
        setState(() => _openingCropper = false);
        return;
      }
      Navigator.of(context).pop<String>(cropped.path);
    } catch (error) {
      if (!mounted) return;
      setState(() => _openingCropper = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('بازکردن ابزار برش ناموفق بود: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('کادربندی عکس پرسنلی')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(110),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('نسبت تصویر قفل‌شده: ۳ به ۴',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text(
                      'در صفحه برش، تصویر را جابه‌جا یا بزرگ‌نمایی کنید تا سر و شانه‌ها در کادر مناسب قرار بگیرند.',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(height: 1.7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.file(File(widget.sourcePath), fit: BoxFit.cover),
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.oceanBlue, width: 2),
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openingCropper ? null : _openNativeCropper,
                  icon: _openingCropper
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.crop_free_rounded),
                  label: Text(_openingCropper ? 'در حال آماده‌سازی...' : 'تنظیم دقیق کادر برش'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
