import 'dart:math' as math;
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hue_quito/services/translation_service.dart';

class MenuOcrResult {
  final List<Map<String, dynamic>> dishes;
  final String rawText;

  MenuOcrResult({required this.dishes, required this.rawText});
}

class _PriceInfo {
  final double value;
  final String rawMatch;
  final int startIndex;
  final int endIndex;

  _PriceInfo({
    required this.value,
    required this.rawMatch,
    required this.startIndex,
    required this.endIndex,
  });
}

class _ParsedPriceToken {
  final double value;
  final String label;

  _ParsedPriceToken({
    required this.value,
    required this.label,
  });
}

class _SpatialLine {
  final String text;
  final Rect rect;

  _SpatialLine({required this.text, required this.rect});

  double get centerY => (rect.top + rect.bottom) / 2;
  double get height => rect.height;
}

class MenuOcrService {
  /// Procesa una imagen física de la carta usando ML Kit y devuelve los platos extraídos
  static Future<MenuOcrResult> extractDishesFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text;

      final List<Map<String, dynamic>> parsedDishes = await _parseRecognizedTextToDishes(recognizedText);
      print('[OCR_DEBUG] ML Kit blocks: ${recognizedText.blocks.length}, rawText chars: ${rawText.length}');
      print('[OCR_DEBUG] Dishes detected (${parsedDishes.length}): ${parsedDishes.map((d) => d['name']['es']).toList()}');

      return MenuOcrResult(dishes: parsedDishes, rawText: rawText);
    } catch (e) {
      print('Error en MenuOcrService: $e');
      return MenuOcrResult(dishes: [], rawText: '');
    } finally {
      await textRecognizer.close();
    }
  }

  /// Procesa RecognizedText adaptándose tanto a cartas con precios, matrices de precios y afiches promocionales
  static Future<List<Map<String, dynamic>>> _parseRecognizedTextToDishes(RecognizedText recognized) async {
    final List<_SpatialLine> spatialLines = [];
    String detectedCategory = 'Platos Fuertes';

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final clean = _stripEmojisAndSymbols(line.text);
        if (clean.isEmpty || _isNoiseOrMetadataLine(clean)) continue;

        // Banners verticales (ej: "SMASHED BURGERS" lateral en el margen)
        if (line.boundingBox.height > line.boundingBox.width * 1.8) {
          if (_isCategoryHeader(clean)) {
            detectedCategory = _mapCategoryFromHeader(clean);
          }
          continue;
        }

        spatialLines.add(_SpatialLine(text: clean, rect: line.boundingBox));
      }
    }

    if (spatialLines.isEmpty) {
      return parseRawTextToDishes(recognized.text);
    }

    final List<String> orderedLines = _orderSpatialLines(spatialLines);
    return _extractDishesFromLines(orderedLines, defaultCategory: detectedCategory);
  }

  /// Método público para procesar texto plano directamente (ej. desde el modal de revisión de texto)
  static Future<List<Map<String, dynamic>>> parseRawTextToDishes(String rawText) async {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map(_stripEmojisAndSymbols)
        .where((l) => l.isNotEmpty && !_isNoiseOrMetadataLine(l))
        .toList();
    return _extractDishesFromLines(lines);
  }

  /// Motor principal público para procesar listas de renglones
  static Future<List<Map<String, dynamic>>> parseRawLinesToDishes(List<String> rawLines) async {
    return _extractDishesFromLines(rawLines);
  }

  /// Extrae platos a partir de una secuencia de renglones
  /// Admite tanto platos con precio ($X.XX) como platos sin precio (ej. afiches o flyers gastronómicos)
  static Future<List<Map<String, dynamic>>> _extractDishesFromLines(
    List<String> rawLines, {
    String defaultCategory = 'Platos Fuertes',
  }) async {
    final List<Map<String, dynamic>> dishes = [];
    String currentCategory = defaultCategory;

    final lines = rawLines
        .map(_stripEmojisAndSymbols)
        .where((l) => l.isNotEmpty && !_isNoiseOrMetadataLine(l))
        .toList();

    Map<String, dynamic>? currentDish;
    List<String> pendingVariantLabels = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 1. Detectar encabezados de categoría (ej: "BANDEJAS", "BEBIDAS", "SMASHED BURGERS")
      if (_isCategoryHeader(line)) {
        currentCategory = _mapCategoryFromHeader(line);
        continue;
      }

      // 2. Línea compuesta exclusivamente por palabras de variantes sin precio (ej: "SENCILLA COMBO DOBLE COMBO")
      if (_isPureVariantOrSize(line)) {
        final priceTokens = _extractAllPriceTokens(line);
        if (priceTokens.isEmpty) {
          pendingVariantLabels = line
              .split(RegExp(r'[/,\-\|\s]+'))
              .where((w) => w.isNotEmpty && !_isNoiseOrMetadataLine(w))
              .map(_toTitleCase)
              .toList();
          continue;
        }
      }

      // 3. Extracción de precios y variantes en la línea
      final priceTokens = _extractAllPriceTokens(line);

      if (priceTokens.isNotEmpty) {
        // ¿Es una matriz de variantes / modificadores o un precio solitario para el plato en curso?
        final bool isVariantMatrix = priceTokens.length > 1 ||
            priceTokens.first.label.isEmpty ||
            _isPureVariantOrSize(priceTokens.first.label) ||
            pendingVariantLabels.isNotEmpty;

        if (isVariantMatrix) {
          final List<String> formattedOptions = [];
          double minPrice = double.infinity;

          for (int tIdx = 0; tIdx < priceTokens.length; tIdx++) {
            final t = priceTokens[tIdx];
            if (t.value < minPrice) minPrice = t.value;

            String label = t.label;
            if (label.isEmpty && tIdx < pendingVariantLabels.length) {
              label = pendingVariantLabels[tIdx];
            }

            if (label.isNotEmpty) {
              formattedOptions.add('${_toTitleCase(label)}: \$${t.value.toStringAsFixed(2)}');
            } else {
              formattedOptions.add('\$${t.value.toStringAsFixed(2)}');
            }
          }
          pendingVariantLabels.clear();

          if (currentDish != null) {
            final currentPrice = (currentDish['price'] as double);
            if (currentPrice == 0.0 || (minPrice > 0 && minPrice < currentPrice)) {
              currentDish['price'] = minPrice;
            }

            if (formattedOptions.isNotEmpty) {
              final optionsStr = formattedOptions.join(' | ');
              final existingDesc = currentDish['description']['es'] as String;
              currentDish['description']['es'] = existingDesc.isNotEmpty
                  ? '$existingDesc. $optionsStr'
                  : optionsStr;
            }
          }
          continue;
        } else {
          // Es un plato con precio explícito (ej: "SUPER BANDEJA $39", "Seco de Chivo $4.50")
          final cleanName = priceTokens.first.label;

          if (_isValidDishName(cleanName)) {
            if (currentDish != null) {
              dishes.add(currentDish);
              currentDish = null;
            }

            final formattedName = _toTitleCase(cleanName);
            final translatedName = await TranslationService.translateEsToEn(formattedName);

            currentDish = {
              'id': 'dish_${DateTime.now().millisecondsSinceEpoch}_${dishes.length}',
              'name': {
                'es': formattedName,
                'en': translatedName.isNotEmpty && translatedName != formattedName ? translatedName : formattedName,
              },
              'description': {'es': '', 'en': ''},
              'price': priceTokens.first.value,
              'category': currentCategory != 'Platos Fuertes' ? currentCategory : _guessCategory(formattedName),
              'imageUrl': '',
              'isAvailable': true,
            };
            continue;
          } else if (currentDish != null) {
            currentDish['price'] = priceTokens.first.value;
            continue;
          }
        }
      }

      // 4. Línea de título de plato (con o sin precio en la imagen) o continuación de título en 2 renglones
      final existingTitle = currentDish != null ? (currentDish['name']['es'] as String) : '';
      final currentHasDesc = currentDish != null && (currentDish['description']['es'] as String).isNotEmpty;
      final currentHasPrice = currentDish != null && (currentDish['price'] as double) > 0.0;
      final isContinuation = currentDish != null &&
          !currentHasDesc &&
          !currentHasPrice &&
          _shouldContinueTitle(existingTitle, line);

      if (_isTitleLine(line) || isContinuation) {
        // Si el plato anterior ya tenía descripción o precio, o NO es una continuación válida, se finaliza
        if (currentDish != null && !isContinuation) {
          dishes.add(currentDish);
          currentDish = null;
        }

        if (currentDish == null) {
          final formattedName = _toTitleCase(_cleanDishName(line));
          final translatedName = await TranslationService.translateEsToEn(formattedName);

          currentDish = {
            'id': 'dish_${DateTime.now().millisecondsSinceEpoch}_${dishes.length}',
            'name': {
              'es': formattedName,
              'en': translatedName.isNotEmpty && translatedName != formattedName ? translatedName : formattedName,
            },
            'description': {'es': '', 'en': ''},
            'price': 0.0,
            'category': currentCategory != 'Platos Fuertes' ? currentCategory : _guessCategory(formattedName),
            'imageUrl': '',
            'isAvailable': true,
          };
        } else {
          // Concatenar como título en 2 renglones (ej: "SUPER" + "BANDEJA")
          final existingName = currentDish['name']['es'] as String;
          final joinedName = _toTitleCase('$existingName ${_cleanDishName(line)}');
          currentDish['name']['es'] = joinedName;
          final trans = await TranslationService.translateEsToEn(joinedName);
          currentDish['name']['en'] = trans.isNotEmpty ? trans : joinedName;
        }
        continue;
      }

      // 5. Es una descripción, lista de ingredientes, gramaje o porción
      if (currentDish != null) {
        final cleanDesc = _cleanDescription(line);
        if (cleanDesc.isNotEmpty) {
          final existingDesc = currentDish['description']['es'] as String;
          currentDish['description']['es'] = existingDesc.isNotEmpty ? '$existingDesc $cleanDesc' : cleanDesc;
        }
      }
    }

    // Agregar el último plato si quedó pendiente
    if (currentDish != null) {
      dishes.add(currentDish);
    }

    // Traducir descripciones al inglés
    for (final d in dishes) {
      final descEs = (d['description']['es'] as String).trim();
      if (descEs.isNotEmpty) {
        final descEn = await TranslationService.translateEsToEn(descEs);
        d['description']['en'] = descEn.isNotEmpty ? descEn : descEs;
      }
    }

    return dishes;
  }

  /// Limpia emojis Unicode y símbolos decorativos
  static String _stripEmojisAndSymbols(String text) {
    if (text.isEmpty) return text;

    final emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}'
      r'\u{1F300}-\u{1F5FF}'
      r'\u{1F680}-\u{1F6FF}'
      r'\u{1F700}-\u{1F77F}'
      r'\u{1F780}-\u{1F7FF}'
      r'\u{1F800}-\u{1F8FF}'
      r'\u{1F900}-\u{1F9FF}'
      r'\u{1FA00}-\u{1FA6F}'
      r'\u{1FA70}-\u{1FAFF}'
      r'\u{2600}-\u{26FF}'
      r'\u{2700}-\u{27BF}'
      r'\u{2300}-\u{23FF}'
      r'\u{2B50}'
      r'\u{200D}\u{FE0F}'
      r']',
      unicode: true,
    );

    var cleaned = text.replaceAll(emojiRegex, ' ');

    // Símbolos de adornos frecuentes en menús
    cleaned = cleaned.replaceAll(RegExp(r'[★☆✪✫✬✭✮✰✦✧•●▪▫◆◇►◄✔✓✕✖❤♡♨🍴🍽🏷📌🔥🍔🍕🍖🍗🥩🍲🍜🍛☕🍹🍷🍺]'), ' ');

    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Limpia descripciones removiendo signos iniciales decorativos
  static String _cleanDescription(String raw) {
    var desc = _stripEmojisAndSymbols(raw);
    desc = desc.replaceAll(RegExp(r'^[\.\-:,_•]+'), '');
    return desc.trim();
  }

  /// Filtra líneas que corresponden a datos irrelevantes (WiFi, teléfono, RUC, redes sociales, horarios, logos)
  static bool _isNoiseOrMetadataLine(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.isEmpty) return true;

    // Teléfonos y mensajería
    if (RegExp(r'\b(?:tel|telf|cel|celular|whatsapp|wssp|contacto|pedidos|domicilio|delivery)\b').hasMatch(lower) ||
        RegExp(r'\b09\d{8}\b').hasMatch(lower) ||
        RegExp(r'\b\d{3}[-\s]?\d{4}\b').hasMatch(lower)) {
      return true;
    }

    // Redes sociales y páginas web
    if (lower.contains('facebook') ||
        lower.contains('instagram') ||
        lower.contains('tiktok') ||
        lower.contains('www.') ||
        lower.contains('http') ||
        RegExp(r'@[\w\d_\.]+').hasMatch(lower)) {
      return true;
    }

    // Datos fiscales e impuestos
    if (lower.contains('ruc') ||
        lower.contains('factura') ||
        lower.contains('sri') ||
        lower.contains('iva incl') ||
        lower.contains('no incluye iva') ||
        lower.contains('mas iva') ||
        lower.contains('propina') ||
        lower.contains('servicio no incl')) {
      return true;
    }

    // Horarios y ubicaciones generales
    if (lower.startsWith('horario') ||
        lower.startsWith('atención') ||
        lower.startsWith('abierto') ||
        lower.startsWith('lunes a') ||
        lower.startsWith('martes a') ||
        lower.startsWith('dirección') ||
        lower.startsWith('ubicación') ||
        lower.startsWith('sector ') ||
        lower.contains('quito - ecuador')) {
      return true;
    }

    // Claves de Wi-Fi
    if (lower.contains('wifi') || lower.contains('wi-fi') || lower.contains('clave:')) {
      return true;
    }

    // Saludos generales
    if (lower.contains('bienvenidos') ||
        lower.contains('buen provecho') ||
        lower.contains('gracias por su visita') ||
        lower.contains('gracias por preferirnos') ||
        lower.contains('sabor de la casa')) {
      return true;
    }

    // Formas de pago
    if (lower.contains('formas de pago') ||
        lower.contains('transferencia') ||
        lower.contains('deuna') ||
        lower.contains('tarjeta de crédito') ||
        lower.contains('banco pichincha')) {
      return true;
    }

    // Logos, certificaciones comerciales y sellos de marca (líneas independientes)
    if (lower == 'beyond meat' ||
        lower == 'roger\'s' ||
        lower == 'rogers' ||
        lower == 'roger\'s smash burgers' ||
        lower == 'rogers smash burgers' ||
        lower == 'smash burgers' ||
        lower == 'gluten free' ||
        lower == 'sin gluten' ||
        lower == '100% artesanal' ||
        lower == 'hecho en casa' ||
        lower == 'est.' ||
        lower == 'gye' ||
        lower == 'est. gye' ||
        lower == 'r') {
      return true;
    }

    return false;
  }

  /// Ordena líneas espaciales detectando columnas (1 o 2 columnas) y agrupando filas horizontales
  static List<String> _orderSpatialLines(List<_SpatialLine> lines) {
    if (lines.isEmpty) return [];

    final minX = lines.map((l) => l.rect.left).reduce(math.min);
    final maxX = lines.map((l) => l.rect.right).reduce(math.max);
    final totalWidth = maxX - minX;

    // Detectar si el menú tiene estructura de 2 columnas
    // (al menos 3 renglones en la mitad izquierda y 3 renglones en la mitad derecha)
    final splitX = minX + (totalWidth * 0.50);
    final leftLines = lines.where((l) => ((l.rect.left + l.rect.right) / 2) < splitX).toList();
    final rightLines = lines.where((l) => ((l.rect.left + l.rect.right) / 2) >= splitX).toList();

    if (totalWidth > 180 && leftLines.length >= 3 && rightLines.length >= 3) {
      final col1 = _mergeRowsInColumn(leftLines);
      final col2 = _mergeRowsInColumn(rightLines);
      return [...col1, ...col2];
    }

    return _mergeRowsInColumn(lines);
  }

  /// Agrupa líneas dentro de una misma columna que comparten altura vertical (misma fila)
  static List<String> _mergeRowsInColumn(List<_SpatialLine> colLines) {
    if (colLines.isEmpty) return [];

    final lines = List<_SpatialLine>.from(colLines);
    final heights = lines.map((l) => l.height).where((h) => h > 5).toList()..sort();
    final medianH = heights.isNotEmpty ? heights[heights.length ~/ 2] : 20.0;
    final yThreshold = medianH * 0.75;

    lines.sort((a, b) => a.rect.top.compareTo(b.rect.top));

    final List<List<_SpatialLine>> rows = [];
    for (final line in lines) {
      List<_SpatialLine>? matchedRow;
      for (final row in rows) {
        final rowCenterY = row.map((l) => l.centerY).reduce((a, b) => a + b) / row.length;
        if ((line.centerY - rowCenterY).abs() < yThreshold) {
          matchedRow = row;
          break;
        }
      }

      if (matchedRow != null) {
        matchedRow.add(line);
      } else {
        rows.add([line]);
      }
    }

    final List<String> result = [];
    for (final row in rows) {
      row.sort((a, b) => a.rect.left.compareTo(b.rect.left));
      final mergedText = row.map((l) => l.text.trim()).join(' ').trim();
      if (mergedText.isNotEmpty) {
        result.add(mergedText);
      }
    }

    return result;
  }

  /// Extrae el precio de un texto admitiendo prefijos de moneda, decimales o enteros
  static _PriceInfo? _extractPrice(String text) {
    // 1. Prefijo de moneda: "$39", "$ 39", "$39.00", "$ 7.50", "USD 25", "US$ 14"
    final currencyPrefix = RegExp(r'(?:\$|\bUSD|\bUS\$)\s*(\d{1,4}(?:[.,]\d{1,2})?)\b', caseSensitive: false);
    final m1 = currencyPrefix.firstMatch(text);
    if (m1 != null) {
      final numStr = m1.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null && val > 0 && val < 500) {
        return _PriceInfo(value: val, rawMatch: m1.group(0)!, startIndex: m1.start, endIndex: m1.end);
      }
    }

    // 2. Sufijo de moneda o de unidad: "39$", "25.00 USD", "14 USD", "$3.50 c/u"
    final currencySuffix = RegExp(r'\b(\d{1,4}(?:[.,]\d{1,2})?)\s*(?:\$|USD|US\$|c/u|cu)\b', caseSensitive: false);
    final m2 = currencySuffix.firstMatch(text);
    if (m2 != null) {
      final numStr = m2.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null && val > 0 && val < 500) {
        return _PriceInfo(value: val, rawMatch: m2.group(0)!, startIndex: m2.start, endIndex: m2.end);
      }
    }

    // 3. Formato decimal independiente: "7.50", "14.00", "25,00" (sin confundir fracciones como 1/4 o multiplicadores x 10)
    final decimalRegex = RegExp(r'(?<![xX\d/\\])\b(\d{1,4}[.,]\d{1,2})\b(?!\s*personas|\s*min|\s*gr|\s*kg|\s*ml)');
    final m3 = decimalRegex.firstMatch(text);
    if (m3 != null) {
      final numStr = m3.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null && val > 0 && val < 500) {
        return _PriceInfo(value: val, rawMatch: m3.group(0)!, startIndex: m3.start, endIndex: m3.end);
      }
    }

    // 4. Entero precedido de puntos o guiones de menú: "SUPER BANDEJA ... 39"
    final dottedIntRegex = RegExp(r'[\.\-_]{2,}\s*(?:\$)?\s*(\d{1,3})\s*$');
    final m4 = dottedIntRegex.firstMatch(text);
    if (m4 != null) {
      final val = double.tryParse(m4.group(1)!);
      if (val != null && val > 0 && val < 500) {
        return _PriceInfo(value: val, rawMatch: m4.group(0)!, startIndex: m4.start, endIndex: m4.end);
      }
    }

    return null;
  }

  static const _pureVariantWords = {
    'sencilla', 'sencillo', 'simple',
    'doble', 'triple', 'cuadruple', 'cuádruple',
    'combo', 'combos',
    'personal', 'mediana', 'mediano', 'familiar', 'grande', 'chico', 'chica', 'pequeño', 'pequeña', 'mini', 'gigante', 'junior',
    'solo', 'sola', 'individual',
    'vaso', 'jarra', 'copa', 'botella', 'lata',
    'porcion', 'porción',
    'adicional', 'extra', 'orden'
  };

  /// Determina si un texto está compuesto exclusivamente por palabras de variantes/tamaños/porciones
  static bool _isPureVariantOrSize(String text) {
    final clean = text.replaceAll(RegExp(r'[\$0-9.,\-_/\\:\(\)]+'), ' ').trim().toLowerCase();
    if (clean.isEmpty) return false;
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return false;
    const allowedConnectors = {'en', 'de', 'con', 'y', 'o', 'al', 'el', 'la', 'los', 'las', 'del'};
    for (final w in words) {
      if (!_pureVariantWords.contains(w) && !allowedConnectors.contains(w)) {
        return false;
      }
    }
    return true;
  }

  /// Extrae todos los precios y las etiquetas que los preceden en una línea
  static List<_ParsedPriceToken> _extractAllPriceTokens(String text) {
    final List<_ParsedPriceToken> tokens = [];
    final priceRegex = RegExp(
      r'(?:\$|\bUSD|\bUS\$)\s*(\d{1,4}(?:[.,]\d{1,2})?)\b|\b(\d{1,4}[.,]\d{2})\b(?!\s*personas|\s*min|\s*gr|\s*kg|\s*ml|\s*g\b)',
      caseSensitive: false,
    );

    final matches = priceRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      // Fallback a _extractPrice si es un entero con formato estándar (ej: $39)
      final singlePrice = _extractPrice(text);
      if (singlePrice != null) {
        final labelSegment = text.substring(0, singlePrice.startIndex).trim();
        final cleanLabel = _cleanDishName(labelSegment);
        tokens.add(_ParsedPriceToken(value: singlePrice.value, label: cleanLabel));
      }
      return tokens;
    }

    int prevEnd = 0;
    for (int i = 0; i < matches.length; i++) {
      final m = matches[i];
      final numStr = (m.group(1) ?? m.group(2))!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null && val > 0 && val < 500) {
        final labelSegment = text.substring(prevEnd, m.start).trim();
        final cleanLabel = _cleanDishName(labelSegment);
        tokens.add(_ParsedPriceToken(value: val, label: cleanLabel));
      }
      prevEnd = m.end;
    }

    return tokens;
  }

  /// Limpia adornos visuales comunes en cartas (estrellas, viñetas, guiones, numeración, gramajes iniciales)
  static String _cleanDishName(String raw) {
    var name = _stripEmojisAndSymbols(raw);
    // Eliminar gramajes o porciones iniciales ej: "115G, ", "(180G) ", "200 gr - "
    name = name.replaceAll(RegExp(r'^\(?\s*\d+\s*(?:g|gr|kg|oz|ml|l|lb)\s*\)?[\s,:\.\-]*', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'^[★☆•\*\-\d\.\s\(\)]+'), '');
    name = name.replaceAll(RegExp(r'[\.\-:,_]+$'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    return name.trim();
  }

  /// Detecta líneas que representan exclusivamente opciones de porciones, tamaños o gramajes
  /// Ej: "(180G)", "8 ALITAS 12 ALITAS", "6 ALITAS / 12 ALITAS", "PERSONAL / MEDIANA / FAMILIAR"
  static bool _isPortionOrOptionLine(String line) {
    final clean = _stripEmojisAndSymbols(line).trim();
    if (clean.isEmpty) return false;

    // Gramaje único: "(180G)", "200 gr", "1 lb", "500 gramos"
    if (RegExp(r'^\(?\s*\d+\s*(?:g|gr|kg|oz|ml|l|lb|libras|gramos)\s*\)?$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    // Porciones combinadas o repetidas: "8 ALITAS 12 ALITAS", "6 ALITAS / 12 ALITAS", "10 PIEZAS / 20 PIEZAS"
    final portionToken = RegExp(r'\b\d+\s*(?:alitas|piezas|pzas|unidades|uds|porciones|personas|g|gr|kg|oz|ml|lb)\b', caseSensitive: false);
    final matches = portionToken.allMatches(clean);
    if (matches.isNotEmpty) {
      final withoutPortions = clean.replaceAll(portionToken, '').replaceAll(RegExp(r'[/,\-\|\s\(\)]+'), '').trim();
      if (withoutPortions.isEmpty) {
        return true;
      }
    }

    // Opciones de tamaño solas: "PERSONAL / MEDIANA / FAMILIAR", "CHICO / MEDIANO / GRANDE"
    if (RegExp(r'^(?:personal|mediana|familiar|chico|mediano|grande|vaso|jarra)(?:\s*[/,\-\|]\s*(?:personal|mediana|familiar|chico|mediano|grande|vaso|jarra))*$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    return false;
  }

  /// Determina si una línea es la continuación de un título dividido en 2 renglones
  /// (ej: "SUPER" + "BANDEJA", "BANDEJA" + "AMAZONAS", "SMASH BACON" + "CEBOLLITAS")
  static bool _shouldContinueTitle(String existingTitle, String nextLine) {
    final existingClean = existingTitle.trim();
    final nextClean = _cleanDishName(nextLine);
    if (existingClean.isEmpty || nextClean.isEmpty) return false;
    if (_isCategoryHeader(nextClean) ||
        _isDescriptionLine(nextClean) ||
        _isPureVariantOrSize(nextClean) ||
        _isNoiseOrMetadataLine(nextClean)) {
      return false;
    }

    final existingWords = existingClean.split(RegExp(r'\s+'));
    final nextWords = nextClean.split(RegExp(r'\s+'));

    // Si ya suma más de 4 palabras, es muy poco probable que sea un solo plato
    if (existingWords.length + nextWords.length > 4) return false;

    // Conectores que indican que el título quedó inconcluso: "Seco de", "Pollo al", etc.
    final lastWord = existingWords.last.toLowerCase();
    const connectors = {'de', 'del', 'con', 'en', 'al', 'a', 'y', 'la', 'el', 'los', 'las', 'por'};
    if (connectors.contains(lastWord)) return true;

    // Prefijos típicos de una o dos palabras que se complementan con la siguiente
    const prefixWords = {
      'super', 'gran', 'media', 'medio', 'combo', 'mini', 'mega', 'extra',
      'plato', 'porcion', 'porción', 'sopa', 'caldo', 'crema', 'arroz',
      'seco', 'carne', 'pollo', 'lomo', 'hamburguesa', 'burger', 'pizza',
      'sandwich', 'sándwich', 'bandeja', 'taco', 'tacos', 'smash', 'classic', 'bacon', 'doble'
    };

    if (existingWords.any((w) => prefixWords.contains(w.toLowerCase()))) {
      return true;
    }

    return false;
  }

  /// Determina si una línea es un título de plato
  static bool _isTitleLine(String line) {
    final clean = _cleanDishName(line);
    if (clean.isEmpty) return false;
    if (_isCategoryHeader(clean)) return false;
    if (_isNoiseOrMetadataLine(clean)) return false;
    if (_isPureVariantOrSize(clean)) return false;
    if (_isPortionOrOptionLine(line) || _isPortionOrOptionLine(clean)) return false;
    if (_isDescriptionLine(clean) || _isDescriptionLine(line)) return false;

    // Ningún título de plato contiene comas, punto y coma, o dos puntos
    if (clean.contains(',') || clean.contains(';') || clean.contains(':')) return false;

    // Gramaje o porciones puras como "(180G)", "8 ALITAS", "12 ALITAS", "PORCIÓN"
    if (RegExp(r'^\(?\s*\d+\s*(?:g|gr|kg|oz|ml|l|lb|alitas|piezas|unidades)\s*\)?$', caseSensitive: false).hasMatch(clean)) {
      return false;
    }

    // Prefijos preposicionales
    final lower = clean.toLowerCase();
    if (RegExp(r'^(?:en|con|y|de|del|al|a la|a base de)\s+').hasMatch(lower)) {
      return false;
    }

    // Cantidad de palabras razonable para un título (1 a 5 palabras, < 40 caracteres)
    final words = clean.split(RegExp(r'\s+'));
    if (words.length > 5 || clean.length > 38) return false;

    // Menús usan MAYÚSCULAS o Formato Título
    final isAllCaps = clean == clean.toUpperCase() && clean.contains(RegExp(r'[A-ZÁÉÍÓÚÑ]'));
    final isTitleCase = RegExp(r'^[A-ZÁÉÍÓÚÑ]').hasMatch(clean) && !clean.contains(RegExp(r'[,;\.!?¿¡]'));

    return (isAllCaps || isTitleCase) && _isValidDishName(clean);
  }

  /// Convierte texto todo en mayúsculas a formato de título limpio y elegante
  static String _toTitleCase(String text) {
    if (text.isEmpty) return text;

    const lowercaseWords = {'de', 'con', 'en', 'y', 'a', 'al', 'del', 'la', 'el', 'los', 'las', 'un', 'una', 'por', 'o'};
    final words = text.toLowerCase().split(' ');
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;
      if (i > 0 && lowercaseWords.contains(w)) {
        words[i] = w;
      } else {
        words[i] = w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
      }
    }
    return words.join(' ');
  }

  /// Identifica si una línea es una descripción de ingredientes o porción
  static bool _isDescriptionLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;

    if (_isPortionOrOptionLine(trimmed)) return true;

    // Gramajes o pesos al inicio: "115G", "195G, ...", "160G, ...", "(180G)"
    if (RegExp(r'^\(?\s*\d+\s*(?:g|gr|kg|oz|ml|lb)\b', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    // Líneas con comas: en los menús, las listas de ingredientes llevan comas
    if (trimmed.contains(',')) {
      return true;
    }

    final lower = trimmed.toLowerCase();

    // Líneas que inician con preposiciones o frases culinarias
    if (RegExp(r'^(?:en|con|y|de|del|al|a la|a base de|bañad[oa]s? en|servid[oa]s? con|acompañad[oa]s? de|preparado con)\s+', caseSensitive: false).hasMatch(lower)) {
      return true;
    }

    // Ingredientes, panes, quesos, aderezos o salsas comunes en cartas
    final ingredientKeywords = [
      'pan brioche', 'pan de papa', 'pretzel bun', 'pan de molde', 'pan artesanal', 'en pan',
      'queso cheddar', 'queso pepper jack', 'queso emmental', 'queso mozzarella', 'mozzarella',
      'doble queso', 'bacon bits', 'bacon jam', 'cebollitas caramelizadas', 'cebolla caramelizada',
      'sweet & smokey', 'bbq sauce', 'jalapeño mayo', 'smokey mayo', 'salsa rogers', 'salsa p.m.',
      'ultra smashed', 'beyond meat', 'pickles', 'lechuga', 'tomate', 'carne magra',
      'papas fritas', 'vegetales frescos', 'al grill', 'a las brasas'
    ];
    for (final kw in ingredientKeywords) {
      if (lower.contains(kw)) return true;
    }

    if (lower.startsWith('¡') ||
        lower.startsWith('¿') ||
        lower.startsWith('un clásico') ||
        lower.startsWith('una porción') ||
        lower.startsWith('media porción') ||
        lower.startsWith('1/4 de porción') ||
        lower.startsWith('1/2 porción') ||
        lower.startsWith('porción de') ||
        lower.startsWith('acompañad') ||
        lower.startsWith('servido con') ||
        lower.startsWith('incluye') ||
        lower.startsWith('preparado con') ||
        lower.startsWith('rinde para') ||
        lower.startsWith('cocinadas a') ||
        lower.startsWith('vegetales frescos') ||
        lower.startsWith('con papas') ||
        lower.startsWith('con arroz') ||
        lower.startsWith('a base de')) {
      return true;
    }

    if (trimmed.length > 30 && (trimmed.contains(',') || trimmed.contains('.'))) {
      return true;
    }

    if (RegExp(r'^[a-z]').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Valida que el texto corresponda a un nombre de plato legítimo
  static bool _isValidDishName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\$\d\.,\-_/\\:\(\)]+'), '').trim();
    if (cleaned.length < 2 || !RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ]').hasMatch(cleaned)) return false;
    if (_isPureVariantOrSize(cleaned)) return false;
    if (_isNoiseOrMetadataLine(cleaned)) return false;
    if (_isCategoryHeader(cleaned)) return false;

    // Palabras individuales o compuestas de solo ingredientes que nunca son platos
    const invalidTitleWords = {
      'mozzarella', 'cheddar', 'emmental', 'bacon', 'bits', 'jam',
      'pickles', 'lechuga', 'tomate', 'cebollitas', 'cebolla', 'caramelizadas',
      'mayo', 'mayonesa', 'mostaza', 'ketchup', 'pan', 'brioche', 'pretzel', 'bun',
      'salsa', 'sauce', 'queso', 'papas', 'arroz', 'mote', 'chulpi', 'aguacate',
      'maduro', 'tortilla', 'ensalada', 'habas', 'choclo', 'carne', 'pollo'
    };
    final lowerClean = cleaned.toLowerCase();
    if (invalidTitleWords.contains(lowerClean)) return false;

    return true;
  }

  /// Identifica encabezados de categorías comunes en menús
  static bool _isCategoryHeader(String line) {
    final clean = line.replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚñÑ\s]'), '').trim().toUpperCase();
    if (clean.isEmpty) return false;

    const knownCategories = [
      'BANDEJAS', 'PLATOS FUERTES', 'PLATOS TÍPICOS', 'PLATOS TIPICOS',
      'ENTRADAS', 'SOPAS', 'CALDOS', 'BEBIDAS', 'POSTRES', 'COMBOS',
      'DESAYUNOS', 'ALMUERZOS', 'CENAS', 'MARISCOS', 'CARNES', 'POLLOS',
      'ESPECIALIDADES', 'PICADITAS', 'PORCIONES', 'ADICIONALES', 'EXTRAS',
      'MENU', 'MENÚ', 'MENU DEL DIA', 'MENÚ DEL DÍA', 'CARTA', 'CAFETERÍA',
      'PLATOS A LA CARTA', 'PARRILLADAS', 'CEVICHES', 'GUARNICIONES',
      'HAMBURGUESAS', 'BURGERS', 'ALITAS', 'SMASHED BURGERS', 'SMASH BURGERS'
    ];

    if (knownCategories.contains(clean)) return true;
    if (clean.endsWith('BURGERS') || clean.endsWith('HAMBURGUESAS')) return true;

    return false;
  }

  /// Mapea un encabezado a una categoría reconocida del sistema
  static String _mapCategoryFromHeader(String line) {
    final upper = line.toUpperCase();
    if (upper.contains('BEBIDA') || upper.contains('JUGO') || upper.contains('GASEOSA') || upper.contains('COCTEL')) {
      return 'Bebidas';
    }
    if (upper.contains('POSTRE') || upper.contains('DULCE') || upper.contains('HELADO')) {
      return 'Postres';
    }
    if (upper.contains('ENTRADA') || upper.contains('SOPA') || upper.contains('CALDO') || upper.contains('LOCRO')) {
      return 'Entradas / Sopas';
    }
    if (upper.contains('TIPIC') || upper.contains('TRADICIONAL') || upper.contains('CRIOLL') || upper.contains('BANDEJA')) {
      return 'Platos Típicos';
    }
    if (upper.contains('BURGER') || upper.contains('HAMBURGUESA')) {
      return 'Platos Fuertes';
    }
    return 'Platos Fuertes';
  }

  /// Infiere una categoría inicial basada en palabras clave
  static String _guessCategory(String dishName) {
    final lower = dishName.toLowerCase();

    // Bebidas
    if (lower.contains('jugo') ||
        lower.contains('cola') ||
        lower.contains('cerveza') ||
        lower.contains('agua') ||
        lower.contains('bebida') ||
        lower.contains('jarra') ||
        lower.contains('gaseosa') ||
        lower.contains('limonada') ||
        lower.contains('chicha') ||
        lower.contains('morocho') ||
        lower.contains('colada morada') ||
        lower.contains('canelazo') ||
        lower.contains('café') ||
        lower.contains('cafe') ||
        lower.contains('té') ||
        lower.contains('te')) {
      return 'Bebidas';
    }

    // Postres
    if (lower.contains('postre') ||
        lower.contains('helado') ||
        lower.contains('dulce') ||
        lower.contains('tarta') ||
        lower.contains('torta') ||
        lower.contains('flan') ||
        lower.contains('tres leches') ||
        lower.contains('cheesecake') ||
        lower.contains('espumilla') ||
        lower.contains('pristiño')) {
      return 'Postres';
    }

    // Entradas / Sopas
    if (lower.contains('empanada') ||
        lower.contains('entrada') ||
        lower.contains('sopa') ||
        lower.contains('caldo') ||
        lower.contains('locro') ||
        lower.contains('crema') ||
        lower.contains('consomé') ||
        lower.contains('ensalada') ||
        lower.contains('picada') ||
        lower.contains('alita')) {
      return 'Entradas / Sopas';
    }

    // Platos Típicos
    if (lower.contains('fritada') ||
        lower.contains('hornado') ||
        lower.contains('ceviche') ||
        lower.contains('encebollado') ||
        lower.contains('chivo') ||
        lower.contains('guatita') ||
        lower.contains('mote') ||
        lower.contains('bandeja') ||
        lower.contains('yahuarlocro') ||
        lower.contains('cuy') ||
        lower.contains('caldo de patas') ||
        lower.contains('seco') ||
        lower.contains('chulpi') ||
        lower.contains('chicharrón') ||
        lower.contains('chicharron') ||
        lower.contains('llapingacho') ||
        lower.contains('humita') ||
        lower.contains('tamal') ||
        lower.contains('bolón') ||
        lower.contains('bolon') ||
        lower.contains('tigrillo') ||
        lower.contains('corviche') ||
        lower.contains('tripa')) {
      return 'Platos Típicos';
    }

    return 'Platos Fuertes';
  }
}
