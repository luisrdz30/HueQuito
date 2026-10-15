import 'dart:math';

/// Servicio de generación asistida con Inteligencia Artificial para
/// redactar descripciones atractivas y persuasivas de promociones, noticias y eventos de huecas.
class AiGenerationService {
  static final Random _random = Random();

  /// Genera opciones creativas de texto para la notificación según el título,
  /// la categoría, la hueca y los detalles adicionales.
  static List<String> generateCopyOptions({
    required String title,
    required String huecaName,
    required String category,
    String? discountTag,
    String? branchName,
  }) {
    final cleanTitle = title.trim();
    final cleanHueca = huecaName.trim().isEmpty ? 'nuestra hueca' : huecaName.trim();
    final branchText = (branchName != null && branchName.trim().isNotEmpty)
        ? ' en sucursal $branchName'
        : '';
    final tagText = (discountTag != null && discountTag.trim().isNotEmpty)
        ? ' con $discountTag'
        : '';

    // Detección contextual de palabras clave en el título
    final lowerTitle = cleanTitle.toLowerCase();
    final mentionsFood = lowerTitle.contains('seco') ||
        lowerTitle.contains('fritada') ||
        lowerTitle.contains('corvina') ||
        lowerTitle.contains('hornado') ||
        lowerTitle.contains('caldo') ||
        lowerTitle.contains('yaguarlocro') ||
        lowerTitle.contains('guatita') ||
        lowerTitle.contains('empanada') ||
        lowerTitle.contains('ceviche') ||
        lowerTitle.contains('encebollado') ||
        lowerTitle.contains('plato') ||
        lowerTitle.contains('combo');

    final mentionsTime = lowerTitle.contains('hoy') ||
        lowerTitle.contains('viernes') ||
        lowerTitle.contains('sabado') ||
        lowerTitle.contains('sábado') ||
        lowerTitle.contains('domingo') ||
        lowerTitle.contains('fin de semana') ||
        lowerTitle.contains('almuerzo') ||
        lowerTitle.contains('noche');

    switch (category) {
      case 'promocion':
        return [
          // Opción 1: Antojo irresistible & Llamada a la acción
          mentionsFood
              ? '¡El auténtico sabor de $cleanHueca te espera! Ven a deleitarte con $cleanTitle$branchText. ¡Aprovecha hoy mismo con la mejor sazón de Quito!'
              : '¡No te quedes con las ganas! Disfruta de "$cleanTitle" en $cleanHueca$branchText$tagText. Promoción válida en nuestro local hasta agotar stock.',
          
          // Opción 2: Oferta imperdible & Compañía
          '¡Arma el plan con tus amigos o familia! En $cleanHueca tenemos listo para ti: $cleanTitle$branchText. ¡Sabor tradicional al mejor precio quiteño!',
          
          // Opción 3: Urgencia y exclusividad
          '¡Por tiempo limitado! Pásate por $cleanHueca y aprovecha "$cleanTitle"$branchText$tagText. ¡Te esperamos con el calor del fogón tradicional!'
        ];

      case 'nuevo_plato':
        return [
          '¡Estreno en nuestro menú! 🎉 Ven a descubrir nuestra nueva creación en $cleanHueca: $cleanTitle$branchText. ¡Pura tradición e innovación para tu paladar!',
          '¿Buscabas algo nuevo y delicioso? Te presentamos en primicia: $cleanTitle en $cleanHueca$branchText. ¡Ven a ser de los primeros en probarlo!',
          'Ampliamos la carta con el auténtico toque de $cleanHueca: $cleanTitle$branchText. ¡Preparado con ingredientes frescos de nuestra tierra!'
        ];

      case 'evento':
        return [
          '¡Vive una experiencia especial en $cleanHueca! 🎶 No te pierdas "$cleanTitle"$branchText. El mejor ambiente tradicional con deliciosa comida.',
          '¡Tenemos casa llena de fiesta y tradición! Acompáñanos en $cleanHueca para vivir "$cleanTitle"$branchText. ¡Reserva tu mesa o llega temprano!',
          'Celebra con nosotros en $cleanHueca: $cleanTitle$branchText. Música, tradición y los platillos que tanto te gustan. ¡Te esperamos!'
        ];

      case 'noticia':
      default:
        return [
          '¡Novedades en $cleanHueca! 📢 Queremos contarte que $cleanTitle$branchText. ¡Gracias por ser parte de nuestra querida comunidad comensal!',
          '¡Aviso importante de $cleanHueca! Pensando siempre en brindarte la mejor atención: $cleanTitle$branchText. ¡Te esperamos con los brazos abiertos!',
          '¡Entérate de lo nuevo en $cleanHueca! $cleanTitle$branchText. Consulta los detalles en nuestro local y sigue coleccionando sellos en tu pasaporte.'
        ];
    }
  }

  /// Retorna una sugerencia directa seleccionando aleatoriamente entre las mejores opciones
  static String generateQuickSuggestion({
    required String title,
    required String huecaName,
    required String category,
    String? discountTag,
    String? branchName,
  }) {
    final options = generateCopyOptions(
      title: title,
      huecaName: huecaName,
      category: category,
      discountTag: discountTag,
      branchName: branchName,
    );
    return options[_random.nextInt(options.length)];
  }
}
