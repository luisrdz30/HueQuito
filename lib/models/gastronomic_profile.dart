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

class QuizOption {
  final String id;
  final String textEs;
  final String textEn;
  final String profileId;
  final String emoji;

  QuizOption({
    required this.id,
    required this.textEs,
    required this.textEn,
    required this.profileId,
    required this.emoji,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'textEs': textEs,
    'textEn': textEn,
    'profileId': profileId,
    'emoji': emoji,
  };

  factory QuizOption.fromMap(Map<String, dynamic> map, [String? fallbackId]) => QuizOption(
    id: map['id']?.toString() ?? fallbackId ?? '',
    textEs: map['textEs']?.toString() ?? '',
    textEn: map['textEn']?.toString() ?? '',
    profileId: map['profileId']?.toString() ?? 'aventurero',
    emoji: map['emoji']?.toString() ?? '🍽️',
  );
}

class QuizQuestion {
  final String id;
  final int order;
  final String titleEs;
  final String titleEn;
  final String imageUrl;
  final List<QuizOption> options;

  QuizQuestion({
    required this.id,
    required this.order,
    required this.titleEs,
    required this.titleEn,
    required this.imageUrl,
    required this.options,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'order': order,
    'titleEs': titleEs,
    'titleEn': titleEn,
    'imageUrl': imageUrl,
    'options': options.map((o) => o.toMap()).toList(),
  };

  factory QuizQuestion.fromMap(Map<String, dynamic> map, String docId) => QuizQuestion(
    id: docId,
    order: map['order'] is int ? map['order'] as int : int.tryParse(map['order']?.toString() ?? '0') ?? 0,
    titleEs: map['titleEs']?.toString() ?? '',
    titleEn: map['titleEn']?.toString() ?? '',
    imageUrl: map['imageUrl']?.toString() ?? '',
    options: (map['options'] as List<dynamic>? ?? [])
        .map((o) => QuizOption.fromMap(Map<String, dynamic>.from(o as Map)))
        .toList(),
  );

  QuizQuestion copyWith({
    String? id,
    int? order,
    String? titleEs,
    String? titleEn,
    String? imageUrl,
    List<QuizOption>? options,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      order: order ?? this.order,
      titleEs: titleEs ?? this.titleEs,
      titleEn: titleEn ?? this.titleEn,
      imageUrl: imageUrl ?? this.imageUrl,
      options: options ?? this.options,
    );
  }
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

final List<QuizQuestion> defaultQuizQuestions = [
  QuizQuestion(
    id: 'default_q1',
    order: 1,
    titleEs: 'Es domingo por la mañana y el cuerpo lo sabe, ¿qué te pide el estómago?',
    titleEn: 'It is Sunday morning, what is your stomach craving?',
    imageUrl: 'https://images.unsplash.com/photo-1547592180-85f173990554?w=800&auto=format&fit=crop&q=80',
    options: [
      QuizOption(
        id: 'q1_o1',
        textEs: 'Un caldito caliente "levanta muertos"',
        textEn: 'A hot "reviving" broth',
        profileId: 'sopero',
        emoji: '🥣',
      ),
      QuizOption(
        id: 'q1_o2',
        textEs: 'Un hornado o fritada con harto mote',
        textEn: 'A big plate of roast pork and mote',
        profileId: 'carnivoro',
        emoji: '🍖',
      ),
      QuizOption(
        id: 'q1_o3',
        textEs: 'Algo dulce, quesadilla o pan con café',
        textEn: 'Something sweet with hot fresh coffee',
        profileId: 'dulcero',
        emoji: '☕',
      ),
      QuizOption(
        id: 'q1_o4',
        textEs: 'Lo más auténtico que haya en el mercado',
        textEn: 'Whatever authentic spot the local market has',
        profileId: 'aventurero',
        emoji: '🎪',
      ),
    ],
  ),
  QuizQuestion(
    id: 'default_q2',
    order: 2,
    titleEs: 'Seamos sinceros... ¿qué tanto ají le pones a la comida?',
    titleEn: 'Be honest... how much spicy sauce do you add?',
    imageUrl: 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=800&auto=format&fit=crop&q=80',
    options: [
      QuizOption(
        id: 'q2_o1',
        textEs: 'Cero ají, prefiero cuidar mi estómago',
        textEn: 'No spicy sauce, prefer to protect my stomach',
        profileId: 'picador',
        emoji: '🛑',
      ),
      QuizOption(
        id: 'q2_o2',
        textEs: 'Solo un chorrito para realzar el caldo',
        textEn: 'Just a few drops to bring out the soup flavor',
        profileId: 'sopero',
        emoji: '🤏',
      ),
      QuizOption(
        id: 'q2_o3',
        textEs: 'En las papas o hamburguesas, ¡bastante!',
        textEn: 'On fries or street burgers, plenty of it!',
        profileId: 'callejero',
        emoji: '🍟',
      ),
      QuizOption(
        id: 'q2_o4',
        textEs: '¡Póngale ají de la casa con pepa y con todo!',
        textEn: 'Put the house spicy sauce with seeds and all!',
        profileId: 'aventurero',
        emoji: '🔥',
      ),
    ],
  ),
  QuizQuestion(
    id: 'default_q3',
    order: 3,
    titleEs: '¿Qué ambiente prefieres para comer bien rico?',
    titleEn: 'What atmosphere do you prefer for great food?',
    imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&auto=format&fit=crop&q=80',
    options: [
      QuizOption(
        id: 'q3_o1',
        textEs: 'El mercado popular, bullicioso y auténtico',
        textEn: 'The traditional market, buzzing and lively',
        profileId: 'aventurero',
        emoji: '🗣️',
      ),
      QuizOption(
        id: 'q3_o2',
        textEs: 'Una hueca clásica de barrio, tranquilo',
        textEn: 'A cozy neighborhood spot, relaxing vibe',
        profileId: 'picador',
        emoji: '🏡',
      ),
      QuizOption(
        id: 'q3_o3',
        textEs: 'Al paso, rápido y contundente sin rodeos',
        textEn: 'Quick street counter, fast and hearty',
        profileId: 'callejero',
        emoji: '⚡',
      ),
      QuizOption(
        id: 'q3_o4',
        textEs: 'Una cafetería con aroma a pan recién horneado',
        textEn: 'A quiet bakery with fresh baked aromas',
        profileId: 'dulcero',
        emoji: '🥐',
      ),
    ],
  ),
  QuizQuestion(
    id: 'default_q4',
    order: 4,
    titleEs: 'Para cerrar con broche de oro, tu plan ideal es:',
    titleEn: 'To top off the day, your ideal plan is:',
    imageUrl: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=800&auto=format&fit=crop&q=80',
    options: [
      QuizOption(
        id: 'q4_o1',
        textEs: 'Helado de paila o postrecito en La Ronda',
        textEn: 'Paila ice cream or dessert in historic downtown',
        profileId: 'dulcero',
        emoji: '🍦',
      ),
      QuizOption(
        id: 'q4_o2',
        textEs: 'Salir tarde y rematar con pollo broaster o alitas',
        textEn: 'Late night out and finish with crispy fried chicken',
        profileId: 'callejero',
        emoji: '🍗',
      ),
      QuizOption(
        id: 'q4_o3',
        textEs: 'Ir por una fritada con cuero reventado o asado',
        textEn: 'Feast on crispy pork fritada or prime BBQ',
        profileId: 'carnivoro',
        emoji: '🥩',
      ),
      QuizOption(
        id: 'q4_o4',
        textEs: 'Picar empanadas de viento con morocho caliente',
        textEn: 'Nibble cheese empanadas with sweet spiced morocho',
        profileId: 'picador',
        emoji: '🥟',
      ),
    ],
  ),
];
