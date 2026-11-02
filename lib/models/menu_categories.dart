/// Categorías de platos del menú. El dueño puede crear otras; estas son las
/// sugeridas (y las que usa Gemini al leer una carta).
class MenuCategory {
  final String id;
  final String nameEn;
  final String emoji;

  const MenuCategory(this.id, this.nameEn, this.emoji);

  String name(bool isEn) => isEn ? nameEn : id;
}

const List<MenuCategory> defaultMenuCategories = [
  MenuCategory('Desayunos', 'Breakfast', '🍳'),
  MenuCategory('Entradas', 'Starters', '🥟'),
  MenuCategory('Sopas y Caldos', 'Soups', '🍲'),
  MenuCategory('Platos Fuertes', 'Main Dishes', '🍛'),
  MenuCategory('Platos Típicos', 'Traditional Dishes', '⭐'),
  MenuCategory('Especialidades', 'Specialties', '👨‍🍳'),
  MenuCategory('Panadería', 'Bakery', '🥖'),
  MenuCategory('Postres', 'Desserts', '🍰'),
  MenuCategory('Bebidas', 'Drinks', '🥤'),
  MenuCategory('Otros', 'Others', '🍽️'),
];

List<String> get defaultMenuCategoryIds => defaultMenuCategories.map((c) => c.id).toList();

/// Nombres viejos que se muestran agrupados con la categoría actual.
const Map<String, String> _legacyCategories = {
  'Sopas': 'Sopas y Caldos',
  'Caldos': 'Sopas y Caldos',
  'Entradas y Guarniciones': 'Entradas',
  'Guarniciones': 'Entradas',
};

String dishCategory(dynamic dish) {
  final raw = (dish is Map ? dish['category']?.toString().trim() : null) ?? '';
  if (raw.isEmpty) return 'Otros';
  return _legacyCategories[raw] ?? raw;
}

MenuCategory? menuCategoryById(String id) {
  for (final c in defaultMenuCategories) {
    if (c.id == id) return c;
  }
  return null;
}

String menuCategoryLabel(String id, bool isEn) {
  final c = menuCategoryById(id);
  return c == null ? id : '${c.emoji} ${c.name(isEn)}';
}

/// Categorías presentes en un menú: primero las sugeridas en su orden, luego las propias del dueño.
List<String> menuCategoriesOf(List<dynamic> items) {
  final present = items.map(dishCategory).toSet();
  return [
    ...defaultMenuCategoryIds.where(present.contains),
    ...(present.where((c) => menuCategoryById(c) == null).toList()..sort()),
  ];
}
