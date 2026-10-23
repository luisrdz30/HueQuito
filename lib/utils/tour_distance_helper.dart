import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

class TourLeg {
  final int fromIndex;
  final int toIndex;
  final String fromName;
  final String toName;
  final double distanceKm;
  final int durationMinutes;

  const TourLeg({
    required this.fromIndex,
    required this.toIndex,
    required this.fromName,
    required this.toName,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class TourMetrics {
  final double totalDistanceKm;
  final int totalDurationMinutes;
  final List<TourLeg> legs;

  const TourMetrics({
    required this.totalDistanceKm,
    required this.totalDurationMinutes,
    required this.legs,
  });
}

class TourDistanceHelper {
  /// Velocidad media estimada de tráfico urbano en Quito (~24 km/h)
  static const double _averageCitySpeedKmh = 24.0;

  /// Calcula la distancia en kilómetros entre dos coordenadas
  static double calculateDistanceKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    if (startLat == 0 || startLng == 0 || endLat == 0 || endLng == 0) return 0.0;
    try {
      final meters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
      return meters / 1000.0;
    } catch (_) {
      // Fallback matemático (Haversine)
      const p = 0.017453292519943295;
      final a = 0.5 -
          cos((endLat - startLat) * p) / 2 +
          cos(startLat * p) * cos(endLat * p) * (1 - cos((endLng - startLng) * p)) / 2;
      return 12742 * asin(sqrt(a));
    }
  }

  /// Estima los minutos de viaje en auto en base a la distancia en km
  static int estimateDrivingMinutes(double distanceKm) {
    if (distanceKm <= 0.05) return 0;
    final minutes = ((distanceKm / _averageCitySpeedKmh) * 60).round();
    return max(2, minutes);
  }

  /// Formatea la distancia amigablemente (ej: '850 m' o '3.4 km')
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Formatea la duración en auto (ej: '12 min' o '1 h 15 min')
  static String formatDuration(int minutes, {bool isEn = false}) {
    if (minutes < 60) {
      return isEn ? '$minutes min by car' : '$minutes min en auto';
    }
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) {
      return isEn ? '$hours h by car' : '$hours h en auto';
    }
    return isEn ? '$hours h $remaining min by car' : '$hours h $remaining min en auto';
  }

  /// Calcula las métricas completas para una lista ordenada de huecas
  static TourMetrics calculateMetrics(List<Hueca> stops) {
    if (stops.length < 2) {
      return const TourMetrics(
        totalDistanceKm: 0.0,
        totalDurationMinutes: 0,
        legs: [],
      );
    }

    double totalDist = 0.0;
    int totalMins = 0;
    final List<TourLeg> legs = [];

    for (int i = 0; i < stops.length - 1; i++) {
      final current = stops[i];
      final next = stops[i + 1];

      final dist = calculateDistanceKm(
        current.location.latitude,
        current.location.longitude,
        next.location.latitude,
        next.location.longitude,
      );
      final mins = estimateDrivingMinutes(dist);

      totalDist += dist;
      totalMins += mins;

      legs.add(TourLeg(
        fromIndex: i,
        toIndex: i + 1,
        fromName: current.name,
        toName: next.name,
        distanceKm: dist,
        durationMinutes: mins,
      ));
    }

    return TourMetrics(
      totalDistanceKm: totalDist,
      totalDurationMinutes: totalMins,
      legs: legs,
    );
  }

  /// Ordena una lista de huecas por cercanía geográfica respecto a una hueca de origen.
  /// Las más cercanas aparecen primero. Las distantes NO se eliminan, quedan abajo.
  static List<HuecaDistanceItem> sortHuecasByProximity({
    required List<Hueca> huecas,
    required Hueca fromHueca,
  }) {
    final List<HuecaDistanceItem> items = [];

    for (final h in huecas) {
      if (h.id == fromHueca.id) continue; // No sugerir la misma hueca
      final dist = calculateDistanceKm(
        fromHueca.location.latitude,
        fromHueca.location.longitude,
        h.location.latitude,
        h.location.longitude,
      );
      final mins = estimateDrivingMinutes(dist);
      items.add(HuecaDistanceItem(
        hueca: h,
        distanceKm: dist,
        drivingMinutes: mins,
        isClose: dist <= 4.0, // Consideramos "cerca" hasta 4 km en Quito
      ));
    }

    // Ordenar de menor a mayor distancia
    items.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return items;
  }

  /// Comprueba si una hueca encaja con el tipo de antojo seleccionado
  static bool matchesCraving(Hueca hueca, TourCravingType craving) {
    if (craving == TourCravingType.any) return true;

    final List<String> keywords = switch (craving) {
      TourCravingType.soup => [
        'sopa', 'caldo', 'locro', 'encebollado', 'crema', 'viche', 'yaguarlocro', 'pata', 'mote pata', 'ramen'
      ],
      TourCravingType.heavy => [
        'hornado', 'fritada', 'seco', 'chivo', 'guatita', 'carne', 'parrilla', 'asado', 'pollo', 'chancho', 'cerdo', 'churrasco', 'tripa', 'mishqui', 'costilla', 'menestra'
      ],
      TourCravingType.seafood => [
        'ceviche', 'cebiche', 'marisco', 'camaron', 'corvina', 'pescado', 'encebollado', 'cangrejo', 'concha', 'marinero'
      ],
      TourCravingType.streetFood => [
        'hamburguesa', 'salchipapa', 'pizza', 'taco', 'hot dog', 'alitas', 'sandwich', 'sanduche', 'chuzo'
      ],
      TourCravingType.snacks => [
        'empanada', 'morocho', 'viento', 'humita', 'tamal', 'quimbolito', 'tortilla', 'choclo', 'mote', 'patacon'
      ],
      TourCravingType.dessert => [
        'helado', 'paila', 'dulce', 'postre', 'cafe', 'cafeteria', 'higos', 'quesadilla', 'pan', 'pasteleria', 'chocolate', 'espumilla', 'pristino', 'colada'
      ],
      TourCravingType.any => [],
    };

    // Extraer texto acumulado de la hueca
    final buffer = StringBuffer();
    buffer.write('${hueca.name.toLowerCase()} ');
    buffer.write('${hueca.sector.toLowerCase()} ');
    for (var t in hueca.tags) {
      buffer.write('${t.toLowerCase()} ');
    }
    for (var st in hueca.searchTags) {
      buffer.write('${st.toLowerCase()} ');
    }
    if (hueca.mainDish['name'] != null) {
      final nameVal = hueca.mainDish['name'];
      if (nameVal is Map) {
        buffer.write('${nameVal['es']?.toString().toLowerCase() ?? ''} ');
        buffer.write('${nameVal['en']?.toString().toLowerCase() ?? ''} ');
      } else {
        buffer.write('${nameVal.toString().toLowerCase()} ');
      }
    }
    if (hueca.description['es'] != null) {
      buffer.write('${hueca.description['es']?.toString().toLowerCase() ?? ''} ');
    }

    final fullText = buffer.toString();
    return keywords.any((kw) => fullText.contains(kw));
  }
}

enum TourCravingType {
  soup,
  heavy,
  seafood,
  streetFood,
  snacks,
  dessert,
  any,
}

class HuecaDistanceItem {
  final Hueca hueca;
  final double distanceKm;
  final int drivingMinutes;
  final bool isClose;

  const HuecaDistanceItem({
    required this.hueca,
    required this.distanceKm,
    required this.drivingMinutes,
    required this.isClose,
  });
}

