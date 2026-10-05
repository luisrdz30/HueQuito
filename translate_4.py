import os

file_path = 'lib/screens/route_map_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = {
    "Text('Error al cargar mapa'": "Text(lang == 'es' ? 'Error al cargar mapa' : 'Error loading map'",
    "Text(_selectedSector == 'Todos' ? 'Mostrando todo' : _selectedSector": "Text(_selectedSector == 'Todos' ? (lang == 'es' ? 'Mostrando todo' : 'Showing all') : _selectedSector",
    "Text('$count huecas'": "Text('$count ${lang == 'es' ? 'huecas' : 'spots'}'",
    "Text('0 huecas'": "Text(lang == 'es' ? '0 huecas' : '0 spots'",
    "Text('Abierto'": "Text(lang == 'es' ? 'Abierto' : 'Open'",
    "Text('Cómo llegar'": "Text(lang == 'es' ? 'Cómo llegar' : 'Directions'",
    "Text('Ver Ficha'": "Text(lang == 'es' ? 'Ver Hueca' : 'View Spot'",
    "Text('Inicia sesión para guardar favoritos'": "Text(lang == 'es' ? 'Inicia sesión para guardar favoritos' : 'Log in to save favorites'"
}

for es, en in replacements.items():
    content = content.replace(es, en)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
