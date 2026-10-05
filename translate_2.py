import os

file_path = 'lib/screens/hueca_detail_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = {
    "const Text('Deja tu opinión'": "Text(lang == 'es' ? 'Deja tu opinión' : 'Leave your review'",
    "const SnackBar(content: Text('¡Gracias por tu opinión!'))": "SnackBar(content: Text(lang == 'es' ? '¡Gracias por tu opinión!' : 'Thanks for your review!'))",
    "Text('Error al enviar reseña: $e')": "Text(lang == 'es' ? 'Error al enviar reseña: $e' : 'Error submitting review: $e')",
    "const Text('Enviar Reseña')": "Text(lang == 'es' ? 'Enviar Reseña' : 'Submit Review')",
    "Text('Error al cargar reseñas.')": "Text(lang == 'es' ? 'Error al cargar reseñas.' : 'Error loading reviews.')",
    "Text('Sé el primero en dejar una opinión sobre este local.'": "Text(lang == 'es' ? 'Sé el primero en dejar una opinión sobre este local.' : 'Be the first to leave a review for this spot.'",
    "Text('No hay mapas instalados')": "Text(lang == 'es' ? 'No hay mapas instalados' : 'No maps installed')",
    "Text('Abrir ubicación con'": "Text(lang == 'es' ? 'Abrir ubicación con' : 'Open location with'",
    "Text(!_isFavorite ? 'Añadido a favoritos' : 'Eliminado de favoritos')": "Text(!_isFavorite ? (lang == 'es' ? 'Añadido a favoritos' : 'Added to favorites') : (lang == 'es' ? 'Eliminado de favoritos' : 'Removed from favorites'))"
}

for es, en in replacements.items():
    content = content.replace(es, en)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
