import os

file_path = 'lib/screens/hueca_detail_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = {
    "Text('Menú'": "Text(lang == 'es' ? 'Menú' : 'Menu'",
    "Text('Especialidades'": "Text(lang == 'es' ? 'Especialidades' : 'Specialties'",
    "Text('Plato Insignia'": "Text(lang == 'es' ? 'Plato Insignia' : 'Signature Dish'",
    "Text('Horarios'": "Text(lang == 'es' ? 'Horarios' : 'Hours'",
    "Text('Guardar'": "Text(lang == 'es' ? 'Guardar' : 'Save'",
    "Text('Eliminar'": "Text(lang == 'es' ? 'Eliminar' : 'Remove'"
}

for es, en in replacements.items():
    content = content.replace(es, en)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
