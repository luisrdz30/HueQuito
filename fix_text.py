import os

filepath = 'lib/screens/route_list_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

original_str = "lang == 'es' ? 'Recorridos a pie curados para saborear Quito' : 'Curated walking tours to savor Quito'"
new_str = "lang == 'es' ? 'Recorridos para saborear Quito' : 'Tours to savor Quito'"

content = content.replace(original_str, new_str)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
