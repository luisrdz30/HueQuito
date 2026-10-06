import os

filepath = 'lib/screens/profile_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the Seed routes button
seed_button = "SizedBox(height: 16),\n                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => seedRoutes(context), child: Text('Seed 3 Routes (Dev)'))),"
if seed_button in content:
    content = content.replace(seed_button, "")
else:
    # try a more relaxed replacement
    import re
    content = re.sub(r"SizedBox\(height:\s*16\),\s*SizedBox\(width:\s*double\.infinity,\s*child:\s*ElevatedButton\(onPressed:\s*\(\)\s*=>\s*seedRoutes\(context\),\s*child:\s*Text\('Seed 3 Routes \(Dev\)'\)\)\),", "", content)

# Check if `langCode` is defined for simple ternary or if we use `lang['key']` map.
# Looking at the code, it uses a map: `final Map<String, String> lang = ...` but it also uses `final langCode = ref.watch(settingsProvider).language;` implicitly?
# Let's check how lang is defined. It probably defines `final langCode = ref.watch(settingsProvider).language;` or just uses a local `lang` Map.
# We will just replace Text('Huecas') with `Text(ref.read(settingsProvider).language == 'es' ? 'Huecas' : 'Spots')` etc.
# Actually, since it's inside `build`, `ref.watch(settingsProvider).language` is best.
# Let's see if `langCode` or similar exists.

# Just do direct string replace
content = content.replace("Text('Huecas', style: TextStyle(fontSize: 10, color: Colors.grey))", "Text(ref.watch(settingsProvider).language == 'es' ? 'Huecas' : 'Spots', style: TextStyle(fontSize: 10, color: Colors.grey))")
content = content.replace("Text('Favoritos', style: TextStyle(fontSize: 10, color: Colors.grey))", "Text(ref.watch(settingsProvider).language == 'es' ? 'Favoritos' : 'Favorites', style: TextStyle(fontSize: 10, color: Colors.grey))")
content = content.replace("Text('Premios', style: TextStyle(fontSize: 10, color: Colors.grey))", "Text(ref.watch(settingsProvider).language == 'es' ? 'Premios' : 'Rewards', style: TextStyle(fontSize: 10, color: Colors.grey))")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
