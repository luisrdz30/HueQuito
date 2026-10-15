import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static Future<String> translateEsToEn(String text) async {
    try {
      final url = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=es&tl=en&dt=t&q=${Uri.encodeComponent(text)}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<dynamic> translations = data[0];
        String fullTranslation = '';
        for (var i = 0; i < translations.length; i++) {
          fullTranslation += translations[i][0].toString();
        }
        return fullTranslation;
      }
      return text; // Fallback to original text if error
    } catch (e) {
      print('Error en traducción: $e');
      return text;
    }
  }
}
