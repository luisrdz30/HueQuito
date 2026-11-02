/// Zonas fijas de Quito: son las únicas que se guardan en `hueca.sector`,
/// en `branch.sector` y en la preferencia `sector` del usuario.
class QuitoZone {
  final String id;
  final String nameEn;
  final String icon;
  final String barriosEs;
  final String barriosEn;

  const QuitoZone({
    required this.id,
    required this.nameEn,
    required this.icon,
    required this.barriosEs,
    required this.barriosEn,
  });

  String name(bool isEn) => isEn ? nameEn : id;
  String barrios(bool isEn) => isEn ? barriosEn : barriosEs;
}

const String allQuitoZone = 'Todo Quito';

const List<QuitoZone> quitoZones = [
  QuitoZone(
    id: 'Centro',
    nameEn: 'Downtown',
    icon: '🏛️',
    barriosEs: 'Centro Histórico, La Ronda, San Roque, San Blas, San Juan, La Tola',
    barriosEn: 'Historic Center, La Ronda, San Roque, San Blas, San Juan, La Tola',
  ),
  QuitoZone(
    id: 'Norte',
    nameEn: 'North',
    icon: '🏔️',
    barriosEs: 'La Mariscal, La Floresta, La Carolina, Iñaquito, Cotocollao, Carcelén',
    barriosEn: 'La Mariscal, La Floresta, La Carolina, Iñaquito, Cotocollao, Carcelén',
  ),
  QuitoZone(
    id: 'Sur',
    nameEn: 'South',
    icon: '🏘️',
    barriosEs: 'Villaflora, La Magdalena, Chimbacalle, Cinco Esquinas, Solanda, Quitumbe',
    barriosEn: 'Villaflora, La Magdalena, Chimbacalle, Cinco Esquinas, Solanda, Quitumbe',
  ),
  QuitoZone(
    id: 'Valles',
    nameEn: 'Valleys',
    icon: '🌄',
    barriosEs: 'Cumbayá, Tumbaco, Conocoto, Sangolquí, San Rafael, Valle de los Chillos',
    barriosEn: 'Cumbayá, Tumbaco, Conocoto, Sangolquí, San Rafael, Los Chillos valley',
  ),
];

List<String> get quitoZoneIds => quitoZones.map((z) => z.id).toList();

QuitoZone? quitoZoneById(String id) {
  for (final z in quitoZones) {
    if (z.id == id) return z;
  }
  return null;
}

/// Lleva cualquier sector viejo o barrio ("Conocoto", "La Mariscal", "Centro Histórico"...)
/// a una de las 4 zonas. Devuelve null si no se reconoce (o si es "Todo Quito").
String? normalizeQuitoZone(String? raw) {
  final s = (raw ?? '').toLowerCase().trim()
      .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
      .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ñ', 'n');
  if (s.isEmpty || s == 'todo quito' || s == 'all quito' || s == 'todos' || s == 'all') return null;
  bool has(List<String> words) => words.any(s.contains);

  if (has(['valle', 'cumbaya', 'tumbaco', 'chillos', 'conocoto', 'sangolqui', 'san rafael',
      'puembo', 'pifo', 'alangasi', 'amaguana', 'capelo', 'armenia', 'playa chica'])) {
    return 'Valles';
  }
  if (has(['sur', 'villaflora', 'magdalena', 'chimbacalle', 'solanda', 'quitumbe', 'chillogallo',
      'guamani', 'recreo', 'pintado', 'cinco esquinas', '5 esquinas', 'barrio nuevo', 'ferroviaria',
      'la mena', 'san bartolo', 'santa rita'])) {
    return 'Sur';
  }
  if (has(['centro', 'la ronda', 'san roque', 'san blas', 'san juan', 'la tola', 'san marcos',
      'panecillo', 'santo domingo', 'plaza grande', 'el tejar', 'mercado central'])) {
    return 'Centro';
  }
  if (has(['norte', 'mariscal', 'floresta', 'guapulo', 'carolina', 'inaquito', 'bellavista', 'batan',
      'cotocollao', 'carcelen', 'calderon', 'ponceano', 'kennedy', 'pomasqui', 'rumipamba',
      'granda centeno', 'galo plaza', 'monteserrin', 'comite', 'el inca', 'san carlos', 'mitad del mundo'])) {
    return 'Norte';
  }
  return null;
}

/// Zona aproximada por coordenadas, para cuando la dirección no dice nada.
String zoneFromCoordinates(double lat, double lng) {
  if (lng > -78.46 || (lat < -0.26 && lng > -78.50)) return 'Valles';
  if (lat < -0.235) return 'Sur';
  if (lat > -0.205) return 'Norte';
  return 'Centro';
}
