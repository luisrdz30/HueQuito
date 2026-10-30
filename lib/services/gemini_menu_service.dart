import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:firebase_ai/firebase_ai.dart';

/// Excepción que se mantiene por compatibilidad con MenuOcrService.
/// Con Firebase AI Logic ya no hay API Key en la app, así que no se lanza.
class GeminiApiKeyMissingException implements Exception {
  final String message;
  GeminiApiKeyMissingException([this.message = 'Gemini no está disponible.']);

  @override
  String toString() => message;
}

/// Servicio de Digitalización de Cartas Gastronómicas con Google Gemini Vision.
///
/// Usa Firebase AI Logic (paquete firebase_ai): la llamada a Gemini pasa por
/// Firebase, por lo que NO hay ninguna API Key de Gemini dentro de la app
/// (ni en el APK ni en el código JavaScript de la versión web).
class GeminiMenuService {
  // Modelos ordenados por prioridad y disponibilidad
  static const List<String> _modelsToTry = [
    'gemini-3.5-flash',
    'gemini-3.6-flash',
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash',
  ];

  /// Gemini siempre está disponible a través de Firebase (no requiere clave local).
  static Future<bool> hasApiKey() async => true;

  /// Detecta el tipo MIME adecuado según la extensión de la imagen
  static String _detectMimeType(String path, [Uint8List? bytes]) {
    // En web la ruta es un blob: sin extensión, así que se revisa la cabecera del archivo
    if (bytes != null && bytes.length >= 12) {
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
          bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
        return 'image/webp';
      }
    }
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  /// Prompt especializado para gastronomía ecuatoriana y extracción estructurada de cartas
  static const String _systemPrompt = '''
Eres un experto gastronómico ecuatoriano y asistente de digitalización de cartas de huecas y restaurantes en Quito, Ecuador.
Analiza la fotografía de esta página de menú o carta física.
Extrae minuciosamente todos los platos, comidas, bebidas y combos que aparezcan.

Para cada comida encontrada, genera un objeto con:
- "name_es": Nombre exacto del plato en español (en Formato Título, corrigiendo faltas ortográficas o tipográficas evidentes).
- "name_en": Traducción precisa y apetitosa al inglés para turistas comensales (ej: "Seco de Chivo" -> "Ecuadorian Goat Stew", "Locro de Papa" -> "Traditional Potato & Cheese Soup", "Fritada" -> "Crispy Braised Pork with Hominy").
- "description_es": Descripción de acompañamientos o ingredientes si aparecen en la carta (o una breve descripción tradicional ecuatoriana).
- "description_en": Traducción al inglés de la descripción.
- "price": Precio en dólares como número decimal positivo (ej: 4.50, 3.00, 12.50). Si no tiene precio visible o es según el peso, pon 0.0.
- "category": Clasifica el plato en EXACTAMENTE una de las siguientes categorías oficiales:
  * "Platos Fuertes"
  * "Platos Típicos"
  * "Sopas y Caldos"
  * "Entradas y Guarniciones"
  * "Bebidas"
  * "Postres"
  * "Especialidades"
  * "Otros"

IMPORTANTE: Responde ÚNICAMENTE en formato JSON con la siguiente estructura exacta:
{
  "dishes": [
    {
      "name_es": "Nombre en español",
      "name_en": "Name in english",
      "description_es": "Descripción",
      "description_en": "Description",
      "price": 4.50,
      "category": "Platos Típicos"
    }
  ]
}
''';

  /// Extrae todos los platos de una sola página de la carta usando Gemini 1.5 Flash
  static Future<List<Map<String, dynamic>>> extractDishesFromImage(String imagePath) async {
    // XFile funciona igual en Android/iOS (ruta local) y en web (blob del navegador)
    final Uint8List bytes;
    try {
      bytes = await XFile(imagePath).readAsBytes();
    } catch (_) {
      throw Exception('El archivo de imagen no existe en la ruta: $imagePath');
    }
    final mimeType = _detectMimeType(imagePath, bytes);

    final content = [
      Content.multi([
        TextPart(_systemPrompt),
        InlineDataPart(mimeType, bytes),
      ]),
    ];

    GenerateContentResponse? response;
    dynamic lastError;

    for (final modelName in _modelsToTry) {
      try {
        final model = FirebaseAI.googleAI().generativeModel(
          model: modelName,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.1,
          ),
        );

        final res = await model.generateContent(content);
        if (res.text != null && res.text!.trim().isNotEmpty) {
          debugPrint('[GEMINI_MENU] Respuesta exitosa con modelo: $modelName');
          response = res;
          break;
        }
      } catch (err) {
        lastError = err;
        debugPrint('[GEMINI_MENU] Modelo $modelName falló ($err), intentando siguiente...');
      }
    }

    if (response == null || response.text == null || response.text!.trim().isEmpty) {
      if (lastError != null) throw lastError;
      return [];
    }

    final responseText = response.text!;

    try {
      final decoded = jsonDecode(responseText);
      final List<dynamic> dishesJson = (decoded is Map && decoded['dishes'] is List)
          ? decoded['dishes']
          : (decoded is List ? decoded : []);

      final List<Map<String, dynamic>> result = [];
      for (int i = 0; i < dishesJson.length; i++) {
        final item = dishesJson[i];
        if (item is! Map) continue;

        final nameEs = item['name_es']?.toString().trim() ?? '';
        if (nameEs.isEmpty) continue;

        final nameEn = item['name_en']?.toString().trim() ?? nameEs;
        final descEs = item['description_es']?.toString().trim() ?? '';
        final descEn = item['description_en']?.toString().trim() ?? descEs;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final category = item['category']?.toString().trim() ?? 'Platos Fuertes';

        result.add({
          'id': 'dish_${DateTime.now().millisecondsSinceEpoch}_$i',
          'name': {'es': nameEs, 'en': nameEn},
          'description': {'es': descEs, 'en': descEn},
          'price': price,
          'category': category,
          'imageUrl': '',
          'image': '',
          'isAvailable': true,
          '_localImagePath': '',
        });
      }

      return result;
    } catch (e) {
      debugPrint('[GEMINI_MENU_ERROR] Error al parsear JSON de Gemini: $e\nRespuesta cruda: $responseText');
      throw Exception('Error al interpretar la respuesta de la IA: $e');
    }
  }

  /// Procesa múltiples imágenes de páginas de carta (hasta 10 fotos) de forma secuencial
  static Future<List<Map<String, dynamic>>> extractDishesFromMultipleImages(
    List<String> imagePaths, {
    void Function(int current, int total)? onProgress,
  }) async {
    final List<Map<String, dynamic>> allDishes = [];

    for (int i = 0; i < imagePaths.length; i++) {
      if (onProgress != null) {
        onProgress(i + 1, imagePaths.length);
      }

      final dishes = await extractDishesFromImage(imagePaths[i]);
      for (final dish in dishes) {
        // Asegurar ID único
        dish['id'] = 'dish_${DateTime.now().millisecondsSinceEpoch}_${allDishes.length}';
        allDishes.add(dish);
      }
    }

    return allDishes;
  }
}
