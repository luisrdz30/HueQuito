import os

file_path = 'lib/screens/home_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("'Ver Hueca'", "lang == 'es' ? 'Ver Hueca' : 'View Spot'")
content = content.replace("'Cómo llegar'", "lang == 'es' ? 'Cómo llegar' : 'Directions'")

content = content.replace("const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(lang == 'es'", "Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(lang == 'es'")
content = content.replace("const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions, size: 16), SizedBox(width: 4), Text(lang == 'es'", "Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions, size: 16), SizedBox(width: 4), Text(lang == 'es'")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
