import os

filepath = 'lib/screens/map_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

original_url = "urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',"
new_url = "urlTemplate: Theme.of(context).brightness == Brightness.dark ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',"

content = content.replace(original_url, new_url)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
