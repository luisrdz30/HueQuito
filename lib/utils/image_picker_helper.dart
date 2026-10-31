import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
    if (kIsWeb) return;
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
  static Future<XFile?> showImageSourceDialog({
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

              // Web (PC o navegador del celular): explorador de archivos / galería
              if (kIsWeb)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_open_outlined, color: AppTheme.primary, size: 22),
                  ),
                  title: Text(
                    isEn ? 'Choose a file' : 'Elegir un archivo',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    isEn ? 'Open your files or photo gallery' : 'Abre tus archivos o la galería de fotos',
                    style: TextStyle(fontSize: 11, color: subtextColor),
                  ),
                  onTap: () => Navigator.pop(ctx, PhotoSourceChoice.deviceGallery),
                ),

              // 1. Galería del Dispositivo (Galería local)
              if (!kIsWeb)
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
              if (!kIsWeb)
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

              // 3. Tomar foto con la cámara (en web solo se muestra en el navegador del celular)
              if (!kIsWeb || _isMobileBrowser)
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
        return picked;
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }

    return null;
  }

  /// true cuando la app web se abre desde el navegador de un celular/tablet.
  static bool get _isMobileBrowser =>
      kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Deduce el tipo MIME de la imagen (requerido por las reglas de Storage).
  static String contentTypeFor(XFile file) {
    final mime = file.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    final name = (file.name.isNotEmpty ? file.name : file.path).toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  /// Sube una imagen elegida a Firebase Storage.
  /// Android/iOS: igual que antes (putFile). Web: sube los bytes (putData).
  static Future<TaskSnapshot> uploadXFile(Reference ref, XFile file) async {
    final metadata = SettableMetadata(contentType: contentTypeFor(file));
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      return await ref.putData(bytes, metadata);
    }
    return await ref.putFile(File(file.path), metadata);
  }

  /// Igual que [uploadXFile] pero a partir de la ruta guardada de la imagen.
  static Future<TaskSnapshot> uploadPath(Reference ref, String path) {
    return uploadXFile(ref, XFile(path));
  }

  /// Vista previa de una imagen local en cualquier plataforma.
  static Widget previewPath(
    String path, {
    BoxFit? fit,
    double? width,
    double? height,
    ImageErrorWidgetBuilder? errorBuilder,
  }) {
    if (kIsWeb) {
      return Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, path, fit: fit, width: width, height: height, errorBuilder: errorBuilder);
    }
    return Image.file(File(path), fit: fit, width: width, height: height, errorBuilder: errorBuilder);
  }

  /// Vista previa de una imagen elegida ([XFile]) en cualquier plataforma.
  static Widget preview(
    XFile file, {
    BoxFit? fit,
    double? width,
    double? height,
    ImageErrorWidgetBuilder? errorBuilder,
  }) {
    return previewPath(file.path, fit: fit, width: width, height: height, errorBuilder: errorBuilder);
  }

  /// ImageProvider para usar en CircleAvatar/DecorationImage.
  static ImageProvider providerFor(XFile file) {
    if (kIsWeb) return NetworkImage(file.path);
    return FileImage(File(file.path));
  }
}
