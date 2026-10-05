import os

file_path = 'lib/screens/route_navigation_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = {
    "Text('A pie'": "Text(lang == 'es' ? 'A pie' : 'Walking'",
    "Text('En carro'": "Text(lang == 'es' ? 'En carro' : 'Driving'",
    "Text('Indicaciones'": "Text(lang == 'es' ? 'Indicaciones' : 'Directions'",
    "Text('Calculando ruta...'": "Text(lang == 'es' ? 'Calculando ruta...' : 'Calculating route...'",
    "Text('Ir con Google Maps'": "Text(lang == 'es' ? 'Ir con Google Maps' : 'Open in Google Maps'"
}

for es, en in replacements.items():
    content = content.replace(es, en)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
