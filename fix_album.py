with open('lib/screens/album_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

c = c.replace("Text('Cartillas por Hueca'", "Text(lang == 'es' ? 'Cartillas por Hueca' : 'Cards by Spot'")
c = c.replace("Text('Cromos por Sector'", "Text(lang == 'es' ? 'Cromos por Sector' : 'Stickers by Sector'")
c = c.replace("?? 'Novato'", "?? (lang == 'es' ? 'Novato' : 'Rookie')")
c = c.replace("Text('Error cargando cartillas')", "Text(lang == 'es' ? 'Error cargando cartillas' : 'Error loading cards')")

with open('lib/screens/album_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
