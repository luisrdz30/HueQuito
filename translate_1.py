import os

file_path = 'lib/screens/route_list_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = {
    "'Lista de circuitos'": "lang == 'es' ? 'Lista de circuitos' : 'Tour List'",
    "'Mapa interactivo'": "lang == 'es' ? 'Mapa interactivo' : 'Interactive Map'",
    "['Todos']": "[lang == 'es' ? 'Todos' : 'All']",
    "'¿Prefieres explorar libremente sin ruta fija?'": "lang == 'es' ? '¿Prefieres explorar libremente sin ruta fija?' : 'Prefer exploring freely without a fixed route?'",
    "'Toca \"Mapa interactivo\" arriba o filtra para ver todas las huecas directamente en el mapa por sector.'": "lang == 'es' ? 'Toca \"Mapa interactivo\" arriba o filtra para ver todas las huecas directamente en el mapa por sector.' : 'Tap \"Interactive Map\" above or filter to see all spots directly on the map by sector.'",
    "'Circuito Popular'": "lang == 'es' ? 'Circuito Popular' : 'Popular Tour'",
    "'PARADAS DEL RECORRIDO'": "lang == 'es' ? 'PARADAS DEL RECORRIDO' : 'TOUR STOPS'",
    "'Ver Tour'": "lang == 'es' ? 'Ver Tour' : 'View Tour'",
    "'Iniciar Ruta'": "lang == 'es' ? 'Iniciar Ruta' : 'Start Route'"
}

for es, en in replacements.items():
    content = content.replace(es, en)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
