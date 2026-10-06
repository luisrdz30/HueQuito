import 'package:flutter/material.dart';

class GastronomicProfile {
  final String id;
  final String titleEs;
  final String titleEn;
  final String descriptionEs;
  final String descriptionEn;
  final IconData icon;
  final String emoji;
  final List<String> matchingTags;

  GastronomicProfile({
    required this.id,
    required this.titleEs,
    required this.titleEn,
    required this.descriptionEs,
    required this.descriptionEn,
    required this.icon,
    required this.emoji,
    required this.matchingTags,
  });
}

final List<GastronomicProfile> hueQuitoProfiles = [
  GastronomicProfile(
    id: 'sopero',
    titleEs: 'El Sopero',
    titleEn: 'The Soup Lover',
    descriptionEs: 'Para ti no hay almuerzo completo si no empieza (o termina) con un buen caldo. Crees fielmente que una buena sopa revive a cualquiera.',
    descriptionEn: 'For you, no meal is complete without a hot soup. You truly believe a good broth can bring anyone back to life.',
    icon: Icons.ramen_dining,
    emoji: '🥣',
    matchingTags: ['sopas', 'caldos', 'locro', 'encebollado', 'yahuarlocro', 'sancochos'],
  ),
  GastronomicProfile(
    id: 'carnivoro',
    titleEs: 'El Carnívoro',
    titleEn: 'The Meat King',
    descriptionEs: 'Buscas platos fuertes, contundentes y donde la carne sea la estrella. Tu plato siempre tiene que ir bien "puesto".',
    descriptionEn: 'You look for heavy, fulfilling dishes where meat is the main star. Your plate always has to be well-served.',
    icon: Icons.kebab_dining,
    emoji: '🍖',
    matchingTags: ['hornado', 'fritada', 'carnes', 'churrasco', 'asados', 'menestras', 'parrilladas'],
  ),
  GastronomicProfile(
    id: 'callejero',
    titleEs: 'El Callejero',
    titleEn: 'The Street Foodie',
    descriptionEs: 'Eres fan del "con todo". Te encanta la comida rápida, contundente y perfecta para rematar la noche o calmar un antojo fuerte.',
    descriptionEn: 'You love fast, heavy food perfect for ending the night or satisfying a huge craving.',
    icon: Icons.fastfood,
    emoji: '🍔',
    matchingTags: ['hamburguesas', 'pizzas', 'pollo frito', 'salchipapas', 'comida rápida', 'alitas'],
  ),
  GastronomicProfile(
    id: 'dulcero',
    titleEs: 'El Dulcero',
    titleEn: 'The Sweet Tooth',
    descriptionEs: 'Siempre tienes "un huequito extra" para el postre o un buen café. Tu paseo perfecto incluye caminar buscando algo dulce.',
    descriptionEn: 'You always have "extra room" for dessert or coffee. Your perfect walk involves looking for a sweet treat.',
    icon: Icons.icecream,
    emoji: '🍰',
    matchingTags: ['postres', 'helados', 'dulces', 'cafes', 'quesadillas', 'empanadas dulces'],
  ),
  GastronomicProfile(
    id: 'picador',
    titleEs: 'El Picador Clásico',
    titleEn: 'The Classic Snacker',
    descriptionEs: 'Prefieres ir de hueca en hueca probando "picaditas" y antojitos tradicionales. No te comprometes con un solo plato gigante.',
    descriptionEn: 'You prefer going from spot to spot trying traditional snacks rather than committing to one huge meal.',
    icon: Icons.tapas,
    emoji: '🥟',
    matchingTags: ['empanadas', 'humitas', 'corvinas', 'tamales', 'motes', 'antojitos', 'quimbolitos'],
  ),
  GastronomicProfile(
    id: 'aventurero',
    titleEs: 'El Aventurero',
    titleEn: 'The Adventurer',
    descriptionEs: 'No le tienes miedo a nada. Te encanta el ambiente del mercado, los sabores intensos y esos platos extremos que otros evitan.',
    descriptionEn: 'You fear nothing. You love the market vibe, intense flavors, and extreme dishes that others avoid.',
    icon: Icons.local_fire_department,
    emoji: '🤠',
    matchingTags: ['tripa mishqui', 'cuy', 'menudencias', 'ceviche', 'guatita', 'mercado'],
  ),
];
