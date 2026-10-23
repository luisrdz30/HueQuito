import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:hue_quito/theme/theme.dart';

enum PhotoSourceChoice {
  camera,
  deviceGallery,
  googlePhotos,
  remove,
}

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Configura dinámicamente si se usa el selector de Google Fotos (Photo Picker)
  /// o la galería local del dispositivo (Android Intent Chooser).
  static void configureAndroidPicker({required bool usePhotoPicker}) {
    final implementation = ImagePickerPlatform.instance;
    if (implementation is ImagePickerAndroid) {
      implementation.useAndroidPhotoPicker = usePhotoPicker;
    }
  }

  /// Muestra un modal elegante que permite al usuario elegir explícitamente entre:
  /// 1. Tomar foto con la cámara
  /// 2. Galería del dispositivo (Galería local de Samsung/Android)
  /// 3. Google Fotos / Selector del sistema
  /// 4. Quitar foto (opcional)
  static Future<File?> showImageSourceDialog({
    required BuildContext context,
    String? title,
    String? subtitle,
    String? lang,
    bool includeRemove = false,
    VoidCallback? onRemove,
    int imageQuality = 80,
    double? maxWidth,
    double? maxHeight,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final subtextColor = isDark ? Colors.grey[400] : AppTheme.textMedium;
    final isEn = lang == 'en';

    final resolvedTitle = title ?? (isEn ? 'Select Photo' : 'Seleccionar foto');
    final resolvedSubtitle = subtitle ?? (isEn ? 'Where would you like to choose the image from?' : '¿Desde dónde prefieres elegir la imagen?');

    final choice = await showModalBottomSheet<PhotoSourceChoice>(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                resolvedTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                resolvedSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: subtextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // 1. Galería del Dispositivo (Galería local)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppTheme.primary, size: 22),
                ),
                title: Text(
                  isEn ? 'Device Gallery' : 'Galería del dispositivo',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14),
                ),
                subtitle: Text(
                  isEn ? 'Open your phone local gallery and albums' : 'Abre la galería local y álbumes de tu teléfono',
                  style: TextStyle(fontSize: 11, color: subtextColor),
                ),
                onTap: () => Navigator.pop(ctx, PhotoSourceChoice.deviceGallery),
              ),

              // 2. Google Fotos / Selector del Sistema
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_outlined, color: Colors.blue, size: 22),
                ),
                title: Text(
                  isEn ? 'Google Photos / System Picker' : 'Google Fotos / Selector del sistema',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14),
                ),
                subtitle: Text(
                  isEn ? 'Select from cloud or recent Google Photos' : 'Selecciona desde la nube o fotos recientes de Google',
                  style: TextStyle(fontSize: 11, color: subtextColor),
                ),
                onTap: () => Navigator.pop(ctx, PhotoSourceChoice.googlePhotos),
              ),

              // 3. Tomar foto con la cámara
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Colors.green, size: 22),
                ),
                title: Text(
                  isEn ? 'Take photo with camera' : 'Tomar foto con la cámara',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14),
                ),
                subtitle: Text(
                  isEn ? 'Capture an image right away' : 'Captura una imagen al instante',
                  style: TextStyle(fontSize: 11, color: subtextColor),
                ),
                onTap: () => Navigator.pop(ctx, PhotoSourceChoice.camera),
              ),

              // 4. Quitar foto si aplica
              if (includeRemove)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                  ),
                  title: Text(
                    isEn ? 'Remove current photo' : 'Quitar foto actual',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent, fontSize: 14),
                  ),
                  onTap: () => Navigator.pop(ctx, PhotoSourceChoice.remove),
                ),
            ],
          ),
        ),
      ),
    );

    if (choice == null) return null;

    if (choice == PhotoSourceChoice.remove) {
      onRemove?.call();
      return null;
    }

    try {
      XFile? picked;
      if (choice == PhotoSourceChoice.camera) {
        picked = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: imageQuality,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      } else if (choice == PhotoSourceChoice.deviceGallery) {
        // useAndroidPhotoPicker = false para abrir Galería local / Intent Chooser
        configureAndroidPicker(usePhotoPicker: false);
        picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: imageQuality,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      } else if (choice == PhotoSourceChoice.googlePhotos) {
        // useAndroidPhotoPicker = true para abrir el selector de Google Fotos
        configureAndroidPicker(usePhotoPicker: true);
        picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: imageQuality,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      }

      if (picked != null) {
        return File(picked.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }

    return null;
  }
}
